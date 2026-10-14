import AVFoundation
import CoreAudio

enum MicrophoneAccess {
  case pending
  case granted
  case denied
}

/// Decides where sounds are heard: the default output always, BlackHole when it is installed.
@MainActor
@Observable
final class AudioRouter {
  static let blackHoleName = "BlackHole 2ch"

  private(set) var isBlackHoleAvailable = false
  private(set) var microphoneAccess = MicrophoneAccess.pending
  private(set) var errorMessage: String?

  @ObservationIgnored private let bridge = MicrophoneBridge()
  @ObservationIgnored private let monitorEngine = AVAudioEngine()
  @ObservationIgnored private let monitorPlayer: ClipPlayer
  @ObservationIgnored private var blackHoleID: AudioDeviceID?

  init() {
    monitorPlayer = ClipPlayer(engine: monitorEngine)
    bridge.onConfigurationChange = { [weak self] in self?.restartBridge() }
    AudioDevices.observe([kAudioHardwarePropertyDevices]) { [weak self] in
      self?.deviceListDidChange()
    }
    AudioDevices.observe([
      kAudioHardwarePropertyDefaultInputDevice, kAudioHardwarePropertyDefaultOutputDevice,
    ]) { [weak self] in self?.restartBridge() }
    deviceListDidChange(force: true)
  }

  /// The sound currently playing on the default output.
  var playingSoundID: Sound.ID? { monitorPlayer.currentClip?.soundID }

  /// Seconds from the file start at the playback position on the default output.
  var playheadTime: TimeInterval? { monitorPlayer.playheadTime }

  /// Asks for microphone access, then starts the passthrough if BlackHole is present.
  func start() async {
    let granted = await AVCaptureDevice.requestAccess(for: .audio)
    microphoneAccess = granted ? .granted : .denied
    restartBridge()
  }

  /// Plays on BlackHole when it is running, then on the default output; each fails on its own.
  func play(_ clip: Clip) {
    stop()
    errorMessage = nil
    if bridge.isRunning {
      play(on: bridge.clipPlayer, clip: clip) {}
    }
    play(on: monitorPlayer, clip: clip) { [monitorEngine] in monitorEngine.stop() }
  }

  /// Plays on the default output only.
  func preview(_ clip: Clip) {
    stop()
    errorMessage = nil
    play(on: monitorPlayer, clip: clip) { [monitorEngine] in monitorEngine.stop() }
  }

  /// Stops the clip on every output.
  func stop() {
    monitorPlayer.stop()
    monitorEngine.stop()
    bridge.clipPlayer.stop()
  }

  /// Plays on one player and reports a failure without affecting the others.
  private func play(on player: ClipPlayer, clip: Clip, onFinish: @escaping @MainActor () -> Void) {
    do {
      try player.play(clip, onFinish: onFinish)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Re-detects BlackHole and restarts the passthrough when it changed or is not running.
  private func deviceListDidChange(force: Bool = false) {
    let currentID: AudioDeviceID?
    do {
      currentID = try AudioDevices.deviceID(named: Self.blackHoleName)
    } catch {
      errorMessage = error.localizedDescription
      return
    }
    guard force || currentID != blackHoleID || !bridge.isRunning else { return }
    blackHoleID = currentID
    isBlackHoleAvailable = currentID != nil
    restartBridge()
  }

  /// Restarts the passthrough, which also retries after a failure.
  private func restartBridge() {
    bridge.stop()
    guard let blackHoleID, microphoneAccess == .granted else { return }
    do {
      try bridge.start(outputDevice: blackHoleID)
      errorMessage = nil
    } catch {
      errorMessage = "Microphone passthrough failed: \(error.localizedDescription)"
    }
  }
}
