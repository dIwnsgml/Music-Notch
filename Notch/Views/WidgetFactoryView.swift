import SwiftUI
import Combine
import AppKit
import CoreLocation
import Darwin
import IOKit
import IOKit.ps
import ObjectiveC

private enum WidgetPerformance {
    static let mediaAnimationFrameInterval: TimeInterval = 1.0 / 30.0
    static let mediaStartRampDuration: TimeInterval = 0.65
    static let mediaStopRampDuration: TimeInterval = 0.85

    static func smoothstep(_ value: Double) -> Double {
        let t = min(max(value, 0), 1)
        return t * t * (3 - 2 * t)
    }

    static func smoothstepIntegral(_ value: Double) -> Double {
        let t = min(max(value, 0), 1)
        return t * t * t - 0.5 * t * t * t * t
    }

    static func easingOutIntegral(_ value: Double) -> Double {
        let t = min(max(value, 0), 1)
        return t - t * t * t + 0.5 * t * t * t * t
    }
}

struct WidgetFactoryView: View {
    let widgetType: NotchWidgetType
    
    @ObservedObject var nowPlaying: NowPlayingManager
    let expandedWidth: CGFloat
    var isCompact: Bool
    @Binding var skipDirection: Int
    @Binding var glowOpacity: Double
    let onSwipe: (Bool) -> Void
    
    @AppStorage("themeBackgroundType") var themeBackgroundType: String = "color"
    @AppStorage("themeGlassyWidgets") var themeGlassyWidgets: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            if widgetType == .player {
                PlayerTabView(
                    nowPlaying: nowPlaying,
                    expandedWidth: expandedWidth,
                    isCompact: isCompact,
                    skipDirection: $skipDirection,
                    glowOpacity: $glowOpacity,
                    onSwipe: onSwipe
                )
            } else {
                Group {
                    switch widgetType {
                    case .player: EmptyView() // Handled above
                    case .spotifyQueue: SpotifyQueueWidget(nowPlaying: nowPlaying)
                    case .spotifyPlaylists: PlaylistTabView(nowPlaying: nowPlaying)
                    case .turntable: TurntablePlayerWidget(nowPlaying: nowPlaying)
                    case .cassette: CassetteTapeWidget(nowPlaying: nowPlaying)
                    case .youtubeQueue: YouTubeQueueWidget(nowPlaying: nowPlaying)
                    case .youtubePlaylists: YouTubePlaylistsWidget(nowPlaying: nowPlaying)
                    case .calendar: CalendarWidget()
                    case .pomodoro: PomodoroTimerWidget(isCompact: isCompact)
                    case .clipboard: ClipboardHistoryWidget()
                    case .fileTray: FileTrayWidget()
                    case .tasks: TasksWidget()
                    case .kaomoji: KaomojiBoardWidget()
                    case .weather: WeatherWidget()
                    case .hardwareHUD: HardwareHUDWidget()
                    case .bluetoothBattery: BluetoothBatteryWidget()
                    case .screenCapture: ScreenCaptureWidget()
                    case .networkSpeed: NetworkSpeedWidget()
                    case .notchPets: EmptyView()
                    }
                }
                .frame(maxHeight: .infinity)
                .background(
                    Group {
                        if themeBackgroundType == "image" && themeGlassyWidgets {
                            if #available(macOS 26.0, *) {
                                Color.clear.glassEffect(in: .rect(cornerRadius: 16))
                            } else {
                                ZStack {
                                    VisualEffectView(material: .popover, blendingMode: .withinWindow, alpha: 0.5)
                                    LinearGradient(colors: [Color.white.opacity(0.15), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                                }
                            }
                        } else {
                            Color.white.opacity(0.03)
                        }
                    }
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
            }
        }
    }
}

struct BluetoothBatterySnapshot: Identifiable, Equatable {
    enum Kind: String {
        case laptop
        case keyboard
        case mouse
        case trackpad
        case headphones
        case airPods
        case leftEarbud
        case rightEarbud
        case caseBattery
        case gameController
        case generic
    }

    let id: String
    let name: String
    let percent: Int?
    let isCharging: Bool
    let kind: Kind

    var iconName: String {
        switch kind {
        case .laptop: return "laptopcomputer"
        case .keyboard: return "keyboard"
        case .mouse: return "magicmouse"
        case .trackpad: return "rectangle.and.hand.point.up.left"
        case .headphones: return "headphones"
        case .airPods, .leftEarbud, .rightEarbud: return "airpods"
        case .caseBattery: return "case.fill"
        case .gameController: return "gamecontroller.fill"
        case .generic: return "battery.100"
        }
    }
}

final class BluetoothBatteryManager: ObservableObject {
    static let shared = BluetoothBatteryManager()

    @Published private(set) var devices: [BluetoothBatterySnapshot] = []
    @Published private(set) var lastUpdated: Date?

    private var timer: Timer?
    private var isRefreshing = false

    private init() {}

