import SwiftUI

struct StatusBanner: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    VStack(spacing: 0) {
      if !model.router.isBlackHoleAvailable {
        banner(
          "\(AudioRouter.blackHoleName) is not installed, so sounds only play locally. Install it with:",
          command: "brew install --cask blackhole-2ch"
        )
      }
      if model.router.microphoneAccess == .denied {
        banner(
          "Microphone access is denied. Allow it in System Settings > Privacy & Security > Microphone."
        )
      }
      ForEach(
        [model.router.errorMessage, model.library.errorMessage, model.hotKeys.errorMessage]
          .compactMap { $0 }, id: \.self
      ) { banner($0) }
    }
  }

  /// Shows one warning line, with an optional command.
  private func banner(_ message: String, command: String? = nil) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Label(message, systemImage: "exclamationmark.triangle.fill")
      if let command {
        Text(command).font(.system(.body, design: .monospaced)).textSelection(.enabled)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(8)
    .background(.yellow.opacity(0.25))
  }
}
