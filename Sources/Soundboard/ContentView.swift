import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @Environment(AppModel.self) private var model
  @State private var isImporting = false

  var body: some View {
    @Bindable var model = model
    NavigationSplitView {
      List(model.library.sounds, selection: $model.selectedSoundID) { sound in
        SoundRow(sound: sound)
      }
      .navigationSplitViewColumnWidth(min: 220, ideal: 260)
      .overlay {
        if model.library.sounds.isEmpty {
          ContentUnavailableView(
            "No sounds",
            systemImage: "waveform",
            description: Text("Drop audio files here or press +.")
          )
        }
      }
    } detail: {
      if let id = model.selectedSoundID, let sound = model.library.sound(withID: id) {
        SoundDetailView(sound: sound).id(sound.id)
      } else {
        ContentUnavailableView("Select a sound", systemImage: "speaker.wave.2")
      }
    }
    .safeAreaInset(edge: .top, spacing: 0) { StatusBanner() }
    .toolbar {
      ToolbarItemGroup {
        Button("Stop", systemImage: "stop.fill") { model.stop() }
        Button("Add sounds", systemImage: "plus") { isImporting = true }
      }
    }
    .fileImporter(
      isPresented: $isImporting, allowedContentTypes: [.audio], allowsMultipleSelection: true
    ) { result in
      if case .success(let urls) = result { model.importSounds(from: urls) }
    }
    .dropDestination(for: URL.self) { urls, _ in
      model.importSounds(from: urls)
      return true
    }
  }
}

private struct SoundRow: View {
  @Environment(AppModel.self) private var model
  let sound: Sound

  var body: some View {
    HStack {
      Button("Play", systemImage: "play.fill") { model.play(sound.id) }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
      Text(sound.name).lineLimit(1)
      Spacer()
      if let shortcut = sound.shortcut {
        Text(shortcut.displayName).foregroundStyle(.secondary).font(.caption)
      }
    }
    .contextMenu {
      Button("Delete", role: .destructive) { model.delete(sound.id) }
    }
  }
}
