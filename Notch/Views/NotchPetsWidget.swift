import SwiftUI
import AppKit
import SpriteKit
import IOKit.ps
import Combine

enum NotchPetsPreferences {
    static let enabledKey = "notch_pets_enabled"
    private static let migrationKey = "notch_pets_plugin_to_feature_migrated_20260708"

    static func migratePluginStateIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationKey) else { return }

        if defaults.object(forKey: enabledKey) == nil {
            let oldInstalled = defaults.bool(forKey: "plugin_notch_pets_installed")
            let oldEnabled = defaults.bool(forKey: "plugin_notch_pets_enabled")
            defaults.set(oldInstalled && oldEnabled, forKey: enabledKey)
        }

        defaults.set(true, forKey: migrationKey)
    }
}

struct NotchPetsSettingsView: View {
    @AppStorage("notch_pets_kind") private var petKindRaw = NotchPetKind.cat.rawValue
    @AppStorage("notch_pets_name") private var petName = "Pixel"
    @AppStorage("notch_pets_cat_style") private var catStyleRaw = NotchCatStyle.classic.rawValue
    @AppStorage("notch_pets_dog_style") private var dogStyleRaw = NotchDogStyle.fluffyPup.rawValue
    @AppStorage("notch_pets_more_style") private var moreStyleRaw = NotchMorePetStyle.codeTiger.rawValue
    @AppStorage("notch_pets_collapsed_scale") private var collapsedPetScale = 1.0
    @AppStorage("notch_pets_expanded_scale") private var expandedPetScale = 0.7

    private var selectedKind: NotchPetKind {
        NotchPetKind(rawValue: petKindRaw) ?? .cat
    }

    private var selectedCatStyle: NotchCatStyle {
        NotchCatStyle(rawValue: catStyleRaw) ?? .classic
    }

    private var selectedDogStyle: NotchDogStyle {
        NotchDogStyle.storedValue(dogStyleRaw)
    }

    private var selectedMoreStyle: NotchMorePetStyle {
        NotchMorePetStyle(rawValue: moreStyleRaw) ?? .codeTiger
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dashboard companion")
                    .font(.system(size: 13, weight: .semibold))
                Text("Pick a pet that walks over the collapsed notch and expanded dashboard without taking a widget slot. Pets react to music, focus sessions, battery, and system load.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().opacity(0.15)

            VStack(alignment: .leading, spacing: 6) {
                Text("Pet Name")
                    .font(.system(size: 13, weight: .medium))
                TextField("Pixel", text: $petName)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }

            Divider().opacity(0.15)

            VStack(alignment: .leading, spacing: 8) {
                Text("Pet")
                    .font(.system(size: 13, weight: .medium))

                HStack(spacing: 8) {
                    ForEach([NotchPetKind.cat, NotchPetKind.dog, NotchPetKind.more]) { kind in
                        Button {
                            petKindRaw = kind.rawValue
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: kind.symbolName)
                                    .font(.system(size: 13, weight: .bold))
                                Text(kind.title)
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(selectedKind == kind ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.07))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(selectedKind == kind ? Color.accentColor.opacity(0.7) : Color.white.opacity(0.10), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider().opacity(0.15)

            VStack(alignment: .leading, spacing: 12) {
                petSizeSlider(
                    title: "Collapsed size",
                    description: "Pet size while the island is collapsed.",
                    value: clampedCollapsedPetScale,
                    currentValue: clampedCollapsedPetScaleValue,
                    range: 0.6...1.6,
                    lowerLabel: "60%"
                )

                petSizeSlider(
                    title: "Expanded size",
                    description: "Pet size while the dashboard is expanded.",
                    value: clampedExpandedPetScale,
                    currentValue: clampedExpandedPetScaleValue,
                    range: 0.35...1.6,
                    lowerLabel: "35%"
                )
            }

            Divider().opacity(0.15)

            if selectedKind == .cat {
                petStyleSection(
                    title: "Cat Style",
                    styles: NotchCatStyle.allCases,
                    selected: selectedCatStyle,
                    select: { catStyleRaw = $0.rawValue },
                    card: { style in
                        PetStyleOptionCard(
                            title: style.title,
                            subtitle: style.subtitle,
                            color: Color(nsColor: style.tint),
                            isSelected: selectedCatStyle == style
                        )
                    }
                )

                Divider().opacity(0.15)
            }

            if selectedKind == .dog {
                petStyleSection(
                    title: "Dog Style",
                    styles: NotchDogStyle.allCases,
                    selected: selectedDogStyle,
                    select: { dogStyleRaw = $0.rawValue },
                    card: { style in
                        PetStyleOptionCard(
                            title: style.title,
                            subtitle: style.subtitle,
                            color: Color(nsColor: style.swatchColor),
                            isSelected: selectedDogStyle == style
                        )
                    }
                )

                Divider().opacity(0.15)
            }

            if selectedKind == .more {
                petStyleSection(
                    title: "More Styles",
                    styles: NotchMorePetStyle.allCases,
                    selected: selectedMoreStyle,
                    select: { moreStyleRaw = $0.rawValue },
                    card: { style in
                        PetStyleOptionCard(
                            title: style.title,
                            subtitle: style.subtitle,
                            color: Color(nsColor: style.swatchColor),
                            isSelected: selectedMoreStyle == style
                        )
                    }
                )

                Divider().opacity(0.15)
            }

            PluginSettingToggle(
                title: "Show name pill",
                description: "Display the pet status label under the pet in the dashboard.",
                key: "notch_pets_show_name",
                defaultValue: true
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Show habitat background",
                description: "Use a subtle habitat panel behind the pet.",
                key: "notch_pets_dashboard_habitat",
                defaultValue: true
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Music reactions",
                description: "Let the pet move more when music is playing.",
                key: "notch_pets_music_reactions",
                defaultValue: true
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Focus reactions",
                description: "Let the pet calm down during Pomodoro focus sessions.",
                key: "notch_pets_focus_reactions",
                defaultValue: true
            )
        }
        .onAppear {
            collapsedPetScale = clampedCollapsedPetScaleValue
            expandedPetScale = clampedExpandedPetScaleValue
        }
    }

    private func petStyleSection<Style: Identifiable & Hashable, Card: View>(
        title: String,
        styles: [Style],
        selected _: Style,
        select: @escaping (Style) -> Void,
        @ViewBuilder card: @escaping (Style) -> Card
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 8)], spacing: 8) {
                ForEach(styles) { style in
                    Button {
                        select(style)
                    } label: {
                        card(style)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func petSizeSlider(
        title: String,
        description: String,
        value: Binding<Double>,
        currentValue: Double,
        range: ClosedRange<Double>,
        lowerLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(Int((currentValue * 100).rounded()))%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                Text(lowerLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Slider(value: value, in: range, step: 0.05)
                    .labelsHidden()
                Text("160%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var clampedCollapsedPetScale: Binding<Double> {
        Binding(
            get: { clampedCollapsedPetScaleValue },
            set: { collapsedPetScale = min(max($0, 0.6), 1.6) }
        )
    }

    private var clampedExpandedPetScale: Binding<Double> {
        Binding(
            get: { clampedExpandedPetScaleValue },
            set: { expandedPetScale = min(max($0, 0.35), 1.6) }
        )
    }

    private var clampedCollapsedPetScaleValue: Double {
        min(max(collapsedPetScale, 0.6), 1.6)
    }

    private var clampedExpandedPetScaleValue: Double {
        min(max(expandedPetScale, 0.35), 1.6)
    }
}

private struct PetStyleOptionCard: View {
    let title: String
    let subtitle: String
    let color: Color
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(color)
                    .frame(width: 20, height: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                }
            }

            Text(title)
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.7) : Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

enum NotchPetKind: String, CaseIterable, Identifiable {
    case cat
    case dog
    case more
    case bird
    case capybara
    case owl

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cat: return "Cat"
        case .dog: return "Dog"
        case .more: return "More"
        case .bird: return "Bird"
        case .capybara: return "Capybara"
        case .owl: return "Night Owl"
        }
    }

    var symbolName: String {
        switch self {
        case .cat: return "pawprint.fill"
        case .dog: return "dog.fill"
        case .more: return "sparkles"
        case .bird: return "bird.fill"
        case .capybara: return "leaf.fill"
        case .owl: return "moon.stars.fill"
        }
    }
}

enum NotchPetSheetLayout: Equatable {
    case oneko
    case codexPet
}

enum NotchCatStyle: String, CaseIterable, Identifiable {
    case classic
    case orangeTabby
    case tuxedo
    case calico
    case siamese
    case goldenCat
    case blackFish
    case gritcat
    case yuexinmiao
    case frosttail

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .orangeTabby: return "Orange"
        case .tuxedo: return "Tuxedo"
        case .calico: return "Calico"
        case .siamese: return "Siamese"
        case .goldenCat: return "Golden Cat"
        case .blackFish: return "Black Fish"
        case .gritcat: return "Gritcat"
        case .yuexinmiao: return "Yuexinmiao"
        case .frosttail: return "Frosttail"
        }
    }

    var subtitle: String {
        switch self {
        case .classic: return "Balanced"
        case .orangeTabby: return "Fast"
        case .tuxedo: return "Calm"
        case .calico: return "Curious"
        case .siamese: return "Sleepy"
        case .goldenCat: return "Codex Pets"
        case .blackFish: return "Fish Spirit"
        case .gritcat: return "Focused"
        case .yuexinmiao: return "Moonlit"
        case .frosttail: return "Icy"
        }
    }

    var spriteAssetName: String {
        switch self {
        case .classic: return "NotchPetOnekoSprite"
        case .orangeTabby: return "NotchPetOrangeTabbySprite"
        case .tuxedo: return "NotchPetTuxedoSprite"
        case .calico: return "NotchPetCalicoSprite"
        case .siamese: return "NotchPetSiameseSprite"
        case .goldenCat: return "NotchPetCatGoldenSprite"
        case .blackFish: return "NotchPetCatBlackFishSprite"
        case .gritcat: return "NotchPetCatGritcatSprite"
        case .yuexinmiao: return "NotchPetCatYuexinmiaoSprite"
        case .frosttail: return "NotchPetCatFrosttailSprite"
        }
    }

    var sheetLayout: NotchPetSheetLayout {
        switch self {
        case .classic, .orangeTabby, .tuxedo, .calico, .siamese:
            return .oneko
        case .goldenCat, .blackFish, .gritcat, .yuexinmiao, .frosttail:
            return .codexPet
        }
    }

    var tint: NSColor {
        switch self {
        case .classic:
            return .white
        case .orangeTabby:
            return NSColor(calibratedRed: 1.00, green: 0.55, blue: 0.18, alpha: 1)
        case .tuxedo:
            return NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.14, alpha: 1)
        case .calico:
            return NSColor(calibratedRed: 0.98, green: 0.93, blue: 0.82, alpha: 1)
        case .siamese:
            return NSColor(calibratedRed: 0.88, green: 0.78, blue: 0.58, alpha: 1)
        case .goldenCat:
            return NSColor(calibratedRed: 1.00, green: 0.67, blue: 0.20, alpha: 1)
        case .blackFish:
            return NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.12, alpha: 1)
        case .gritcat:
            return NSColor(calibratedRed: 0.76, green: 0.70, blue: 0.61, alpha: 1)
        case .yuexinmiao:
            return NSColor(calibratedRed: 0.52, green: 0.64, blue: 0.98, alpha: 1)
        case .frosttail:
            return NSColor(calibratedRed: 0.72, green: 0.90, blue: 1.00, alpha: 1)
        }
    }

    var tintAmount: CGFloat {
        switch self {
        case .classic: return 0.0
        case .orangeTabby: return 0.42
        case .tuxedo: return 0.46
        case .calico: return 0.16
        case .siamese: return 0.30
        case .goldenCat, .blackFish, .gritcat, .yuexinmiao, .frosttail: return 0
        }
    }

    var speedMultiplier: CGFloat {
        switch self {
        case .orangeTabby: return 1.08
        case .tuxedo: return 0.82
        case .calico: return 0.96
        case .siamese: return 0.78
        case .goldenCat: return 1.02
        case .blackFish: return 0.92
        case .gritcat: return 0.88
        case .yuexinmiao: return 0.96
        case .frosttail: return 0.90
        default: return 1.0
        }
    }

    var prefersLongNaps: Bool {
        self == .siamese || self == .tuxedo || self == .frosttail || self == .blackFish
    }

    var prefersExtraScratches: Bool {
        self == .calico || self == .orangeTabby || self == .goldenCat || self == .yuexinmiao
    }
}

