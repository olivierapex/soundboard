import SwiftUI

struct SoundDetailView: View {
  @Environment(AppModel.self) private var model
  let sound: Sound

  @State private var peaks: [Float] = []
  @State private var name = ""
  @State private var isConfirmingDeletion = false
  @State private var peaksError: String?
  @FocusState private var isNameFocused: Bool

  private let minimumTrimLength = 0.01

  var body: some View {
    Form {
      TextField("Name", text: $name)
        .focused($isNameFocused)
        .onSubmit(commitName)
        .onChange(of: isNameFocused) { if !isNameFocused { commitName() } }

      WaveformView(
        peaks: peaks,
        startFraction: sound.trimStart / sound.duration,
        endFraction: sound.trimEnd / sound.duration
      )
      .frame(height: 120)
      if let peaksError {
        Text(peaksError).foregroundStyle(.red).font(.caption)
      }

      LabeledContent("Start") {
        Slider(
          value: startBinding, in: 0...max(0, sound.trimEnd - minimumTrimLength),
          onEditingChanged: saveWhenDone)
        Text(sound.trimStart, format: .number.precision(.fractionLength(2))).monospacedDigit()
      }
      LabeledContent("End") {
        Slider(
          value: endBinding,
          in: min(sound.duration, sound.trimStart + minimumTrimLength)...sound.duration,
          onEditingChanged: saveWhenDone)
        Text(sound.trimEnd, format: .number.precision(.fractionLength(2))).monospacedDigit()
      }

      LabeledContent("Shortcut") {
        VStack(alignment: .leading) {
          ShortcutRecorder(shortcut: sound.shortcut) { model.setShortcut($0, for: sound.id) }
          if model.hotKeys.duplicateSoundIDs.contains(sound.id) {
            Text("Another sound in this app already uses this shortcut.")
              .foregroundStyle(.red).font(.caption)
          } else if model.hotKeys.conflictingSoundIDs.contains(sound.id) {
            Text("Another app already uses this shortcut.").foregroundStyle(.red).font(.caption)
          }
        }
      }

      HStack {
        Button("Play", systemImage: "play.fill") { model.play(sound.id) }
        Button("Preview", systemImage: "headphones") { model.preview(sound.id) }
        Spacer()
        Button("Delete", systemImage: "trash", role: .destructive) { isConfirmingDeletion = true }
      }
    }
    .formStyle(.grouped)
    .task(id: sound.id) {
      name = sound.name
      peaks = []
      let url = model.library.url(for: sound)
      peaksError = nil
      let soundID = sound.id
      do {
        let computed = try await Task.detached {
          try WaveformPeaks.compute(url: url, bucketCount: 600)
        }.value
        if !Task.isCancelled && soundID == sound.id { peaks = computed }
      } catch {
        if !Task.isCancelled {
          peaksError = "Could not draw the waveform: \(error.localizedDescription)"
        }
      }
    }
    .onDisappear(perform: commitName)
    .confirmationDialog("Delete \(sound.name)?", isPresented: $isConfirmingDeletion) {
      Button("Delete", role: .destructive) { model.delete(sound.id) }
    }
  }

  private var startBinding: Binding<Double> {
    Binding(
      get: { sound.trimStart },
      set: { model.library.setTrim(sound.id, start: $0, end: sound.trimEnd) }
    )
  }

  private var endBinding: Binding<Double> {
    Binding(
      get: { sound.trimEnd },
      set: { model.library.setTrim(sound.id, start: sound.trimStart, end: $0) }
    )
  }

  /// Saves the name if it changed.
  private func commitName() {
    if name != sound.name { model.library.rename(sound.id, to: name) }
  }

  /// Persists the trim once the slider is released.
  private func saveWhenDone(isEditing: Bool) {
    if !isEditing { model.library.save() }
  }
}
