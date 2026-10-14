import AppKit
import SwiftUI

/// Records the next key combination pressed while active; Escape alone cancels.
struct ShortcutRecorder: View {
  @Environment(AppModel.self) private var model
  let shortcut: Shortcut?
  let onChange: (Shortcut?) -> Void

  @State private var monitor: Any?
  @State private var hint: String?

  var body: some View {
    HStack {
      Text(monitor == nil ? (shortcut?.displayName ?? "None") : (hint ?? "Press the keys…"))
        .frame(minWidth: 100, alignment: .leading)
      if monitor == nil {
        Button("Record shortcut", action: beginRecording)
        Button("Clear") { onChange(nil) }.disabled(shortcut == nil)
      } else {
        Button("Cancel", action: endRecording)
      }
    }
    .onDisappear(perform: endRecording)
    .onChange(of: model.selectedSoundID) { endRecording() }
  }

  /// Frees the global shortcuts and listens for the next key press.
  private func beginRecording() {
    model.beginShortcutRecording()
    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      MainActor.assumeIsolated {
        handle(event)
      }
      return nil
    }
  }

  /// Accepts, rejects or cancels on a recorded key press.
  private func handle(_ event: NSEvent) {
    guard let recorded = Shortcut(event: event) else { return }
    if recorded.keyCode == 53 && recorded.modifiers == 0 {
      endRecording()
    } else if recorded.isAllowed {
      onChange(recorded)
      endRecording()
    } else {
      hint = "Add a modifier key"
    }
  }

  /// Stops listening and registers the shortcuts again.
  private func endRecording() {
    guard let monitor else { return }
    NSEvent.removeMonitor(monitor)
    self.monitor = nil
    hint = nil
    model.endShortcutRecording()
  }
}
