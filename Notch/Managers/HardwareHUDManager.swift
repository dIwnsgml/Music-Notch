import Foundation
import Combine
import Darwin
import IOKit

struct HardwareHUDSnapshot: Equatable {
    var cpuCores: [Double] = []
    var memoryUsedBytes: UInt64 = 0
    var memoryTotalBytes: UInt64 = ProcessInfo.processInfo.physicalMemory
    var temperatureCelsius: Double? = nil
    var thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    var updatedAt: Date = Date()

    var cpuAverage: Double {
        guard !cpuCores.isEmpty else { return 0 }
        return cpuCores.reduce(0, +) / Double(cpuCores.count)
    }

    var memoryPressure: Double {
        guard memoryTotalBytes > 0 else { return 0 }
        return min(max(Double(memoryUsedBytes) / Double(memoryTotalBytes), 0), 1)
    }
}

final class HardwareHUDManager: ObservableObject {
    static let shared = HardwareHUDManager()

    @Published private(set) var snapshot = HardwareHUDSnapshot()

    private let workQueue = DispatchQueue(label: "com.wavenotch.hardware-hud", qos: .utility)
    private var timer: Timer?
    private var defaultsObserver: NSObjectProtocol?
    private var previousCPULoad: [[UInt64]] = []
    private var smcReader = SMCReader()
    private var currentRefreshInterval: TimeInterval = 2
    private let temperatureRefreshInterval: TimeInterval = 10
    private var lastTemperatureRead = Date(timeIntervalSince1970: 0)
    private var cachedTemperatureCelsius: Double?
    private var isRefreshing = false
    private var isDashboardVisible = false

    private init() {
        currentRefreshInterval = Self.refreshIntervalFromDefaults()

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restartTimerIfNeeded()
        }
    }

    deinit {
        timer?.invalidate()
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    func setDashboardVisible(_ visible: Bool) {
        guard isDashboardVisible != visible else { return }
        isDashboardVisible = visible

        if visible {
            startTimer()
            refresh()
        } else {
            timer?.invalidate()
            timer = nil
        }
    }

    func refresh() {
        workQueue.async { [weak self] in
            guard let self, !self.isRefreshing else { return }
            self.isRefreshing = true
            let nextSnapshot = self.collectSnapshot()
            self.isRefreshing = false

            DispatchQueue.main.async {
                self.snapshot = nextSnapshot
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()

        guard Self.isPluginEnabled, isDashboardVisible else {
            timer = nil
            return
        }

        let timer = Timer(timeInterval: currentRefreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = max(0.2, currentRefreshInterval * 0.25)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func restartTimerIfNeeded() {
        guard Self.isPluginEnabled, isDashboardVisible else {
            timer?.invalidate()
            timer = nil
            return
        }

        let interval = Self.refreshIntervalFromDefaults()
        guard timer == nil || abs(interval - currentRefreshInterval) > 0.01 else { return }
        currentRefreshInterval = interval
        startTimer()
    }

    private static var isPluginEnabled: Bool {
        UserDefaults.standard.bool(forKey: "plugin_hardware_hud_enabled")
    }

    private static func refreshIntervalFromDefaults() -> TimeInterval {
        let raw = UserDefaults.standard.double(forKey: "hardware_hud_refresh_interval")
        if raw == 0 { return 2 }
        return min(max(raw, 1), 10)
    }

    private func collectSnapshot() -> HardwareHUDSnapshot {
        HardwareHUDSnapshot(
            cpuCores: readCPUCoreUsage(),
            memoryUsedBytes: readMemoryUsedBytes(),
            memoryTotalBytes: ProcessInfo.processInfo.physicalMemory,
            temperatureCelsius: readInternalTemperatureIfNeeded(),
            thermalState: ProcessInfo.processInfo.thermalState,
            updatedAt: Date()
        )
    }

    private func readCPUCoreUsage() -> [Double] {
        var processorInfo: processor_info_array_t?
        var processorCount: natural_t = 0
        var processorInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorInfoCount
        )

        guard result == KERN_SUCCESS, let processorInfo else {
            return snapshot.cpuCores
        }

        defer {
            let byteCount = vm_size_t(processorInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: processorInfo)), byteCount)
        }

        var latest: [[UInt64]] = []
        var usages: [Double] = []

        processorInfo.withMemoryRebound(to: processor_cpu_load_info_data_t.self, capacity: Int(processorCount)) { cpuLoad in
            for index in 0..<Int(processorCount) {
                let ticks = cpuLoad[index].cpu_ticks
                let current = [
                    UInt64(ticks.0),
                    UInt64(ticks.1),
                    UInt64(ticks.2),
                    UInt64(ticks.3)
                ]

                latest.append(current)

                let previous = previousCPULoad.indices.contains(index) ? previousCPULoad[index] : current.map { _ in 0 }
                let deltas = zip(current, previous).map { currentTick, previousTick in
                    currentTick >= previousTick ? currentTick - previousTick : 0
                }
                let total = deltas.reduce(0, +)
                let idle = deltas[Int(CPU_STATE_IDLE)]

                let usage = total > 0 ? 1 - (Double(idle) / Double(total)) : 0
                usages.append(min(max(usage, 0), 1))
            }
        }

        previousCPULoad = latest
        return usages
    }

    private func readMemoryUsedBytes() -> UInt64 {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return snapshot.memoryUsedBytes }

        let usedPages = UInt64(stats.active_count)
            + UInt64(stats.wire_count)
            + UInt64(stats.compressor_page_count)
        return usedPages * UInt64(pageSize)
    }

    private func readInternalTemperatureIfNeeded() -> Double? {
        let now = Date()
        guard cachedTemperatureCelsius == nil || now.timeIntervalSince(lastTemperatureRead) >= temperatureRefreshInterval else {
            return cachedTemperatureCelsius
        }

        lastTemperatureRead = now
        cachedTemperatureCelsius = readInternalTemperature()
        return cachedTemperatureCelsius
    }

    private func readInternalTemperature() -> Double? {
        let keys = [
            "TC0P", "TC0E", "TC0F", "TC1C", "TC2C", "TC3C",
            "Tp09", "Tp0P", "Tp0T", "Tm0P"
        ]

        for key in keys {
            guard let value = smcReader?.readTemperature(key), value > 0, value < 130 else {
                continue
            }
            return value
        }

        return nil
    }
}

