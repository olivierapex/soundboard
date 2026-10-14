import AVFoundation

enum WaveformPeaks {
  /// Returns `bucketCount` peak amplitudes between 0 and 1 for the whole file.
  static func compute(url: URL, bucketCount: Int) throws -> [Float] {
    let file = try AVAudioFile(forReading: url)
    let totalFrames = Int(file.length)
    guard totalFrames > 0,
      let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 65_536)
    else { return [] }

    var peaks = [Float](repeating: 0, count: bucketCount)
    var framePosition = 0
    while framePosition < totalFrames {
      try file.read(into: buffer)
      guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { break }
      for frame in 0..<Int(buffer.frameLength) {
        var amplitude: Float = 0
        for channel in 0..<Int(buffer.format.channelCount) {
          amplitude = max(amplitude, abs(channels[channel][frame]))
        }
        let bucket = min((framePosition + frame) * bucketCount / totalFrames, bucketCount - 1)
        peaks[bucket] = max(peaks[bucket], amplitude)
      }
      framePosition += Int(buffer.frameLength)
    }
    return peaks
  }
}
