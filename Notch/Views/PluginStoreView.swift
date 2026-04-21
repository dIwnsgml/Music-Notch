import SwiftUI

struct PluginStoreView: View {
    @StateObject private var manager = PluginManager.shared
    @State private var selectedCategory: String = "All"
    @State private var selectedPlugin: WaveNotchPlugin? = nil
    
    var categories: [String] {
        ["All"] + PluginCategory.allCases.map { $0.rawValue }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Category Selector
            Picker("Category", selection: $selectedCategory) {
                ForEach(categories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    
                    let filtered = manager.availablePlugins.filter { 
                        selectedCategory == "All" || $0.category.rawValue == selectedCategory 
                    }
                    
                    ForEach(filtered) { plugin in
                        PluginCardView(plugin: plugin)
                            .onTapGesture {
                                selectedPlugin = plugin
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(item: $selectedPlugin) { plugin in
            PluginDetailView(plugin: plugin)
        }
    }
}

struct PluginCardView: View {
    let plugin: WaveNotchPlugin
    @AppStorage var isEnabled: Bool
    
    init(plugin: WaveNotchPlugin) {
        self.plugin = plugin
        self._isEnabled = AppStorage(wrappedValue: false, plugin.enabledKey)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(plugin.assetImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .cornerRadius(6)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(plugin.name)
                        .font(.system(size: 14, weight: .bold))
                    
                    Text(plugin.category.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)
                }
                
                Spacer()
            }
            
            Text(plugin.description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 30, alignment: .top)
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isEnabled ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        .contentShape(Rectangle())
    }
}

struct PluginDetailView: View {
    let plugin: WaveNotchPlugin
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(plugin.assetImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .cornerRadius(10)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(plugin.name)
                        .font(.system(size: 22, weight: .bold))
                    
                    Text(plugin.category.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)
                    
                    if plugin.isPremium {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill").foregroundColor(.yellow)
                            Text("Premium").font(.system(size: 11, weight: .bold)).foregroundColor(.yellow)
                        }
                        .padding(.top, 2)
                    }
                }
                
                Spacer()
                
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            
            // Description
            Text(plugin.description)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Footer Action
            HStack {
                Spacer()
                PluginActionButton(plugin: plugin)
            }
        }
        .padding(24)
        .frame(width: 400, height: 300)
    }
}

struct PluginActionButton: View {
    let plugin: WaveNotchPlugin
    
    @AppStorage var isInstalled: Bool
    @AppStorage var isEnabled: Bool
    @AppStorage("spotifyAccessToken") private var spotifyAccessToken: String = ""
    @State private var isDownloading = false
    
    init(plugin: WaveNotchPlugin) {
        self.plugin = plugin
        self._isInstalled = AppStorage(wrappedValue: false, plugin.installedKey)
        self._isEnabled = AppStorage(wrappedValue: false, plugin.enabledKey)
    }
    
    var body: some View {
        if isDownloading {
            ProgressView().controlSize(.small).frame(width: 70, height: 24)
        } else if !isInstalled {
            Button(action: {
                isDownloading = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isDownloading = false
                    withAnimation(.spring()) { isInstalled = true }
                }
            }) {
                Text("Install")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 24)
            }
            .buttonStyle(.plain)
            .background(Color.accentColor)
            .clipShape(Capsule())
        } else {
            HStack(spacing: 8) {
                if isEnabled {
                    Button(action: {
                        withAnimation(.spring()) { isEnabled = false }
                    }) {
                        Text("Disable")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(width: 60, height: 24)
                    }
                    .buttonStyle(.plain)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
                } else {
                    Button(action: {
                        if plugin.id == "spotify_plus" {
                            SpotifyAuthManager.shared.authenticate()
                        } else {
                            withAnimation(.spring()) { isEnabled = true }
                        }
                    }) {
                        Text("Enable")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 24)
                    }
                    .buttonStyle(.plain)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                    .onChange(of: spotifyAccessToken) { newValue in
                        if plugin.id == "spotify_plus" && !newValue.isEmpty {
                            withAnimation(.spring()) { isEnabled = true }
                        }
                    }
                }
                
                Button(action: {
                    withAnimation(.spring()) {
                        isEnabled = false
                        isInstalled = false
                    }
                }) {
                    Text("Uninstall")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(width: 70, height: 24)
                }
                .buttonStyle(.plain)
                .background(Color.red.opacity(0.15))
                .clipShape(Capsule())
            }
        }
    }
}