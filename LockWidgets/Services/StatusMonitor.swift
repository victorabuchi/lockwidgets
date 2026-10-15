import AppKit
import CoreAudio
import CoreMediaIO
import CoreWLAN
import Darwin

/// Hotspot, calls and meetings: system states the island shows while they last.
final class StatusMonitor: ObservableObject {
    static let shared = StatusMonitor()

    /// Network name when the Mac is joined to an iPhone's Personal Hotspot.
    @Published private(set) var hotspot: String?
    @Published private(set) var isOnHotspot = false

    struct Meeting: Equatable {
        let app: String
        let bundleID: String?
        let started: Date
        var microphone: Bool
        var camera: Bool
    }

    @Published private(set) var meeting: Meeting?

    private var timer: Timer?

    private init() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        // iPhone hotspots hand out addresses in 172.20.10.0/28.
        let onHotspot = Self.ipv4Addresses().contains { $0.hasPrefix("172.20.10.") }
        if onHotspot != isOnHotspot { isOnHotspot = onHotspot }
        let name = onHotspot ? (CWWiFiClient.shared().interface()?.ssid() ?? "iPhone") : nil
        if name != hotspot { hotspot = name }

        let microphone = Self.microphoneInUse()
        let camera = Self.cameraInUse()
        let zoomMeeting = Self.processRunning("CptHost")
        var next: Meeting?
        if zoomMeeting {
            next = Meeting(app: "Zoom", bundleID: "us.zoom.xos", started: meeting?.app == "Zoom" ? meeting!.started : .now, microphone: microphone, camera: camera)
        } else if microphone || camera, let app = Self.callApp() {
            next = Meeting(app: app.name, bundleID: app.bundleID, started: meeting?.app == app.name ? meeting!.started : .now, microphone: microphone, camera: camera)
        }
        if next != meeting { meeting = next }
    }

    /// Calls and meeting apps that may be using the mic or camera, most specific first.
    private static let callApps: [(bundleID: String, name: String)] = [
        ("us.zoom.xos", "Zoom"),
        ("com.apple.FaceTime", "FaceTime"),
        ("com.microsoft.teams2", "Teams"),
        ("com.microsoft.teams", "Teams"),
        ("com.cisco.webexmeetingsapp", "Webex"),
        ("com.hnc.Discord", "Discord"),
        ("com.tinyspeck.slackmacgap", "Slack"),
        ("net.whatsapp.WhatsApp", "WhatsApp"),
        ("com.google.Chrome", "Google Meet"),
    ]

    private static func callApp() -> (name: String, bundleID: String)? {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        return callApps.first { running.contains($0.bundleID) }.map { ($0.name, $0.bundleID) }
    }

    // MARK: Zoom controls

    /// Sends one of Zoom's own shortcuts: ⌘⇧A toggles the microphone, ⌘⇧V the camera.
    static func sendZoomShortcut(_ key: CGKeyCode) {
        guard let zoom = NSRunningApplication.runningApplications(withBundleIdentifier: "us.zoom.xos").first else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down)
            event?.flags = [.maskCommand, .maskShift]
            event?.postToPid(zoom.processIdentifier)
        }
    }

    static let zoomMuteKey: CGKeyCode = 0x00 // A
    static let zoomVideoKey: CGKeyCode = 0x09 // V

    // MARK: System probes

    private static func ipv4Addresses() -> [String] {
        var results: [String] = []
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0 else { return [] }
        defer { freeifaddrs(addresses) }
        var pointer = addresses
        while let entry = pointer?.pointee {
            if entry.ifa_addr?.pointee.sa_family == UInt8(AF_INET) {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(entry.ifa_addr, socklen_t(entry.ifa_addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    results.append(String(cString: host))
                }
            }
            pointer = entry.ifa_next
        }
        return results
    }

    private static func processRunning(_ name: String) -> Bool {
        var pids = [pid_t](repeating: 0, count: 4096)
        let count = Int(proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.size * pids.count)))
        var buffer = [CChar](repeating: 0, count: 256)
        for pid in pids.prefix(max(count, 0)) where pid > 0 {
            if proc_name(pid, &buffer, UInt32(buffer.count)) > 0, String(cString: buffer) == name {
                return true
            }
        }
        return false
    }

    private static func microphoneInUse() -> Bool {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr else { return false }
        var running = UInt32(0)
        size = UInt32(MemoryLayout<UInt32>.size)
        address.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr else { return false }
        return running != 0
    }

    private static func cameraInUse() -> Bool {
        var address = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices), mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal), mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, &size) == 0 else { return false }
        var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, size, &used, &devices) == 0 else { return false }
        for device in devices {
            var running: UInt32 = 0
            var runningAddress = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere), mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard), mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard))
            var dataUsed: UInt32 = 0
            if CMIOObjectGetPropertyData(device, &runningAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &dataUsed, &running) == 0, running != 0 {
                return true
            }
        }
        return false
    }
}