enum NotchDogStyle: String, CaseIterable, Identifiable {
    case fluffyPup
    case curryDog
    case snowfieldPup
    case akaShiba

    var id: String { rawValue }

    static func storedValue(_ rawValue: String) -> NotchDogStyle {
        if rawValue == "cavalierPup" || rawValue == "codexPuppy" { return .fluffyPup }
        return NotchDogStyle(rawValue: rawValue) ?? .fluffyPup
    }

    var title: String {
        switch self {
        case .fluffyPup: return "Fluffy Pup"
        case .curryDog: return "Curry Dog"
        case .snowfieldPup: return "Snowfield"
        case .akaShiba: return "Aka Shiba"
        }
    }

    var subtitle: String {
        switch self {
        case .fluffyPup: return "Codex Pets"
        case .curryDog: return "Warm"
        case .snowfieldPup: return "Snow"
        case .akaShiba: return "Shiba"
        }
    }

    var spriteAssetName: String {
        switch self {
        case .fluffyPup: return "NotchPetDogFluffyPupSprite"
        case .curryDog: return "NotchPetDogCurrySprite"
        case .snowfieldPup: return "NotchPetDogSnowfieldSprite"
        case .akaShiba: return "NotchPetDogAkaShibaSprite"
        }
    }

    var swatchColor: NSColor {
        switch self {
        case .fluffyPup: return NSColor(calibratedRed: 0.96, green: 0.95, blue: 0.90, alpha: 1)
        case .curryDog: return NSColor(calibratedRed: 0.72, green: 0.42, blue: 0.20, alpha: 1)
        case .snowfieldPup: return NSColor(calibratedRed: 0.78, green: 0.90, blue: 1.00, alpha: 1)
        case .akaShiba: return NSColor(calibratedRed: 0.88, green: 0.34, blue: 0.12, alpha: 1)
        }
    }

    var speedMultiplier: CGFloat {
        switch self {
        case .fluffyPup: return 0.98
        case .curryDog: return 0.92
        case .snowfieldPup: return 0.96
        case .akaShiba: return 1.02
        }
    }

    var prefersLongNaps: Bool {
        self == .snowfieldPup
    }

    var prefersExtraScratches: Bool {
        self == .fluffyPup || self == .akaShiba
    }
}

