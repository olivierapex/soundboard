import os

/// Single-producer, single-consumer buffer of mono samples that absorbs clock drift
/// between the microphone and the output device by dropping or zero-filling.
final class RingBuffer: Sendable {
  private struct State {
    var samples: [Float]
    var readPosition = 0
    var writePosition = 0
    var isPrimed = false
  }

  private let state: OSAllocatedUnfairLock<State>
  private let capacity: Int
  private let primeFrames: Int
  private let maximumFrames: Int
  private let targetFrames: Int

  init(sampleRate: Double) {
    capacity = Int(sampleRate)
    primeFrames = Int(sampleRate * 0.04)
    targetFrames = Int(sampleRate * 0.06)
    maximumFrames = Int(sampleRate * 0.15)
    state = OSAllocatedUnfairLock(
      initialState: State(samples: [Float](repeating: 0, count: capacity)))
  }

  /// Appends the first channel of an audio buffer whose frames are `stride` samples apart.
  func write(samples: UnsafePointer<Float>, stride: Int, frameCount: Int) {
    let capacity = capacity
    state.withLockUnchecked { state in
      for frame in 0..<frameCount {
        state.samples[(state.writePosition + frame) % capacity] = samples[frame * stride]
      }
      state.writePosition += frameCount
      if state.writePosition - state.readPosition > capacity {
        state.readPosition = state.writePosition - capacity
      }
    }
  }

  /// Fills `destination`, with silence while the buffer is refilling or the lock is busy.
  func read(into destination: UnsafeMutablePointer<Float>, frameCount: Int) {
    let capacity = capacity
    let primeFrames = primeFrames
    let targetFrames = targetFrames
    let maximumFrames = maximumFrames
    let didRead: Void? = state.withLockIfAvailableUnchecked { state in
      var available = state.writePosition - state.readPosition
      if available > maximumFrames {
        state.readPosition = state.writePosition - targetFrames
        available = targetFrames
      }
      if !state.isPrimed {
        guard available >= primeFrames else {
          destination.update(repeating: 0, count: frameCount)
          return
        }
        state.isPrimed = true
      }
      let framesToCopy = min(available, frameCount)
      for frame in 0..<framesToCopy {
        destination[frame] = state.samples[(state.readPosition + frame) % capacity]
      }
      state.readPosition += framesToCopy
      if framesToCopy < frameCount {
        (destination + framesToCopy).update(repeating: 0, count: frameCount - framesToCopy)
        state.isPrimed = false
      }
    }
    if didRead == nil {
      destination.update(repeating: 0, count: frameCount)
    }
  }
}
