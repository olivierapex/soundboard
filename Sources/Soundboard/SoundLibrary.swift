import AVFoundation

/// The sounds on disk: files in `Sounds/` and their metadata in `library.json`.
@MainActor
@Observable
final class SoundLibrary {
  private(set) var sounds: [Sound] = []
  private(set) var errorMessage: String?

  @ObservationIgnored private let directory: URL
  @ObservationIgnored private var soundsDirectory: URL {
    directory.appending(path: "Sounds", directoryHint: .isDirectory)
  }
  @ObservationIgnored private var libraryURL: URL { directory.appending(path: "library.json") }

  init() {
    directory = URL.applicationSupportDirectory.appending(
      path: "Soundboard", directoryHint: .isDirectory)
    load()
  }

  /// Returns the sound with that ID.
  func sound(withID id: Sound.ID) -> Sound? {
    sounds.first { $0.id == id }
  }

  /// Returns the file URL of a sound in the library.
  func url(for sound: Sound) -> URL {
    soundsDirectory.appending(path: sound.fileName)
  }

  /// Copies each readable audio file into the library and returns the new sounds.
  @discardableResult
  func importSounds(from urls: [URL]) -> [Sound] {
    var imported: [Sound] = []
    errorMessage = nil
    for url in urls {
      do {
        imported.append(try importSound(from: url))
      } catch {
        report("Could not import \(url.lastPathComponent): \(error.localizedDescription)")
      }
    }
    guard !imported.isEmpty else { return [] }
    sounds.append(contentsOf: imported)
    save()
    return imported
  }

  /// Renames a sound; blank names are ignored.
  func rename(_ id: Sound.ID, to name: String) {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { return }
    update(id) { $0.name = trimmedName }
    save()
  }

  /// Removes the sound and its file.
  func delete(_ id: Sound.ID) {
    guard let sound = sound(withID: id) else { return }
    do {
      try FileManager.default.removeItem(at: url(for: sound))
    } catch {
      report("Could not remove \(sound.fileName): \(error.localizedDescription)")
    }
    sounds.removeAll { $0.id == id }
    save()
  }

  /// Sets or clears a sound's shortcut.
  func setShortcut(_ shortcut: Shortcut?, for id: Sound.ID) {
    update(id) { $0.shortcut = shortcut }
    save()
  }

  /// Updates the trim in memory only; call `save()` once editing ends.
  func setTrim(_ id: Sound.ID, start: TimeInterval, end: TimeInterval) {
    update(id) {
      $0.trimStart = start
      $0.trimEnd = end
    }
  }

  /// Writes `library.json`, creating the directory if needed.
  func save() {
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      try encoder.encode(sounds).write(to: libraryURL, options: .atomic)
    } catch {
      report("Could not save the library: \(error.localizedDescription)")
    }
  }

  /// Adds a line to the error message.
  private func report(_ message: String) {
    errorMessage = [errorMessage, message].compactMap { $0 }.joined(separator: "\n")
  }

  /// Applies a change to one sound.
  private func update(_ id: Sound.ID, _ change: (inout Sound) -> Void) {
    guard let index = sounds.firstIndex(where: { $0.id == id }) else { return }
    change(&sounds[index])
  }

  /// Copies one file into the library.
  private func importSound(from url: URL) throws -> Sound {
    let file = try AVAudioFile(forReading: url)
    let id = UUID()
    let fileName = "\(id.uuidString).\(url.pathExtension)"
    try FileManager.default.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: url, to: soundsDirectory.appending(path: fileName))
    let duration = Double(file.length) / file.processingFormat.sampleRate
    return Sound(
      id: id,
      name: url.deletingPathExtension().lastPathComponent,
      fileName: fileName,
      duration: duration,
      trimStart: 0,
      trimEnd: duration,
      shortcut: nil
    )
  }

  /// Reads `library.json`, moving an unreadable file to a backup first.
  private func load() {
    guard FileManager.default.fileExists(atPath: libraryURL.path) else { return }
    do {
      sounds = try JSONDecoder().decode([Sound].self, from: Data(contentsOf: libraryURL))
    } catch {
      let backupURL = libraryURL.appendingPathExtension("bak")
      do {
        try? FileManager.default.removeItem(at: backupURL)
        try FileManager.default.moveItem(at: libraryURL, to: backupURL)
        report(
          "Could not read the library (\(error.localizedDescription)). It was moved to \(backupURL.path)."
        )
      } catch {
        report("Could not read or back up the library: \(error.localizedDescription)")
      }
    }
  }
}