    func start() {
        refresh()
        guard timer == nil else { return }

        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = 6
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        let includeLaptop = UserDefaults.standard.object(forKey: "bluetooth_battery_show_laptop") as? Bool ?? true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let snapshots = Self.collectSnapshots(includeLaptop: includeLaptop)

            DispatchQueue.main.async {
                guard let self else { return }
                self.devices = snapshots
                self.lastUpdated = Date()
                self.isRefreshing = false
            }
        }
    }

    private static func collectSnapshots(includeLaptop: Bool) -> [BluetoothBatterySnapshot] {
        var snapshots: [BluetoothBatterySnapshot] = []
        var seen = Set<String>()

        if includeLaptop, let laptop = laptopBatterySnapshot() {
            snapshots.append(laptop)
            seen.insert(laptop.id)
        }

        let ioBluetoothSnapshots = ioBluetoothBatterySnapshots()
        for snapshot in ioBluetoothSnapshots {
            guard !seen.contains(snapshot.id),
                  !containsEquivalentBatterySnapshot(in: snapshots, candidate: snapshot) else { continue }
            seen.insert(snapshot.id)
            snapshots.append(snapshot)
        }

        let hasRealAppleAudioBattery = ioBluetoothSnapshots.contains { snapshot in
            snapshot.percent != nil && isAppleAudioBatteryKind(snapshot.kind)
        }

        for snapshot in bluetoothBatterySnapshots(includeAppleAudioPlaceholders: !hasRealAppleAudioBattery) {
            guard !seen.contains(snapshot.id),
                  !containsEquivalentBatterySnapshot(in: snapshots, candidate: snapshot) else { continue }
            seen.insert(snapshot.id)
            snapshots.append(snapshot)
        }

        return snapshots.sorted { lhs, rhs in
            if lhs.kind == .laptop { return true }
            if rhs.kind == .laptop { return false }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func containsEquivalentBatterySnapshot(in snapshots: [BluetoothBatterySnapshot], candidate: BluetoothBatterySnapshot) -> Bool {
        guard candidate.percent != nil else { return false }
        return snapshots.contains { snapshot in
            snapshot.percent != nil
                && snapshot.kind == candidate.kind
                && snapshot.name.localizedCaseInsensitiveCompare(candidate.name) == .orderedSame
        }
    }

    private static func laptopBatterySnapshot() -> BluetoothBatterySnapshot? {
        guard let powerInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(powerInfo)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(powerInfo, source)?.takeUnretainedValue() as? [String: Any],
                  let type = description[kIOPSTypeKey] as? String,
                  type == kIOPSInternalBatteryType,
                  let currentCapacity = numberValue(description[kIOPSCurrentCapacityKey]) else {
                continue
            }

            let isCharging = (description[kIOPSIsChargingKey] as? Bool) ?? false
            return BluetoothBatterySnapshot(
                id: "internal-mac-battery",
                name: "MacBook",
                percent: clampPercent(currentCapacity),
                isCharging: isCharging,
                kind: .laptop
            )
        }

        return nil
    }

    private static func ioBluetoothBatterySnapshots() -> [BluetoothBatterySnapshot] {
        guard let deviceClass = ioBluetoothDeviceClass() else { return [] }

        var snapshots: [BluetoothBatterySnapshot] = []
        var seen = Set<String>()

        for device in ioBluetoothDeviceCandidates(deviceClass: deviceClass) {
            for snapshot in ioBluetoothBatterySnapshots(from: device) {
                guard !seen.contains(snapshot.id) else { continue }
                seen.insert(snapshot.id)
                snapshots.append(snapshot)
            }
        }

        return snapshots
    }

    private static func ioBluetoothDeviceClass() -> AnyClass? {
        _ = dlopen("/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth", RTLD_LAZY)
        return NSClassFromString("IOBluetoothDevice")
    }

    private static func ioBluetoothDeviceCandidates(deviceClass: AnyClass) -> [NSObject] {
        var devices: [NSObject] = []

        for selector in ["connectedDevices", "pairedDevices", "favoriteDevices", "configuredDevices"] {
            devices.append(contentsOf: objcClassArray(deviceClass, selector))
        }

        if let address = lastNowPlayingHeadsetAddress(),
           let device = objcClassObject(deviceClass, "deviceWithAddressString:", string: address) as? NSObject {
            devices.append(device)
        }

        var seen = Set<String>()
        return devices.filter { device in
            let identity = ioBluetoothDeviceIdentity(device)
            guard !seen.contains(identity) else { return false }
            seen.insert(identity)
            return true
        }
    }

    private static func ioBluetoothBatterySnapshots(from device: NSObject) -> [BluetoothBatterySnapshot] {
        let isConnected = objcBool(device, "isConnected") ?? false
        let name = ioBluetoothDeviceName(device)
        let identity = ioBluetoothDeviceIdentity(device)
        let isCharging = objcBool(device, "isBatteryCharging") ?? objcBool(device, "isCharging") ?? false
        let isMultiBattery = objcBool(device, "isMultiBatteryDevice") ?? false

        let combinedPercent = bluetoothBatteryPercent(objcUInt8(device, "batteryPercentCombined"))
            ?? bluetoothBatteryPercent(objcUInt8(device, "batteryPercentSingle"))
            ?? bluetoothBatteryPercent(objcInt64(device, "headsetBattery"))
        let leftPercent = bluetoothBatteryPercent(objcUInt8(device, "batteryPercentLeft"))
        let rightPercent = bluetoothBatteryPercent(objcUInt8(device, "batteryPercentRight"))
        let casePercent = bluetoothBatteryPercent(objcUInt8(device, "batteryPercentCase"))
        let hasComponentBattery = leftPercent != nil || rightPercent != nil || casePercent != nil
        let hasBatteryValue = combinedPercent != nil || hasComponentBattery

        guard isConnected || hasBatteryValue else { return [] }

        let shortName = shortAccessoryName(name)
        let baseID = "iobluetooth-\(identity)"
        var snapshots: [BluetoothBatterySnapshot] = []

        if isMultiBattery || hasComponentBattery {
            if let leftPercent {
                snapshots.append(
                    BluetoothBatterySnapshot(
                        id: "\(baseID)-left",
                        name: "\(shortName) L",
                        percent: leftPercent,
                        isCharging: isCharging,
                        kind: .leftEarbud
                    )
                )
            }

            if let rightPercent {
                snapshots.append(
                    BluetoothBatterySnapshot(
                        id: "\(baseID)-right",
                        name: "\(shortName) R",
                        percent: rightPercent,
                        isCharging: isCharging,
                        kind: .rightEarbud
                    )
                )
            }

            if let casePercent {
                snapshots.append(
                    BluetoothBatterySnapshot(
                        id: "\(baseID)-case",
                        name: "\(shortName) Case",
                        percent: casePercent,
                        isCharging: isCharging,
                        kind: .caseBattery
                    )
                )
            }
        }

        if snapshots.isEmpty, let combinedPercent {
            snapshots.append(
                BluetoothBatterySnapshot(
                    id: "\(baseID)-combined",
                    name: name,
                    percent: combinedPercent,
                    isCharging: isCharging,
                    kind: deviceKind(for: name)
                )
            )
        }

        return snapshots
    }

    private static func ioBluetoothDeviceName(_ device: NSObject) -> String {
        let name = [
            objcString(device, "getDisplayName"),
            objcString(device, "displayName"),
            objcString(device, "name"),
            objcString(device, "getName"),
            objcString(device, "nameOrAddress"),
            objcString(device, "addressString"),
            objcString(device, "getAddressString")
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        return cleanedDeviceName(name ?? "Bluetooth Device")
    }

    private static func ioBluetoothDeviceIdentity(_ device: NSObject) -> String {
        let identity = [
            objcString(device, "addressString"),
            objcString(device, "getAddressString"),
            objcString(device, "nameOrAddress"),
            objcString(device, "name"),
            objcString(device, "getName")
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        return (identity ?? "\(ObjectIdentifier(device))")
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func bluetoothBatteryPercent(_ value: UInt8?) -> Int? {
        guard let value, value > 0, value <= 100 else { return nil }
        return Int(value)
    }

    private static func bluetoothBatteryPercent(_ value: Int64?) -> Int? {
        guard let value, value > 0, value <= 100 else { return nil }
        return Int(value)
    }

    private static func lastNowPlayingHeadsetAddress() -> String? {
        CFPreferencesCopyAppValue(
            "lastNowPlayingTargetHeadsetAddress" as CFString,
            "com.apple.bluetooth" as CFString
        ) as? String
    }

    private static func objcClassArray(_ cls: AnyClass, _ selectorName: String) -> [NSObject] {
        guard let result = objcClassObject(cls, selectorName) else { return [] }
        if let devices = result as? [NSObject] { return devices }
        if let array = result as? NSArray {
            return array.compactMap { $0 as? NSObject }
        }
        if let device = result as? NSObject { return [device] }
        return []
    }

    private static func objcClassObject(_ cls: AnyClass, _ selectorName: String) -> AnyObject? {
        let selector = NSSelectorFromString(selectorName)
        guard let method = class_getClassMethod(cls, selector) else { return nil }
        let implementation = method_getImplementation(method)
        typealias Function = @convention(c) (AnyClass, Selector) -> AnyObject?
        return unsafeBitCast(implementation, to: Function.self)(cls, selector)
    }

    private static func objcClassObject(_ cls: AnyClass, _ selectorName: String, string: String) -> AnyObject? {
        let selector = NSSelectorFromString(selectorName)
        guard let method = class_getClassMethod(cls, selector) else { return nil }
        let implementation = method_getImplementation(method)
        typealias Function = @convention(c) (AnyClass, Selector, NSString) -> AnyObject?
        return unsafeBitCast(implementation, to: Function.self)(cls, selector, string as NSString)
    }

    private static func objcString(_ object: NSObject, _ selectorName: String) -> String? {
        let selector = NSSelectorFromString(selectorName)
        guard object.responds(to: selector),
              let implementation = object.method(for: selector) else { return nil }
        typealias Function = @convention(c) (AnyObject, Selector) -> AnyObject?
        let value = unsafeBitCast(implementation, to: Function.self)(object, selector)
        return value as? String
    }

    private static func objcBool(_ object: NSObject, _ selectorName: String) -> Bool? {
        let selector = NSSelectorFromString(selectorName)
        guard object.responds(to: selector),
              let implementation = object.method(for: selector) else { return nil }
        typealias Function = @convention(c) (AnyObject, Selector) -> Bool
        return unsafeBitCast(implementation, to: Function.self)(object, selector)
    }

    private static func objcUInt8(_ object: NSObject, _ selectorName: String) -> UInt8? {
        let selector = NSSelectorFromString(selectorName)
        guard object.responds(to: selector),
              let implementation = object.method(for: selector) else { return nil }
        typealias Function = @convention(c) (AnyObject, Selector) -> UInt8
        return unsafeBitCast(implementation, to: Function.self)(object, selector)
    }

    private static func objcInt64(_ object: NSObject, _ selectorName: String) -> Int64? {
        let selector = NSSelectorFromString(selectorName)
        guard object.responds(to: selector),
              let implementation = object.method(for: selector) else { return nil }
        typealias Function = @convention(c) (AnyObject, Selector) -> Int64
        return unsafeBitCast(implementation, to: Function.self)(object, selector)
    }

    private static func bluetoothBatterySnapshots(includeAppleAudioPlaceholders: Bool) -> [BluetoothBatterySnapshot] {
        var snapshots: [BluetoothBatterySnapshot] = []
        var seen = Set<String>()

        let matchingClasses = [
            "AppleDeviceManagementHIDEventService",
            "IOBluetoothHIDDriver",
            "AppleHSBluetoothDevice",
            "IOHIDDevice",
            "IOHIDInterface",
            "AppleUserHIDEventService"
        ]

        for className in matchingClasses {
            for candidate in registryBatteryCandidates(matchingClass: className) {
                guard candidate.percent >= 0, candidate.percent <= 100 else { continue }
                let requiresBluetoothTransport = className == "IOHIDDevice"
                guard !requiresBluetoothTransport || candidate.isBluetooth else { continue }

                let identity = candidate.identity
                guard !seen.contains(identity) else { continue }
                seen.insert(identity)

                snapshots.append(
                    BluetoothBatterySnapshot(
                        id: identity,
                        name: candidate.name,
                        percent: candidate.percent,
                        isCharging: candidate.isCharging,
                        kind: deviceKind(for: candidate.name)
                    )
                )
            }
        }

        for snapshot in appleAudioBatterySnapshots() {
            guard includeAppleAudioPlaceholders || snapshot.percent != nil else { continue }
            guard !seen.contains(snapshot.id) else { continue }
            seen.insert(snapshot.id)
            snapshots.append(snapshot)
        }

        return snapshots
    }

    private static func isAppleAudioBatteryKind(_ kind: BluetoothBatterySnapshot.Kind) -> Bool {
        switch kind {
        case .airPods, .leftEarbud, .rightEarbud, .caseBattery, .headphones:
            return true
        case .laptop, .keyboard, .mouse, .trackpad, .gameController, .generic:
            return false
        }
    }

    private struct RegistryBatteryCandidate {
        let identity: String
        let name: String
        let percent: Int
        let isCharging: Bool
        let isBluetooth: Bool
    }

    private static func registryBatteryCandidates(matchingClass: String) -> [RegistryBatteryCandidate] {
        var candidates: [RegistryBatteryCandidate] = []

        for entry in registryEntries(matchingClass: matchingClass) {
            let properties = entry.properties
            guard !isAppleBluetoothAudioDevice(properties: properties, registryName: entry.registryName),
                  let percent = percentValue(in: properties) else {
                continue
            }

            let name = bestDeviceName(from: properties, fallback: entry.registryName)
            guard !name.isEmpty, !isInternalBatteryName(name) else { continue }

            let identity = bestDeviceIdentity(from: properties, fallback: "\(matchingClass)-\(name)-\(percent)")
            let isBluetooth = isBluetoothDevice(properties: properties, registryName: entry.registryName)
            let isCharging = boolValue(properties["IsCharging"])
                ?? boolValue(properties["BatteryIsCharging"])
                ?? boolValue(properties["ExternalConnected"])
                ?? false

            candidates.append(
                RegistryBatteryCandidate(
                    identity: identity,
                    name: name,
                    percent: clampPercent(percent),
                    isCharging: isCharging,
                    isBluetooth: isBluetooth
                )
            )
        }

        return candidates
    }

    private struct RegistryEntry {
        let matchingClass: String
        let registryName: String
        let properties: [String: Any]
    }

    private struct AppleAudioBatteryGroup {
        var identity: String
        var displayName: String
        var combinedPercent: Int?
        var leftPercent: Int?
        var rightPercent: Int?
        var casePercent: Int?
        var isCharging: Bool
    }

    private static func appleAudioBatterySnapshots() -> [BluetoothBatterySnapshot] {
        let matchingClasses = ["IOHIDInterface", "AppleUserHIDEventService", "IOHIDDevice"]
        var groups: [String: AppleAudioBatteryGroup] = [:]

        for className in matchingClasses {
            for entry in registryEntries(matchingClass: className) {
                let properties = entry.properties
                guard isAppleBluetoothAudioDevice(properties: properties, registryName: entry.registryName) else {
                    continue
                }

                let identity = bestDeviceIdentity(
                    from: properties,
                    fallback: "\(className)-\(entry.registryName)-\(numberValue(properties["ProductID"]) ?? 0)"
                )
                let displayName = appleAudioDisplayName(from: properties, fallback: entry.registryName)
                let values = appleAudioBatteryValues(in: properties)
                let isCharging = boolValue(properties["IsCharging"])
                    ?? boolValue(properties["BatteryIsCharging"])
                    ?? boolValue(properties["ExternalConnected"])
                    ?? false

                var group = groups[identity] ?? AppleAudioBatteryGroup(
                    identity: identity,
                    displayName: displayName,
                    combinedPercent: nil,
                    leftPercent: nil,
                    rightPercent: nil,
                    casePercent: nil,
                    isCharging: false
                )

                if !displayName.isEmpty, group.displayName == "AirPods" || group.displayName == "Bluetooth Audio" {
                    group.displayName = displayName
                }
                group.combinedPercent = group.combinedPercent ?? values.combined
                group.leftPercent = group.leftPercent ?? values.left
                group.rightPercent = group.rightPercent ?? values.right
                group.casePercent = group.casePercent ?? values.caseBattery
                group.isCharging = group.isCharging || isCharging
                groups[identity] = group
            }
        }

        return groups.values.flatMap { group in
            appleAudioSnapshots(from: group)
        }
    }

    private static func appleAudioSnapshots(from group: AppleAudioBatteryGroup) -> [BluetoothBatterySnapshot] {
        let baseID = "apple-audio-\(group.identity)"
        let hasComponentBattery = group.leftPercent != nil || group.rightPercent != nil || group.casePercent != nil
        var snapshots: [BluetoothBatterySnapshot] = []

        if hasComponentBattery {
            if let leftPercent = group.leftPercent {
                snapshots.append(
                    BluetoothBatterySnapshot(
                        id: "\(baseID)-left",
                        name: "\(shortAccessoryName(group.displayName)) L",
                        percent: clampPercent(leftPercent),
                        isCharging: group.isCharging,
                        kind: .leftEarbud
                    )
                )
            }

            if let rightPercent = group.rightPercent {
                snapshots.append(
                    BluetoothBatterySnapshot(
                        id: "\(baseID)-right",
                        name: "\(shortAccessoryName(group.displayName)) R",
                        percent: clampPercent(rightPercent),
                        isCharging: group.isCharging,
                        kind: .rightEarbud
                    )
                )
            }

            if let casePercent = group.casePercent {
                snapshots.append(
                    BluetoothBatterySnapshot(
                        id: "\(baseID)-case",
                        name: "\(shortAccessoryName(group.displayName)) Case",
                        percent: clampPercent(casePercent),
                        isCharging: group.isCharging,
                        kind: .caseBattery
                    )
                )
            }
        } else if let combinedPercent = group.combinedPercent {
            snapshots.append(
                BluetoothBatterySnapshot(
                    id: "\(baseID)-combined",
                    name: group.displayName,
                    percent: clampPercent(combinedPercent),
                    isCharging: group.isCharging,
                    kind: deviceKind(for: group.displayName)
                )
            )
        } else {
            snapshots.append(
                BluetoothBatterySnapshot(
                    id: "\(baseID)-connected",
                    name: group.displayName,
                    percent: nil,
                    isCharging: group.isCharging,
                    kind: deviceKind(for: group.displayName)
                )
            )
        }

        return snapshots
    }

    private static func registryEntries(matchingClass: String) -> [RegistryEntry] {
        guard let matching = IOServiceMatching(matchingClass) else { return [] }

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var entries: [RegistryEntry] = []

        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            defer { IOObjectRelease(service) }

            guard let properties = registryProperties(for: service) else { continue }
            entries.append(
                RegistryEntry(
                    matchingClass: matchingClass,
                    registryName: registryEntryName(service),
                    properties: properties
                )
            )
        }

        return entries
    }

    private static func registryProperties(for service: io_object_t) -> [String: Any]? {
        var propertiesRef: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &propertiesRef, kCFAllocatorDefault, 0)
        guard result == KERN_SUCCESS,
              let retainedProperties = propertiesRef?.takeRetainedValue(),
              let properties = retainedProperties as NSDictionary as? [String: Any] else {
            return nil
        }
        return properties
    }

    private static func registryEntryName(_ service: io_object_t) -> String {
        var nameBuffer = [CChar](repeating: 0, count: 256)
        guard IORegistryEntryGetName(service, &nameBuffer) == KERN_SUCCESS else { return "" }
        return String(cString: nameBuffer).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func bestDeviceName(from properties: [String: Any], fallback: String) -> String {
        let keys = ["Product", "ProductName", "DeviceName", "Name", "DisplayName", "Manufacturer"]
        for key in keys {
            if let value = stringValue(properties[key]), !value.isEmpty {
                return cleanedDeviceName(value)
            }
        }
        return cleanedDeviceName(fallback)
    }

    private static func appleAudioDisplayName(from properties: [String: Any], fallback: String) -> String {
        let productID = numberValue(properties["ProductID"])
        if let productID, knownAirPodsProductIDs.contains(productID) {
            return "AirPods"
        }

        let name = bestDeviceName(from: properties, fallback: fallback)
        let lowerName = name.lowercased()
        let genericNames = ["apple", "headset", "bluetooth audio", "appleuserhideventservice", "iohidinterface"]
        if !name.isEmpty, name != fallback, !genericNames.contains(lowerName) {
            return name
        }

        if lowerName == "headset" {
            return "Headphones"
        }

        let fallbackName = cleanedDeviceName(fallback)
        return fallbackName.isEmpty || fallbackName == "AppleUserHIDEventService" || fallbackName == "IOHIDInterface"
            ? "Bluetooth Audio"
            : fallbackName
    }

    private static func bestDeviceIdentity(from properties: [String: Any], fallback: String) -> String {
        let keys = ["DeviceAddress", "BluetoothAddress", "BD_ADDR", "SerialNumber", "ProductID", "LocationID"]
        for key in keys {
            if let value = stringValue(properties[key]), !value.isEmpty {
                return "\(key)-\(value)"
            }
            if let value = numberValue(properties[key]) {
                return "\(key)-\(value)"
            }
        }
        return fallback
    }

    private static func percentValue(in properties: [String: Any]) -> Int? {
        let keys = [
            "BatteryPercent",
            "BatteryPercentCombined",
            "BatteryPercentage",
            "Battery Level",
            "BatteryLevel",
            "Battery",
            "DeviceBatteryLevel",
            "BatteryCurrentCapacity",
            "PowerSourcePercent"
        ]

        return percentValue(in: properties, keys: keys)
    }

    private static func appleAudioBatteryValues(in properties: [String: Any]) -> (combined: Int?, left: Int?, right: Int?, caseBattery: Int?) {
        let combinedKeys = [
            "BatteryPercent",
            "BatteryPercentCombined",
            "BatteryPercentage",
            "Battery Level",
            "BatteryLevel",
            "Battery",
            "DeviceBatteryLevel",
            "bat",
            "batP"
        ]
        let leftKeys = [
            "BatteryPercentLeft",
            "BatteryPercentLeftBud",
            "BatteryPercentLeftAirPod",
            "LeftBatteryPercent",
            "LeftBatteryLevel",
            "LeftBattery",
            "BatteryLevelLeft",
            "BatteryLeft",
            "Battery Left",
            "leftBattery",
            "batL"
        ]
        let rightKeys = [
            "BatteryPercentRight",
            "BatteryPercentRightBud",
            "BatteryPercentRightAirPod",
            "RightBatteryPercent",
            "RightBatteryLevel",
            "RightBattery",
            "BatteryLevelRight",
            "BatteryRight",
            "Battery Right",
            "rightBattery",
            "batR"
        ]
        let caseKeys = [
            "BatteryPercentCase",
            "CaseBatteryPercent",
            "CaseBatteryLevel",
            "CaseBattery",
            "BatteryLevelCase",
            "BatteryCase",
            "Battery Case",
            "ChargingCaseBatteryPercent",
            "chargingCaseBattery",
            "batC"
        ]

        return (
            percentValue(in: properties, keys: combinedKeys),
            percentValue(in: properties, keys: leftKeys),
            percentValue(in: properties, keys: rightKeys),
            percentValue(in: properties, keys: caseKeys)
        )
    }

    private static func percentValue(in properties: [String: Any], keys: [String]) -> Int? {
        recursivePercentValue(in: properties, wantedKeys: Set(keys.map(normalizedPropertyKey)))
    }

    private static func recursivePercentValue(in value: Any?, wantedKeys: Set<String>) -> Int? {
        guard let value else { return nil }

        if let dictionary = value as? [String: Any] {
            for (key, nestedValue) in dictionary {
                guard wantedKeys.contains(normalizedPropertyKey(key)),
                      let percent = normalizedPercent(nestedValue) else {
                    continue
                }
                return percent
            }

            for nestedValue in dictionary.values {
                if let percent = recursivePercentValue(in: nestedValue, wantedKeys: wantedKeys) {
                    return percent
                }
            }
        } else if let dictionary = value as? NSDictionary {
            for (key, nestedValue) in dictionary {
                guard let key = stringValue(key),
                      wantedKeys.contains(normalizedPropertyKey(key)),
                      let percent = normalizedPercent(nestedValue) else {
                    continue
                }
                return percent
            }

            for nestedValue in dictionary.allValues {
                if let percent = recursivePercentValue(in: nestedValue, wantedKeys: wantedKeys) {
                    return percent
                }
            }
        } else if let array = value as? [Any] {
            for nestedValue in array {
                if let percent = recursivePercentValue(in: nestedValue, wantedKeys: wantedKeys) {
                    return percent
                }
            }
        } else if let array = value as? NSArray {
            for nestedValue in array {
                if let percent = recursivePercentValue(in: nestedValue, wantedKeys: wantedKeys) {
                    return percent
                }
            }
        }

        return nil
    }

    private static func normalizedPercent(_ value: Any?) -> Int? {
        guard let percent = numberValue(value), percent >= 0, percent <= 100 else { return nil }
        return percent
    }

    nonisolated private static func normalizedPropertyKey(_ key: String) -> String {
        key.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func isBluetoothDevice(properties: [String: Any], registryName: String) -> Bool {
        let strings = [
            stringValue(properties["Transport"]),
            stringValue(properties["DeviceUsage"]),
            stringValue(properties["BluetoothAddress"]),
            stringValue(properties["DeviceAddress"]),
            stringValue(properties["BD_ADDR"]),
            registryName
        ]
            .compactMap { $0?.lowercased() }

        return strings.contains { value in
            value.contains("bluetooth") || value.contains("bt-") || value.contains("btaacp") || value.contains(":")
        }
    }

    private static func isAppleBluetoothAudioDevice(properties: [String: Any], registryName: String) -> Bool {
        let transport = stringValue(properties["Transport"])?.lowercased() ?? ""
        if transport.contains("bt-aacp") || transport.contains("btaacp") {
            return true
        }

        let name = bestDeviceName(from: properties, fallback: registryName).lowercased()
        let isKnownAudioName = name.contains("airpods")
            || name.contains("airpod")
            || name.contains("beats")
            || name.contains("headphone")
            || name.contains("earbuds")
        return isKnownAudioName && isBluetoothDevice(properties: properties, registryName: registryName)
    }

    private static func deviceKind(for name: String) -> BluetoothBatterySnapshot.Kind {
        let lower = name.lowercased()
        if lower.contains("macbook") { return .laptop }
        if lower.contains("keyboard") { return .keyboard }
        if lower.contains("mouse") { return .mouse }
        if lower.contains("trackpad") { return .trackpad }
        if lower.contains("airpods") || lower.contains("airpod") { return .airPods }
        if lower.contains("case") { return .caseBattery }
        if lower.contains("headphone") || lower.contains("buds") || lower.contains("beats") { return .headphones }
        if lower.contains("controller") || lower.contains("gamepad") { return .gameController }
        return .generic
    }

    private static func shortAccessoryName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpods") || lower.contains("airpod") { return "AirPods" }
        if lower.contains("beats") { return "Beats" }
        if lower == "bluetooth audio" { return "Audio" }
        return name
    }

    private static let knownAirPodsProductIDs: Set<Int> = [
        8212,
        8214,
        8228
    ]

    private static func isInternalBatteryName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.contains("internalbattery") || lower == "battery"
    }

    private static func cleanedDeviceName(_ value: String) -> String {
        value
            .replacingOccurrences(of: "Bluetooth", with: "")
            .replacingOccurrences(of: "Device", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSString { return value as String }
        if let value = value as? Data {
            return value.map { String(format: "%02x", $0) }.joined(separator: ":")
        }
        return nil
    }

    private static func numberValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        if let value = value as? String {
            let normalized = value.lowercased()
            if normalized == "yes" || normalized == "true" || normalized == "1" { return true }
            if normalized == "no" || normalized == "false" || normalized == "0" { return false }
        }
        return nil
    }

    private static func clampPercent(_ value: Int) -> Int {
        min(max(value, 0), 100)
    }
}

struct BluetoothBatteryWidget: View {
    @StateObject private var manager = BluetoothBatteryManager.shared
    @AppStorage("bluetooth_battery_show_laptop") private var showLaptopBattery = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "battery.100.bolt")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.green)
                    .frame(width: 34, height: 34)
                    .background(Color.green.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Batteries")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    manager.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.68))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.09))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            if manager.devices.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geo in
                    let ringSize = min(60, max(48, geo.size.height - 48))
                    let itemWidth = max(76, ringSize + 22)
                    let spacing: CGFloat = 14
                    let deviceCount = CGFloat(manager.devices.count)
                    let contentWidth = deviceCount * itemWidth + max(0, deviceCount - 1) * spacing
                    let railWidth = max(geo.size.width, contentWidth + 12)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: spacing) {
                            ForEach(manager.devices) { device in
                                BluetoothBatteryRing(device: device, ringSize: ringSize, lineWidth: 6)
                                    .frame(width: itemWidth)
                            }
                        }
                        .frame(width: railWidth, alignment: contentWidth <= geo.size.width ? .center : .leading)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
        .onAppear { manager.start() }
        .onDisappear { manager.stop() }
        .onChange(of: showLaptopBattery) { _, _ in
            manager.refresh()
        }
    }

    private var subtitle: String {
        guard !manager.devices.isEmpty else { return "No battery devices found" }
        let deviceCount = manager.devices.count
        return "\(deviceCount) \(deviceCount == 1 ? "device" : "devices")"
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "battery.0")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.white.opacity(0.42))
            Text("Connect Bluetooth devices")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.58))
        }
    }
}

private struct BluetoothBatteryRing: View {
    let device: BluetoothBatterySnapshot
    var ringSize: CGFloat = 58
    var lineWidth: CGFloat = 8

    private var ringColor: Color {
        guard let percent = device.percent else { return .white.opacity(0.55) }
        if percent <= 20 { return .red }
        if percent <= 40 { return .orange }
        return .green
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(ringColor.opacity(0.18), lineWidth: lineWidth)
                    .padding(lineWidth / 2)

                if let percent = device.percent {
                    Circle()
                        .trim(from: 0, to: CGFloat(percent) / 100)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .padding(lineWidth / 2)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: ringColor.opacity(0.28), radius: 4, x: 0, y: 0)
                } else {
                    Circle()
                        .trim(from: 0, to: 0.78)
                        .stroke(ringColor.opacity(0.42), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [3.5, 7]))
                        .padding(lineWidth / 2)
                        .rotationEffect(.degrees(-90))
                }

                Image(systemName: device.iconName)
                    .font(.system(size: max(18, ringSize * 0.36), weight: .semibold))
                    .foregroundColor(.white.opacity(0.86))

                if device.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: max(9, ringSize * 0.17), weight: .black))
                        .foregroundColor(.white)
                        .offset(y: -ringSize * 0.42)
                }
            }
            .frame(width: ringSize, height: ringSize)
            .padding(.horizontal, 3)
            .padding(.vertical, 2)

            Text(device.percent.map { "\($0)%" } ?? "--")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(device.name)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.48))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if let percent = device.percent {
            return "\(device.name), \(percent) percent"
        }
        return "\(device.name), battery unavailable"
    }
}

