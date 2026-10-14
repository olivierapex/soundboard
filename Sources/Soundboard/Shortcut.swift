import AppKit
import Carbon.HIToolbox

struct Shortcut: Codable, Hashable, Sendable {
  let keyCode: UInt32
  /// Carbon modifier mask, as expected by `RegisterEventHotKey`.
  let modifiers: UInt32
  let keyLabel: String

  var displayName: String {
    var symbols = ""
    if modifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
    if modifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
    if modifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
    if modifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
    return symbols + keyLabel
  }

  /// Plain F-keys and numpad keys are the only keys allowed without a modifier.
  var isAllowed: Bool {
    modifiers != 0 || Self.unmodifiedKeyCodes.contains(UInt16(keyCode))
  }

  /// Creates a shortcut from a key-down event, or returns nil for other events.
  init?(event: NSEvent) {
    guard event.type == .keyDown else { return nil }
    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    var carbonModifiers = 0
    if flags.contains(.control) { carbonModifiers |= controlKey }
    if flags.contains(.option) { carbonModifiers |= optionKey }
    if flags.contains(.shift) { carbonModifiers |= shiftKey }
    if flags.contains(.command) { carbonModifiers |= cmdKey }
    keyCode = UInt32(event.keyCode)
    modifiers = UInt32(carbonModifiers)
    keyLabel =
      Self.specialKeyLabels[event.keyCode]
      ?? event.charactersIgnoringModifiers?.uppercased()
      ?? "Key \(event.keyCode)"
  }

  private static let unmodifiedKeyCodes: Set<UInt16> = [
    122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90,
    65, 67, 69, 75, 78, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92,
  ]

  private static let specialKeyLabels: [UInt16: String] = [
    122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7",
    100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13",
    107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20",
    36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 117: "⌦",
    115: "Home", 119: "End", 116: "Page Up", 121: "Page Down",
    123: "←", 124: "→", 125: "↓", 126: "↑",
  ]
}