enum NotchMorePetStyle: String, CaseIterable, Identifiable {
    case codeTiger
    case nekoOtter
    case leafbud
    case robot
    case bucketAxolotl

    var id: String { rawValue }

    var title: String {
        switch self {
        case .codeTiger: return "Code Tiger"
        case .nekoOtter: return "Neko Otter"
        case .leafbud: return "Leafbud"
        case .robot: return "Robot"
        case .bucketAxolotl: return "Axolotl"
        }
    }

    var subtitle: String {
        switch self {
        case .codeTiger: return "Animal"
        case .nekoOtter: return "Otter"
        case .leafbud: return "Plant"
        case .robot: return "Robot"
        case .bucketAxolotl: return "Fantasy"
        }
    }

    var spriteAssetName: String {
        switch self {
        case .codeTiger: return "NotchPetMoreCodeTigerSprite"
        case .nekoOtter: return "NotchPetMoreNekoOtterSprite"
        case .leafbud: return "NotchPetMoreLeafbudSprite"
        case .robot: return "NotchPetMoreRobotSprite"
        case .bucketAxolotl: return "NotchPetMoreBucketAxolotlSprite"
        }
    }

    var swatchColor: NSColor {
        switch self {
        case .codeTiger: return NSColor(calibratedRed: 1.00, green: 0.54, blue: 0.12, alpha: 1)
        case .nekoOtter: return NSColor(calibratedRed: 0.50, green: 0.36, blue: 0.24, alpha: 1)
        case .leafbud: return NSColor(calibratedRed: 0.34, green: 0.78, blue: 0.34, alpha: 1)
        case .robot: return NSColor(calibratedRed: 0.54, green: 0.68, blue: 0.82, alpha: 1)
        case .bucketAxolotl: return NSColor(calibratedRed: 0.94, green: 0.55, blue: 0.76, alpha: 1)
        }
    }

    var speedMultiplier: CGFloat {
        switch self {
        case .codeTiger: return 1.08
        case .nekoOtter: return 0.98
        case .leafbud: return 0.78
        case .robot: return 0.90
        case .bucketAxolotl: return 0.88
        }
    }

    var prefersLongNaps: Bool {
        self == .leafbud || self == .bucketAxolotl
    }

    var prefersExtraScratches: Bool {
        self == .codeTiger || self == .nekoOtter
    }
}

private enum NotchPetMood {
    case idle
    case blink
    case sleep
    case music
    case focus
    case happy
    case stressed
    case tired
    case stretch
    case bark
    case chill
    case nightWatch
}

final class NotchPetBatteryMonitor: ObservableObject {
    static let shared = NotchPetBatteryMonitor()

    @Published private(set) var percent: Int?
    @Published private(set) var isCharging = false

    private var timer: Timer?

    private init() {}

    func start() {
        refresh()
        guard timer == nil else { return }

        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = 12
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard let powerInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(powerInfo)?.takeRetainedValue() as? [CFTypeRef] else {
            percent = nil
            isCharging = false
            return
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(powerInfo, source)?.takeUnretainedValue() as? [String: Any],
                  let type = description[kIOPSTypeKey] as? String,
                  type == kIOPSInternalBatteryType,
                  let capacity = description[kIOPSCurrentCapacityKey] as? Int else {
                continue
            }

            percent = min(max(capacity, 0), 100)
            isCharging = (description[kIOPSIsChargingKey] as? Bool) ?? false
            return
        }

        percent = nil
        isCharging = false
    }

    var isLowBattery: Bool {
        guard let percent else { return false }
        return percent <= 20 && !isCharging
    }
}

struct NotchPetsWidget: View {
    @AppStorage("notch_pets_kind") private var petKindRaw = NotchPetKind.cat.rawValue
    @AppStorage("notch_pets_cat_style") private var catStyleRaw = NotchCatStyle.classic.rawValue
    @AppStorage("notch_pets_dog_style") private var dogStyleRaw = NotchDogStyle.fluffyPup.rawValue
    @AppStorage("notch_pets_more_style") private var moreStyleRaw = NotchMorePetStyle.codeTiger.rawValue
    @AppStorage("notch_pets_name") private var petName = "Pixel"
    @AppStorage("notch_pets_show_name") private var showName = true
    @AppStorage("notch_pets_dashboard_habitat") private var showHabitat = true
    @AppStorage("notch_pets_music_reactions") private var musicReactions = true
    @AppStorage("notch_pets_focus_reactions") private var focusReactions = true
    @AppStorage("notch_pets_system_reactions") private var systemReactions = true
    @AppStorage("notch_pets_battery_reactions") private var batteryReactions = true
    @AppStorage("notch_pets_expanded_scale") private var expandedPetScale = 0.7

    @ObservedObject private var nowPlaying = NowPlayingManager.shared
    @ObservedObject private var pomodoro = PomodoroTimerManager.shared
    @ObservedObject private var hardware = HardwareHUDManager.shared
    @ObservedObject private var calendar = GoogleCalendarManager.shared
    @StateObject private var battery = NotchPetBatteryMonitor.shared

    private var petKind: NotchPetKind {
        NotchPetKind(rawValue: petKindRaw) ?? .cat
    }

    private var catStyle: NotchCatStyle {
        NotchCatStyle(rawValue: catStyleRaw) ?? .classic
    }

    private var dogStyle: NotchDogStyle {
        NotchDogStyle.storedValue(dogStyleRaw)
    }

    private var moreStyle: NotchMorePetStyle {
        NotchMorePetStyle(rawValue: moreStyleRaw) ?? .codeTiger
    }

