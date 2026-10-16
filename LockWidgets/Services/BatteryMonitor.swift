import Foundation
import IOKit.ps

/// The internal battery: macOS reports the charger going in or out the moment it happens, and the level is read
/// again every 30 seconds. `level` stays nil on Macs without one.
final class BatteryMonitor: ObservableObject {
    static let shared = BatteryMonitor()

    @Published private(set) var level: Int?
    @Published private(set) var isCharging = false
    @Published private(set) var isPluggedIn = false
    /// Minutes to full while charging, otherwise minutes to empty. nil while macOS is still estimating.
    @Published private(set) var minutesRemaining: Int?

    private var timer: Timer?
    private var powerSource: CFRunLoopSource?

    private init() {
        refresh()
        // Plugging in dims or brightens the screen straight away, so the island needs to hear about the charger at
        // once, not at the next poll, to show the charging alert instead of the brightness change.
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue().refresh()
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            powerSource = source
        }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else {
            level = nil
            return
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
            else { continue }

            let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let capacity = description[kIOPSMaxCapacityKey] as? Int ?? 100
            level = current * 100 / Swift.max(capacity, 1)
            isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
            isPluggedIn = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue

            let key = isCharging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
            let minutes = description[key] as? Int ?? -1
            minutesRemaining = minutes > 0 ? minutes : nil
            return
        }
        level = nil
    }
}

#if DEBUG
extension BatteryMonitor {
    func loadSample() {
        level = 84
        isCharging = false
        isPluggedIn = false
        minutesRemaining = 289
    }
}
#endif
