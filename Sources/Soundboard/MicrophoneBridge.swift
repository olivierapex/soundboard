import AVFoundation
import CoreAudio

/// Passes an input device (the default microphone) to an output device (BlackHole) where clips are mixed in.
@MainActor
final class MicrophoneBridge {
  private let microphoneEngine = AVAudioEngine()
  private let outputEngine = AVAudioEngine()
  private var sourceNode: AVAudioSourceNode?
  private var sinkNode: AVAudioSinkNode?
  private var observers: [NSObjectProtocol] = []

  let clipPlayer: ClipPlayer
  private(set) var isRunning = false
  var onConfigurationChange: (@MainActor () -> Void)?

  init() {
    clipPlayer = ClipPlayer(engine: outputEngine)
    observers = [microphoneEngine, outputEngine].map { engine in
      NotificationCenter.default.addObserver(
        forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.onConfigurationChange?() }
      }
    }
  }

  /// Starts both engines; the input device feeds the output device through the ring buffer.
  /// A nil device means the system default.
  func start(inputDevice: AudioDeviceID? = nil, outputDevice: AudioDeviceID? = nil) throws {
    stop()
    if let inputDevice { try microphoneEngine.inputNode.auAudioUnit.setDeviceID(inputDevice) }
    let inputNode = microphoneEngine.inputNode
    let microphoneFormat = inputNode.outputFormat(forBus: 0)
    guard microphoneFormat.sampleRate > 0, microphoneFormat.channelCount > 0 else {
      throw AudioError.noMicrophone
    }

    let ringBuffer = RingBuffer(sampleRate: microphoneFormat.sampleRate)
    let sinkNode = Self.sinkNode(writingTo: ringBuffer)
    microphoneEngine.attach(sinkNode)
    microphoneEngine.connect(inputNode, to: sinkNode, format: microphoneFormat)
    self.sinkNode = sinkNode

    if let outputDevice { try outputEngine.outputNode.auAudioUnit.setDeviceID(outputDevice) }
    let sourceNode = Self.sourceNode(
      readingFrom: ringBuffer,
      format: AVAudioFormat(standardFormatWithSampleRate: microphoneFormat.sampleRate, channels: 1)!
    )
    outputEngine.attach(sourceNode)
    outputEngine.connect(
      sourceNode, to: outputEngine.mainMixerNode, format: sourceNode.outputFormat(forBus: 0))
    self.sourceNode = sourceNode

    do {
      try outputEngine.start()
      try microphoneEngine.start()
    } catch {
      stop()
      throw error
    }
    isRunning = true
  }

  /// Stops both engines and removes the nodes.
  func stop() {
    clipPlayer.stop()
    microphoneEngine.stop()
    outputEngine.stop()
    if let sinkNode {
      microphoneEngine.detach(sinkNode)
      self.sinkNode = nil
    }
    if let sourceNode {
      outputEngine.detach(sourceNode)
      self.sourceNode = nil
    }
    isRunning = false
  }

  private nonisolated static func sinkNode(writingTo ringBuffer: RingBuffer) -> AVAudioSinkNode {
    AVAudioSinkNode { _, frameCount, audioBufferList in
      let buffers = UnsafeMutableAudioBufferListPointer(
        UnsafeMutablePointer(mutating: audioBufferList))
      guard let buffer = buffers.first, let data = buffer.mData?.assumingMemoryBound(to: Float.self)
      else { return noErr }
      ringBuffer.write(
        samples: data, stride: max(1, Int(buffer.mNumberChannels)), frameCount: Int(frameCount))
      return noErr
    }
  }

  private nonisolated static func sourceNode(
    readingFrom ringBuffer: RingBuffer, format: AVAudioFormat
  ) -> AVAudioSourceNode {
    AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
      let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
      guard let destination = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else {
        return noErr
      }
      ringBuffer.read(into: destination, frameCount: Int(frameCount))
      return noErr
    }
  }
}
