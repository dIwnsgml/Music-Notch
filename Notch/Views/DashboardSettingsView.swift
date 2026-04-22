import SwiftUI
import UniformTypeIdentifiers

struct DashboardSettingsView: View {
    @StateObject private var dashboardManager = DashboardManager.shared
    @State private var draggedItem: NotchWidgetType?
    
    // Layout that mimics the notch
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Dashboard Layout")
                    .font(.system(size: 22, weight: .bold))
                
                Text("Drag modules to rearrange. Use the (x) to temporarily hide a module from the dashboard.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            // The "Notch" Preview Container
            VStack(spacing: 0) {
                Text("Expanded Notch Preview")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.black)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    let columns = dashboardManager.activeLayout.count > 1 ? [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ] : [
                        GridItem(.flexible())
                    ]
                    
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(dashboardManager.activeLayout) { widget in
                                WidgetPreviewItem(widget: widget) {
                                    withAnimation {
                                        dashboardManager.activeLayout.removeAll { $0 == widget }
                                    }
                                }
                                .onDrag {
                                    self.draggedItem = widget
                                    return NSItemProvider(object: widget.rawValue as NSString)
                                }
                                .onDrop(of: [.text], delegate: WidgetDropDelegate(item: widget, items: $dashboardManager.activeLayout, draggedItem: $draggedItem))
                            }
                        }
                        .padding(16)
                    }
                }
                .frame(height: 240)
                .frame(maxWidth: 600)
            }
            
            // Add Back Section
            if dashboardManager.activeLayout.count < NotchWidgetType.allCases.count {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Modules")
                        .font(.system(size: 14, weight: .bold))
                    
                    HStack(spacing: 12) {
                        ForEach(NotchWidgetType.allCases) { type in
                            if !dashboardManager.activeLayout.contains(type) {
                                Button(action: {
                                    withAnimation {
                                        dashboardManager.activeLayout.append(type)
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus.circle.fill")
                                        Text(type.displayName)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.accentColor.opacity(0.15))
                                    .foregroundColor(.accentColor)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct WidgetPreviewItem: View {
    let widget: NotchWidgetType
    let onRemove: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                Image(systemName: iconFor(widget))
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                
                Text(widget.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            
            if isHovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white))
                }
                .buttonStyle(.plain)
                .padding(4)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onHover { isHovering = $0 }
    }
    
    func iconFor(_ type: NotchWidgetType) -> String {
        switch type {
        case .nowPlaying: return "play.circle.fill"
        case .playlist: return "music.note.list"
        case .calendar: return "calendar.circle.fill"
        case .weather: return "cloud.sun.fill"
        }
    }
}

struct WidgetDropDelegate: DropDelegate {
    let item: NotchWidgetType
    @Binding var items: [NotchWidgetType]
    @Binding var draggedItem: NotchWidgetType?

    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem else { return }
        
        if draggedItem != item {
            let from = items.firstIndex(of: draggedItem)!
            let to = items.firstIndex(of: item)!
            withAnimation(.default) {
                self.items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        self.draggedItem = nil
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