struct TurntablePlayerWidget: View {
    @ObservedObject var nowPlaying: NowPlayingManager
    @AppStorage("turntable_spin_speed") private var spinSpeed = 1.0
    @AppStorage("turntable_show_controls") private var showControls = false
    @AppStorage("turntable_click_record_toggle") private var clickRecordToggle = true
    @AppStorage("turntable_show_track_info") private var showTrackInfo = true
    @AppStorage("turntable_show_track_title") private var showTrackTitle = true
    @AppStorage("turntable_show_track_artist") private var showTrackArtist = true
    @AppStorage("turntable_plinth_style") private var plinthStyle = "graphite"

    @State private var songChangeCue = false
    @State private var songChangeTask: Task<Void, Never>? = nil

    private var hasMedia: Bool {
        nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
    }

    private var trackTexts: (title: String, artist: String) {
        guard hasMedia else { return ("Nothing playing", "") }

        let parts = nowPlaying.currentSong.components(separatedBy: " - ")
        let title = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? nowPlaying.currentSong
        let artist = parts.count > 1
            ? parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        return (title.isEmpty ? nowPlaying.currentSong : title, artist)
    }

    private var trackIdentity: String {
        "\(nowPlaying.currentSong)|\(nowPlaying.artworkURL?.absoluteString ?? "")"
    }

    private var infoVisible: Bool {
        showTrackInfo && hasMedia && (showTrackTitle || (showTrackArtist && !trackTexts.artist.isEmpty))
    }

    private var playbackProgress: CGFloat {
        guard hasMedia, nowPlaying.duration > 0 else { return 0 }
        return CGFloat(min(max(nowPlaying.currentTime / max(nowPlaying.duration, 1), 0), 1))
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let compact = width < 360
            let controlsVisible = showControls && hasMedia
            let infoAtTop = infoVisible && compact
            let topInfoReserve: CGFloat = infoAtTop ? 44 : 0
            let controlsHeight: CGFloat = controlsVisible ? 42 : 0
            let availableHeight = max(96, height - topInfoReserve - controlsHeight - 4)
            let targetPlinthSide = compact ? width * 0.76 : width * (infoVisible ? 0.64 : 0.76)
            let plinthSide = min(availableHeight, targetPlinthSide, 320)
            let recordSize = plinthSide * 0.86
            let recordRadius = recordSize / 2
            let targetRecordX = width * (compact ? 0.50 : (infoVisible ? 0.28 : 0.36))
            let recordCenterX = min(max(plinthSide / 2 + 6, targetRecordX), width - recordRadius - 40)
            let activeHeight = max(plinthSide, height - topInfoReserve - controlsHeight)
            let recordCenterY = topInfoReserve + activeHeight / 2
            let recordCenter = CGPoint(x: recordCenterX, y: recordCenterY)
            let controlsWidth: CGFloat = 112
            let infoWidth = infoAtTop ? max(120, width - 36) : min(max(126, width - recordCenter.x - recordRadius - 76), 230)
            let infoCenterX = infoAtTop ? width / 2 : width - infoWidth / 2 - 18
            let infoCenterY = infoAtTop ? 22 : max(38, min(height - controlsHeight - 34, recordCenter.y - recordRadius * 0.52))
            let controlsX = compact ? width / 2 : min(width - controlsWidth / 2 - 16, recordCenter.x + recordRadius + controlsWidth / 2 + 16)

            ZStack {
                if plinthStyle != "none" {
                    TurntablePlinthView(
                        side: plinthSide,
                        style: plinthStyle,
                        accentColor: nowPlaying.artworkDominantColor,
                        isChangingSong: songChangeCue
                    )
                    .position(recordCenter)
                    .shadow(color: .black.opacity(songChangeCue ? 0.44 : 0.34), radius: songChangeCue ? 18 : 12, x: 0, y: 8)
                    .zIndex(0)
                }

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.black.opacity(0.96),
                                    Color(red: 0.09, green: 0.09, blue: 0.085),
                                    Color.black
                                ],
                                center: .center,
                                startRadius: 8,
                                endRadius: recordSize * 0.6
                            )
                        )
                        .frame(width: recordSize + 18, height: recordSize + 18)
                        .shadow(color: .black.opacity(0.62), radius: 14, x: 0, y: 9)

                    TurntableRecordView(
                        artworkURL: nowPlaying.artworkURL,
                        artworkIdentity: trackIdentity,
                        isPlaying: nowPlaying.isPlaying && hasMedia,
                        hasMedia: hasMedia,
                        size: recordSize,
                        spinSpeed: spinSpeed
                    )
                }
                .position(recordCenter)
                .contentShape(Circle())
                .onTapGesture {
                    guard clickRecordToggle, hasMedia else { return }
                    nowPlaying.togglePlayPause()
                }
                .help(clickRecordToggle && hasMedia ? "Play/Pause" : "")
                .zIndex(1)

                TurntableTonearmView(
                    isPlaying: nowPlaying.isPlaying && hasMedia,
                    hasMedia: hasMedia,
                    playbackProgress: playbackProgress,
                    recordCenter: recordCenter,
                    recordRadius: recordRadius
                )
                .frame(width: width, height: height)
                .zIndex(3)

                if infoVisible {
                    TurntableTrackInfoView(
                        title: trackTexts.title,
                        artist: trackTexts.artist,
                        showTitle: showTrackTitle,
                        showArtist: showTrackArtist,
                        compact: compact
                    )
                    .frame(width: infoWidth, alignment: .leading)
                    .position(x: infoCenterX, y: infoCenterY)
                    .id(trackIdentity)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .leading)))
                    .zIndex(5)
                }

                if controlsVisible {
                    HStack(spacing: 8) {
                        turntableControl(systemName: "backward.fill", label: "Previous") {
                            nowPlaying.skipBackward()
                        }

                        turntableControl(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill", label: "Play/Pause", isPrimary: true) {
                            nowPlaying.togglePlayPause()
                        }

                        turntableControl(systemName: "forward.fill", label: "Next") {
                            nowPlaying.skipForward()
                        }
                    }
                    .frame(width: controlsWidth)
                    .position(x: controlsX, y: height - 25)
                    .zIndex(5)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.22), value: trackIdentity)
        .animation(.easeInOut(duration: 0.28), value: songChangeCue)
        .onChange(of: trackIdentity) { _, _ in
            triggerSongChangeAnimation()
        }
        .onDisappear {
            songChangeTask?.cancel()
            songChangeTask = nil
        }
    }

    private func turntableControl(systemName: String, label: String, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: isPrimary ? 12 : 10, weight: .bold))
                .foregroundColor(.white.opacity(isPrimary ? 0.92 : 0.78))
                .frame(width: isPrimary ? 32 : 28, height: 26)
                .background(isPrimary ? Color.white.opacity(0.18) : Color.white.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(label)
    }

    private func triggerSongChangeAnimation() {
        songChangeTask?.cancel()
        withAnimation(.easeOut(duration: 0.18)) {
            songChangeCue = true
        }

        songChangeTask = Task {
            try? await Task.sleep(nanoseconds: 520_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.32)) {
                    songChangeCue = false
                }
                songChangeTask = nil
            }
        }
    }
}

private struct TurntablePlinthView: View {
    let side: CGFloat
    let style: String
    let accentColor: Color
    let isChangingSong: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(fillStyle)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.black.opacity(0.28), lineWidth: 1)
                    .padding(6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(isChangingSong ? 0.20 : 0.04),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
            )
            .frame(width: side, height: side)
    }

    private var fillStyle: AnyShapeStyle {
        switch style {
        case "walnut":
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.34, green: 0.25, blue: 0.21).opacity(0.58),
                        Color(red: 0.18, green: 0.12, blue: 0.10).opacity(0.72),
                        Color.black.opacity(0.34)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case "album":
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        accentColor.opacity(0.46),
                        accentColor.opacity(0.20),
                        Color.black.opacity(0.38)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case "glass":
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.18),
                        Color.white.opacity(0.055),
                        Color.black.opacity(0.24)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        default:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.11),
                        Color(red: 0.08, green: 0.08, blue: 0.085).opacity(0.58),
                        Color.black.opacity(0.34)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var borderColor: Color {
        switch style {
        case "album": return accentColor.opacity(isChangingSong ? 0.34 : 0.18)
        case "glass": return Color.white.opacity(isChangingSong ? 0.22 : 0.14)
        case "walnut": return Color.white.opacity(isChangingSong ? 0.20 : 0.11)
        default: return Color.white.opacity(isChangingSong ? 0.20 : 0.10)
        }
    }
}

private struct TurntableTrackInfoView: View {
    let title: String
    let artist: String
    let showTitle: Bool
    let showArtist: Bool
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if showTitle {
                MarqueeText(
                    text: title,
                    font: .system(size: compact ? 13 : 15, weight: .bold),
                    alignment: .leading
                )
                .frame(height: compact ? 17 : 20)
                .foregroundColor(.white)
            }

            if showArtist && !artist.isEmpty {
                MarqueeText(
                    text: artist,
                    font: .system(size: compact ? 11 : 12, weight: .semibold),
                    alignment: .leading
                )
                .frame(height: 15)
                .foregroundColor(.white.opacity(0.62))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct TurntableRecordView: View {
    let artworkURL: URL?
    let artworkIdentity: String
    let isPlaying: Bool
    let hasMedia: Bool
    let size: CGFloat
    let spinSpeed: Double

    @State private var displayedArtworkURL: URL? = nil
    @State private var labelFlipDegrees: Double = 0
    @State private var artworkTransitionTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            AnimatedTurntableDisc(
                size: size,
                isPlaying: isPlaying,
                spinSpeed: spinSpeed,
                hasMedia: hasMedia,
                displayedArtworkURL: displayedArtworkURL,
                labelFlipDegrees: labelFlipDegrees
            )

            TurntableReflection(size: size)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .onAppear {
            displayedArtworkURL = artworkURL
        }
        .onChange(of: artworkIdentity) { _, _ in
            rotateToArtwork(artworkURL)
        }
        .onDisappear {
            artworkTransitionTask?.cancel()
            artworkTransitionTask = nil
        }
    }

    private func rotateToArtwork(_ newArtworkURL: URL?) {
        artworkTransitionTask?.cancel()

        withAnimation(.easeIn(duration: 0.16)) {
            labelFlipDegrees = 88
        }

        artworkTransitionTask = Task {
            try? await Task.sleep(nanoseconds: 160_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                displayedArtworkURL = newArtworkURL
                labelFlipDegrees = -88

                withAnimation(.easeOut(duration: 0.22)) {
                    labelFlipDegrees = 0
                }

                artworkTransitionTask = nil
            }
        }
    }
}

private struct TurntableReflection: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.white.opacity(0.16), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size * 0.84, height: size * 0.08)
                .blur(radius: 4)
                .rotationEffect(.degrees(-8))
                .blendMode(.screen)

            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                .padding(5)
        }
    }
}

private struct AnimatedTurntableDisc: View {
    let size: CGFloat
    let isPlaying: Bool
    let spinSpeed: Double
    let hasMedia: Bool
    let displayedArtworkURL: URL?
    let labelFlipDegrees: Double

    @State private var phaseAtTransition: Double = 0
    @State private var velocityAtTransition: Double = 0
    @State private var transitionDate = Date()
    @State private var animateAfterPause = false
    @State private var pauseAnimationTask: Task<Void, Never>? = nil

    var body: some View {
        TimelineView(.animation(minimumInterval: WidgetPerformance.mediaAnimationFrameInterval, paused: !isPlaying && !animateAfterPause)) { timeline in
            ZStack {
                TurntableVinylBase(size: size)
                    .equatable()

                TurntableCenterLabel(
                    size: size,
                    hasMedia: hasMedia,
                    displayedArtworkURL: displayedArtworkURL,
                    labelFlipDegrees: labelFlipDegrees
                )
                .equatable()
                .rotationEffect(.degrees(rotation(at: timeline.date)))
            }
            .onAppear {
                transitionDate = timeline.date
                velocityAtTransition = isPlaying ? targetSpinVelocity : 0
            }
            .onChange(of: isPlaying) { wasPlaying, _ in
                resetMotion(at: timeline.date, wasPlaying: wasPlaying)
            }
            .onChange(of: spinSpeed) { _, _ in
                resetMotion(at: timeline.date, wasPlaying: isPlaying)
            }
        }
        .onDisappear {
            pauseAnimationTask?.cancel()
            pauseAnimationTask = nil
        }
    }

    private var targetSpinVelocity: Double {
        122 * min(max(spinSpeed, 0.5), 2.0)
    }

    private func rotation(at date: Date) -> Double {
        rotation(at: date, playing: isPlaying)
    }

    private func rotation(at date: Date, playing: Bool) -> Double {
        let elapsed = max(0, date.timeIntervalSince(transitionDate))

        if playing {
            let ramp = WidgetPerformance.mediaStartRampDuration
            if elapsed < ramp {
                return phaseAtTransition + targetSpinVelocity * ramp * WidgetPerformance.smoothstepIntegral(elapsed / ramp)
            }
            return phaseAtTransition + targetSpinVelocity * ((ramp * 0.5) + (elapsed - ramp))
        }

        let ramp = WidgetPerformance.mediaStopRampDuration
        if elapsed < ramp {
            return phaseAtTransition + velocityAtTransition * ramp * WidgetPerformance.easingOutIntegral(elapsed / ramp)
        }
        return phaseAtTransition + velocityAtTransition * ramp * 0.5
    }

    private func velocity(at date: Date) -> Double {
        velocity(at: date, playing: isPlaying)
    }

    private func velocity(at date: Date, playing: Bool) -> Double {
        let elapsed = max(0, date.timeIntervalSince(transitionDate))

        if playing {
            let ramp = WidgetPerformance.mediaStartRampDuration
            guard elapsed < ramp else { return targetSpinVelocity }
            return targetSpinVelocity * WidgetPerformance.smoothstep(elapsed / ramp)
        }

        let ramp = WidgetPerformance.mediaStopRampDuration
        guard elapsed < ramp else { return 0 }
        return velocityAtTransition * (1 - WidgetPerformance.smoothstep(elapsed / ramp))
    }

    private func resetMotion(at date: Date, wasPlaying: Bool) {
        phaseAtTransition = rotation(at: date, playing: wasPlaying).truncatingRemainder(dividingBy: 360)
        velocityAtTransition = velocity(at: date, playing: wasPlaying)
        transitionDate = date

        pauseAnimationTask?.cancel()
        if isPlaying {
            animateAfterPause = false
        } else {
            animateAfterPause = true
            pauseAnimationTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64((WidgetPerformance.mediaStopRampDuration + 0.1) * 1_000_000_000))
                animateAfterPause = false
            }
        }
    }
}

private struct TurntableVinylBase: View, Equatable {
    let size: CGFloat

    static func == (lhs: TurntableVinylBase, rhs: TurntableVinylBase) -> Bool {
        abs(lhs.size - rhs.size) < 0.5
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.025, green: 0.025, blue: 0.025),
                            Color.black,
                            Color(red: 0.055, green: 0.055, blue: 0.052),
                            Color.black
                        ],
                        center: .center,
                        startRadius: 3,
                        endRadius: size * 0.55
                    )
                )

            Circle()
                .stroke(Color.black.opacity(0.85), lineWidth: 10)
                .padding(3)

            Circle()
                .stroke(Color.black.opacity(0.42), lineWidth: 4)
                .padding(13)

            Circle()
                .stroke(Color.white.opacity(0.055), lineWidth: 1.5)
                .padding(18)

            ForEach(0..<14, id: \.self) { index in
                let ringSize = size * (0.27 + CGFloat(index) * 0.045)
                Circle()
                    .stroke(
                        Color.white.opacity(index.isMultiple(of: 3) ? 0.060 : 0.020),
                        lineWidth: index.isMultiple(of: 3) ? 0.72 : 0.36
                    )
                    .frame(width: ringSize, height: ringSize)
            }

            ForEach(0..<8, id: \.self) { index in
                Rectangle()
                    .fill(Color.white.opacity(index.isMultiple(of: 2) ? 0.014 : 0.007))
                    .frame(width: 1, height: size * 0.34)
                    .offset(y: -size * 0.17)
                    .rotationEffect(.degrees(Double(index) * 45))
                    .blendMode(.screen)
            }

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.09),
                            Color.clear,
                            Color.white.opacity(0.045),
                            Color.clear
                        ],
                        center: .center
                    ),
                    lineWidth: 7
                )
                .padding(size * 0.09)
        }
    }
}

private struct TurntableCenterLabel: View, Equatable {
    let size: CGFloat
    let hasMedia: Bool
    let displayedArtworkURL: URL?
    let labelFlipDegrees: Double

    static func == (lhs: TurntableCenterLabel, rhs: TurntableCenterLabel) -> Bool {
        abs(lhs.size - rhs.size) < 0.5
            && lhs.hasMedia == rhs.hasMedia
            && lhs.displayedArtworkURL == rhs.displayedArtworkURL
            && abs(lhs.labelFlipDegrees - rhs.labelFlipDegrees) < 0.5
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(labelBackground)
                .frame(width: size * 0.50, height: size * 0.50)
                .overlay(labelArtwork)
                .rotation3DEffect(
                    .degrees(labelFlipDegrees),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.48
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.42), radius: 4, y: 2)

            Circle()
                .fill(Color.white.opacity(0.88))
                .frame(width: size * 0.058, height: size * 0.058)
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
        }
    }

    private var labelBackground: some ShapeStyle {
        RadialGradient(
            colors: [
                Color.white.opacity(hasMedia ? 0.32 : 0.18),
                Color.gray.opacity(hasMedia ? 0.22 : 0.10),
                Color.black.opacity(0.18)
            ],
            center: .center,
            startRadius: 1,
            endRadius: size * 0.25
        )
    }

    @ViewBuilder
    private var labelArtwork: some View {
        if hasMedia, let displayedArtworkURL {
            AsyncImage(url: displayedArtworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ProgressView()
                    .controlSize(.mini)
            }
            .clipShape(Circle())
        } else {
            Image(systemName: "music.note")
                .font(.system(size: size * 0.16, weight: .bold))
                .foregroundColor(.white.opacity(0.58))
        }
    }
}
private struct TurntableTonearmView: View {
    let isPlaying: Bool
    let hasMedia: Bool
    let playbackProgress: CGFloat
    let recordCenter: CGPoint
    let recordRadius: CGFloat

