import SwiftUI
import Combine
import Darwin

struct NetworkSpeedSnapshot: Equatable {
    var downloadBytesPerSecond: Double
    var uploadBytesPerSecond: Double
    var totalDownloadBytes: UInt64
    var totalUploadBytes: UInt64
    var interfaceNames: [String]
    var lastUpdated: Date?
    var history: [NetworkSpeedHistoryPoint]

    static let empty = NetworkSpeedSnapshot(
        downloadBytesPerSecond: 0,
        uploadBytesPerSecond: 0,
        totalDownloadBytes: 0,
        totalUploadBytes: 0,
        interfaceNames: [],
        lastUpdated: nil,
        history: []
    )

    var isConnected: Bool {
        !interfaceNames.isEmpty
    }

    var combinedBytesPerSecond: Double {
        downloadBytesPerSecond + uploadBytesPerSecond
    }
}

struct NetworkSpeedHistoryPoint: Equatable {
    var downloadBytesPerSecond: Double
    var uploadBytesPerSecond: Double
}

final class NetworkSpeedManager: ObservableObject {
    static let shared = NetworkSpeedManager()

    @Published private(set) var snapshot = NetworkSpeedSnapshot.empty

    private var previousCounters: NetworkCountersSnapshot?
    private var timer: Timer?
    private var isRefreshing = false

    private init() {}

    func start() {
        refresh(resetBaseline: previousCounters == nil)
        restartTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func syncSettings() {
        if timer != nil {
            restartTimer()
        }
        refresh(resetBaseline: true)
    }

    func refresh(resetBaseline: Bool = false) {
        guard !isRefreshing else { return }
        isRefreshing = true

        let includeVirtual = Self.includeVirtualInterfaces
        let current = Self.collectCounters(includeVirtualInterfaces: includeVirtual)
        let previous = resetBaseline ? nil : previousCounters
        previousCounters = current

        var nextSnapshot = snapshot
        nextSnapshot.totalDownloadBytes = current.downloadBytes
        nextSnapshot.totalUploadBytes = current.uploadBytes
        nextSnapshot.interfaceNames = current.interfaceNames
        nextSnapshot.lastUpdated = current.date

        if let previous {
            let elapsed = max(current.date.timeIntervalSince(previous.date), 0.1)
            nextSnapshot.downloadBytesPerSecond = Double(Self.counterDelta(current.downloadBytes, previous.downloadBytes)) / elapsed
            nextSnapshot.uploadBytesPerSecond = Double(Self.counterDelta(current.uploadBytes, previous.uploadBytes)) / elapsed
        } else {
            nextSnapshot.downloadBytesPerSecond = 0
            nextSnapshot.uploadBytesPerSecond = 0
        }

        nextSnapshot.history.append(
            NetworkSpeedHistoryPoint(
                downloadBytesPerSecond: nextSnapshot.downloadBytesPerSecond,
                uploadBytesPerSecond: nextSnapshot.uploadBytesPerSecond
            )
        )
        if nextSnapshot.history.count > 36 {
            nextSnapshot.history.removeFirst(nextSnapshot.history.count - 36)
        }

        snapshot = nextSnapshot
        isRefreshing = false
    }

    private func restartTimer() {
        timer?.invalidate()

        let interval = Self.refreshInterval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = min(0.5, interval * 0.2)
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private static var refreshInterval: TimeInterval {
        let raw = UserDefaults.standard.double(forKey: "network_speed_refresh_interval")
        return min(max(raw > 0 ? raw : 1.0, 0.5), 5.0)
    }

    private static var includeVirtualInterfaces: Bool {
        UserDefaults.standard.bool(forKey: "network_speed_include_virtual")
    }

    static var unitMode: String {
        UserDefaults.standard.string(forKey: "network_speed_unit") ?? "bits"
    }

    static func formattedSpeed(_ bytesPerSecond: Double, unitMode: String = NetworkSpeedManager.unitMode) -> (value: String, unit: String) {
        let clamped = max(0, bytesPerSecond)
        if unitMode == "bytes" {
            if clamped >= 1_073_741_824 {
                return (String(format: "%.1f", clamped / 1_073_741_824), "GB/s")
            }
            if clamped >= 1_048_576 {
                return (String(format: "%.1f", clamped / 1_048_576), "MB/s")
            }
            if clamped >= 1024 {
                return (String(format: "%.0f", clamped / 1024), "KB/s")
            }
            return (String(format: "%.0f", clamped), "B/s")
        }

        let bitsPerSecond = clamped * 8
        if bitsPerSecond >= 1_000_000_000 {
            return (String(format: "%.1f", bitsPerSecond / 1_000_000_000), "Gbps")
        }
        if bitsPerSecond >= 1_000_000 {
            return (String(format: "%.1f", bitsPerSecond / 1_000_000), "Mbps")
        }
        if bitsPerSecond >= 1_000 {
            return (String(format: "%.0f", bitsPerSecond / 1_000), "Kbps")
        }
        return (String(format: "%.0f", bitsPerSecond), "bps")
    }

    private static func collectCounters(includeVirtualInterfaces: Bool) -> NetworkCountersSnapshot {
        var interfacePointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfacePointer) == 0, let firstInterface = interfacePointer else {
            return NetworkCountersSnapshot(date: Date(), downloadBytes: 0, uploadBytes: 0, interfaceNames: [])
        }
        defer { freeifaddrs(interfacePointer) }

        var downloadBytes: UInt64 = 0
        var uploadBytes: UInt64 = 0
        var names = Set<String>()
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstInterface

        while let current = cursor {
            let interface = current.pointee
            cursor = interface.ifa_next

            guard let address = interface.ifa_addr,
                  Int32(address.pointee.sa_family) == AF_LINK,
                  let dataPointer = interface.ifa_data,
                  let rawName = interface.ifa_name else {
                continue
            }

            let name = String(cString: rawName)
            let flags = Int32(interface.ifa_flags)
            let data = dataPointer.assumingMemoryBound(to: if_data.self).pointee
            let received = UInt64(data.ifi_ibytes)
            let sent = UInt64(data.ifi_obytes)

            guard shouldIncludeInterface(
                name: name,
                flags: flags,
                received: received,
                sent: sent,
                includeVirtualInterfaces: includeVirtualInterfaces
            ) else {
                continue
            }

            downloadBytes &+= received
            uploadBytes &+= sent
            names.insert(displayName(for: name))
        }

        return NetworkCountersSnapshot(
            date: Date(),
            downloadBytes: downloadBytes,
            uploadBytes: uploadBytes,
            interfaceNames: names.sorted()
        )
    }

    private static func shouldIncludeInterface(
        name: String,
        flags: Int32,
        received: UInt64,
        sent: UInt64,
        includeVirtualInterfaces: Bool
    ) -> Bool {
        guard flags & IFF_UP != 0,
              flags & IFF_LOOPBACK == 0,
              received > 0 || sent > 0 else {
            return false
        }

        if includeVirtualInterfaces {
            return true
        }

        let virtualPrefixes = ["awdl", "llw", "utun", "bridge", "gif", "stf", "p2p", "ap", "anpi"]
        return !virtualPrefixes.contains { name.hasPrefix($0) }
    }

    private static func displayName(for interfaceName: String) -> String {
        if interfaceName.hasPrefix("en") { return "Wi-Fi" }
        if interfaceName.hasPrefix("eth") { return "Ethernet" }
        if interfaceName.hasPrefix("utun") { return "VPN" }
        return interfaceName
    }

    private static func counterDelta(_ current: UInt64, _ previous: UInt64) -> UInt64 {
        if current >= previous {
            return current - previous
        }
        return current
    }
}

private struct NetworkCountersSnapshot {
    let date: Date
    let downloadBytes: UInt64
    let uploadBytes: UInt64
    let interfaceNames: [String]
}

struct NetworkSpeedWidget: View {
    @StateObject private var manager = NetworkSpeedManager.shared
    @AppStorage("network_speed_unit") private var unitMode = "bits"
    @AppStorage("network_speed_show_graph") private var showGraph = true
    @AppStorage("network_speed_show_interface") private var showInterface = true

