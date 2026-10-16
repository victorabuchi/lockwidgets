import Darwin
import Foundation

/// Samples CPU, memory, network and disk every few seconds, keeping a short history for sparklines.
final class SystemMonitor: ObservableObject {
    static let shared = SystemMonitor()

    struct Sample {
        var cpu: Double = 0
        var memory: Double = 0
        var memoryUsedGB: Double = 0
        var memoryTotalGB: Double = 0
        var download: Double = 0
        var upload: Double = 0
        var diskFreeGB: Double = 0
        var diskTotalGB: Double = 0
        var load: Double = 0
        var uptime: TimeInterval = 0
    }

    @Published private(set) var current = Sample()
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var memoryHistory: [Double] = []
    @Published private(set) var networkHistory: [Double] = []

    private var timer: Timer?
    private var previousTicks: (used: UInt64, total: UInt64)?
    private var previousBytes: (received: UInt64, sent: UInt64, date: Date)?
    private let historyLength = 30

    private init() {
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.sample()
        }
    }

    private func sample() {
        var next = Sample()
        next.cpu = cpuUsage()
        (next.memory, next.memoryUsedGB, next.memoryTotalGB) = memoryUsage()
        (next.download, next.upload) = networkRates()
        (next.diskFreeGB, next.diskTotalGB) = diskSpace()
        var loads = [Double](repeating: 0, count: 3)
        getloadavg(&loads, 3)
        next.load = loads[0]
        next.uptime = ProcessInfo.processInfo.systemUptime
        current = next

        append(&cpuHistory, next.cpu)
        append(&memoryHistory, next.memory)
        append(&networkHistory, next.download + next.upload)
    }

    private func append(_ history: inout [Double], _ value: Double) {
        history.append(value)
        if history.count > historyLength { history.removeFirst(history.count - historyLength) }
    }

    private func cpuUsage() -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let user = UInt64(info.cpu_ticks.0)
        let system = UInt64(info.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2)
        let nice = UInt64(info.cpu_ticks.3)
        let used = user + system + nice
        let total = used + idle
        defer { previousTicks = (used, total) }
        guard let previous = previousTicks, total > previous.total else { return 0 }
        return Double(used - previous.used) / Double(total - previous.total)
    }

    private func memoryUsage() -> (Double, Double, Double) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        guard result == KERN_SUCCESS, total > 0 else { return (0, 0, total / 1e9) }
        let page = Double(vm_kernel_page_size)
        let used = (Double(stats.active_count) + Double(stats.wire_count) + Double(stats.compressor_page_count)) * page
        return (used / total, used / 1_073_741_824, total / 1_073_741_824)
    }

    private func networkRates() -> (Double, Double) {
        var received: UInt64 = 0
        var sent: UInt64 = 0
        var addresses: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&addresses) == 0 {
            var pointer = addresses
            while let entry = pointer?.pointee {
                let name = String(cString: entry.ifa_name)
                if entry.ifa_addr?.pointee.sa_family == UInt8(AF_LINK), name.hasPrefix("en"),
                   let data = entry.ifa_data?.assumingMemoryBound(to: if_data.self).pointee
                {
                    received += UInt64(data.ifi_ibytes)
                    sent += UInt64(data.ifi_obytes)
                }
                pointer = entry.ifa_next
            }
            freeifaddrs(addresses)
        }
        let now = Date()
        defer { previousBytes = (received, sent, now) }
        guard let previous = previousBytes, received >= previous.received, sent >= previous.sent else { return (0, 0) }
        let seconds = max(now.timeIntervalSince(previous.date), 0.1)
        return (Double(received - previous.received) / seconds, Double(sent - previous.sent) / seconds)
    }

    private func diskSpace() -> (Double, Double) {
        let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
        let free = Double(values?.volumeAvailableCapacityForImportantUsage ?? 0)
        let total = Double(values?.volumeTotalCapacity ?? 0)
        return (free / 1e9, total / 1e9)
    }
}

extension Double {
    /// Bytes per second as "2.5 MB/s".
    var rateText: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .file) + "/s"
    }
}

#if DEBUG
extension SystemMonitor {
    func loadSample() {
        current = Sample(cpu: 0.16, memory: 0.64, memoryUsedGB: 10.3, memoryTotalGB: 16, download: 2_150_000, upload: 240_000, diskFreeGB: 312, diskTotalGB: 494, load: 1.8, uptime: 29 * 3600)
        cpuHistory = (0 ..< 60).map { (index: Int) -> Double in
            let spike: Double = index % 9 == 0 ? 0.1 : 0
            return 0.12 + 0.08 * abs(sin(Double(index) * 0.7)) + spike
        }
        memoryHistory = (0 ..< 60).map { (index: Int) -> Double in 0.62 + 0.02 * sin(Double(index) * 0.2) }
        networkHistory = (0 ..< 60).map { (index: Int) -> Double in
            index % 17 == 5 ? 2_150_000 : 120_000 + 60_000 * abs(sin(Double(index)))
        }
    }
}
#endif
