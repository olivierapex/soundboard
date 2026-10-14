import CoreAudio
import Foundation

struct AudioDeviceError: LocalizedError {
  let operation: String
  let status: OSStatus

  var errorDescription: String? { "Core Audio could not \(operation) (error \(status))." }
}

enum AudioDevices {
  /// Returns the first audio device whose name is exactly `name`, or nil when there is none.
  static func deviceID(named name: String) throws -> AudioDeviceID? {
    try allDeviceIDs().first { try deviceName($0) == name }
  }

  /// Calls `onChange` on the main queue whenever one of the system properties changes.
  static func observe(
    _ selectors: [AudioObjectPropertySelector], onChange: @escaping @MainActor () -> Void
  ) {
    for selector in selectors {
      var address = propertyAddress(selector)
      AudioObjectAddPropertyListenerBlock(
        AudioObjectID(kAudioObjectSystemObject), &address, .main
      ) { _, _ in
        MainActor.assumeIsolated { onChange() }
      }
    }
  }

  private static func propertyAddress(_ selector: AudioObjectPropertySelector)
    -> AudioObjectPropertyAddress
  {
    AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
  }

  private static func allDeviceIDs() throws -> [AudioDeviceID] {
    var address = propertyAddress(kAudioHardwarePropertyDevices)
    let system = AudioObjectID(kAudioObjectSystemObject)
    var size: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size)
    guard status == noErr else { throw AudioDeviceError(operation: "list devices", status: status) }
    var identifiers = [AudioDeviceID](
      repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
    status = AudioObjectGetPropertyData(system, &address, 0, nil, &size, &identifiers)
    guard status == noErr else { throw AudioDeviceError(operation: "list devices", status: status) }
    return identifiers
  }

  private static func deviceName(_ identifier: AudioDeviceID) throws -> String? {
    var address = propertyAddress(kAudioObjectPropertyName)
    var name: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    let status = AudioObjectGetPropertyData(identifier, &address, 0, nil, &size, &name)
    guard status == noErr else {
      throw AudioDeviceError(operation: "read a device name", status: status)
    }
    return name?.takeRetainedValue() as String?
  }
}
