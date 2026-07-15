@preconcurrency import AppKit
import SwiftUI

struct EndEditingOnOutsideClickModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(EndEditingOnOutsideClickView())
    }
}

private struct EndEditingOnOutsideClickView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        context.coordinator.installMonitor()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.installMonitor()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private var monitor: Any?

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func installMonitor() {
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
                nonisolated(unsafe) let unsafeEvent = event
                MainActor.assumeIsolated {
                    Self.endEditingIfNeeded(for: unsafeEvent)
                }
                return event
            }
        }

        @MainActor
        private static func endEditingIfNeeded(for event: NSEvent) {
            guard let window = event.window,
                  let firstResponder = window.firstResponder,
                  firstResponder is NSTextView
            else { return }

            let clickedView = window.contentView?.hitTest(event.locationInWindow)
            guard clickedView?.isTextInputViewOrDescendant == false else { return }

            _ = window.makeFirstResponder(nil)
        }
    }
}

@MainActor
private extension NSView {
    var isTextInputViewOrDescendant: Bool {
        if self is NSTextField || self is NSTextView {
            return true
        }

        return superview?.isTextInputViewOrDescendant ?? false
    }
}

extension View {
    func endEditingOnOutsideClick() -> some View {
        modifier(EndEditingOnOutsideClickModifier())
    }
}
