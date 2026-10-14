import Carbon.HIToolbox

/// Registers global shortcuts with Carbon, which needs no Accessibility permission.
@MainActor
@Observable
final class HotKeyCenter {
  private(set) var duplicateSoundIDs: Set<Sound.ID> = []
  private(set) var conflictingSoundIDs: Set<Sound.ID> = []
  private(set) var errorMessage: String?

  @ObservationIgnored var onPress: ((Sound.ID) -> Void)?
  @ObservationIgnored private var registrations:
    [UInt32: (reference: EventHotKeyRef, soundID: Sound.ID)] = [:]

  private static let signature: OSType = 0x5342_5244

  init() {
    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )
    let status = InstallEventHandler(
      GetApplicationEventTarget(),
      hotKeyHandler,
      1,
      &eventType,
      Unmanaged.passUnretained(self).toOpaque(),
      nil
    )
    if status != noErr {
      errorMessage = "Global shortcuts are unavailable (error \(status))."
    }
  }

  /// Replaces all registrations with the shortcuts of `sounds`.
  func register(_ sounds: [Sound]) {
    unregisterAll()
    var claimedShortcuts: Set<Shortcut> = []
    for (index, sound) in sounds.enumerated() {
      guard let shortcut = sound.shortcut else { continue }
      guard claimedShortcuts.insert(shortcut).inserted else {
        duplicateSoundIDs.insert(sound.id)
        continue
      }
      let identifier = UInt32(index + 1)
      var reference: EventHotKeyRef?
      let status = RegisterEventHotKey(
        shortcut.keyCode,
        shortcut.modifiers,
        EventHotKeyID(signature: Self.signature, id: identifier),
        GetApplicationEventTarget(),
        0,
        &reference
      )
      if status == noErr, let reference {
        registrations[identifier] = (reference, sound.id)
      } else {
        conflictingSoundIDs.insert(sound.id)
      }
    }
  }

  /// Unregisters every shortcut and clears the failure state.
  func unregisterAll() {
    for registration in registrations.values {
      UnregisterEventHotKey(registration.reference)
    }
    registrations.removeAll()
    duplicateSoundIDs.removeAll()
    conflictingSoundIDs.removeAll()
  }

  /// Forwards a shortcut press to `onPress`.
  fileprivate func handlePress(identifier: UInt32) {
    guard let soundID = registrations[identifier]?.soundID else { return }
    onPress?(soundID)
  }
}

private func hotKeyHandler(
  _ nextHandler: EventHandlerCallRef?,
  _ event: EventRef?,
  _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
  guard let event, let userData else { return OSStatus(eventNotHandledErr) }
  var identifier = EventHotKeyID()
  let status = GetEventParameter(
    event,
    EventParamName(kEventParamDirectObject),
    EventParamType(typeEventHotKeyID),
    nil,
    MemoryLayout<EventHotKeyID>.size,
    nil,
    &identifier
  )
  guard status == noErr else { return status }
  let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
  MainActor.assumeIsolated { center.handlePress(identifier: identifier.id) }
  return noErr
}
