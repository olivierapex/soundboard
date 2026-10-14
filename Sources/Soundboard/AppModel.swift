import Foundation

/// Wires the library, the audio routing and the global shortcuts together.
@MainActor
@Observable
final class AppModel {
  let library = SoundLibrary()
  let router = AudioRouter()
  let hotKeys = HotKeyCenter()
  var selectedSoundID: Sound.ID?

  init() {
    hotKeys.onPress = { [weak self] id in self?.play(id) }
    hotKeys.register(library.sounds)
  }

  /// Requests microphone access and starts the passthrough.
  func start() async {
    await router.start()
  }

  /// Imports audio files and selects the last one.
  func importSounds(from urls: [URL]) {
    let imported = library.importSounds(from: urls)
    if let last = imported.last { selectedSoundID = last.id }
  }

  /// Plays the sound on the default output and BlackHole.
  func play(_ id: Sound.ID) {
    guard let sound = library.sound(withID: id) else { return }
    router.play(clip(for: sound))
  }

  /// Plays the trimmed range on the default output only.
  func preview(_ id: Sound.ID) {
    guard let sound = library.sound(withID: id) else { return }
    router.preview(clip(for: sound))
  }

  /// Plays the trimmed range on BlackHole only and plays back what BlackHole receives.
  func test(_ id: Sound.ID) {
    guard let sound = library.sound(withID: id) else { return }
    router.test(clip(for: sound))
  }

  /// Stops whatever is playing.
  func stop() {
    router.stop()
  }

  /// Deletes the sound and frees its shortcut.
  func delete(_ id: Sound.ID) {
    router.stop()
    library.delete(id)
    hotKeys.register(library.sounds)
  }

  /// Sets or clears the shortcut and re-registers all shortcuts.
  func setShortcut(_ shortcut: Shortcut?, for id: Sound.ID) {
    library.setShortcut(shortcut, for: id)
    hotKeys.register(library.sounds)
  }

  /// Frees all shortcuts so the recorder can see the key combination.
  func beginShortcutRecording() {
    hotKeys.unregisterAll()
  }

  /// Registers the shortcuts again.
  func endShortcutRecording() {
    hotKeys.register(library.sounds)
  }

  /// Builds the trimmed clip of a sound.
  private func clip(for sound: Sound) -> Clip {
    Clip(
      soundID: sound.id, url: library.url(for: sound), start: sound.trimStart, end: sound.trimEnd)
  }
}
