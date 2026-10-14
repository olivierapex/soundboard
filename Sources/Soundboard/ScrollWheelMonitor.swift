import AppKit
import SwiftUI

/// Reports horizontal scrolling over the view as a fraction of its width; vertical scrolling passes through.
struct ScrollWheelMonitor: NSViewRepresentable {
  let onScroll: (Double) -> Void

  func makeNSView(context: Context) -> MonitorView { MonitorView() }

  func updateNSView(_ view: MonitorView, context: Context) { view.onScroll = onScroll }

  final class MonitorView: NSView {
    var onScroll: ((Double) -> Void)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if let monitor { NSEvent.removeMonitor(monitor) }
      monitor = nil
      guard window != nil else { return }
      monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
        let window = event.window
        let location = event.locationInWindow
        let delta = CGVector(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY)
        let isHandled = MainActor.assumeIsolated {
          self?.handle(window: window, location: location, delta: delta) ?? false
        }
        return isHandled ? nil : event
      }
    }

    /// Returns whether the scroll is horizontal and over this view, and so was consumed.
    private func handle(window eventWindow: NSWindow?, location: CGPoint, delta: CGVector) -> Bool {
      guard eventWindow === window, bounds.width > 0,
        bounds.contains(convert(location, from: nil)), abs(delta.dx) > abs(delta.dy)
      else { return false }
      onScroll?(Double(delta.dx / bounds.width))
      return true
    }
  }
}
