import Foundation

struct Sound: Identifiable, Codable, Hashable, Sendable {
  let id: UUID
  var name: String
  let fileName: String
  let duration: TimeInterval
  var trimStart: TimeInterval
  var trimEnd: TimeInterval
  var shortcut: Shortcut?
}