    @State private var displayedGrooveProgress: CGFloat = 0
    @State private var engagementProgress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let postX = min(width - 24, recordCenter.x + recordRadius * 1.10)
            let pivot = CGPoint(x: postX, y: recordCenter.y - recordRadius * 0.35)
            
            let armLength = recordRadius * 1.25
            
            // Angles (in degrees) relative to pointing straight down
            let parkedAngle: Double = -12.0
            let outerGrooveAngle: Double = 18.0
            let innerGrooveAngle: Double = 38.0
            
            let currentAngle = (1 - engagementProgress) * parkedAngle + engagementProgress * (outerGrooveAngle + (innerGrooveAngle - outerGrooveAngle) * displayedGrooveProgress)

            ZStack {
                // The Base
                TurntableArmBaseView(
                    pivot: pivot,
                    isEngaged: hasMedia && isPlaying
                )

                // The Rotating Arm Assembly
                ZStack(alignment: .center) {
                    // Arm counterweight
                    Capsule()
                        .fill(Color(white: 0.6))
                        .frame(width: 8, height: 16)
                        .offset(y: -12)
                        
                    // Arm pole
                    Capsule()
                        .fill(Color(white: 0.8))
                        .frame(width: 4, height: armLength)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                        .offset(y: armLength / 2)
                    
                    // Cartridge
                    TurntableCartridgeView()
                        .rotationEffect(.degrees(22), anchor: .top) // Rotate AT the attachment point
                        .offset(y: armLength) // Then move it down to the end of the pole
                }
                .frame(width: 0, height: 0)
                .rotationEffect(.degrees(currentAngle), anchor: .center)
                .position(pivot)
                
                // Pivot cap on top
                Circle()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: 12, height: 12)
                    .position(pivot)
                
                Circle()
                    .fill(Color.gray)
                    .frame(width: 4, height: 4)
                    .position(pivot)
            }
            .onAppear {
                displayedGrooveProgress = targetGrooveProgress
                engagementProgress = targetEngagementProgress
            }
            .onChange(of: targetGrooveProgress) { _, newProgress in
                withAnimation(.linear(duration: 0.9)) {
                    displayedGrooveProgress = newProgress
                }
            }
            .onChange(of: targetEngagementProgress) { _, newProgress in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    engagementProgress = newProgress
                }
            }
        }
    }

    private var targetGrooveProgress: CGFloat {
        guard hasMedia else { return 0 }
        return min(max(playbackProgress, 0), 1)
    }

    private var targetEngagementProgress: CGFloat {
        hasMedia && isPlaying ? 1 : 0
    }
}

private struct TurntableArmBaseView: View {
    let pivot: CGPoint
    let isEngaged: Bool

    var body: some View {
        ZStack {
            // Main pivot circle
            Circle()
                .fill(Color(white: 0.2))
                .frame(width: 24, height: 24)
                .position(pivot)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
    }
}

private struct TurntableCartridgeView: View {
    var body: some View {
        ZStack(alignment: .top) {
            // Head shell
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(white: 0.15))
                .frame(width: 12, height: 24)
                .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1)
            
            // Stylus line
            Rectangle()
                .fill(Color.gray)
                .frame(width: 2, height: 4)
                .offset(y: 24)
        }
    }
}

struct CassetteTapeWidget: View {
    @ObservedObject var nowPlaying: NowPlayingManager

    @AppStorage("cassette_reel_speed") private var reelSpeed = 1.0
    @AppStorage("cassette_click_to_toggle") private var clickToToggle = true
    @AppStorage("cassette_show_track_info") private var showTrackInfo = true
    @AppStorage("cassette_show_track_title") private var showTrackTitle = true
    @AppStorage("cassette_show_track_artist") private var showTrackArtist = true
    @AppStorage("cassette_show_album_cover") private var showAlbumCover = true
    @AppStorage("cassette_label_color") private var labelColor = "orange"
    @AppStorage("cassette_body_color") private var bodyColor = "black"

    private var hasMedia: Bool {
        nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
    }

    private var trackTexts: (title: String, artist: String) {
        guard hasMedia else { return ("No tape loaded", "") }

        let parts = nowPlaying.currentSong.components(separatedBy: " - ")
        let title = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? nowPlaying.currentSong
        let artist = parts.count > 1
            ? parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        return (title.isEmpty ? nowPlaying.currentSong : title, artist)
    }

    private var trackIdentity: String {
        "\(nowPlaying.currentSong)|\(nowPlaying.artworkURL?.absoluteString ?? "")"
    }

    private var playbackProgress: CGFloat {
        guard hasMedia, nowPlaying.duration > 0 else { return 0 }
        return CGFloat(min(max(nowPlaying.currentTime / max(nowPlaying.duration, 1), 0), 1))
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let cassetteHeight = min(max(118, height - 20), max(118, (width - 24) / 1.62), 188)
            let cassetteWidth = min(width - 20, cassetteHeight * 1.62)

            CassetteTapeDeckView(
                artworkURL: nowPlaying.artworkURL,
                artworkIdentity: trackIdentity,
                title: trackTexts.title,
                artist: trackTexts.artist,
                isPlaying: nowPlaying.isPlaying && hasMedia,
                hasMedia: hasMedia,
                playbackProgress: playbackProgress,
                width: cassetteWidth,
                height: cassetteHeight,
                reelSpeed: reelSpeed,
                showTrackInfo: showTrackInfo,
                showTrackTitle: showTrackTitle,
                showTrackArtist: showTrackArtist,
                showAlbumCover: showAlbumCover,
                accentColor: nowPlaying.artworkDominantColor,
                labelColor: labelColor,
                bodyColor: bodyColor
            )
            .position(x: width / 2, y: height / 2)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onTapGesture {
                guard clickToToggle, hasMedia else { return }
                nowPlaying.togglePlayPause()
            }
            .help(clickToToggle && hasMedia ? "Play/Pause" : "")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CassetteTapeDeckView: View {
    let artworkURL: URL?
    let artworkIdentity: String
    let title: String
    let artist: String
    let isPlaying: Bool
    let hasMedia: Bool
    let playbackProgress: CGFloat
    let width: CGFloat
    let height: CGFloat
    let reelSpeed: Double
    let showTrackInfo: Bool
    let showTrackTitle: Bool
    let showTrackArtist: Bool
    let showAlbumCover: Bool
    let accentColor: Color
    let labelColor: String
    let bodyColor: String

    @State private var artworkPulse = false

    var body: some View {
        ZStack {
            cassetteShell
            cassetteBottom
            cassetteLabel
            staticTapeWindowBackground
            AnimatedCassetteReels(
                width: width,
                height: height,
                playbackProgress: playbackProgress,
                isPlaying: isPlaying,
                reelSpeed: reelSpeed
            )
            screws
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.34), radius: 13, x: 0, y: 8)
        .onChange(of: artworkIdentity) { _, _ in
            triggerArtworkPulse()
        }
    }

    private var baseBodyColor: Color {
        switch bodyColor {
        case "white": return Color(white: 0.85)
        case "transparent": return Color.black.opacity(0.3)
        case "dynamic": return accentColor
        case "black": fallthrough
        default: return Color(red: 0.11, green: 0.11, blue: 0.10)
        }
    }

    private var cassetteShell: some View {
        let currentBodyColor = baseBodyColor

        return RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        currentBodyColor,
                        currentBodyColor.opacity(0.85),
                        currentBodyColor.opacity(0.7)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .animation(.easeInOut(duration: 0.5), value: currentBodyColor)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1.1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.60), lineWidth: 3)
                    .padding(7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.055), lineWidth: 1)
                    .padding(10)
            )
            .overlay(shellTexture)
    }

    private var shellTexture: some View {
        ZStack {
            ForEach(0..<38, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(index.isMultiple(of: 3) ? 0.030 : 0.014))
                    .frame(width: width * 0.76, height: 0.8)
                    .rotationEffect(.degrees(-8))
                    .position(x: width * 0.50, y: height * (0.07 + CGFloat(index) * 0.023))
            }

            ForEach(0..<22, id: \.self) { index in
                Rectangle()
                    .fill(Color.black.opacity(index.isMultiple(of: 2) ? 0.42 : 0.24))
                    .frame(width: 1, height: height * 0.74)
                    .position(x: width * (0.08 + CGFloat(index) * 0.040), y: height * 0.50)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var baseLabelColor: Color {
        switch labelColor {
        case "red": return Color(red: 0.85, green: 0.25, blue: 0.25)
        case "blue": return Color(red: 0.25, green: 0.45, blue: 0.85)
        case "green": return Color(red: 0.25, green: 0.75, blue: 0.35)
        case "purple": return Color(red: 0.55, green: 0.25, blue: 0.75)
        case "gray": return Color(white: 0.65)
        case "dynamic": return accentColor
        case "orange": fallthrough
        default: return Color(red: 1.0, green: 0.58, blue: 0.05)
        }
    }

    private var cassetteLabel: some View {
        let labelWidth = width * 0.82
        let labelX = width / 2
        let topPanelHeight = height * 0.25
        let topPanelY = height * 0.27
        let orangeHeight = height * 0.34
        let orangeY = height * 0.52
        let coverSize = min(height * 0.17, 34)
        let titleLeft = showAlbumCover ? width * 0.24 : width * 0.14
        let titleWidth = width * 0.56 // Increased to prevent horizontal truncation
        let authorLeft = width * 0.115
        let authorWidth = width * 0.395

        let currentLabelColor = baseLabelColor

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(red: 0.05, green: 0.05, blue: 0.045).opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .frame(width: labelWidth, height: height * 0.50)
                .position(x: labelX, y: height * 0.42)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            currentLabelColor.opacity(0.85),
                            currentLabelColor,
                            currentLabelColor.opacity(0.9)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .animation(.easeInOut(duration: 0.5), value: currentLabelColor)
                .frame(width: labelWidth, height: orangeHeight)
                .position(x: labelX, y: orangeY)

            Rectangle()
                .fill(Color.black.opacity(0.90))
                .frame(width: labelWidth, height: topPanelHeight)
                .position(x: labelX, y: topPanelY)

            Text(showTrackInfo && showTrackArtist && !artist.isEmpty ? artist.lowercased() : "wave notch")
                .font(.system(size: max(13, height * 0.155), weight: .heavy, design: .rounded))
                .foregroundColor(currentLabelColor)
                .animation(.easeInOut(duration: 0.5), value: currentLabelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .frame(width: authorWidth, alignment: .leading)
                .position(x: authorLeft + authorWidth / 2, y: height * 0.30)

            VStack(alignment: .trailing, spacing: -4) {
                Text("90")
                    .font(.system(size: max(34, height * 0.35), weight: .black, design: .rounded))
                    .foregroundColor(currentLabelColor)
                    .animation(.easeInOut(duration: 0.5), value: currentLabelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)
                Text("2 x 45 min.")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(currentLabelColor.opacity(0.85))
                    .animation(.easeInOut(duration: 0.5), value: currentLabelColor)
            }
            .frame(width: width * 0.19, alignment: .trailing)
            .position(x: width * 0.76, y: height * 0.27)

            if showAlbumCover {
                CassetteArtworkView(artworkURL: artworkURL, hasMedia: hasMedia)
                    .frame(width: coverSize, height: coverSize)
                    .scaleEffect(artworkPulse ? 1.06 : 1)
                    .rotationEffect(.degrees(-3))
                    .position(x: width * 0.17, y: height * 0.68)
                    .animation(.spring(response: 0.34, dampingFraction: 0.72), value: artworkPulse)
            } else {
                Text("1")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.black.opacity(0.80))
                    .position(x: width * 0.16, y: height * 0.70)
            }

            if showTrackInfo {
                VStack(alignment: .leading, spacing: 0) {
                    if showTrackTitle {
                        MarqueeText(
                            text: title.uppercased(),
                            font: .system(size: max(14, height * 0.15), weight: .heavy, design: .rounded),
                            alignment: .leading
                        )
                        .frame(height: height * 0.17)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 1)
                        .id("cassette_title_\(title)")
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.5), value: title)
                .frame(width: titleWidth, alignment: .leading)
                .position(x: titleLeft + titleWidth / 2, y: height * 0.70)
            }

            Text("Compact\nCassette")
                .font(.system(size: 7, weight: .bold, design: .rounded))
                .italic()
                .foregroundColor(.black.opacity(0.72))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.black.opacity(0.70), lineWidth: 1)
                )
                .rotationEffect(.degrees(-5))
                .position(x: width * 0.80, y: height * 0.61)

            Rectangle()
                .fill(Color.black.opacity(0.70))
                .frame(width: labelWidth * 0.80, height: 1.2)
                .position(x: width * 0.48, y: height * 0.80)
        }
    }

    private var staticTapeWindowBackground: some View {
        let windowWidth = width * 0.58
        let windowHeight = height * 0.21
        let windowY = height * 0.50

        return ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.black.opacity(0.94))
                .frame(width: windowWidth, height: windowHeight)
                .position(x: width / 2, y: windowY)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        .frame(width: windowWidth, height: windowHeight)
                        .position(x: width / 2, y: windowY)
                )
                .shadow(color: .black.opacity(0.52), radius: 4, x: 0, y: 2)

            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: width * 0.24, height: 1.2)
                .position(x: width / 2, y: windowY)

            HStack(spacing: width * 0.035) {
                ForEach(["100", "50", "0"], id: \.self) { marker in
                    Text(marker)
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.28))
                }
            }
            .position(x: width / 2, y: windowY + windowHeight * 0.34)
        }
    }

    private var cassetteBottom: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: width * 0.18, y: height * 0.74))
                path.addLine(to: CGPoint(x: width * 0.82, y: height * 0.74))
                path.addLine(to: CGPoint(x: width * 0.88, y: height * 0.92))
                path.addLine(to: CGPoint(x: width * 0.12, y: height * 0.92))
                path.closeSubpath()
            }
            .fill(Color.black.opacity(0.64))
            .overlay(
                Path { path in
                    path.move(to: CGPoint(x: width * 0.18, y: height * 0.74))
                    path.addLine(to: CGPoint(x: width * 0.82, y: height * 0.74))
                    path.addLine(to: CGPoint(x: width * 0.88, y: height * 0.92))
                    path.addLine(to: CGPoint(x: width * 0.12, y: height * 0.92))
                    path.closeSubpath()
                }
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
            )

            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.black.opacity(0.50))
                    .frame(width: width * 0.12, height: height * 0.20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    .position(x: width * (0.25 + CGFloat(index) * 0.25), y: height * 0.84)
            }

            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.42))
                    .frame(width: height * 0.105, height: height * 0.105)
                    .overlay(Circle().stroke(Color.black.opacity(0.42), lineWidth: 1))
                    .shadow(color: .black.opacity(0.32), radius: 2, y: 1)
                    .position(x: width * (0.32 + CGFloat(index) * 0.12), y: height * 0.86)
            }
        }
    }

    private var screws: some View {
        ZStack {
            ForEach(Array(screwPoints.enumerated()), id: \.offset) { _, point in
                CassetteScrewView()
                    .frame(width: height * 0.12, height: height * 0.12)
                    .position(x: point.x * width, y: point.y * height)
            }
        }
    }

    private var screwPoints: [CGPoint] {
        [
            CGPoint(x: 0.06, y: 0.10),
            CGPoint(x: 0.94, y: 0.10),
            CGPoint(x: 0.06, y: 0.91),
            CGPoint(x: 0.94, y: 0.91)
        ]
    }

    private func triggerArtworkPulse() {
        artworkPulse = true
        Task {
            try? await Task.sleep(nanoseconds: 260_000_000)
            await MainActor.run {
                artworkPulse = false
            }
        }
    }
}

private struct AnimatedCassetteReels: View {
    let width: CGFloat
    let height: CGFloat
    let playbackProgress: CGFloat
    let isPlaying: Bool
    let reelSpeed: Double

    @State private var phaseAtTransition: Double = 0
    @State private var velocityAtTransition: Double = 0
    @State private var transitionDate = Date()
    @State private var animateAfterPause = false
    @State private var pauseAnimationTask: Task<Void, Never>? = nil

    var body: some View {
        TimelineView(.animation(minimumInterval: WidgetPerformance.mediaAnimationFrameInterval, paused: !isPlaying && !animateAfterPause)) { timeline in
            let windowHeight = height * 0.21
            let windowY = height * 0.50
            let leftCenter = CGPoint(x: width * 0.35, y: windowY)
            let rightCenter = CGPoint(x: width * 0.65, y: windowY)
            let reelSize = height * 0.29
            let clampedProgress = min(max(playbackProgress, 0), 1)
            let leftSpool = 0.76 - clampedProgress * 0.34
            let rightSpool = 0.38 + clampedProgress * 0.34
            let reelRotation = rotation(at: timeline.date)
            let tapePhase = (reelRotation * 0.045).truncatingRemainder(dividingBy: 16)

            Canvas(rendersAsynchronously: true) { context, _ in
                drawTapeStrip(
                    context: &context,
                    center: CGPoint(x: width / 2, y: windowY),
                    size: CGSize(width: width * 0.22, height: windowHeight * 0.52),
                    phase: tapePhase,
                    isPlaying: isPlaying
                )
                drawReel(
                    context: &context,
                    center: leftCenter,
                    size: reelSize,
                    rotation: reelRotation,
                    spoolFraction: leftSpool,
                    isPlaying: isPlaying
                )
                drawReel(
                    context: &context,
                    center: rightCenter,
                    size: reelSize,
                    rotation: -reelRotation * 1.08,
                    spoolFraction: rightSpool,
                    isPlaying: isPlaying
                )
            }
            .onAppear {
                transitionDate = timeline.date
                velocityAtTransition = isPlaying ? targetReelVelocity : 0
            }
            .onChange(of: isPlaying) { wasPlaying, _ in
                resetMotion(at: timeline.date, wasPlaying: wasPlaying)
            }
            .onChange(of: reelSpeed) { _, _ in
                resetMotion(at: timeline.date, wasPlaying: isPlaying)
            }
        }
        .onDisappear {
            pauseAnimationTask?.cancel()
            pauseAnimationTask = nil
        }
    }