    var body: some View {
        let mood = resolvedMood(at: Date(), isHoveringNotch: false, preferDashboard: true)

        ZStack {
            if showHabitat {
                NotchPetHabitat(kind: petKind, mood: mood)
            }

            VStack(spacing: 8) {
                Spacer(minLength: 8)

                NotchPetSpriteKitView(
                    kind: petKind,
                    catStyle: catStyle,
                    dogStyle: dogStyle,
                    moreStyle: moreStyle,
                    mood: mood,
                    isCharging: batteryReactions && battery.isCharging,
                    isCompact: false,
                    shouldRoam: false,
                    petScale: CGFloat(clampedExpandedPetScale)
                )
                .frame(width: 150, height: 128)

                if showName {
                    statusPill(for: mood)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onAppear {
            battery.start()
        }
        .onDisappear {
            battery.stop()
        }
    }

    private var displayName: String {
        let trimmed = petName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? petKind.title : trimmed
    }

    private var clampedExpandedPetScale: Double {
        min(max(expandedPetScale, 0.35), 1.6)
    }

    private func statusPill(for mood: NotchPetMood) -> some View {
        HStack(spacing: 6) {
            Image(systemName: statusIcon(for: mood))
                .font(.system(size: 10, weight: .bold))
            Text(statusText(for: mood))
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .lineLimit(1)
        }
        .foregroundColor(.white.opacity(0.9))
        .padding(.horizontal, 12)
        .frame(height: 27)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
    }

    private func statusIcon(for mood: NotchPetMood) -> String {
        switch mood {
        case .music: return "headphones"
        case .focus, .sleep: return "powersleep"
        case .happy: return "heart.fill"
        case .stressed: return "thermometer.high"
        case .tired: return "battery.25"
        case .stretch: return "arrow.left.and.right"
        case .bark: return "bell.fill"
        case .chill: return "leaf.fill"
        case .nightWatch: return "moon.stars.fill"
        default: return petKind.symbolName
        }
    }

    private func statusText(for mood: NotchPetMood) -> String {
        switch mood {
        case .music: return "\(displayName) is grooving"
        case .focus: return "\(displayName) guards focus"
        case .sleep: return "\(displayName) is napping"
        case .happy: return "\(displayName) likes that"
        case .stressed: return "\(displayName) feels the heat"
        case .tired: return "\(displayName) needs charge"
        case .stretch: return "\(displayName) stretches"
        case .bark: return "\(displayName) has a reminder"
        case .chill: return "\(displayName) is chilling"
        case .nightWatch: return "\(displayName) keeps watch"
        default: return displayName
        }
    }

    private func resolvedMood(at date: Date, isHoveringNotch: Bool, preferDashboard: Bool) -> NotchPetMood {
        NotchPetMoodResolver.resolve(
            kind: petKind,
            date: date,
            isHappy: false,
            isHoveringNotch: isHoveringNotch,
            musicReactions: musicReactions,
            focusReactions: focusReactions,
            systemReactions: systemReactions,
            batteryReactions: batteryReactions,
            nowPlaying: nowPlaying,
            pomodoro: pomodoro,
            hardware: hardware,
            battery: battery,
            calendar: calendar,
            preferDashboard: preferDashboard
        )
    }
}

struct NotchPetPerchView: View {
    let kind: NotchPetKind
    let size: Double
    let isExpanded: Bool
    var isHoveringNotch: Bool = false

    @AppStorage("notch_pets_music_reactions") private var musicReactions = true
    @AppStorage("notch_pets_kind") private var petKindRaw = NotchPetKind.cat.rawValue
    @AppStorage("notch_pets_cat_style") private var catStyleRaw = NotchCatStyle.classic.rawValue
    @AppStorage("notch_pets_dog_style") private var dogStyleRaw = NotchDogStyle.fluffyPup.rawValue
    @AppStorage("notch_pets_more_style") private var moreStyleRaw = NotchMorePetStyle.codeTiger.rawValue
    @AppStorage("notch_pets_focus_reactions") private var focusReactions = true
    @AppStorage("notch_pets_system_reactions") private var systemReactions = true
    @AppStorage("notch_pets_battery_reactions") private var batteryReactions = true

    @ObservedObject private var nowPlaying = NowPlayingManager.shared
    @ObservedObject private var pomodoro = PomodoroTimerManager.shared
    @ObservedObject private var hardware = HardwareHUDManager.shared
    @ObservedObject private var calendar = GoogleCalendarManager.shared
    @StateObject private var battery = NotchPetBatteryMonitor.shared

    var body: some View {
        GeometryReader { geometry in
            let selectedKind = NotchPetKind(rawValue: petKindRaw) ?? kind
            let mood = NotchPetMoodResolver.resolve(
                kind: selectedKind,
                date: Date(),
                isHappy: false,
                isHoveringNotch: isHoveringNotch,
                musicReactions: musicReactions,
                focusReactions: focusReactions,
                systemReactions: systemReactions,
                batteryReactions: batteryReactions,
                nowPlaying: nowPlaying,
                pomodoro: pomodoro,
                hardware: hardware,
                battery: battery,
                calendar: calendar,
                preferDashboard: isExpanded
            )

            NotchPetSpriteKitView(
                kind: selectedKind,
                catStyle: NotchCatStyle(rawValue: catStyleRaw) ?? .classic,
                dogStyle: NotchDogStyle.storedValue(dogStyleRaw),
                moreStyle: NotchMorePetStyle(rawValue: moreStyleRaw) ?? .codeTiger,
                mood: mood,
                isCharging: batteryReactions && battery.isCharging,
                isCompact: !isExpanded,
                shouldRoam: true,
                petScale: CGFloat(min(max(size, isExpanded ? 0.35 : 0.6), 1.6))
            )
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                battery.start()
            }
            .onDisappear {
                battery.stop()
            }
        }
        .accessibilityHidden(true)
    }
}

private enum NotchPetMoodResolver {
    static func resolve(
        kind: NotchPetKind,
        date: Date,
        isHappy: Bool,
        isHoveringNotch: Bool,
        musicReactions: Bool,
        focusReactions: Bool,
        systemReactions: Bool,
        batteryReactions: Bool,
        nowPlaying: NowPlayingManager,
        pomodoro: PomodoroTimerManager,
        hardware: HardwareHUDManager,
        battery: NotchPetBatteryMonitor,
        calendar: GoogleCalendarManager,
        preferDashboard: Bool
    ) -> NotchPetMood {
        if isHappy { return .happy }

        if kind == .capybara {
            let tick = Int(date.timeIntervalSince1970 / 1.6)
            return tick % 9 == 0 ? .blink : .chill
        }

        if batteryReactions, battery.isLowBattery, kind != .capybara {
            return .tired
        }

        if kind == .dog, dogHasUpcomingEvent(calendar: calendar, date: date) {
            return .bark
        }

        if systemReactions, kind != .capybara {
            let snapshot = hardware.snapshot
            let snapshotIsFresh = date.timeIntervalSince(snapshot.updatedAt) < 12
            if snapshotIsFresh, snapshot.cpuAverage > 0.78 || snapshot.memoryPressure > 0.84 {
                return .stressed
            }
        }

        if focusReactions, pomodoro.isRunning, pomodoro.mode == .focus {
            return .focus
        }

        if musicReactions,
           nowPlaying.isPlaying,
           nowPlaying.currentSong != "No Music",
           nowPlaying.currentSong != "NOT_PLAYING" {
            return .music
        }

        if kind == .owl {
            let hour = Calendar.current.component(.hour, from: date)
            if (8...20).contains(hour) {
                return .sleep
            }
            if hour <= 5 {
                return .nightWatch
            }
        }

        if kind == .cat {
            let stretchTick = Int(date.timeIntervalSince1970 / 6.5)
            if preferDashboard, stretchTick % 5 == 2 {
                return .stretch
            }
        }

        if !preferDashboard, kind != .capybara {
            return .sleep
        }

        let tick = Int(date.timeIntervalSince1970 / 0.8)
        return tick % (kind == .capybara ? 10 : 7) == 0 ? .blink : .idle
    }

    private static func dogHasUpcomingEvent(calendar: GoogleCalendarManager, date: Date) -> Bool {
        guard calendar.isAuthenticated else { return false }

        return calendar.upcomingEvents.contains { event in
            guard let startString = event.start.dateTime ?? event.start.date,
                  let startDate = parseGoogleDate(startString) else {
                return false
            }

            let interval = startDate.timeIntervalSince(date)
            return interval >= 0 && interval <= 10 * 60
        }
    }

    private static func parseGoogleDate(_ string: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: string) {
            return date
        }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        return dayFormatter.date(from: string)
    }
}

private struct NotchPetHabitat: View {
    let kind: NotchPetKind
    let mood: NotchPetMood

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                habitatColor.opacity(mood == .happy ? 0.26 : 0.18),
                                Color.white.opacity(0.045),
                                Color.black.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack {
                    HStack(spacing: 5) {
                        ForEach(0..<5, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(habitatColor.opacity(index == 2 ? 0.34 : 0.18))
                                .frame(width: 8, height: CGFloat(7 + index % 3 * 4))
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(14)

                Ellipse()
                    .fill(Color.black.opacity(0.22))
                    .frame(width: geo.size.width * 0.54, height: 18)
                    .blur(radius: 2)
                    .offset(y: geo.size.height * 0.29)
            }
        }
    }