    private var snapshot: NetworkSpeedSnapshot {
        manager.snapshot
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            header

            HStack(spacing: 10) {
                NetworkSpeedMetricTile(
                    title: "Download",
                    iconName: "arrow.down",
                    color: .cyan,
                    speed: snapshot.downloadBytesPerSecond,
                    unitMode: unitMode
                )

                NetworkSpeedMetricTile(
                    title: "Upload",
                    iconName: "arrow.up",
                    color: .green,
                    speed: snapshot.uploadBytesPerSecond,
                    unitMode: unitMode
                )
            }

            if showGraph {
                NetworkSpeedMiniGraph(history: snapshot.history)
                    .frame(height: 34)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            manager.start()
        }
        .onDisappear {
            manager.stop()
        }
        .onChange(of: unitMode) { _, _ in
            manager.refresh(resetBaseline: false)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.cyan.opacity(0.16))
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.cyan)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 1) {
                Text("Network")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            NetworkActivityPulse(isActive: snapshot.combinedBytesPerSecond > 512)
        }
    }

    private var subtitle: String {
        guard snapshot.isConnected else { return "No active network" }
        guard showInterface else { return "Live speed" }
        return snapshot.interfaceNames.prefix(2).joined(separator: " + ")
    }
}

private struct NetworkSpeedMetricTile: View {
    let title: String
    let iconName: String
    let color: Color
    let speed: Double
    let unitMode: String

    var body: some View {
        let formatted = NetworkSpeedManager.formattedSpeed(speed, unitMode: unitMode)

        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: iconName)
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formatted.value)
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                Text(formatted.unit)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(color.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct NetworkSpeedMiniGraph: View {
    let history: [NetworkSpeedHistoryPoint]

    var body: some View {
        GeometryReader { geo in
            let points = Array(history.suffix(28))
            let maxSpeed = max(1, points.map { max($0.downloadBytesPerSecond, $0.uploadBytesPerSecond) }.max() ?? 1)
            let barWidth = max(3, (geo.size.width - CGFloat(max(points.count - 1, 0)) * 3) / CGFloat(max(points.count, 1)))

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    VStack(spacing: 1.5) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.cyan)
                            .frame(height: barHeight(point.downloadBytesPerSecond, maxSpeed: maxSpeed, availableHeight: geo.size.height * 0.58))
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.green)
                            .frame(height: barHeight(point.uploadBytesPerSecond, maxSpeed: maxSpeed, availableHeight: geo.size.height * 0.34))
                    }
                    .frame(width: barWidth, height: geo.size.height, alignment: .bottom)
                    .opacity(point.downloadBytesPerSecond + point.uploadBytesPerSecond > 1 ? 0.9 : 0.26)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.horizontal, 1)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.045))
            )
        }
    }

    private func barHeight(_ speed: Double, maxSpeed: Double, availableHeight: CGFloat) -> CGFloat {
        max(2, availableHeight * CGFloat(min(max(speed / maxSpeed, 0), 1)))
    }
}

private struct NetworkActivityPulse: View {
    let isActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(isActive ? Color.cyan : Color.white.opacity(0.28))
                    .frame(width: 5, height: 5)
                    .scaleEffect(isActive ? 1.0 + CGFloat(index) * 0.12 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.7)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.12),
                        value: isActive
                    )
            }
        }
        .frame(width: 28, height: 20)
    }
}