    private func drawTapeStrip(
        context: inout GraphicsContext,
        center: CGPoint,
        size: CGSize,
        phase: Double,
        isPlaying: Bool
    ) {
        let rect = CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        let strip = Path(roundedRect: rect, cornerRadius: 4)
        context.fill(
            strip,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.07, green: 0.04, blue: 0.025),
                    Color(red: 0.27, green: 0.18, blue: 0.10),
                    Color(red: 0.08, green: 0.04, blue: 0.025)
                ]),
                startPoint: CGPoint(x: rect.minX, y: rect.midY),
                endPoint: CGPoint(x: rect.maxX, y: rect.midY)
            )
        )

        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: rect.minX + 5, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX - 5, y: rect.midY))
            },
            with: .color(Color.white.opacity(0.24)),
            lineWidth: 0.9
        )

        guard isPlaying else { return }

        let phaseOffset = CGFloat(phase.truncatingRemainder(dividingBy: 16))
        for index in -2...6 {
            let x = rect.minX + CGFloat(index) * 8 + phaseOffset
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: x, y: rect.minY + 3))
                    path.addLine(to: CGPoint(x: x + 7, y: rect.maxY - 3))
                },
                with: .color(Color.white.opacity(0.08)),
                lineWidth: 0.7
            )
        }
    }

    private func drawReel(
        context: inout GraphicsContext,
        center: CGPoint,
        size: CGFloat,
        rotation: Double,
        spoolFraction: CGFloat,
        isPlaying: Bool
    ) {
        let outerSize = size * 0.92
        let outerRect = CGRect(
            x: center.x - outerSize / 2,
            y: center.y - outerSize / 2,
            width: outerSize,
            height: outerSize
        )
        let outer = Path(ellipseIn: outerRect)

        context.fill(
            outer,
            with: .radialGradient(
                Gradient(colors: [
                    Color.black.opacity(0.96),
                    Color(red: 0.19, green: 0.16, blue: 0.12),
                    Color.black.opacity(0.88)
                ]),
                center: center,
                startRadius: 2,
                endRadius: size * 0.45
            )
        )
        context.stroke(outer, with: .color(Color.white.opacity(0.16)), lineWidth: 1)

        let spoolSize = size * min(max(spoolFraction, 0.36), 0.78)
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - spoolSize / 2,
                y: center.y - spoolSize / 2,
                width: spoolSize,
                height: spoolSize
            )),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.23, green: 0.15, blue: 0.08),
                    Color(red: 0.10, green: 0.06, blue: 0.035),
                    Color.black
                ]),
                center: center,
                startRadius: 1,
                endRadius: spoolSize * 0.52
            )
        )

        let baseTransform = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: CGFloat(rotation * .pi / 180))
            .translatedBy(x: -center.x, y: -center.y)
        let spokeWidth = size * 0.12
        let spokeHeight = size * 0.28
        let spokeOffset = size * 0.18

        for index in 0..<6 {
            let transform = baseTransform
                .translatedBy(x: center.x, y: center.y)
                .rotated(by: CGFloat(index) * .pi / 3)
                .translatedBy(x: -center.x, y: -center.y)
            let rect = CGRect(
                x: center.x - spokeWidth / 2,
                y: center.y - spokeOffset - spokeHeight / 2,
                width: spokeWidth,
                height: spokeHeight
            )
            context.fill(
                Path(roundedRect: rect, cornerRadius: spokeWidth * 0.32).applying(transform),
                with: .color(Color.white.opacity(0.76))
            )
        }

        let hubRect = CGRect(
            x: center.x - size * 0.18,
            y: center.y - size * 0.18,
            width: size * 0.36,
            height: size * 0.36
        )
        context.fill(
            Path(ellipseIn: hubRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(0.95),
                    Color(red: 0.62, green: 0.62, blue: 0.58),
                    Color.white.opacity(0.62)
                ]),
                center: CGPoint(x: hubRect.minX, y: hubRect.minY),
                startRadius: 1,
                endRadius: size * 0.22
            )
        )
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - size * 0.07,
                y: center.y - size * 0.07,
                width: size * 0.14,
                height: size * 0.14
            )),
            with: .color(Color.black.opacity(isPlaying ? 0.30 : 0.24))
        )
    }

    private var targetReelVelocity: Double {
        235 * min(max(reelSpeed, 0.5), 2.0)
    }

    private func rotation(at date: Date) -> Double {
        rotation(at: date, playing: isPlaying)
    }

    private func rotation(at date: Date, playing: Bool) -> Double {
        let elapsed = max(0, date.timeIntervalSince(transitionDate))

        if playing {
            let ramp = WidgetPerformance.mediaStartRampDuration
            if elapsed < ramp {
                return phaseAtTransition + targetReelVelocity * ramp * WidgetPerformance.smoothstepIntegral(elapsed / ramp)
            }
            return phaseAtTransition + targetReelVelocity * ((ramp * 0.5) + (elapsed - ramp))
        }

        let ramp = WidgetPerformance.mediaStopRampDuration
        if elapsed < ramp {
            return phaseAtTransition + velocityAtTransition * ramp * WidgetPerformance.easingOutIntegral(elapsed / ramp)
        }
        return phaseAtTransition + velocityAtTransition * ramp * 0.5
    }

    private func velocity(at date: Date) -> Double {
        velocity(at: date, playing: isPlaying)
    }

    private func velocity(at date: Date, playing: Bool) -> Double {
        let elapsed = max(0, date.timeIntervalSince(transitionDate))

        if playing {
            let ramp = WidgetPerformance.mediaStartRampDuration
            guard elapsed < ramp else { return targetReelVelocity }
            return targetReelVelocity * WidgetPerformance.smoothstep(elapsed / ramp)
        }

        let ramp = WidgetPerformance.mediaStopRampDuration
        guard elapsed < ramp else { return 0 }
        return velocityAtTransition * (1 - WidgetPerformance.smoothstep(elapsed / ramp))
    }

    private func resetMotion(at date: Date, wasPlaying: Bool) {
        phaseAtTransition = rotation(at: date, playing: wasPlaying).truncatingRemainder(dividingBy: 360)
        velocityAtTransition = velocity(at: date, playing: wasPlaying)
        transitionDate = date

        pauseAnimationTask?.cancel()
        if isPlaying {
            animateAfterPause = false
        } else {
            animateAfterPause = true
            pauseAnimationTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64((WidgetPerformance.mediaStopRampDuration + 0.1) * 1_000_000_000))
                animateAfterPause = false
            }
        }
    }
}
private struct CassetteArtworkView: View {
    let artworkURL: URL?
    let hasMedia: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.black.opacity(0.28))

            if hasMedia, let artworkURL {
                AsyncImage(url: artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                        .controlSize(.mini)
                }
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black.opacity(0.34))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color.black.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.24), radius: 2, y: 1)
    }
}

private struct CassetteScrewView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.78),
                            Color(red: 0.42, green: 0.42, blue: 0.40),
                            Color.black.opacity(0.82)
                        ],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 9
                    )
                )

            Rectangle()
                .fill(Color.black.opacity(0.70))
                .frame(height: 1.7)
                .padding(.horizontal, 3.5)
                .rotationEffect(.degrees(-18))
        }
    }
}

struct CalendarWidget: View {
    @ObservedObject var googleManager = GoogleCalendarManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !googleManager.isAuthenticated {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                    Text("Google Login Required")
                        .font(.system(size: 13, weight: .bold))
                    Text("Please sign in to Google in the Plugin Store.")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if googleManager.isFetching && googleManager.upcomingEvents.isEmpty {
                VStack {
                    Spacer()
                    ProgressView().controlSize(.small)
                    Text("Syncing Google Calendar...")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if googleManager.upcomingEvents.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("All clear for today!")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(googleManager.upcomingEvents) { event in
                            HStack(spacing: 10) {
                                // Calendar Color Strip
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(colorFromHex(event.calendarColor))
                                    .frame(width: 3, height: 24)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(event.summary)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    Text(formatGoogleEventTime(event))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            googleManager.fetchTodaysEvents()
        }
    }
    
    private func colorFromHex(_ hex: String?) -> Color {
        guard let hex = hex else { return .accentColor }
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHex.hasPrefix("#") { cleanHex.removeFirst() }
        
        var rgb: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgb)
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        return Color(red: r, green: g, blue: b)
    }
    
    private func formatGoogleEventTime(_ event: GoogleCalendarEvent) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        if let startStr = event.start.dateTime, let endStr = event.end.dateTime {
            let iso = ISO8601DateFormatter()
            if let start = iso.date(from: startStr), let end = iso.date(from: endStr) {
                return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
            }
        }
        
        return "All Day"
    }
}

enum PomodoroMode: String {
    case focus
    case shortBreak
    case longBreak

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    var subtitle: String {
        switch self {
        case .focus: return "Study session"
        case .shortBreak: return "Quick reset"
        case .longBreak: return "Long reset"
        }
    }

    var color: Color {
        switch self {
        case .focus: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }

    var iconName: String {
        switch self {
        case .focus: return "book.fill"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "moon.stars.fill"
        }
    }
}

struct PomodoroTransition: Equatable {
    let completedMode: PomodoroMode
    let nextMode: PomodoroMode
    let nextCompletedFocusSessions: Int
}

final class PomodoroTimerManager: ObservableObject {
    static let shared = PomodoroTimerManager()

    @Published private(set) var mode: PomodoroMode
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var totalSeconds: Int
    @Published private(set) var isRunning = false
    @Published private(set) var completedFocusSessions: Int
    @Published private(set) var longBreakEvery: Int
    @Published private(set) var pendingTransition: PomodoroTransition?

    private var timer: Timer?
    private let defaults = UserDefaults.standard

    private enum Key {
        static let mode = "pomodoro_mode"
        static let remainingSeconds = "pomodoro_remaining_seconds"
        static let completedFocusSessions = "pomodoro_completed_focus_sessions"
        static let focusMinutes = "pomodoro_focus_minutes"
        static let shortBreakMinutes = "pomodoro_short_break_minutes"
        static let longBreakMinutes = "pomodoro_long_break_minutes"
        static let longBreakEvery = "pomodoro_long_break_every"
        static let soundOnModeChange = "pomodoro_sound_on_mode_change"
    }

    private init() {
        let storedMode = defaults.string(forKey: Key.mode).flatMap(PomodoroMode.init(rawValue:)) ?? .focus
        let storedCompleted = defaults.integer(forKey: Key.completedFocusSessions)
        let total = Self.duration(for: storedMode, defaults: defaults)
        let storedRemaining = defaults.object(forKey: Key.remainingSeconds) as? Int
        let storedLongBreakEvery = Self.storedLongBreakEvery(defaults: defaults)

        mode = storedMode
        completedFocusSessions = storedCompleted
        totalSeconds = total
        remainingSeconds = min(max(storedRemaining ?? total, 0), total)
        longBreakEvery = storedLongBreakEvery
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / Double(totalSeconds))
    }

    var timeText: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var roundText: String {
        let round = (completedFocusSessions % longBreakEvery) + 1
        return "Round \(round)/\(longBreakEvery)"
    }

    func startPause() {
        if pendingTransition != nil {
            resumeNextSession()
        } else {
            isRunning ? pause() : start()
        }
    }

    func start() {
        if pendingTransition != nil {
            resumeNextSession()
            return
        }
        syncSettings()
        if remainingSeconds <= 0 {
            reset()
        }
        isRunning = true
        scheduleTimer()
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        persist()
    }

    func reset() {
        pause()
        pendingTransition = nil
        totalSeconds = Self.duration(for: mode, defaults: defaults)
        remainingSeconds = totalSeconds
        persist()
    }

    func skip() {
        if pendingTransition != nil {
            resumeNextSession()
            return
        }
        advanceSession(keepRunning: isRunning)
    }

    func resumeNextSession() {
        guard let transition = pendingTransition else {
            start()
            return
        }

        timer?.invalidate()
        timer = nil
        completedFocusSessions = transition.nextCompletedFocusSessions
        mode = transition.nextMode
        totalSeconds = Self.duration(for: mode, defaults: defaults)
        remainingSeconds = totalSeconds
        pendingTransition = nil
        isRunning = true
        persist()
        scheduleTimer()
    }

    func syncSettings() {
        let newTotal = Self.duration(for: mode, defaults: defaults)
        let newLongBreakEvery = Self.storedLongBreakEvery(defaults: defaults)
        guard newTotal != totalSeconds || newLongBreakEvery != longBreakEvery else { return }

        if newLongBreakEvery != longBreakEvery {
            longBreakEvery = newLongBreakEvery
        }

        if newTotal != totalSeconds {
            totalSeconds = newTotal
            if isRunning || pendingTransition != nil {
                remainingSeconds = min(remainingSeconds, newTotal)
            } else {
                remainingSeconds = newTotal
            }
        }

        persist()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        newTimer.tolerance = 0.1
        timer = newTimer
        RunLoop.main.add(newTimer, forMode: .common)
    }

    private func tick() {
        guard isRunning else { return }

        if remainingSeconds > 0 {
            remainingSeconds -= 1
        }

        if remainingSeconds <= 0 {
            completeSessionAndWait()
        } else {
            persist()
        }
    }

    private func completeSessionAndWait() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        remainingSeconds = 0

        let nextCompletedFocusSessions = completedFocusSessions + (mode == .focus ? 1 : 0)
        let nextMode: PomodoroMode
        if mode == .focus {
            nextMode = nextCompletedFocusSessions % longBreakEvery == 0 ? .longBreak : .shortBreak
        } else {
            nextMode = .focus
        }

        pendingTransition = PomodoroTransition(
            completedMode: mode,
            nextMode: nextMode,
            nextCompletedFocusSessions: nextCompletedFocusSessions
        )
        persist()
        playCompletionFeedback()

        NotificationCenter.default.post(
            name: .pomodoroSessionCompleted,
            object: nil,
            userInfo: ["completedMode": mode.rawValue, "nextMode": nextMode.rawValue]
        )
    }

    private func advanceSession(keepRunning: Bool) {
        pendingTransition = nil
        if mode == .focus {
            completedFocusSessions += 1
            mode = completedFocusSessions % longBreakEvery == 0 ? .longBreak : .shortBreak
        } else {
            mode = .focus
        }

        totalSeconds = Self.duration(for: mode, defaults: defaults)
        remainingSeconds = totalSeconds
        isRunning = keepRunning
        persist()

        if keepRunning && timer == nil {
            scheduleTimer()
        } else if !keepRunning {
            timer?.invalidate()
            timer = nil
        }
    }

    private func playCompletionFeedback() {
        let soundEnabled = defaults.object(forKey: Key.soundOnModeChange) as? Bool ?? true
        if soundEnabled {
            let sound = NSSound(named: NSSound.Name("Glass")) ?? NSSound(named: NSSound.Name("Ping"))
            sound?.play()
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }

    private func persist() {
        defaults.set(mode.rawValue, forKey: Key.mode)
        defaults.set(remainingSeconds, forKey: Key.remainingSeconds)
        defaults.set(completedFocusSessions, forKey: Key.completedFocusSessions)
    }

    private static func duration(for mode: PomodoroMode, defaults: UserDefaults) -> Int {
        let minutes: Int
        switch mode {
        case .focus:
            minutes = storedMinutes(forKey: Key.focusMinutes, defaultValue: 25, defaults: defaults)
        case .shortBreak:
            minutes = storedMinutes(forKey: Key.shortBreakMinutes, defaultValue: 5, defaults: defaults)
        case .longBreak:
            minutes = storedMinutes(forKey: Key.longBreakMinutes, defaultValue: 15, defaults: defaults)
        }
        return minutes * 60
    }

    private static func storedMinutes(forKey key: String, defaultValue: Int, defaults: UserDefaults) -> Int {
        let stored = defaults.integer(forKey: key)
        return stored > 0 ? stored : defaultValue
    }

    private static func storedLongBreakEvery(defaults: UserDefaults) -> Int {
        let stored = defaults.integer(forKey: Key.longBreakEvery)
        return min(max(stored > 0 ? stored : 4, 2), 8)
    }
}

struct PomodoroTimerWidget: View {
    @StateObject private var timer = PomodoroTimerManager.shared
    @AppStorage("pomodoro_show_mode_change_banner") private var showModeChangeBanner = true
    @State private var visibleCompletion: PomodoroTransition?
    @State private var completionBannerTask: Task<Void, Never>? = nil
    let isCompact: Bool

    var body: some View {
        ZStack(alignment: .top) {
            timerContent

            if let transition = visibleCompletion {
                PomodoroCompletionBanner(
                    transition: transition,
                    isCompact: isCompact
                )
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.96, anchor: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    )
                )
                .zIndex(5)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: visibleCompletion)
        .onAppear {
            updateCompletionBanner(for: timer.pendingTransition)
        }
        .onDisappear {
            completionBannerTask?.cancel()
            completionBannerTask = nil
        }
        .onChange(of: timer.pendingTransition) { _, transition in
            updateCompletionBanner(for: transition)
        }
        .onChange(of: showModeChangeBanner) { _, _ in
            updateCompletionBanner(for: timer.pendingTransition)
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            timer.syncSettings()
        }
    }

    private var activeColor: Color {
        timer.pendingTransition?.completedMode.color ?? timer.mode.color
    }

    private var timerContent: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(activeColor)
                Text("Pomodoro")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Text(timer.roundText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
            }