    private var palette: NotchPetPalette {
        NotchPetPalette(kind: kind)
    }

    private var habitatColor: Color {
        switch mood {
        case .music: return .cyan
        case .focus, .sleep: return .indigo
        case .happy: return .pink
        case .stressed: return .orange
        case .tired: return .red
        default: return palette.accent
        }
    }
}

private struct NotchPetSpriteKitView: NSViewRepresentable {
    let kind: NotchPetKind
    let catStyle: NotchCatStyle
    let dogStyle: NotchDogStyle
    let moreStyle: NotchMorePetStyle
    let mood: NotchPetMood
    let isCharging: Bool
    let isCompact: Bool
    let shouldRoam: Bool
    let petScale: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> ClearNotchPetSKView {
        let view = ClearNotchPetSKView()
        view.preferredFramesPerSecond = 30
        view.ignoresSiblingOrder = true
        view.allowsTransparency = true
        view.shouldCullNonVisibleNodes = true
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.layer?.backgroundColor = NSColor.clear.cgColor

        let scene = context.coordinator.scene
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        view.presentScene(scene)

        configureClearSurface(view)
        scene.updateConfiguration(
            kind: kind,
            catStyle: catStyle,
            dogStyle: dogStyle,
            moreStyle: moreStyle,
            mood: mood,
            isCharging: isCharging,
            isCompact: isCompact,
            shouldRoam: shouldRoam,
            petScale: petScale
        )
        return view
    }

    func updateNSView(_ view: ClearNotchPetSKView, context: Context) {
        configureClearSurface(view)
        if view.scene !== context.coordinator.scene {
            view.presentScene(context.coordinator.scene)
        }

        context.coordinator.scene.size = view.bounds.size
        context.coordinator.scene.updateConfiguration(
            kind: kind,
            catStyle: catStyle,
            dogStyle: dogStyle,
            moreStyle: moreStyle,
            mood: mood,
            isCharging: isCharging,
            isCompact: isCompact,
            shouldRoam: shouldRoam,
            petScale: petScale
        )
    }

    static func dismantleNSView(_ view: ClearNotchPetSKView, coordinator: Coordinator) {
        coordinator.scene.removeAllActions()
        coordinator.scene.removeAllChildren()
        view.presentScene(nil)
    }

    private func configureClearSurface(_ view: ClearNotchPetSKView) {
        view.allowsTransparency = true
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.scene?.backgroundColor = .clear
        view.enforceClearWindow()
    }

    final class Coordinator {
        let scene = NotchPetSpriteScene(size: .zero)
    }
}

private final class ClearNotchPetSKView: SKView {
    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        enforceClearWindow()
    }

    func enforceClearWindow() {
        allowsTransparency = true
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
        window?.isOpaque = false
        window?.backgroundColor = .clear
    }
}

private enum NotchPetSpriteAnimation: String {
    case idle
    case alert
    case walkRight
    case walkLeft
    case walkUp
    case walkDown
    case walkUpLeft
    case walkUpRight
    case walkDownLeft
    case walkDownRight
    case eat
    case scratchSelf
    case scratchWallUp
    case scratchWallDown
    case scratchWallLeft
    case scratchWallRight
    case tired
    case rest
    case nap

    var timePerFrame: TimeInterval {
        switch self {
        case .idle: return 0.34
        case .alert: return 0.28
        case .walkRight, .walkLeft, .walkUp, .walkDown, .walkUpLeft, .walkUpRight, .walkDownLeft, .walkDownRight:
            return 0.12
        case .eat: return 0.18
        case .scratchSelf, .scratchWallUp, .scratchWallDown, .scratchWallLeft, .scratchWallRight:
            return 0.14
        case .tired: return 0.44
        case .rest: return 0.48
        case .nap: return 0.56
        }
    }

    var isStationary: Bool {
        switch self {
        case .eat, .scratchSelf, .scratchWallUp, .scratchWallDown, .scratchWallLeft, .scratchWallRight, .tired, .rest, .nap:
            return true
        default:
            return false
        }
    }

    var walkingAnimation: NotchPetSpriteAnimation? {
        switch self {
        case .walkRight, .walkLeft, .walkUp, .walkDown, .walkUpLeft, .walkUpRight, .walkDownLeft, .walkDownRight:
            return self
        default:
            return nil
        }
    }
}

private final class NotchPetSpriteScene: SKScene {
    private let containerNode = SKNode()
    private let shadowNode = SKShapeNode()
    private let petNode = SKSpriteNode()
    private let foodNode = SKNode()

    private var currentKind: NotchPetKind = .cat
    private var currentCatStyle: NotchCatStyle = .classic
    private var currentDogStyle: NotchDogStyle = .fluffyPup
    private var currentMoreStyle: NotchMorePetStyle = .codeTiger
    private var currentMood: NotchPetMood = .idle
    private var currentAnimation: NotchPetSpriteAnimation?
    private var currentIsCompact = false
    private var currentShouldRoam = false
    private var currentIsCharging = false
    private var currentPetScale: CGFloat = 1
    private var lastLayoutSize: CGSize = .zero
    private var lastRoamState = false

    private static var textureCache: [String: [SKTexture]] = [:]
    private static var sheetTextureCache: [String: SKTexture] = [:]

    private struct SpriteSource {
        let assetName: String
        let layout: NotchPetSheetLayout
    }

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
        anchorPoint = .zero
        isUserInteractionEnabled = false

        shadowNode.fillColor = NSColor.black.withAlphaComponent(0.26)
        shadowNode.strokeColor = .clear
        shadowNode.zPosition = 0

        petNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        petNode.zPosition = 1

