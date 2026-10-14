import SwiftUI

/// Draws the visible part of the peaks and highlights the part between the two fractions (0...1 of the whole sound).
struct WaveformView: View {
  let peaks: [Float]
  let viewport: WaveformViewport
  let startFraction: Double
  let endFraction: Double

  private static let columnWidth: CGFloat = 1.5

  var body: some View {
    Canvas { context, size in
      guard !peaks.isEmpty else { return }
      let columnCount = max(1, Int(size.width / Self.columnWidth))
      let columnWidth = size.width / CGFloat(columnCount)
      var inside = Path()
      var outside = Path()
      for column in 0..<columnCount {
        let columnStart =
          viewport.start + viewport.visibleFraction * Double(column) / Double(columnCount)
        let columnEnd = columnStart + viewport.visibleFraction / Double(columnCount)
        let peak = peak(from: columnStart, to: columnEnd)
        let x = (CGFloat(column) + 0.5) * columnWidth
        let half = max(1, CGFloat(peak) * size.height / 2)
        var line = Path()
        line.move(to: CGPoint(x: x, y: size.height / 2 - half))
        line.addLine(to: CGPoint(x: x, y: size.height / 2 + half))
        if columnStart >= startFraction && columnStart <= endFraction {
          inside.addPath(line)
        } else {
          outside.addPath(line)
        }
      }
      let lineWidth = max(1, columnWidth * 0.8)
      context.stroke(outside, with: .color(.secondary.opacity(0.4)), lineWidth: lineWidth)
      context.stroke(inside, with: .color(.accentColor), lineWidth: lineWidth)
    }
    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
  }

  /// The largest peak between two fractions of the sound.
  private func peak(from start: Double, to end: Double) -> Float {
    let first = min(Int(start * Double(peaks.count)), peaks.count - 1)
    let last = min(max(Int((end * Double(peaks.count)).rounded(.up)), first + 1), peaks.count)
    return peaks[first..<last].max() ?? 0
  }
}
