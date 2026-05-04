import AppKit
import UniformTypeIdentifiers

final class FileDragDetector {
    typealias RegionProvider = () -> CGRect?
    typealias DragCallback = () -> Void

    var onDragEntersRegion: DragCallback?
    var onDragExitsRegion: DragCallback?
    var onDragEnds: DragCallback?

    private let regionProvider: RegionProvider
    private let dragPasteboard = NSPasteboard(name: .drag)

    private var mouseDownMonitor: Any?
    private var mouseDraggedMonitor: Any?
    private var mouseUpMonitor: Any?

    private var pasteboardChangeCount = -1
    private var isMouseDragging = false
    private var isContentDragging = false
    private var isInsideRegion = false

    init(regionProvider: @escaping RegionProvider) {
        self.regionProvider = regionProvider
    }

    func startMonitoring() {
        stopMonitoring()

        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            guard let self else { return }
            self.pasteboardChangeCount = self.dragPasteboard.changeCount
            self.isMouseDragging = true
            self.isContentDragging = false
            self.isInsideRegion = false
        }

        mouseDraggedMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            guard let self, self.isMouseDragging else { return }

            if self.dragPasteboard.changeCount != self.pasteboardChangeCount,
               !self.isContentDragging,
               self.hasSupportedDragContent() {
                self.isContentDragging = true
            }

            guard self.isContentDragging, let region = self.regionProvider() else { return }

            let containsMouse = region.contains(NSEvent.mouseLocation)
            if containsMouse && !self.isInsideRegion {
                self.isInsideRegion = true
                self.onDragEntersRegion?()
            } else if !containsMouse && self.isInsideRegion {
                self.isInsideRegion = false
                self.onDragExitsRegion?()
            }
        }

        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            self?.resetDragState(notify: true)
        }
    }

    func stopMonitoring() {
        [mouseDownMonitor, mouseDraggedMonitor, mouseUpMonitor].forEach { monitor in
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        mouseDownMonitor = nil
        mouseDraggedMonitor = nil
        mouseUpMonitor = nil
        resetDragState(notify: false)
    }

    private func resetDragState(notify: Bool) {
        let wasInsideRegion = isInsideRegion
        pasteboardChangeCount = -1
        isMouseDragging = false
        isContentDragging = false
        isInsideRegion = false

        if notify {
            if wasInsideRegion {
                onDragExitsRegion?()
            }
            onDragEnds?()
        }
    }

    private func hasSupportedDragContent() -> Bool {
        guard let types = dragPasteboard.types else { return false }

        let supportedTypes: [NSPasteboard.PasteboardType] = [
            .fileURL,
            .string,
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
            NSPasteboard.PasteboardType(UTType.fileURL.identifier),
            NSPasteboard.PasteboardType(UTType.url.identifier),
            NSPasteboard.PasteboardType(UTType.item.identifier),
            NSPasteboard.PasteboardType(UTType.data.identifier)
        ]

        return types.contains { type in
            supportedTypes.contains(type)
        }
    }

    deinit {
        stopMonitoring()
    }
}