        containerNode.addChild(shadowNode)
        containerNode.addChild(petNode)
        containerNode.addChild(foodNode)
        configureFoodBowl()
        addChild(containerNode)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = .clear
        view.allowsTransparency = true
        view.window?.isOpaque = false
        view.window?.backgroundColor = .clear
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutPet(forceRoamRestart: false)
    }

    func updateConfiguration(
        kind: NotchPetKind,
        catStyle: NotchCatStyle,
        dogStyle: NotchDogStyle,
        moreStyle: NotchMorePetStyle,
        mood: NotchPetMood,
        isCharging: Bool,
        isCompact: Bool,
        shouldRoam: Bool,
        petScale: CGFloat
    ) {
        let kindChanged = currentKind != kind
        let styleChanged = currentCatStyle != catStyle || currentDogStyle != dogStyle || currentMoreStyle != moreStyle
        let chargingChanged = currentIsCharging != isCharging
        let compactChanged = currentIsCompact != isCompact
        let minScale: CGFloat = isCompact ? 0.6 : 0.35
        let clampedPetScale = min(max(petScale, minScale), 1.6)
        let scaleChanged = abs(currentPetScale - clampedPetScale) > 0.001
        currentKind = kind
        currentCatStyle = catStyle
        currentDogStyle = dogStyle
        currentMoreStyle = moreStyle
        currentMood = mood
        currentIsCompact = isCompact
        currentShouldRoam = shouldRoam
        currentIsCharging = isCharging
        currentPetScale = clampedPetScale
        applyPetStyle()

        if !shouldRoam {
            let animation = spriteAnimation(for: mood, isCharging: isCharging)
            if currentAnimation != animation || kindChanged || styleChanged || chargingChanged {
                runTextureAnimation(animation)
            }
        }

        layoutPet(forceRoamRestart: lastRoamState != shouldRoam || chargingChanged || kindChanged || styleChanged || compactChanged || scaleChanged)
        lastRoamState = shouldRoam
    }

    private func spriteAnimation(for mood: NotchPetMood, isCharging: Bool) -> NotchPetSpriteAnimation {
        if isCharging {
            return .eat
        }

        switch mood {
        case .music, .happy, .stretch, .bark:
            return .walkRight
        case .focus, .sleep:
            return .nap
        case .tired, .chill:
            return .tired
        default:
            return .idle
        }
    }

    private func applyPetStyle() {
        petNode.color = .white
        petNode.colorBlendFactor = 0
    }

    private var currentSpriteSource: SpriteSource {
        Self.spriteSource(kind: currentKind, catStyle: currentCatStyle, dogStyle: currentDogStyle, moreStyle: currentMoreStyle)
    }

    private var currentSpeedMultiplier: CGFloat {
        switch currentKind {
        case .dog:
            return currentDogStyle.speedMultiplier
        case .more:
            return currentMoreStyle.speedMultiplier
        default:
            return currentCatStyle.speedMultiplier
        }
    }

    private var currentPrefersLongNaps: Bool {
        switch currentKind {
        case .dog:
            return currentDogStyle.prefersLongNaps
        case .more:
            return currentMoreStyle.prefersLongNaps
        default:
            return currentCatStyle.prefersLongNaps
        }
    }

    private var currentPrefersExtraScratches: Bool {
        switch currentKind {
        case .dog:
            return currentDogStyle.prefersExtraScratches
        case .more:
            return currentMoreStyle.prefersExtraScratches
        default:
            return currentCatStyle.prefersExtraScratches
        }
    }

    private func runTextureAnimation(_ animation: NotchPetSpriteAnimation) {
        let textures = Self.textures(
            kind: currentKind,
            catStyle: currentCatStyle,
            dogStyle: currentDogStyle,
            moreStyle: currentMoreStyle,
            animation: animation
        )
        guard !textures.isEmpty else { return }

        currentAnimation = animation
        petNode.texture = textures[0]
        petNode.removeAction(forKey: "textureAnimation")
        foodNode.isHidden = animation != .eat

        let animate = SKAction.animate(
            with: textures,
            timePerFrame: animation.timePerFrame,
            resize: false,
            restore: false
        )
        petNode.run(SKAction.repeatForever(animate), withKey: "textureAnimation")
    }

    private func layoutPet(forceRoamRestart: Bool) {
        guard size.width > 1, size.height > 1 else { return }

        let baseSide = currentIsCompact
            ? min(max(size.height * 0.72, 20), 44)
            : min(max(min(size.width, size.height) * 0.72, 74), 116)

        let frameAspect = Self.frameAspectRatio(layout: currentSpriteSource.layout)
        let requestedSide = baseSide * currentPetScale
        let margin = petSafeMargin
        let maxHeightSide = max(18, size.height - margin * 2)
        let maxWidthSide = max(18, (size.width - margin * 2) / max(frameAspect, 0.2))
        let side = min(requestedSide, maxHeightSide, maxWidthSide)
        let petSize = CGSize(width: side * frameAspect, height: side)
        petNode.size = petSize
        petNode.position = CGPoint(x: 0, y: side * 0.10)

        let shadowRect = CGRect(x: -petSize.width * 0.36, y: -side * 0.38, width: petSize.width * 0.72, height: side * 0.16)
        shadowNode.path = CGPath(ellipseIn: shadowRect, transform: nil)

        if currentShouldRoam {
            if forceRoamRestart || containerNode.action(forKey: "perchRoutine") == nil {
                startPerchRoutine(petSide: side)
            }
        } else {
            containerNode.removeAction(forKey: "perchRoutine")
            containerNode.position = CGPoint(x: size.width / 2, y: size.height * 0.52)
        }

        layoutFoodBowl(petSide: side)

        lastLayoutSize = size
    }

    private func startPerchRoutine(petSide: CGFloat) {
        containerNode.removeAction(forKey: "perchRoutine")

        let leftPerch = stationaryPerch(side: .left, petSide: petSide)
        let rightPerch = stationaryPerch(side: .right, petSide: petSide)
        if containerNode.position == .zero {
            containerNode.position = leftPerch
        }
        let startPosition = containerNode.position

        let routine = currentIsCharging
            ? chargingPerchRoutine(leftPerch: leftPerch, rightPerch: rightPerch)
            : defaultPerchRoutine(petSide: petSide, leftPerch: leftPerch, rightPerch: rightPerch)
        containerNode.run(
            SKAction.sequence([
                walkTransition(from: startPosition, to: leftPerch),
                SKAction.repeatForever(routine)
            ]),
            withKey: "perchRoutine"
        )
    }

    private enum PerchSide {
        case left
        case right
    }

    private var petHalfWidth: CGFloat {
        max(petNode.size.width / 2, petNode.size.height / 2)
    }

    private var petHalfHeight: CGFloat {
        petNode.size.height / 2
    }

    private var petSafeMargin: CGFloat {
        currentIsCompact ? 8 : 16
    }

    private func stationaryPerch(side perchSide: PerchSide, petSide _: CGFloat) -> CGPoint {
        let margin = petSafeMargin
        let halfWidth = petHalfWidth
        let halfHeight = petHalfHeight
        let desiredY = currentIsCompact ? size.height * 0.56 : size.height * 0.42
        let minY = halfHeight + margin
        let maxY = max(minY, size.height - halfHeight - margin)
        let y = min(max(desiredY, minY), maxY)

        switch perchSide {
        case .left:
            return CGPoint(x: halfWidth + margin, y: y)
        case .right:
            return CGPoint(x: max(halfWidth + margin, size.width - halfWidth - margin), y: y)
        }
    }

    private func defaultPerchRoutine(petSide: CGFloat, leftPerch: CGPoint, rightPerch: CGPoint) -> SKAction {
        let lapStart = walkingLapCorners(petSide: petSide).topLeft
        let prefersLongNaps = currentPrefersLongNaps
        let prefersExtraScratches = currentPrefersExtraScratches
        let expandedRoutine = !currentIsCompact
        let napDuration = expandedRoutine ? (prefersLongNaps ? 4.8 : 3.2) : (prefersLongNaps ? 8.0 : 5.5)
        let scratchDuration = prefersExtraScratches ? 1.35 : 0.9
        let idleWait = expandedRoutine ? 2.0 : 4.8
        let restWait = expandedRoutine ? 1.25 : 3.2
        let selfScratchWait = expandedRoutine ? 0.9 : 1.2
        let tiredWait = expandedRoutine ? 1.25 : 2.8
        let eatWait = expandedRoutine ? 3.2 : 5.8

        var actions: [SKAction] = [
            setAnimation(.idle),
            SKAction.wait(forDuration: idleWait),
            setAnimation(.alert),
            SKAction.wait(forDuration: 0.9),
            setAnimation(.rest),
            SKAction.wait(forDuration: restWait),
            setAnimation(.scratchSelf),
            SKAction.wait(forDuration: selfScratchWait),
        ]

        if prefersExtraScratches || expandedRoutine {
            actions.append(contentsOf: [
                walkTransition(from: leftPerch, to: lapStart),
                walkingLap(petSide: petSide),
                walkTransition(from: lapStart, to: leftPerch)
            ])
        }

        actions.append(contentsOf: [
            setAnimation(.scratchWallLeft),
            SKAction.wait(forDuration: scratchDuration),
            setAnimation(.scratchSelf),
            SKAction.wait(forDuration: expandedRoutine ? 0.9 : 1.4),
            setAnimation(.tired),
            SKAction.wait(forDuration: tiredWait),

            walkTransition(from: leftPerch, to: rightPerch),
            setAnimation(.scratchWallRight),
            SKAction.wait(forDuration: scratchDuration),
            setAnimation(.eat),
            SKAction.wait(forDuration: eatWait),

            setAnimation(.nap),
            SKAction.wait(forDuration: napDuration),

            walkTransition(from: rightPerch, to: leftPerch)
        ])

        if prefersExtraScratches {
            actions.insert(contentsOf: [
                setAnimation(.scratchWallUp),
                SKAction.wait(forDuration: 0.7)
            ], at: 12)
        }

        return SKAction.sequence(actions)
    }

    private func chargingPerchRoutine(leftPerch: CGPoint, rightPerch: CGPoint) -> SKAction {
        return SKAction.sequence([
            setAnimation(.eat),
            SKAction.wait(forDuration: 7.5),
            setAnimation(.scratchSelf),
            SKAction.wait(forDuration: 1.3),

            setAnimation(.rest),
            SKAction.wait(forDuration: 4.2),

            walkTransition(from: leftPerch, to: rightPerch),
            setAnimation(.nap),
            SKAction.wait(forDuration: 7.0),

            walkTransition(from: rightPerch, to: leftPerch),
            setAnimation(.idle),
            SKAction.wait(forDuration: 4.5)
        ])
    }

    private func walkingLap(petSide: CGFloat) -> SKAction {
        let corners = walkingLapCorners(petSide: petSide)
        let center = CGPoint(
            x: (corners.topLeft.x + corners.topRight.x) / 2,
            y: (corners.topLeft.y + corners.bottomLeft.y) / 2
        )

        return SKAction.sequence([
            walkTransition(from: corners.topLeft, to: center),
            walkTransition(from: center, to: corners.topRight),
            walkTransition(from: corners.topRight, to: corners.bottomRight),
            walkTransition(from: corners.bottomRight, to: center),
            walkTransition(from: center, to: corners.bottomLeft),
            walkTransition(from: corners.bottomLeft, to: corners.topLeft)
        ])
    }

    private func walkingLapCorners(petSide _: CGFloat) -> (topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint) {
        let margin = petSafeMargin
        let halfWidth = petHalfWidth
        let halfHeight = petHalfHeight
        let minX = halfWidth + margin
        let maxX = max(minX, size.width - halfWidth - margin)
        let minY = halfHeight + margin
        let maxY = max(minY, size.height - halfHeight - margin)

        return (
            topLeft: CGPoint(x: minX, y: maxY),
            topRight: CGPoint(x: maxX, y: maxY),
            bottomRight: CGPoint(x: maxX, y: minY),
            bottomLeft: CGPoint(x: minX, y: minY)
        )
    }

    private func walkTransition(from start: CGPoint, to end: CGPoint) -> SKAction {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)
        guard distance > 2 else {
            return setAnimation(.idle)
        }

        let speedMultiplier = currentSpeedMultiplier
        let pixelsPerSecond = max(38, 58 * speedMultiplier)
        let duration = TimeInterval(min(4.0, max(0.72, distance / pixelsPerSecond)))

        let animation: NotchPetSpriteAnimation
        if abs(dx) > 5, abs(dy) > 5 {
            if dx >= 0, dy >= 0 {
                animation = .walkUpRight
            } else if dx >= 0 {
                animation = .walkDownRight
            } else if dy >= 0 {
                animation = .walkUpLeft
            } else {
                animation = .walkDownLeft
            }
        } else if abs(dx) >= abs(dy) {
            animation = dx >= 0 ? .walkRight : .walkLeft
        } else {
            animation = dy >= 0 ? .walkUp : .walkDown
        }

        return SKAction.sequence([
            setAnimation(animation),
            move(to: end, duration: duration)
        ])
    }

    private func setAnimation(_ animation: NotchPetSpriteAnimation) -> SKAction {
        SKAction.run { [weak self] in
            self?.runTextureAnimation(animation)
        }
    }

    private func configureFoodBowl() {
        foodNode.removeAllChildren()
        foodNode.zPosition = 2
        foodNode.isHidden = true

        let kibbleOffsets: [CGPoint] = [
            CGPoint(x: -4, y: 4),
            CGPoint(x: 0, y: 6),
            CGPoint(x: 4, y: 4)
        ]
        for offset in kibbleOffsets {
            let kibble = SKShapeNode(circleOfRadius: 2.2)
            kibble.fillColor = NSColor.systemOrange
            kibble.strokeColor = .clear
            kibble.position = offset
            foodNode.addChild(kibble)
        }

        let bowl = SKShapeNode(path: CGPath(ellipseIn: CGRect(x: -11, y: -5, width: 22, height: 10), transform: nil))
        bowl.fillColor = NSColor.systemPink.withAlphaComponent(0.96)
        bowl.strokeColor = NSColor.white.withAlphaComponent(0.45)
        bowl.lineWidth = 1.5
        bowl.zPosition = 1
        foodNode.addChild(bowl)

        let lip = SKShapeNode(path: CGPath(ellipseIn: CGRect(x: -13, y: 0, width: 26, height: 8), transform: nil))
        lip.fillColor = NSColor.systemPink.withAlphaComponent(0.76)
        lip.strokeColor = NSColor.white.withAlphaComponent(0.38)
        lip.lineWidth = 1.5
        lip.zPosition = 2
        foodNode.addChild(lip)
    }

    private func layoutFoodBowl(petSide: CGFloat) {
        let bowlScale = petSide / 80
        foodNode.setScale(bowlScale)
        foodNode.position = CGPoint(x: petSide * 0.26, y: -petSide * 0.20)
    }

    private func move(to point: CGPoint, duration: TimeInterval) -> SKAction {
        let action = SKAction.move(to: point, duration: duration)
        action.timingMode = .easeInEaseOut
        return action
    }

    private static func textures(
        kind: NotchPetKind,
        catStyle: NotchCatStyle,
        dogStyle: NotchDogStyle,
        moreStyle: NotchMorePetStyle,
        animation: NotchPetSpriteAnimation
    ) -> [SKTexture] {
        let source = spriteSource(kind: kind, catStyle: catStyle, dogStyle: dogStyle, moreStyle: moreStyle)
        let cacheKey = "\(source.assetName)-\(animation.rawValue)"
        if let cached = textureCache[cacheKey] {
            return cached
        }

        let textures = spriteFrames(layout: source.layout, for: animation).compactMap { spriteFrame in
            textureFromPetSheet(source: source, column: spriteFrame.column, row: spriteFrame.row)
        }
        textureCache[cacheKey] = textures
        return textures
    }

    private static func spriteFrames(layout: NotchPetSheetLayout, for animation: NotchPetSpriteAnimation) -> [(column: Int, row: Int)] {
        switch layout {
        case .oneko:
            return onekoSpriteFrames(for: animation)
        case .codexPet:
            return codexPetSpriteFrames(for: animation)
        }
    }

    private static func onekoSpriteFrames(for animation: NotchPetSpriteAnimation) -> [(column: Int, row: Int)] {
        switch animation {
        case .idle:
            return [(3, 3), (7, 3), (3, 3), (7, 3)]
        case .alert:
            return [(7, 3), (7, 3), (7, 3)]
        case .walkRight:
            return [(3, 0), (3, 1), (3, 0), (3, 1)]
        case .walkLeft:
            return [(4, 2), (4, 3), (4, 2), (4, 3)]
        case .walkUp:
            return [(1, 2), (1, 3), (1, 2), (1, 3)]
        case .walkDown:
            return [(6, 3), (7, 2), (6, 3), (7, 2)]
        case .walkUpLeft:
            return [(1, 0), (1, 1), (1, 0), (1, 1)]
        case .walkUpRight:
            return [(0, 2), (0, 3), (0, 2), (0, 3)]
        case .walkDownLeft:
            return [(5, 3), (6, 1), (5, 3), (6, 1)]
        case .walkDownRight:
            return [(5, 1), (5, 2), (5, 1), (5, 2)]
        case .eat:
            return [(5, 0), (6, 0), (7, 0), (6, 0)]
        case .scratchSelf:
            return [(5, 0), (6, 0), (7, 0), (6, 0)]
        case .scratchWallUp:
            return [(0, 0), (0, 1), (0, 0), (0, 1)]
        case .scratchWallDown:
            return [(7, 1), (6, 2), (7, 1), (6, 2)]
        case .scratchWallLeft:
            return [(4, 0), (4, 1), (4, 0), (4, 1)]
        case .scratchWallRight:
            return [(2, 2), (2, 3), (2, 2), (2, 3)]
        case .tired:
            return [(3, 2), (3, 2), (3, 2)]
        case .rest:
            return [(3, 2), (3, 2), (3, 3), (3, 2)]
        case .nap:
            return [(2, 0), (2, 1), (2, 0), (2, 1)]
        }
    }

    private static func codexPetSpriteFrames(for animation: NotchPetSpriteAnimation) -> [(column: Int, row: Int)] {
        switch animation {
        case .idle:
            return frames(row: 0, count: 6)
        case .alert:
            return frames(row: 6, count: 6)
        case .walkRight:
            return frames(row: 1, count: 8)
        case .walkLeft:
            return frames(row: 2, count: 8)
        case .walkUp, .walkDown:
            return frames(row: 7, count: 6)
        case .walkUpLeft, .walkDownLeft:
            return frames(row: 2, count: 8)
        case .walkUpRight, .walkDownRight:
            return frames(row: 1, count: 8)
        case .eat:
            return frames(row: 6, count: 6)
        case .scratchSelf, .scratchWallUp, .scratchWallDown, .scratchWallLeft, .scratchWallRight:
            return frames(row: 3, count: 4)
        case .tired:
            return frames(row: 5, count: 7)
        case .rest, .nap:
            return frames(row: 8, count: 6)
        }
    }

    private static func frames(row: Int, count: Int) -> [(column: Int, row: Int)] {
        (0..<count).map { (column: $0, row: row) }
    }

    private static func textureFromPetSheet(source: SpriteSource, column: Int, row: Int) -> SKTexture? {
        guard let sheet = sheetTexture(source: source) else { return nil }

        let columns = Self.sheetColumns(layout: source.layout)
        let rows = Self.sheetRows(layout: source.layout)
        let rect = CGRect(
            x: CGFloat(column) / CGFloat(columns),
            y: CGFloat(rows - row - 1) / CGFloat(rows),
            width: 1 / CGFloat(columns),
            height: 1 / CGFloat(rows)
        )
        let texture = SKTexture(rect: rect, in: sheet)
        texture.filteringMode = .nearest
        return texture
    }

    private static func sheetColumns(layout: NotchPetSheetLayout) -> Int {
        8
    }

    private static func sheetRows(layout: NotchPetSheetLayout) -> Int {
        layout == .codexPet ? 9 : 4
    }

    private static func frameAspectRatio(layout: NotchPetSheetLayout) -> CGFloat {
        layout == .codexPet ? 192.0 / 208.0 : 1
    }

    private static func sheetTexture(source: SpriteSource) -> SKTexture? {
        let cacheKey = source.assetName
        if let cached = sheetTextureCache[cacheKey] {
            return cached
        }

        guard let dataAsset = NSDataAsset(name: source.assetName) ?? NSDataAsset(name: "NotchPetOnekoSprite"),
              let image = NSImage(data: dataAsset.data) else {
            return nil
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        sheetTextureCache[cacheKey] = texture
        return texture
    }

    private static func spriteSource(
        kind: NotchPetKind,
        catStyle: NotchCatStyle,
        dogStyle: NotchDogStyle,
        moreStyle: NotchMorePetStyle
    ) -> SpriteSource {
        switch kind {
        case .dog:
            return SpriteSource(assetName: dogStyle.spriteAssetName, layout: .codexPet)
        case .more:
            return SpriteSource(assetName: moreStyle.spriteAssetName, layout: .codexPet)
        default:
            return SpriteSource(assetName: catStyle.spriteAssetName, layout: catStyle.sheetLayout)
        }
    }
}

