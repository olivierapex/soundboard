import SwiftUI

/// Draggable trim bars, shading outside the range, and the playhead, laid over a waveform.
struct TrimOverlay: View {
  let duration: TimeInterval
  @Binding var trimStart: TimeInterval
  @Binding var trimEnd: TimeInterval
  let isPlaying: Bool
  let playheadTime: () -> TimeInterval?
  let onTrimEnd: () -> Void

  private static let minimumLength = 0.01
  private static let hitWidth: CGFloat = 14
  private static let coordinateSpaceName = "trim-overlay"

  var body: some View {
    GeometryReader { proxy in
      let width = proxy.size.width
      let height = proxy.size.height
      ZStack {
        shade(from: 0, to: trimStart, width: width)
        shade(from: trimEnd, to: duration, width: width)

        bar(at: trimStart, width: width, height: height, labelOnTrailingSide: true)
          .gesture(drag(width: width) { trimStart = min(max($0, 0), trimEnd - Self.minimumLength) })
        bar(at: trimEnd, width: width, height: height, labelOnTrailingSide: false)
          .gesture(
            drag(width: width) { trimEnd = min(max($0, trimStart + Self.minimumLength), duration) })

        if isPlaying {
          TimelineView(.animation) { _ in
            if let time = playheadTime() {
              bar(
                at: time, width: width, height: height, color: .primary,
                labelOnTrailingSide: time < duration * 0.85, labelAtBottom: true)
            }
          }
          .allowsHitTesting(false)
        }
      }
      .coordinateSpace(.named(Self.coordinateSpaceName))
    }
  }

  private func position(of time: TimeInterval, width: CGFloat) -> CGFloat {
    duration > 0 ? CGFloat(time / duration) * width : 0
  }

  private func shade(from start: TimeInterval, to end: TimeInterval, width: CGFloat) -> some View {
    let startX = position(of: start, width: width)
    return Rectangle()
      .fill(.black.opacity(0.35))
      .frame(width: max(0, position(of: end, width: width) - startX))
      .frame(maxWidth: .infinity, alignment: .leading)
      .offset(x: startX)
      .allowsHitTesting(false)
  }

  private func bar(
    at time: TimeInterval, width: CGFloat, height: CGFloat, color: Color = .accentColor,
    labelOnTrailingSide: Bool, labelAtBottom: Bool = false
  ) -> some View {
    let verticalAlignment: VerticalAlignment = labelAtBottom ? .bottom : .top
    let alignment = Alignment(
      horizontal: labelOnTrailingSide ? .leading : .trailing, vertical: verticalAlignment)
    return Rectangle()
      .fill(color)
      .frame(width: 2)
      .overlay(alignment: alignment) {
        Text("\(time, format: .number.precision(.fractionLength(2))) s")
          .font(.caption.monospacedDigit())
          .fixedSize()
          .offset(x: labelOnTrailingSide ? 6 : -6)
      }
      .frame(width: Self.hitWidth, height: height)
      .contentShape(Rectangle())
      .position(x: position(of: time, width: width), y: height / 2)
  }

  /// Reports the time under the pointer while dragging and saves when the drag ends.
  private func drag(width: CGFloat, update: @escaping (TimeInterval) -> Void) -> some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpaceName))
      .onChanged { value in
        guard width > 0 else { return }
        update(Double(value.location.x / width) * duration)
      }
      .onEnded { _ in onTrimEnd() }
  }
}
