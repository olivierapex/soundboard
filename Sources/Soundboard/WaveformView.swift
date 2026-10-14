import SwiftUI

/// Draws peaks and highlights the part between the two fractions (0...1).
struct WaveformView: View {
  let peaks: [Float]
  let startFraction: Double
  let endFraction: Double

  var body: some View {
    Canvas { context, size in
      guard !peaks.isEmpty else { return }
      let columnWidth = size.width / CGFloat(peaks.count)
      var inside = Path()
      var outside = Path()
      for (index, peak) in peaks.enumerated() {
        let x = (CGFloat(index) + 0.5) * columnWidth
        let half = max(1, CGFloat(peak) * size.height / 2)
        var line = Path()
        line.move(to: CGPoint(x: x, y: size.height / 2 - half))
        line.addLine(to: CGPoint(x: x, y: size.height / 2 + half))
        let fraction = Double(index) / Double(peaks.count)
        if fraction >= startFraction && fraction <= endFraction {
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
}
