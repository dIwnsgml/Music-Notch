import SwiftUI

struct HardwareHUDWidget: View {
    @StateObject private var hardware = HardwareHUDManager.shared
    @AppStorage("hardware_hud_show_per_core") private var showPerCore = true
    @AppStorage("hardware_hud_show_temperature") private var showTemperature = true

    private var snapshot: HardwareHUDSnapshot {
        hardware.snapshot
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.mint.opacity(0.16))
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.mint)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Hardware HUD")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("\(snapshot.cpuCores.count) CPU cores")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.58))
                        .lineLimit(1)
                }

                Spacer()

                Text("\(Int(snapshot.cpuAverage * 100))%")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(cpuColor(snapshot.cpuAverage))
            }

            if showPerCore {
                cpuCoreBars
            }

            HStack(spacing: 10) {
                metricBlock(
                    title: "Memory Pressure",
                    value: "\(formatBytes(snapshot.memoryUsedBytes)) / \(formatBytes(snapshot.memoryTotalBytes))",
                    symbol: "memorychip.fill",
                    color: pressureColor(snapshot.memoryPressure),
                    progress: snapshot.memoryPressure
                )

                if showTemperature {
                    metricBlock(
                        title: "Internal Temp",
                        value: temperatureText,
                        symbol: "thermometer.medium",
                        color: temperatureColor,
                        progress: temperatureProgress
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            hardware.refresh()
        }
    }

    private var cpuCoreBars: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(snapshot.cpuCores.prefix(16).enumerated()), id: \.offset) { index, usage in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(cpuColor(usage))
                        .frame(width: 6, height: max(4, 28 * usage))
                        .frame(height: 28, alignment: .bottom)
                    Text("\(index + 1)")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.36))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 40)
    }

    private func metricBlock(
        title: String,
        value: String,
        symbol: String,
        color: Color,
        progress: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.58))
                    .lineLimit(1)
            }

            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(color)
                        .frame(width: max(8, geo.size.width * CGFloat(min(max(progress, 0), 1))))
                }
            }
            .frame(height: 7)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var temperatureText: String {
        if let temperature = snapshot.temperatureCelsius {
            return "\(Int(temperature.rounded()))°C"
        }
        return thermalStateText
    }

    private var temperatureProgress: Double {
        guard let temperature = snapshot.temperatureCelsius else {
            switch snapshot.thermalState {
            case .nominal: return 0.24
            case .fair: return 0.46
            case .serious: return 0.72
            case .critical: return 0.95
            @unknown default: return 0.35
            }
        }
        return min(max((temperature - 30) / 70, 0.05), 1)
    }

    private var temperatureColor: Color {
        if let temperature = snapshot.temperatureCelsius {
            if temperature >= 88 { return .red }
            if temperature >= 72 { return .orange }
            return .mint
        }

        switch snapshot.thermalState {
        case .nominal: return .mint
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .secondary
        }
    }

    private var thermalStateText: String {
        switch snapshot.thermalState {
        case .nominal: return "Nominal"
        case .fair: return "Warm"
        case .serious: return "Hot"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    private func cpuColor(_ value: Double) -> Color {
        if value >= 0.82 { return .red }
        if value >= 0.58 { return .orange }
        return .mint
    }

    private func pressureColor(_ value: Double) -> Color {
        if value >= 0.86 { return .red }
        if value >= 0.68 { return .orange }
        return .cyan
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 10 {
            return "\(Int(gb.rounded())) GB"
        }
        return String(format: "%.1f GB", gb)
    }
}