            HStack(spacing: isCompact ? 10 : 12) {
                progressRing

                VStack(alignment: .leading, spacing: 3) {
                    Text(timer.pendingTransition == nil ? timer.mode.title : "Ready")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(activeColor)
                    Text(timer.timeText)
                        .font(.system(size: isCompact ? 26 : 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: timer.timeText)
                    Text(statusText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                pomodoroButton(
                    systemName: primaryButtonIcon,
                    label: primaryButtonLabel,
                    isPrimary: true,
                    action: timer.startPause
                )
                pomodoroButton(systemName: "arrow.counterclockwise", label: "Reset", action: timer.reset)
                pomodoroButton(systemName: "forward.end.fill", label: "Skip", action: timer.skip)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var statusText: String {
        if let transition = timer.pendingTransition {
            return "Next: \(transition.nextMode.title)"
        }
        return timer.isRunning ? "In progress" : timer.mode.subtitle
    }

    private var primaryButtonIcon: String {
        if timer.pendingTransition != nil { return "play.circle.fill" }
        return timer.isRunning ? "pause.fill" : "play.fill"
    }

    private var primaryButtonLabel: String {
        if timer.pendingTransition != nil { return "Resume" }
        return timer.isRunning ? "Pause" : "Start"
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 6)
            Circle()
                .trim(from: 0, to: max(0.001, timer.progress))
                .stroke(activeColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(timer.progress * 100))%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(width: isCompact ? 54 : 58, height: isCompact ? 54 : 58)
    }

    private func pomodoroButton(systemName: String, label: String, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isPrimary ? .black : .white.opacity(0.85))
                .frame(width: 32, height: 26)
                .background(isPrimary ? activeColor : Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(label)
    }

    private func updateCompletionBanner(for transition: PomodoroTransition?) {
        completionBannerTask?.cancel()
        completionBannerTask = nil

        guard showModeChangeBanner, let transition else {
            withAnimation(.easeOut(duration: 0.18)) {
                visibleCompletion = nil
            }
            return
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            visibleCompletion = transition
        }

        completionBannerTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard visibleCompletion == transition else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    visibleCompletion = nil
                }
                completionBannerTask = nil
            }
        }
    }
}

struct PomodoroCompletionBanner: View {
    let transition: PomodoroTransition
    let isCompact: Bool

    @State private var pulse = false

    var body: some View {
        HStack(spacing: isCompact ? 8 : 10) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: 4)
                Circle()
                    .trim(from: 0.08, to: pulse ? 1 : 0.58)
                    .stroke(transition.completedMode.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(pulse ? 270 : -90))
                Image(systemName: completionIconName)
                    .font(.system(size: isCompact ? 13 : 15, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(pulse ? 1.08 : 0.94)
            }
            .frame(width: isCompact ? 34 : 40, height: isCompact ? 34 : 40)

            VStack(alignment: .leading, spacing: 1) {
                Text(completionTitle)
                    .font(.system(size: isCompact ? 12 : 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("Next: \(transition.nextMode.title)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.64))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, isCompact ? 10 : 12)
        .padding(.vertical, isCompact ? 8 : 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    LinearGradient(
                        colors: [
                            transition.completedMode.color.opacity(pulse ? 0.28 : 0.18),
                            transition.nextMode.color.opacity(0.12),
                            Color.black.opacity(0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(transition.completedMode.color.opacity(pulse ? 0.55 : 0.32), lineWidth: 1)
        )
        .shadow(color: transition.completedMode.color.opacity(0.24), radius: pulse ? 18 : 8, y: 8)
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.78).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var completionIconName: String {
        transition.completedMode == .longBreak ? "sparkles" : transition.nextMode.iconName
    }

    private var completionTitle: String {
        transition.completedMode == .longBreak ? "Long break complete" : "\(transition.completedMode.title) complete"
    }
}

enum ClipboardHistoryKind: String, Codable {
    case text
    case url
    case file
    case image
}

struct ClipboardHistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let kind: ClipboardHistoryKind
    let text: String
    let filePaths: [String]
    let imageFileName: String?
    let imageWidth: Int?
    let imageHeight: Int?
    let imageByteCount: Int
    let payloadHash: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        kind: ClipboardHistoryKind,
        text: String = "",
        filePaths: [String] = [],
        imageFileName: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        imageByteCount: Int = 0,
        payloadHash: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.filePaths = filePaths
        self.imageFileName = imageFileName
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.imageByteCount = imageByteCount
        self.payloadHash = payloadHash ?? Self.makePayloadHash(
            kind: kind,
            text: text,
            filePaths: filePaths,
            imageFileName: imageFileName,
            imageByteCount: imageByteCount
        )
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case text
        case filePaths
        case imageFileName
        case imageWidth
        case imageHeight
        case imageByteCount
        case payloadHash
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedKind = try container.decodeIfPresent(ClipboardHistoryKind.self, forKey: .kind) ?? .text
        let decodedText = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        let decodedFilePaths = try container.decodeIfPresent([String].self, forKey: .filePaths) ?? []
        let decodedImageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        let decodedImageByteCount = try container.decodeIfPresent(Int.self, forKey: .imageByteCount) ?? 0

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = decodedKind
        text = decodedText
        filePaths = decodedFilePaths
        imageFileName = decodedImageFileName
        imageWidth = try container.decodeIfPresent(Int.self, forKey: .imageWidth)
        imageHeight = try container.decodeIfPresent(Int.self, forKey: .imageHeight)
        imageByteCount = decodedImageByteCount
        payloadHash = try container.decodeIfPresent(String.self, forKey: .payloadHash) ?? Self.makePayloadHash(
            kind: decodedKind,
            text: decodedText,
            filePaths: decodedFilePaths,
            imageFileName: decodedImageFileName,
            imageByteCount: decodedImageByteCount
        )
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    var displayTitle: String {
        switch kind {
        case .text, .url:
            let firstLine = text
                .components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return firstLine.isEmpty ? "Copied Text" : firstLine
        case .file:
            if filePaths.count == 1, let path = filePaths.first {
                return URL(fileURLWithPath: path).lastPathComponent
            }
            return "\(filePaths.count) Files"
        case .image:
            if let imageWidth, let imageHeight {
                return "Image \(imageWidth)x\(imageHeight)"
            }
            return "Copied Image"
        }
    }

    var preview: String {
        switch kind {
        case .text, .url:
            return text
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\t", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .file:
            let names = filePaths.prefix(3).map { URL(fileURLWithPath: $0).lastPathComponent }
            let suffix = filePaths.count > 3 ? " +" + String(filePaths.count - 3) : ""
            return names.joined(separator: ", ") + suffix
        case .image:
            return formattedByteCount
        }
    }

    var formattedByteCount: String {
        guard imageByteCount > 0 else { return "Image" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(imageByteCount))
    }

    private static func makePayloadHash(
        kind: ClipboardHistoryKind,
        text: String,
        filePaths: [String],
        imageFileName: String?,
        imageByteCount: Int
    ) -> String {
        switch kind {
        case .text, .url:
            return "\(kind.rawValue):\(text)"
        case .file:
            return "\(kind.rawValue):\(filePaths.joined(separator: "\n"))"
        case .image:
            return "\(kind.rawValue):\(imageFileName ?? ""):\(imageByteCount)"
        }
    }
}

final class ClipboardHistoryManager: ObservableObject {
    static let shared = ClipboardHistoryManager()

    @Published private(set) var items: [ClipboardHistoryItem] = []

    private let pasteboard = NSPasteboard.general
    private let defaults = UserDefaults.standard
    private let imageCache = NSCache<NSString, NSImage>()
    private var lastChangeCount: Int
    private var timer: Timer?

    private enum Key {
        static let storedItems = "clipboard_history_items"
        static let historyLimit = "clipboard_history_limit"
        static let pluginEnabled = "plugin_clipboard_history_enabled"
        static let trackFiles = "clipboard_history_track_files"
        static let trackImages = "clipboard_history_track_images"
    }

    private enum Constants {
        static let maxStoredImageBytes = 12 * 1024 * 1024
        static let fileNamesPasteboardType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
    }

    private init() {
        lastChangeCount = pasteboard.changeCount
        imageCache.countLimit = 60
        loadItems()
        schedulePolling()
    }

    var historyLimit: Int {
        let stored = defaults.integer(forKey: Key.historyLimit)
        return min(max(stored > 0 ? stored : 30, 5), 100)
    }

    var trackFiles: Bool {
        defaults.object(forKey: Key.trackFiles) as? Bool ?? true
    }

    var trackImages: Bool {
        defaults.object(forKey: Key.trackImages) as? Bool ?? true
    }

    func copyBack(_ item: ClipboardHistoryItem) {
        pasteboard.clearContents()

        switch item.kind {
        case .text:
            pasteboard.setString(item.text, forType: .string)
        case .url:
            if let url = URL(string: item.text) {
                pasteboard.writeObjects([url as NSURL])
            } else {
                pasteboard.setString(item.text, forType: .string)
            }
        case .file:
            let urls = item.filePaths.map { NSURL(fileURLWithPath: $0) }
            if urls.isEmpty {
                pasteboard.setString(item.text, forType: .string)
            } else {
                pasteboard.writeObjects(urls)
            }
        case .image:
            if let data = imageData(for: item), let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        }

        lastChangeCount = pasteboard.changeCount
        moveExistingItemToTop(item)
    }

    func delete(_ item: ClipboardHistoryItem) {
        if let removed = items.first(where: { $0.id == item.id }) {
            removeImageFile(for: removed)
            imageCache.removeObject(forKey: removed.id.uuidString as NSString)
        }
        items.removeAll { $0.id == item.id }
        persistItems()
    }

    func clearHistory() {
        items.forEach(removeImageFile)
        imageCache.removeAllObjects()
        items.removeAll()
        persistItems()
    }

    func syncSettings() {
        let itemCount = items.count
        pruneToLimit()
        if items.count != itemCount {
            persistItems()
        }
    }

    func image(for item: ClipboardHistoryItem) -> NSImage? {
        let cacheKey = item.id.uuidString as NSString
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }

        guard let data = imageData(for: item),
              let image = NSImage(data: data) else {
            return nil
        }

        imageCache.setObject(image, forKey: cacheKey)
        return image
    }

    private func schedulePolling() {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.pollPasteboard()
        }
        newTimer.tolerance = 0.5
        timer = newTimer
        RunLoop.main.add(newTimer, forMode: .common)
    }

    private func pollPasteboard() {
        guard defaults.bool(forKey: Key.pluginEnabled) else {
            lastChangeCount = pasteboard.changeCount
            return
        }

        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        guard let copiedItem = readClipboardItem() else { return }
        record(copiedItem)
    }

    private func readClipboardItem() -> ClipboardHistoryItem? {
        if let fileItem = readClipboardFiles() {
            return fileItem
        }
        if let imageItem = readClipboardImage() {
            return imageItem
        }
        return readClipboardText()
    }

    private func readClipboardText() -> ClipboardHistoryItem? {
        if pasteboardContainsFileReferences() {
            return nil
        }

        let rawText = pasteboard.string(forType: .string)
            ?? pasteboard.string(forType: .URL)
        let text = rawText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return nil }

        let isURL = URL(string: text)?.scheme != nil
        let kind: ClipboardHistoryKind = isURL ? .url : .text
        return ClipboardHistoryItem(
            kind: kind,
            text: text,
            payloadHash: "\(kind.rawValue):\(Self.hashString(text))"
        )
    }

    private func readClipboardFiles() -> ClipboardHistoryItem? {
        guard trackFiles else { return nil }

        var filePaths: [String] = []
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [NSURL] {
            filePaths.append(contentsOf: urls.map { ($0 as URL).path })
        }

        if let paths = pasteboard.propertyList(forType: Constants.fileNamesPasteboardType) as? [String] {
            filePaths.append(contentsOf: paths)
        }

        let uniquePaths = NSOrderedSet(array: filePaths.filter { !$0.isEmpty }).array as? [String] ?? []
        guard !uniquePaths.isEmpty else { return nil }

        return ClipboardHistoryItem(
            kind: .file,
            text: uniquePaths.joined(separator: "\n"),
            filePaths: uniquePaths,
            payloadHash: "file:\(Self.hashString(uniquePaths.joined(separator: "\n")))"
        )
    }

    private func readClipboardImage() -> ClipboardHistoryItem? {
        guard trackImages else { return nil }

        if let pngData = pasteboard.data(forType: .png),
           let item = makeImageItem(from: pngData) {
            return item
        }

        if let tiffData = pasteboard.data(forType: .tiff),
           let image = NSImage(data: tiffData),
           let pngData = pngData(from: image),
           let item = makeImageItem(from: pngData, fallbackImage: image) {
            return item
        }

        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first,
           let pngData = pngData(from: image),
           let item = makeImageItem(from: pngData, fallbackImage: image) {
            return item
        }

        return nil
    }

    private func makeImageItem(from data: Data, fallbackImage: NSImage? = nil) -> ClipboardHistoryItem? {
        guard data.count <= Constants.maxStoredImageBytes else { return nil }

        let id = UUID()
        let image = fallbackImage ?? NSImage(data: data)
        guard let fileName = storeImageData(data, id: id) else { return nil }

        return ClipboardHistoryItem(
            id: id,
            kind: .image,
            imageFileName: fileName,
            imageWidth: image.map { Int($0.size.width.rounded()) },
            imageHeight: image.map { Int($0.size.height.rounded()) },
            imageByteCount: data.count,
            payloadHash: "image:\(Self.hashData(data))"
        )
    }

    private func record(_ item: ClipboardHistoryItem) {
        let duplicates = items.filter { $0.payloadHash == item.payloadHash }
        duplicates.forEach {
            removeImageFile(for: $0)
            imageCache.removeObject(forKey: $0.id.uuidString as NSString)
        }
        items.removeAll { $0.payloadHash == item.payloadHash }
        items.insert(item, at: 0)
        pruneToLimit()
        persistItems()
    }

    private func moveExistingItemToTop(_ item: ClipboardHistoryItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let existingItem = items.remove(at: index)
        items.insert(existingItem, at: 0)
        persistItems()
    }

    private func pruneToLimit() {
        if items.count > historyLimit {
            items.dropFirst(historyLimit).forEach {
                removeImageFile(for: $0)
                imageCache.removeObject(forKey: $0.id.uuidString as NSString)
            }
            items = Array(items.prefix(historyLimit))
        }
    }

    private func loadItems() {
        guard let data = defaults.data(forKey: Key.storedItems),
              let decoded = try? JSONDecoder().decode([ClipboardHistoryItem].self, from: data) else {
            items = []
            return
        }
        items = Array(decoded.prefix(historyLimit))
    }

    private func persistItems() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: Key.storedItems)
        }
    }

    private func pasteboardContainsFileReferences() -> Bool {
        pasteboard.availableType(from: [.fileURL, Constants.fileNamesPasteboardType]) != nil
    }

