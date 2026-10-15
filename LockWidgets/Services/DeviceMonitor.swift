import AppKit
import CoreAudio
import IOBluetooth

/// Bluetooth connections, volume, brightness and Focus: the system changes the island reports briefly.
final class DeviceMonitor: NSObject {
    static let shared = DeviceMonitor()

    enum Event {
        case device(name: String, symbol: String, connected: Bool)
        case volume(level: Double, muted: Bool)
        case brightness(level: Double)
        case focus(name: String, symbol: String, on: Bool)
    }

    /// Called on the main queue.
    var onEvent: ((Event) -> Void)?

    private var connectNotification: IOBluetoothUserNotification?
    private var startedAt = Date()
    private var outputDevice = AudioDeviceID(0)
    private var lastVolume: (Double, Bool)?
    private var lastBrightness: Float?
    private var lastFocus: String?
    private var pollTimer: Timer?

    func start() {
        startedAt = .now
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(connected(_:device:)))
        watchVolume()
        lastFocus = Self.activeFocus()?.id ?? ""
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.pollBrightness()
        }
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.pollFocus()
        }
    }

    // MARK: Bluetooth

    @objc private func connected(_: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        device.register(forDisconnectNotification: self, selector: #selector(disconnected(_:device:)))
        // Registering reports devices that were already connected; only announce new ones.
        guard Date.now.timeIntervalSince(startedAt) > 3 else { return }
        report(device, connected: true)
    }

    @objc private func disconnected(_: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        report(device, connected: false)
    }

    private func report(_ device: IOBluetoothDevice, connected: Bool) {
        let name = device.name ?? "Bluetooth device"
        onEvent?(.device(name: name, symbol: Self.symbol(for: device), connected: connected))
    }

    private static func symbol(for device: IOBluetoothDevice) -> String {
        let name = (device.name ?? "").lowercased()
        if name.contains("airpods pro") { return "airpodspro" }
        if name.contains("airpods max") { return "airpodsmax" }
        if name.contains("airpods") { return "airpods" }
        if name.contains("beats") { return "beats.headphones" }
        switch device.deviceClassMajor {
        case 0x04: return "headphones"
        case 0x05:
            if name.contains("mouse") { return "magicmouse.fill" }
            if name.contains("trackpad") { return "rectangle.and.hand.point.up.left.fill" }
            return "keyboard.fill"
        case 0x02: return "iphone"
        default: return "dot.radiowaves.left.and.right"
        }
    }

    // MARK: Volume

    private func watchVolume() {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main) { [weak self] _, _ in
            self?.attachToOutputDevice()
        }
        attachToOutputDevice()
    }

    private func attachToOutputDevice() {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr, device != outputDevice else { return }
        outputDevice = device
        lastVolume = readVolume()
        for selector in [kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyMute] {
            for element in [kAudioObjectPropertyElementMain, 1, 2] {
                var property = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: element)
                if AudioObjectHasProperty(device, &property) {
                    AudioObjectAddPropertyListenerBlock(device, &property, .main) { [weak self] _, _ in
                        self?.volumeChanged()
                    }
                }
            }
        }
    }

    private func readVolume() -> (Double, Bool)? {
        var volume = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        var found = false
        for element in [kAudioObjectPropertyElementMain, 1] {
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: element)
            if AudioObjectGetPropertyData(outputDevice, &address, 0, nil, &size, &volume) == noErr {
                found = true
                break
            }
        }
        guard found else { return nil }
        var muted = UInt32(0)
        size = UInt32(MemoryLayout<UInt32>.size)
        var muteAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(outputDevice, &muteAddress, 0, nil, &size, &muted)
        return (Double(volume), muted != 0)
    }

    private func volumeChanged() {
        guard let current = readVolume() else { return }
        if let last = lastVolume, abs(last.0 - current.0) < 0.001, last.1 == current.1 { return }
        lastVolume = current
        onEvent?(.volume(level: current.0, muted: current.1))
    }

    // MARK: Brightness

    /// DisplayServices is private, but it is the only way to read the built-in display's brightness.
    private static let getBrightness: (@convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32)? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
              let symbol = dlsym(handle, "DisplayServicesGetBrightness")
        else { return nil }
        return unsafeBitCast(symbol, to: (@convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32).self)
    }()

    private func pollBrightness() {
        guard let getBrightness = Self.getBrightness else { return }
        var level = Float(0)
        guard getBrightness(CGMainDisplayID(), &level) == 0 else { return }
        defer { lastBrightness = level }
        guard let last = lastBrightness, abs(last - level) > 0.004 else { return }
        onEvent?(.brightness(level: Double(level)))
    }

    // MARK: Focus

    private struct Focus {
        let id: String
        let name: String
        let symbol: String
    }

    /// Reads which Focus is on from the files macOS keeps for it (they need Full Disk Access).
    private static func activeFocus() -> Focus? {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/DoNotDisturb/DB")
        guard let assertions = json(folder.appendingPathComponent("Assertions.json")),
              let records = ((assertions["data"] as? [[String: Any]])?.first?["storeAssertionRecords"] as? [[String: Any]]),
              let details = records.last?["assertionDetails"] as? [String: Any],
              let id = details["assertionDetailsModeIdentifier"] as? String
        else { return nil }
        var name = "Focus"
        var symbol = "moon.fill"
        if let configurations = json(folder.appendingPathComponent("ModeConfigurations.json")),
           let modes = (configurations["data"] as? [[String: Any]])?.first?["modeConfigurations"] as? [String: Any],
           let mode = (modes[id] as? [String: Any])?["mode"] as? [String: Any]
        {
            name = mode["name"] as? String ?? name
            symbol = mode["symbolImageName"] as? String ?? symbol
        }
        return Focus(id: id, name: name, symbol: symbol)
    }

    private static func json(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private var lastFocusInfo: Focus?

    private func pollFocus() {
        let focus = Self.activeFocus()
        let id = focus?.id ?? ""
        guard let last = lastFocus, last != id else {
            lastFocus = id
            if let focus { lastFocusInfo = focus }
            return
        }
        lastFocus = id
        if let focus {
            lastFocusInfo = focus
            onEvent?(.focus(name: focus.name, symbol: focus.symbol, on: true))
        } else {
            onEvent?(.focus(name: lastFocusInfo?.name ?? "Focus", symbol: lastFocusInfo?.symbol ?? "moon.fill", on: false))
        }
    }
}
