import SwiftUI

#if os(macOS)
import AppKit

struct TrackpadPanReader: NSViewRepresentable {
    let isEnabled: Bool
    let pan: (CGSize) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> PassthroughView {
        let view = PassthroughView()
        context.coordinator.install(on: view, isEnabled: isEnabled, pan: pan)
        return view
    }

    func updateNSView(_ nsView: PassthroughView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.pan = pan
    }

    static func dismantleNSView(_ nsView: PassthroughView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        var isEnabled = false
        var pan: (CGSize) -> Void = { _ in }
        private weak var view: PassthroughView?
        private var monitor: Any?

        func install(on view: PassthroughView, isEnabled: Bool, pan: @escaping (CGSize) -> Void) {
            self.view = view
            self.isEnabled = isEnabled
            self.pan = pan
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, self.isEnabled, event.hasPreciseScrollingDeltas,
                      let view = self.view, event.window === view.window else { return event }
                let location = view.convert(event.locationInWindow, from: nil)
                guard view.bounds.contains(location) else { return event }
                self.pan(CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY))
                return nil
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }
    }
}

final class PassthroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
#else
struct TrackpadPanReader: View {
    let isEnabled: Bool
    let pan: (CGSize) -> Void

    var body: some View {
        EmptyView()
    }
}
#endif