private typealias SMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

private struct SMCKeyDataVers {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCKeyDataPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyDataKeyInfo {
    var dataSize: IOByteCount = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCKeyData {
    var key: UInt32 = 0
    var vers = SMCKeyDataVers()
    var pLimitData = SMCKeyDataPLimitData()
    var keyInfo = SMCKeyDataKeyInfo()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )
}

private final class SMCReader {
    private let connection: io_connect_t
    private let smcSelector: UInt32 = 2
    private let getKeyInfoCommand: UInt8 = 9
    private let readKeyCommand: UInt8 = 5

    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var connection: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == kIOReturnSuccess else {
            return nil
        }

        self.connection = connection
    }

    deinit {
        IOServiceClose(connection)
    }

    func readTemperature(_ key: String) -> Double? {
        guard let data = readKey(key), data.bytes.count >= 2 else { return nil }

        switch fourCharString(data.dataType) {
        case "sp78":
            let raw = Int16(bitPattern: (UInt16(data.bytes[0]) << 8) | UInt16(data.bytes[1]))
            return Double(raw) / 256.0
        case "fpe2":
            let raw = (UInt16(data.bytes[0]) << 8) | UInt16(data.bytes[1])
            return Double(raw) / 4.0
        case "flt ":
            guard data.bytes.count >= 4 else { return nil }
            let raw = (UInt32(data.bytes[0]) << 24)
                | (UInt32(data.bytes[1]) << 16)
                | (UInt32(data.bytes[2]) << 8)
                | UInt32(data.bytes[3])
            return Double(Float(bitPattern: raw))
        default:
            let raw = Int16(bitPattern: (UInt16(data.bytes[0]) << 8) | UInt16(data.bytes[1]))
            return Double(raw) / 256.0
        }
    }

    private func readKey(_ key: String) -> (dataType: UInt32, bytes: [UInt8])? {
        var input = SMCKeyData()
        input.key = fourCharCode(key)
        input.data8 = getKeyInfoCommand

        guard let keyInfoOutput = call(input), keyInfoOutput.result == 0 else { return nil }

        input.keyInfo = keyInfoOutput.keyInfo
        input.data8 = readKeyCommand

        guard let keyOutput = call(input), keyOutput.result == 0 else { return nil }

        let byteCount = min(Int(keyInfoOutput.keyInfo.dataSize), 32)
        let bytes = Array(bytesArray(keyOutput.bytes).prefix(byteCount))
        return (keyInfoOutput.keyInfo.dataType, bytes)
    }

    private func call(_ input: SMCKeyData) -> SMCKeyData? {
        var mutableInput = input
        var output = SMCKeyData()
        var outputSize = MemoryLayout<SMCKeyData>.stride

        let result = withUnsafePointer(to: &mutableInput) { inputPointer in
            withUnsafeMutablePointer(to: &output) { outputPointer in
                IOConnectCallStructMethod(
                    connection,
                    smcSelector,
                    inputPointer,
                    MemoryLayout<SMCKeyData>.stride,
                    outputPointer,
                    &outputSize
                )
            }
        }

        guard result == kIOReturnSuccess else { return nil }
        return output
    }

    private func fourCharCode(_ string: String) -> UInt32 {
        var result: UInt32 = 0
        for byte in string.utf8.prefix(4) {
            result = (result << 8) + UInt32(byte)
        }
        return result
    }

    private func fourCharString(_ code: UInt32) -> String {
        let bytes = [
            UInt8((code >> 24) & 0xff),
            UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff),
            UInt8(code & 0xff)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }

    private func bytesArray(_ bytes: SMCBytes) -> [UInt8] {
        Mirror(reflecting: bytes).children.compactMap { $0.value as? UInt8 }
    }
}