private struct NotchPetPalette {
    let body: Color
    let accent: Color
    let dark: Color
    let eye: Color
    let blush: Color

    init(kind: NotchPetKind) {
        switch kind {
        case .cat:
            body = Color(red: 0.98, green: 0.96, blue: 0.90)
            accent = Color(red: 0.78, green: 0.50, blue: 0.26)
            dark = Color(red: 0.03, green: 0.03, blue: 0.025)
            eye = Color(red: 0.02, green: 0.02, blue: 0.018)
            blush = Color(red: 1.0, green: 0.63, blue: 0.74)
        case .dog:
            body = Color(red: 0.70, green: 0.48, blue: 0.30)
            accent = Color(red: 0.96, green: 0.75, blue: 0.48)
            dark = Color(red: 0.16, green: 0.09, blue: 0.06)
            eye = Color(red: 0.08, green: 0.07, blue: 0.06)
            blush = Color(red: 0.92, green: 0.42, blue: 0.42)
        case .more:
            body = Color(red: 0.58, green: 0.70, blue: 0.88)
            accent = Color(red: 0.45, green: 0.86, blue: 0.76)
            dark = Color(red: 0.09, green: 0.12, blue: 0.18)
            eye = Color(red: 0.03, green: 0.05, blue: 0.08)
            blush = Color(red: 0.86, green: 0.50, blue: 0.68)
        case .bird:
            body = Color(red: 0.25, green: 0.76, blue: 0.95)
            accent = Color(red: 1.0, green: 0.73, blue: 0.22)
            dark = Color(red: 0.10, green: 0.28, blue: 0.42)
            eye = Color(red: 0.04, green: 0.07, blue: 0.10)
            blush = Color(red: 0.96, green: 0.34, blue: 0.58)
        case .capybara:
            body = Color(red: 0.62, green: 0.43, blue: 0.29)
            accent = Color(red: 0.82, green: 0.61, blue: 0.39)
            dark = Color(red: 0.17, green: 0.10, blue: 0.06)
            eye = Color(red: 0.07, green: 0.05, blue: 0.04)
            blush = Color(red: 0.86, green: 0.43, blue: 0.34)
        case .owl:
            body = Color(red: 0.54, green: 0.38, blue: 0.72)
            accent = Color(red: 1.0, green: 0.78, blue: 0.28)
            dark = Color(red: 0.12, green: 0.08, blue: 0.21)
            eye = Color(red: 0.03, green: 0.03, blue: 0.05)
            blush = Color(red: 0.88, green: 0.40, blue: 0.70)
        }
    }
}
