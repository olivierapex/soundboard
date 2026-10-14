import SwiftUI

/// The part of a sound shown in the waveform: a zoom factor and the left edge as a fraction of the duration.
struct WaveformViewport: Equatable {
  static let maximumZoom = 64.0

  private(set) var zoom = 1.0
  var start = 0.0 {
    didSet { start = min(max(start, 0), maximumStart) }
  }

  var visibleFraction: Double { 1 / zoom }
  var maximumStart: Double { 1 - visibleFraction }
  var isZoomed: Bool { zoom > 1 }

  /// Returns the viewport zoomed by `factor`, keeping the point at `anchor` (0...1 across the view) in place.
  func zoomed(by factor: Double, anchor: Double = 0.5) -> WaveformViewport {
    var result = self
    result.zoom = min(max(zoom * factor, 1), Self.maximumZoom)
    result.start = start + anchor * (visibleFraction - result.visibleFraction)
    return result
  }

  /// Moves the view by a number of view widths.
  mutating func scroll(by viewWidths: Double) {
    start += viewWidths * visibleFraction
  }
}

/// Zoom buttons, a reset, and a scroll bar while zoomed in.
struct WaveformZoomControls: View {
  @Binding var viewport: WaveformViewport

  var body: some View {
    HStack {
      Button("Zoom out", systemImage: "minus.magnifyingglass") {
        viewport = viewport.zoomed(by: 0.5)
      }
      .disabled(!viewport.isZoomed)
      .labelStyle(.iconOnly)
      Button("Zoom in", systemImage: "plus.magnifyingglass") {
        viewport = viewport.zoomed(by: 2)
      }
      .disabled(viewport.zoom >= WaveformViewport.maximumZoom)
      .labelStyle(.iconOnly)
      Button("Fit") { viewport = WaveformViewport() }
        .disabled(!viewport.isZoomed)
      Text("\(viewport.zoom, format: .number.precision(.fractionLength(1))) ×")
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
      if viewport.isZoomed {
        Slider(value: $viewport.start, in: 0...viewport.maximumStart) { Text("Scroll") }
          .labelsHidden()
      } else {
        Spacer()
      }
    }
  }
}