    private func storeImageData(_ data: Data, id: UUID) -> String? {
        guard let directory = imageCacheDirectory() else { return nil }
        let fileName = "\(id.uuidString).png"
        do {
            try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    private func imageData(for item: ClipboardHistoryItem) -> Data? {
        guard let fileName = item.imageFileName,
              let directory = imageCacheDirectory() else {
            return nil
        }
        return try? Data(contentsOf: directory.appendingPathComponent(fileName))
    }

    private func removeImageFile(for item: ClipboardHistoryItem) {
        guard let fileName = item.imageFileName,
              let directory = imageCacheDirectory() else {
            return
        }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
    }

    private func imageCacheDirectory() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = appSupport
            .appendingPathComponent("WaveNotch", isDirectory: true)
            .appendingPathComponent("ClipboardHistoryImages", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            return nil
        }
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    private static func hashString(_ value: String) -> String {
        hashData(Data(value.utf8))
    }

    private static func hashData(_ data: Data) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}

struct ClipboardHistoryWidget: View {
    @StateObject private var clipboard = ClipboardHistoryManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.purple)
                Text("Clipboard")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                Text("\(clipboard.items.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .monospacedDigit()
                Spacer()
                Button {
                    clipboard.clearHistory()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Clear Clipboard History")
                .disabled(clipboard.items.isEmpty)
            }

            if clipboard.items.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(clipboard.items) { item in
                            ClipboardHistoryRow(item: item)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            clipboard.syncSettings()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.purple.opacity(0.8))
            Text("Copy text, images, or files to save them here.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct ClipboardHistoryRow: View {
    let item: ClipboardHistoryItem
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                ClipboardHistoryManager.shared.copyBack(item)
            } label: {
                HStack(spacing: 8) {
                    leadingVisual

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.displayTitle)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(item.preview)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.48))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Text(relativeTime)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                        .monospacedDigit()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(isHovering ? Color.white.opacity(0.10) : Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Copy Back")
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }

            Button {
                ClipboardHistoryManager.shared.delete(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
                    .frame(width: 18, height: 18)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
    }

    @ViewBuilder
    private var leadingVisual: some View {
        switch item.kind {
        case .image:
            if let image = ClipboardHistoryManager.shared.image(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                symbolVisual
            }
        case .file:
            if let path = item.filePaths.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .frame(width: 30, height: 30)
            } else {
                symbolVisual
            }
        case .text, .url:
            symbolVisual
        }
    }

    private var symbolVisual: some View {
        Image(systemName: symbolName)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.purple.opacity(0.9))
            .frame(width: 30, height: 30)
            .background(Color.purple.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var symbolName: String {
        switch item.kind {
        case .url:
            return "link"
        case .file:
            return "doc"
        case .image:
            return "photo"
        case .text:
            return "doc.text"
        }
    }

    private var relativeTime: String {
        let seconds = max(0, Int(Date().timeIntervalSince(item.createdAt)))
        if seconds < 60 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }
}

enum KaomojiBoardCategory: String, CaseIterable, Identifiable {
    case faces
    case mood
    case action
    case symbols
    case emoji

    var id: String { rawValue }

    var title: String {
        switch self {
        case .faces: return "Faces"
        case .mood: return "Mood"
        case .action: return "Action"
        case .symbols: return "Symbols"
        case .emoji: return "Emoji"
        }
    }
}

struct KaomojiBoardEntry: Identifiable, Hashable {
    let category: KaomojiBoardCategory
    let text: String
    let label: String

    var id: String { "\(category.rawValue)|\(text)" }
}

final class KaomojiBoardManager: ObservableObject {
    static let shared = KaomojiBoardManager()

    @Published private(set) var recentItems: [String] = []

    private let defaults = UserDefaults.standard

    private enum Key {
        static let recentItems = "kaomoji_board_recent_items"
        static let recentLimit = "kaomoji_board_recent_limit"
    }

    private init() {
        loadRecent()
    }

    var recentLimit: Int {
        let stored = defaults.object(forKey: Key.recentLimit) as? Int ?? 12
        return min(max(stored, 0), 24)
    }

    var hasRecentItems: Bool {
        !recentItems.isEmpty && recentLimit > 0
    }

    func entries(for category: KaomojiBoardCategory) -> [KaomojiBoardEntry] {
        Self.entries.filter { $0.category == category }
    }

    func copy(_ entry: KaomojiBoardEntry) {
        copyText(entry.text)
    }

    func copyRecent(_ text: String) {
        copyText(text)
    }

    func clearRecent() {
        recentItems.removeAll()
        persistRecent()
    }

    func syncSettings() {
        let previousItems = recentItems
        pruneRecent()
        if previousItems != recentItems {
            persistRecent()
        }
    }

    private func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        remember(text)
    }

    private func remember(_ text: String) {
        guard recentLimit > 0 else { return }
        recentItems.removeAll { $0 == text }
        recentItems.insert(text, at: 0)
        pruneRecent()
        persistRecent()
    }

    private func pruneRecent() {
        if recentItems.count > recentLimit {
            recentItems = Array(recentItems.prefix(recentLimit))
        }
    }

    private func loadRecent() {
        let stored = defaults.stringArray(forKey: Key.recentItems) ?? []
        recentItems = Array(stored.prefix(recentLimit))
    }

    private func persistRecent() {
        defaults.set(recentItems, forKey: Key.recentItems)
    }

    private static let entries: [KaomojiBoardEntry] = [
        KaomojiBoardEntry(category: .faces, text: #"(ง'̀-'́)ง"#, label: "fight"),
        KaomojiBoardEntry(category: .faces, text: #"¯\_(ツ)_/¯"#, label: "shrug"),
        KaomojiBoardEntry(category: .faces, text: #"ಠ_ಠ"#, label: "stare"),
        KaomojiBoardEntry(category: .faces, text: #"( ͡° ͜ʖ ͡°)"#, label: "lenny"),
        KaomojiBoardEntry(category: .faces, text: #"(⌐■_■)"#, label: "cool"),
        KaomojiBoardEntry(category: .faces, text: #"(¬_¬)"#, label: "side eye"),
        KaomojiBoardEntry(category: .faces, text: #"(•_•)"#, label: "deadpan"),
        KaomojiBoardEntry(category: .faces, text: #"(ᵔᴥᵔ)"#, label: "soft"),
        KaomojiBoardEntry(category: .faces, text: #"ʕ•ᴥ•ʔ"#, label: "cute"),
        KaomojiBoardEntry(category: .faces, text: #"(｡◕‿◕｡)"#, label: "smile"),
        KaomojiBoardEntry(category: .faces, text: #"(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧"#, label: "sparkle"),
        KaomojiBoardEntry(category: .faces, text: #"ᕕ( ᐛ )ᕗ"#, label: "march"),

        KaomojiBoardEntry(category: .mood, text: #"(｡♥‿♥｡)"#, label: "love"),
        KaomojiBoardEntry(category: .mood, text: #"(ಥ﹏ಥ)"#, label: "cry"),
        KaomojiBoardEntry(category: .mood, text: #"(╥_╥)"#, label: "sad"),
        KaomojiBoardEntry(category: .mood, text: #"(ง •̀_•́)ง"#, label: "ready"),
        KaomojiBoardEntry(category: .mood, text: #"(ﾉಥ益ಥ）ﾉ"#, label: "rage"),
        KaomojiBoardEntry(category: .mood, text: #"(ᗒᗣᗕ)՞"#, label: "panic"),
        KaomojiBoardEntry(category: .mood, text: #"(￣▽￣)"#, label: "relaxed"),
        KaomojiBoardEntry(category: .mood, text: #"٩(◕‿◕｡)۶"#, label: "happy"),
        KaomojiBoardEntry(category: .mood, text: #"(｡•́︿•̀｡)"#, label: "down"),
        KaomojiBoardEntry(category: .mood, text: #"(≧◡≦)"#, label: "joy"),
        KaomojiBoardEntry(category: .mood, text: #"(*≧ω≦*)"#, label: "excited"),
        KaomojiBoardEntry(category: .mood, text: #"(；￣Д￣)"#, label: "worried"),

        KaomojiBoardEntry(category: .action, text: #"(づ｡◕‿‿◕｡)づ"#, label: "hug"),
        KaomojiBoardEntry(category: .action, text: #"(╯°□°）╯︵ ┻━┻"#, label: "flip"),
        KaomojiBoardEntry(category: .action, text: #"┬─┬ ノ( ゜-゜ノ)"#, label: "fix"),
        KaomojiBoardEntry(category: .action, text: #"(☞ﾟヮﾟ)☞"#, label: "point"),
        KaomojiBoardEntry(category: .action, text: #"☜(ﾟヮﾟ☜)"#, label: "point"),
        KaomojiBoardEntry(category: .action, text: #"ᕙ(⇀‸↼‶)ᕗ"#, label: "flex"),
        KaomojiBoardEntry(category: .action, text: #"(ง°ل͜°)ง"#, label: "go"),
        KaomojiBoardEntry(category: .action, text: #"\(^_^)/"#, label: "cheer"),
        KaomojiBoardEntry(category: .action, text: #"ヽ(•‿•)ノ"#, label: "wave"),
        KaomojiBoardEntry(category: .action, text: #"(シ_ _)シ"#, label: "bow"),
        KaomojiBoardEntry(category: .action, text: #"(っ˘ڡ˘ς)"#, label: "eat"),
        KaomojiBoardEntry(category: .action, text: #"ε=ε=ε=┌(;*´Д`)ﾉ"#, label: "run"),

        KaomojiBoardEntry(category: .symbols, text: #"★"#, label: "star"),
        KaomojiBoardEntry(category: .symbols, text: #"☆"#, label: "star"),
        KaomojiBoardEntry(category: .symbols, text: #"♡"#, label: "heart"),
        KaomojiBoardEntry(category: .symbols, text: #"♥"#, label: "heart"),
        KaomojiBoardEntry(category: .symbols, text: #"✓"#, label: "check"),
        KaomojiBoardEntry(category: .symbols, text: #"✕"#, label: "x"),
        KaomojiBoardEntry(category: .symbols, text: #"→"#, label: "arrow"),
        KaomojiBoardEntry(category: .symbols, text: #"←"#, label: "arrow"),
        KaomojiBoardEntry(category: .symbols, text: #"↑"#, label: "arrow"),
        KaomojiBoardEntry(category: .symbols, text: #"↓"#, label: "arrow"),
        KaomojiBoardEntry(category: .symbols, text: #"∞"#, label: "infinity"),
        KaomojiBoardEntry(category: .symbols, text: #"…"#, label: "ellipsis"),
        KaomojiBoardEntry(category: .symbols, text: #"•"#, label: "bullet"),
        KaomojiBoardEntry(category: .symbols, text: #"※"#, label: "note"),
        KaomojiBoardEntry(category: .symbols, text: #"♪"#, label: "music"),
        KaomojiBoardEntry(category: .symbols, text: #"♫"#, label: "music"),

        KaomojiBoardEntry(category: .emoji, text: #"😀"#, label: "grin"),
        KaomojiBoardEntry(category: .emoji, text: #"😂"#, label: "laugh"),
        KaomojiBoardEntry(category: .emoji, text: #"😭"#, label: "cry"),
        KaomojiBoardEntry(category: .emoji, text: #"🥲"#, label: "tear"),
        KaomojiBoardEntry(category: .emoji, text: #"😍"#, label: "love"),
        KaomojiBoardEntry(category: .emoji, text: #"😎"#, label: "cool"),
        KaomojiBoardEntry(category: .emoji, text: #"🤔"#, label: "think"),
        KaomojiBoardEntry(category: .emoji, text: #"👀"#, label: "eyes"),
        KaomojiBoardEntry(category: .emoji, text: #"🙏"#, label: "pray"),
        KaomojiBoardEntry(category: .emoji, text: #"💀"#, label: "dead"),
        KaomojiBoardEntry(category: .emoji, text: #"🔥"#, label: "fire"),
        KaomojiBoardEntry(category: .emoji, text: #"✨"#, label: "sparkles"),
        KaomojiBoardEntry(category: .emoji, text: #"✅"#, label: "done"),
        KaomojiBoardEntry(category: .emoji, text: #"❌"#, label: "no"),
        KaomojiBoardEntry(category: .emoji, text: #"🎯"#, label: "target"),
        KaomojiBoardEntry(category: .emoji, text: #"🚀"#, label: "ship")
    ]
}

struct KaomojiBoardWidget: View {
    @StateObject private var board = KaomojiBoardManager.shared
    @State private var selectedCategory: KaomojiBoardCategory = .faces
    @State private var copiedText: String?
    @State private var copiedResetTask: Task<Void, Never>?

    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 8),
        GridItem(.flexible(minimum: 0), spacing: 8),
        GridItem(.flexible(minimum: 0), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "face.smiling")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.pink)
                Text("Kaomoji")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                if copiedText != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            categoryStrip

            if board.hasRecentItems {
                recentStrip
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(board.entries(for: selectedCategory)) { entry in
                        KaomojiTokenButton(
                            text: entry.text,
                            label: entry.label,
                            isCopied: copiedText == entry.text
                        ) {
                            copy(entry)
                        }
                    }
                }
                .padding(.bottom, 2)
            }
            .clipped()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            board.syncSettings()
        }
        .onDisappear {
            copiedResetTask?.cancel()
        }
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(KaomojiBoardCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category.title)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(selectedCategory == category ? .white : .white.opacity(0.62))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(selectedCategory == category ? Color.pink.opacity(0.72) : Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 28)
        .clipped()
    }

    private var recentStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.45))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(board.recentItems, id: \.self) { text in
                        Button {
                            board.copyRecent(text)
                            markCopied(text)
                        } label: {
                            Text(text)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                                .allowsTightening(true)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .frame(height: 28)
                                .frame(minWidth: 42)
                                .background(copiedText == text ? Color.green.opacity(0.28) : Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .clipped()
                        }
                        .buttonStyle(.plain)
                        .help(text)
                    }
                }
            }
        }
    }

    private func copy(_ entry: KaomojiBoardEntry) {
        board.copy(entry)
        markCopied(entry.text)
    }

    private func markCopied(_ text: String) {
        copiedText = text
        copiedResetTask?.cancel()
        copiedResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            if copiedText == text {
                copiedText = nil
            }
        }
    }
}

struct KaomojiTokenButton: View {
    let text: String
    let label: String
    let isCopied: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(text)
                    .font(.system(size: text.count <= 2 ? 21 : 15, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.38)
                    .allowsTightening(true)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .clipped()
                Text(label)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.white.opacity(0.38))
                    .lineLimit(1)
                    .clipped()
            }
            .padding(.horizontal, 7)
            .frame(height: 48)
            .frame(maxWidth: .infinity)
            .background(isCopied ? Color.green.opacity(0.26) : Color.white.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isCopied ? Color.green.opacity(0.4) : Color.white.opacity(0.05), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .clipped()
        }
        .buttonStyle(.plain)
        .help(text)
    }
}

struct WeatherSnapshot: Equatable {
    let locationName: String
    let country: String?
    let temperature: Double
    let apparentTemperature: Double
    let humidity: Int
    let windSpeed: Double
    let precipitation: Double
    let weatherCode: Int
    let high: Double?
    let low: Double?
    let unit: String
    let fetchedAt: Date

    var temperatureNumberText: String {
        "\(Int(temperature.rounded()))"
    }

    var unitLetter: String {
        unit == "fahrenheit" ? "F" : "C"
    }

    var temperatureText: String {
        "\(Int(temperature.rounded()))\(unitSymbol)"
    }

    var apparentText: String {
        "\(Int(apparentTemperature.rounded()))\(unitSymbol)"
    }

    var highLowText: String {
        guard let high, let low else { return "" }
        return "H \(Int(high.rounded()))\(unitSymbol)  L \(Int(low.rounded()))\(unitSymbol)"
    }

    var unitSymbol: String {
        "°\(unitLetter)"
    }

    var windText: String {
        let suffix = unit == "fahrenheit" ? "mph" : "km/h"
        return "\(Int(windSpeed.rounded())) \(suffix)"
    }
}

struct WeatherResolvedLocation {
    let displayName: String
    let latitude: Double
    let longitude: Double
    let country: String?
}

struct WeatherLocationResult: Decodable {
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String?

    var displayName: String {
        if let admin1, !admin1.isEmpty {
            return "\(name), \(admin1)"
        }
        return name
    }

    var resolvedLocation: WeatherResolvedLocation {
        WeatherResolvedLocation(
            displayName: displayName,
            latitude: latitude,
            longitude: longitude,
            country: country
        )
    }
}

private struct WeatherGeocodingResponse: Decodable {
    let results: [WeatherLocationResult]?
}

private struct OpenMeteoForecastResponse: Decodable {
    let current: OpenMeteoCurrent
    let daily: OpenMeteoDaily?
}

private struct OpenMeteoCurrent: Decodable {
    let temperature: Double
    let apparentTemperature: Double
    let humidity: Int
    let precipitation: Double
    let weatherCode: Int
    let windSpeed: Double

    enum CodingKeys: String, CodingKey {
        case temperature = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case humidity = "relative_humidity_2m"
        case precipitation
        case weatherCode = "weather_code"
        case windSpeed = "wind_speed_10m"
    }
}

private struct OpenMeteoDaily: Decodable {
    let weatherCode: [Int]?
    let temperatureMax: [Double]?
    let temperatureMin: [Double]?

    enum CodingKeys: String, CodingKey {
        case weatherCode = "weather_code"
        case temperatureMax = "temperature_2m_max"
        case temperatureMin = "temperature_2m_min"
    }
}

final class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherManager()

    @Published private(set) var snapshot: WeatherSnapshot?
    @Published private(set) var isFetching = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var locationStatusText = "Current location"

    private let defaults = UserDefaults.standard
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var refreshTimer: Timer?
    private var lastRequestSignature = ""
    private var lastFetchDate: Date?
    private var lastFailureDate: Date?
    private var lastFailureSignature = ""
    private var pendingCurrentLocationUnit: String?
    private var pendingCurrentLocationForce = false
    private let successRefreshInterval: TimeInterval = 1800
    private let failureRetryInterval: TimeInterval = 300

    private enum Key {
        static let useCurrentLocation = "weather_use_current_location"
        static let locationQuery = "weather_location_query"
        static let temperatureUnit = "weather_temperature_unit"
        static let currentLatitude = "weather_current_latitude"
        static let currentLongitude = "weather_current_longitude"
        static let currentLocationName = "weather_current_location_name"
        static let currentLocationCountry = "weather_current_location_country"
    }

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.fetchWeather()
        }
        refreshTimer?.tolerance = 300
        fetchWeather()
    }

    var useCurrentLocation: Bool {
        defaults.object(forKey: Key.useCurrentLocation) as? Bool ?? true
    }

    var configuredLocation: String {
        let stored = defaults.string(forKey: Key.locationQuery)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stored.isEmpty ? "New York" : stored
    }

    var configuredUnit: String {
        let stored = defaults.string(forKey: Key.temperatureUnit) ?? "fahrenheit"
        return stored == "celsius" ? "celsius" : "fahrenheit"
    }

    func fetchWeather(force: Bool = false) {
        if isFetching && !force {
            return
        }

        let unit = configuredUnit

        if useCurrentLocation {
            fetchCurrentLocationWeather(unit: unit, force: force)
        } else {
            fetchManualLocationWeather(unit: unit, force: force)
        }
    }

    private func fetchManualLocationWeather(unit: String, force: Bool, fallbackStatus: String? = nil) {
        let locationQuery = configuredLocation
        let signature = "manual:\(locationQuery)|\(unit)"

        if !force,
           signature == lastRequestSignature,
           let lastFetchDate,
           Date().timeIntervalSince(lastFetchDate) < successRefreshInterval,
           snapshot != nil {
            return
        }

        if shouldSkipFailedFetch(signature: signature, force: force) {
            return
        }

        lastRequestSignature = signature
        DispatchQueue.main.async {
            self.isFetching = true
            self.errorMessage = nil
            self.locationStatusText = fallbackStatus ?? "Using manual location"
        }

        geocode(locationQuery) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let location):
                if fallbackStatus != nil,
                   self.lastRequestSignature.hasPrefix("current:"),
                   self.snapshot != nil {
                    return
                }
                self.fetchForecast(for: location, unit: unit)
            case .failure:
                DispatchQueue.main.async {
                    self.isFetching = false
                    self.recordWeatherFailure(signature: signature, message: "Location not found")
                    self.errorMessage = "Location not found"
                }
            }
        }
    }

    private func fetchCurrentLocationWeather(unit: String, force: Bool) {
        if !force, let cachedLocation = cachedCurrentLocation {
            let signature = "current:\(coordinateSignature(cachedLocation))|\(unit)"
            if signature == lastRequestSignature,
               let lastFetchDate,
               Date().timeIntervalSince(lastFetchDate) < successRefreshInterval,
               snapshot != nil {
                return
            }

            if shouldSkipFailedFetch(signature: signature, force: force) {
                return
            }

            lastRequestSignature = signature
            DispatchQueue.main.async {
                self.isFetching = true
                self.errorMessage = nil
                self.locationStatusText = "Using \(cachedLocation.displayName)"
            }
            fetchForecast(for: cachedLocation, unit: unit)
            return
        }

        let lookupSignature = "current:lookup|\(unit)"
        if shouldSkipCurrentStartupRetry(unit: unit, force: force) {
            return
        }
        if shouldSkipFailedFetch(signature: lookupSignature, force: force) {
            return
        }
        lastRequestSignature = lookupSignature
        requestCurrentLocation(unit: unit, force: force)

        if !force {
            fetchManualLocationWeather(
                unit: unit,
                force: true,
                fallbackStatus: "Using fallback while finding current location."
            )
        }
    }

    private func requestCurrentLocation(unit: String, force: Bool) {
        pendingCurrentLocationUnit = unit
        pendingCurrentLocationForce = force

        DispatchQueue.main.async {
            self.isFetching = true
            self.errorMessage = nil
            self.locationStatusText = "Finding current location..."
        }

        guard CLLocationManager.locationServicesEnabled() else {
            recordWeatherFailure(signature: lastRequestSignature, message: "Location Services are off")
            handleCurrentLocationUnavailable("Location Services are off", unit: unit, force: force)
            return
        }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        case .denied, .restricted:
            recordWeatherFailure(signature: lastRequestSignature, message: "Location permission denied")
            handleCurrentLocationUnavailable("Location permission denied", unit: unit, force: force)
        @unknown default:
            recordWeatherFailure(signature: lastRequestSignature, message: "Location unavailable")
            handleCurrentLocationUnavailable("Location unavailable", unit: unit, force: force)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let unit = pendingCurrentLocationUnit else { return }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            recordWeatherFailure(signature: lastRequestSignature, message: "Location permission denied")
            handleCurrentLocationUnavailable("Location permission denied", unit: unit, force: pendingCurrentLocationForce)
        case .notDetermined:
            break
        @unknown default:
            recordWeatherFailure(signature: lastRequestSignature, message: "Location unavailable")
            handleCurrentLocationUnavailable("Location unavailable", unit: unit, force: pendingCurrentLocationForce)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              let unit = pendingCurrentLocationUnit else {
            handleCurrentLocationUnavailable("Location unavailable", unit: configuredUnit, force: true)
            return
        }

        pendingCurrentLocationUnit = nil
        pendingCurrentLocationForce = false

        reverseGeocode(location) { [weak self] resolvedLocation in
            guard let self else { return }
            self.cacheCurrentLocation(resolvedLocation)
            self.lastRequestSignature = "current:\(self.coordinateSignature(resolvedLocation))|\(unit)"
            self.locationStatusText = "Using \(resolvedLocation.displayName)"
            self.fetchForecast(for: resolvedLocation, unit: unit)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let unit = pendingCurrentLocationUnit ?? configuredUnit
        let force = pendingCurrentLocationForce
        pendingCurrentLocationUnit = nil
        pendingCurrentLocationForce = false
        recordWeatherFailure(signature: lastRequestSignature, message: "Current location unavailable")
        handleCurrentLocationUnavailable("Current location unavailable", unit: unit, force: force)
    }

    private func handleCurrentLocationUnavailable(_ message: String, unit: String, force: Bool) {
        pendingCurrentLocationUnit = nil
        pendingCurrentLocationForce = false

        if let cachedLocation = cachedCurrentLocation {
            lastRequestSignature = "current:\(coordinateSignature(cachedLocation))|\(unit)"
            DispatchQueue.main.async {
                self.locationStatusText = "\(message). Using last location."
            }
            fetchForecast(for: cachedLocation, unit: unit)
        } else {
            fetchManualLocationWeather(unit: unit, force: true, fallbackStatus: "\(message). Using fallback city.")
        }
    }

    private func geocode(_ query: String, completion: @escaping (Result<WeatherResolvedLocation, Error>) -> Void) {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components?.url else {
            completion(.failure(URLError(.badURL)))
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let data else {
                completion(.failure(URLError(.cannotParseResponse)))
                return
            }

            DispatchQueue.main.async {
                guard let response = try? JSONDecoder().decode(WeatherGeocodingResponse.self, from: data),
                      let location = response.results?.first else {
                    completion(.failure(URLError(.cannotParseResponse)))
                    return
                }

                completion(.success(location.resolvedLocation))
            }
        }.resume()
    }

    private func reverseGeocode(_ location: CLLocation, completion: @escaping (WeatherResolvedLocation) -> Void) {
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            DispatchQueue.main.async {
                let placemark = placemarks?.first
                let city = placemark?.locality?.trimmingCharacters(in: .whitespacesAndNewlines)
                let region = placemark?.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines)
                let displayParts = [city, region]
                    .compactMap { value -> String? in
                        guard let value, !value.isEmpty else { return nil }
                        return value
                    }
                    .reduce(into: [String]()) { parts, value in
                        if !parts.contains(value) { parts.append(value) }
                    }

                let displayName = displayParts.isEmpty ? "Current Location" : displayParts.joined(separator: ", ")
                completion(
                    WeatherResolvedLocation(
                        displayName: displayName,
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        country: placemark?.country
                    )
                )
            }
        }
    }

    private var cachedCurrentLocation: WeatherResolvedLocation? {
        guard defaults.object(forKey: Key.currentLatitude) != nil,
              defaults.object(forKey: Key.currentLongitude) != nil else {
            return nil
        }

        let displayName = defaults.string(forKey: Key.currentLocationName)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return WeatherResolvedLocation(
            displayName: displayName?.isEmpty == false ? displayName! : "Current Location",
            latitude: defaults.double(forKey: Key.currentLatitude),
            longitude: defaults.double(forKey: Key.currentLongitude),
            country: defaults.string(forKey: Key.currentLocationCountry)
        )
    }

    private func cacheCurrentLocation(_ location: WeatherResolvedLocation) {
        defaults.set(location.latitude, forKey: Key.currentLatitude)
        defaults.set(location.longitude, forKey: Key.currentLongitude)
        defaults.set(location.displayName, forKey: Key.currentLocationName)
        defaults.set(location.country, forKey: Key.currentLocationCountry)
    }

    private func coordinateSignature(_ location: WeatherResolvedLocation) -> String {
        "\(String(format: "%.3f", location.latitude)),\(String(format: "%.3f", location.longitude))"
    }

    private func shouldSkipFailedFetch(signature: String, force: Bool) -> Bool {
        guard !force,
              signature == lastFailureSignature,
              let lastFailureDate,
              Date().timeIntervalSince(lastFailureDate) < failureRetryInterval else {
            return false
        }
        return true
    }

    private func shouldSkipCurrentStartupRetry(unit: String, force: Bool) -> Bool {
        guard !force,
              snapshot == nil,
              let lastFailureDate,
              Date().timeIntervalSince(lastFailureDate) < failureRetryInterval else {
            return false
        }

        return lastFailureSignature == "current:lookup|\(unit)" || lastFailureSignature.hasPrefix("manual:")
    }

    private func recordWeatherFailure(signature: String, message: String) {
        lastFailureSignature = signature
        lastFailureDate = Date()
        locationStatusText = message
    }

    private func fetchForecast(for location: WeatherResolvedLocation, unit: String) {
        let signature = lastRequestSignature
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "temperature_unit", value: unit),
            URLQueryItem(name: "wind_speed_unit", value: unit == "fahrenheit" ? "mph" : "kmh"),
            URLQueryItem(name: "precipitation_unit", value: unit == "fahrenheit" ? "inch" : "mm"),
            URLQueryItem(name: "forecast_days", value: "3"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components?.url else {
            DispatchQueue.main.async {
                self.isFetching = false
                self.recordWeatherFailure(signature: signature, message: "Weather request failed")
                self.errorMessage = "Weather request failed"
            }
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data, error == nil else {
                DispatchQueue.main.async {
                    self.isFetching = false
                    self.recordWeatherFailure(signature: signature, message: "Weather unavailable")
                    self.errorMessage = "Weather unavailable"
                }
                return
            }

            DispatchQueue.main.async {
                guard let response = try? JSONDecoder().decode(OpenMeteoForecastResponse.self, from: data) else {
                    self.isFetching = false
                    self.recordWeatherFailure(signature: signature, message: "Weather unavailable")
                    self.errorMessage = "Weather unavailable"
                    return
                }

                let snapshot = WeatherSnapshot(
                    locationName: location.displayName,
                    country: location.country,
                    temperature: response.current.temperature,
                    apparentTemperature: response.current.apparentTemperature,
                    humidity: response.current.humidity,
                    windSpeed: response.current.windSpeed,
                    precipitation: response.current.precipitation,
                    weatherCode: response.current.weatherCode,
                    high: response.daily?.temperatureMax?.first,
                    low: response.daily?.temperatureMin?.first,
                    unit: unit,
                    fetchedAt: Date()
                )

                self.snapshot = snapshot
                self.lastFetchDate = Date()
                self.lastFailureDate = nil
                self.lastFailureSignature = ""
                self.isFetching = false
                self.errorMessage = nil
            }
        }.resume()
    }
}

struct WeatherWidget: View {
    @StateObject private var weather = WeatherManager.shared

    var body: some View {
        Group {
            if let snapshot = weather.snapshot {
                weatherContent(snapshot)
            } else if weather.isFetching {
                loadingState
            } else {
                errorState
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            weather.fetchWeather()
        }
    }

    private func weatherContent(_ snapshot: WeatherSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(weatherColor(for: snapshot.weatherCode).opacity(0.16))
                    Image(systemName: weatherSymbol(for: snapshot.weatherCode))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(weatherColor(for: snapshot.weatherCode))
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.locationName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(conditionText(for: snapshot.weatherCode))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.58))
                        .lineLimit(1)
                    if !snapshot.highLowText.isEmpty {
                        Text(snapshot.highLowText)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.48))
                            .monospacedDigit()
                    }
                }

                Spacer(minLength: 0)

                temperatureDisplay(snapshot)
            }

            HStack(spacing: 8) {
                WeatherMetricPill(icon: "thermometer.medium", text: "Feels \(snapshot.apparentText)")
                WeatherMetricPill(icon: "humidity.fill", text: "\(snapshot.humidity)%")
                WeatherMetricPill(icon: "wind", text: snapshot.windText)
            }

            HStack {
                Text("Updated \(relativeTime(snapshot.fetchedAt))")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.36))
                Spacer()
                Text("Open-Meteo")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.36))
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 8) {
            Spacer()
            ProgressView().controlSize(.small)
            Text("Fetching weather...")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var errorState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.orange)
            Text(weather.errorMessage ?? "Weather unavailable")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
            Text("Check Weather settings.")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.52))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func temperatureDisplay(_ snapshot: WeatherSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(snapshot.temperatureNumberText)°")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            Text(snapshot.unitLetter)
                .font(.system(size: 24, weight: .bold, design: .rounded))
        }
        .monospacedDigit()
        .foregroundColor(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
    }

    private func relativeTime(_ date: Date) -> String {
        let minutes = max(0, Int(Date().timeIntervalSince(date) / 60))
        if minutes < 1 { return "now" }
        return "\(minutes)m ago"
    }

    private func weatherSymbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85...86: return "snowflake"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.sun.fill"
        }
    }

    private func conditionText(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mostly clear"
        case 2: return "Partly cloudy"
        case 3: return "Cloudy"
        case 45, 48: return "Fog"
        case 51...57: return "Drizzle"
        case 61...67: return "Rain"
        case 71...77: return "Snow"
        case 80...82: return "Showers"
        case 85...86: return "Snow showers"
        case 95...99: return "Thunderstorm"
        default: return "Weather"
        }
    }

    private func weatherColor(for code: Int) -> Color {
        switch code {
        case 0...2: return .yellow
        case 45, 48: return .gray
        case 51...67, 80...82: return .blue
        case 71...77, 85...86: return .cyan
        case 95...99: return .purple
        default: return .orange
        }
    }
}

struct WeatherMetricPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundColor(.white.opacity(0.68))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct MediaSectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.42))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }
}

struct MediaArtwork: View {
    let urlString: String?
    let fallbackIcon: String
    let color: Color
    var size: CGFloat = 38

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString), !urlString.isEmpty {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.16))
                }
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.14))
                    .overlay(
                        Image(systemName: fallbackIcon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(color.opacity(0.9))
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct MediaConnectPrompt: View {
    let icon: String
    let title: String
    let subtitle: String
    let buttonTitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.48))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button(action: action) {
                Text(buttonTitle)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 26)
                    .background(color.opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct SpotifyQueueWidget: View {
    @ObservedObject var nowPlaying: NowPlayingManager
    @StateObject private var spotifyManager = SpotifyAuthManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if spotifyManager.accessToken.isEmpty {
                let hasClientID = spotifyManager.hasValidClientID
                MediaConnectPrompt(
                    icon: hasClientID ? "music.note" : "lock.fill",
                    title: hasClientID ? "Sign in to Spotify" : "Setup Required",
                    subtitle: hasClientID ? "Access your queue directly from the notch." : "Open Settings to set your Client ID.",
                    buttonTitle: hasClientID ? "Connect Spotify" : "Open Settings",
                    color: hasClientID ? .green : .gray
                ) {
                        if hasClientID {
                            spotifyManager.authenticate { _ in }
                        } else {
                            UserDefaults.standard.set("Plugins", forKey: "lastSettingsTab")
                            SettingsWindowManager.shared.showSettings()
                        }
                }
            } else if spotifyManager.currentQueueItems.isEmpty {
                emptyStateView(text: "Fetching Spotify queue...", icon: "list.bullet.indent", color: .green)
            } else {
                MediaSectionHeader(
                    icon: "list.bullet.indent",
                    title: "Spotify Queue",
                    subtitle: "\(spotifyManager.currentQueueItems.count) upcoming",
                    color: .green
                )

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(spotifyManager.currentQueueItems.prefix(50).enumerated()), id: \.offset) { index, item in
                            SpotifyQueueRow(index: index + 1, track: item.track) {
                                spotifyManager.skipToQueueItem(index: index)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            spotifyManager.fetchQueue()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                await MainActor.run {
                    spotifyManager.fetchQueue()
                }
            }
        }
        .onChange(of: nowPlaying.currentSong) { _, _ in
            spotifyManager.fetchQueue()
        }
    }
    
    private func emptyStateView(text: String, icon: String, color: Color) -> some View {
        VStack {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color.opacity(0.72))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.52))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct SpotifyQueueRow: View {
    let index: Int
    let track: SpotifyTrack
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text("\(index)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(isHovering ? .green : .white.opacity(0.42))
                    .frame(width: 12, alignment: .trailing)
                
                MediaArtwork(
                    urlString: track.album?.images?.first?.url,
                    fallbackIcon: "music.note",
                    color: .green,
                    size: 34
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    if isHovering {
                        MarqueeText(text: track.name, font: .system(size: 12, weight: .bold), alignment: .leading)
                            .foregroundColor(.green)
                            .frame(height: 14)
                    } else {
                        Text(track.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(height: 14, alignment: .leading)
                    }
                    Text(track.artists.first?.name ?? "Unknown Artist")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                
                if isHovering {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.green)
                        .frame(width: 18, height: 18)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(isHovering ? Color.green.opacity(0.11) : Color.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

struct PlaceholderWidget: View {
    let name: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
            
            Text("\(name)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - YouTube Music Widgets

struct YouTubeQueueWidget: View {
    @ObservedObject var nowPlaying: NowPlayingManager
    @StateObject private var ytManager = YouTubeMusicManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if ytManager.accessToken.isEmpty {
                MediaConnectPrompt(
                    icon: "play.circle.fill",
                    title: "Sign in to YouTube Music",
                    subtitle: "Access your queue directly from the notch.",
                    buttonTitle: "Connect Account",
                    color: .red
                ) {
                    ytManager.authenticate { _ in }
                }
            } else if ytManager.currentPlaylistTracks.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "play.square.stack")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.red.opacity(0.72))
                    Text("Fetching library...")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.52))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                MediaSectionHeader(
                    icon: "play.square.stack",
                    title: "YouTube Queue",
                    subtitle: "\(ytManager.currentPlaylistTracks.count) tracks",
                    color: .red
                )

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(ytManager.currentPlaylistTracks.prefix(50).enumerated()), id: \.element.id) { index, item in
                            YTQueueRow(index: index + 1, item: item) {
                                ytManager.play(videoId: item.videoId, playlistId: item.playlistId, index: index)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct YTQueueRow: View {
    let index: Int
    let item: YTQueueItem
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text("\(index)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(isHovering ? .red : .white.opacity(0.42))
                    .frame(width: 22, alignment: .center)
                
                MediaArtwork(
                    urlString: item.imageURL,
                    fallbackIcon: "play.fill",
                    color: .red,
                    size: 38
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    if isHovering {
                        MarqueeText(text: item.title, font: .system(size: 12, weight: .bold), alignment: .leading)
                            .foregroundColor(.red)
                            .frame(height: 14)
                    } else {
                        Text(item.title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(height: 14, alignment: .leading)
                    }
                    Text(item.artist)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)

                Image(systemName: "play.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isHovering ? .red : .white.opacity(0.30))
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(isHovering ? 0.10 : 0.04))
                    .clipShape(Circle())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(isHovering ? Color.red.opacity(0.11) : Color.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

struct YouTubePlaylistsWidget: View {
    @ObservedObject var nowPlaying: NowPlayingManager
    @StateObject private var ytManager = YouTubeMusicManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if ytManager.accessToken.isEmpty {
                MediaConnectPrompt(
                    icon: "play.rectangle.on.rectangle.fill",
                    title: "YouTube Playlists",
                    subtitle: "Sign in to access your library.",
                    buttonTitle: "Connect Account",
                    color: .red
                ) {
                    ytManager.authenticate { _ in }
                }
            } else {
                MediaSectionHeader(
                    icon: "play.rectangle.on.rectangle.fill",
                    title: "YouTube Playlists",
                    subtitle: "\(ytManager.playlists.count) playlists",
                    color: .red
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ytManager.playlists) { playlist in
                            YouTubePlaylistCard(playlist: playlist) {
                                ytManager.playPlaylist(playlistId: playlist.id)
                                ytManager.fetchPlaylistItems(playlistId: playlist.id)
                            }
                        }
                    }
                }
                .frame(height: 84)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct YouTubePlaylistCard: View {
    let playlist: YTPlaylist
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        let artworkSize: CGFloat = 56

        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                MediaArtwork(
                    urlString: playlist.snippet.thumbnails?.medium?.url ?? playlist.snippet.thumbnails?.default?.url,
                    fallbackIcon: "play.rectangle.on.rectangle.fill",
                    color: .red,
                    size: artworkSize
                )

                Text(playlist.snippet.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isHovering ? .red : .white)
                    .lineLimit(1)
                    .frame(width: artworkSize, alignment: .leading)
            }
            .frame(width: artworkSize, alignment: .leading)
            .padding(5)
            .background(isHovering ? Color.red.opacity(0.10) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
    }
}
