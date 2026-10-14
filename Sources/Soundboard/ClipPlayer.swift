import AVFoundation

struct Clip {
  let url: URL
  let start: TimeInterval
  let end: TimeInterval
}

enum AudioError: LocalizedError {
  case emptyClip
  case noMicrophone

  var errorDescription: String? {
    switch self {
    case .emptyClip: "The trimmed range of this sound is empty."
    case .noMicrophone: "No microphone input is available."
    }
  }
}

/// Plays one clip at a time on an engine, replacing the previous one.
@MainActor
final class ClipPlayer {
  private let engine: AVAudioEngine
  private var node: AVAudioPlayerNode?
  private var generation = 0

  init(engine: AVAudioEngine) {
    self.engine = engine
  }

  /// Starts the engine if needed. `onFinish` runs only when the clip ends without being replaced or stopped.
  func play(_ clip: Clip, onFinish: @escaping @MainActor () -> Void) throws {
    stop()
    let file = try AVAudioFile(forReading: clip.url)
    let sampleRate = file.processingFormat.sampleRate
    let startFrame = AVAudioFramePosition(clip.start * sampleRate)
    let endFrame = min(file.length, AVAudioFramePosition(clip.end * sampleRate))
    guard endFrame > startFrame else { throw AudioError.emptyClip }

    let node = AVAudioPlayerNode()
    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: file.processingFormat)
    if !engine.isRunning { try engine.start() }
    self.node = node
    generation += 1
    let currentGeneration = generation
    node.play()
    Task {
      await node.scheduleSegment(
        file,
        startingFrame: startFrame,
        frameCount: AVAudioFrameCount(endFrame - startFrame),
        at: nil,
        completionCallbackType: .dataPlayedBack
      )
      if generation == currentGeneration {
        stop()
        onFinish()
      }
    }
  }

  /// Stops the current clip and detaches its player node.
  func stop() {
    generation += 1
    guard let node else { return }
    node.stop()
    engine.detach(node)
    self.node = nil
  }
}
