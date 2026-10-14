import AppKit
import SwiftUI

final class ApplicationDelegate: NSObject, NSApplicationDelegate {
  /// Quits when the window closes.
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}

@main
struct SoundboardApp: App {
  @NSApplicationDelegateAdaptor private var delegate: ApplicationDelegate
  @State private var model = AppModel()

  var body: some Scene {
    Window("Soundboard", id: "main") {
      ContentView()
        .environment(model)
        .task { await model.start() }
    }
    .defaultSize(width: 760, height: 480)
  }
}
