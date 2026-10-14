# Soundboard

A native macOS soundboard (like Soundpad). Import sounds, trim them, play them with a click or a global keyboard shortcut, and send them to your microphone so other people in a game or a call hear them with your voice.

The app has no menu bar item, no login item and no background process. Closing the window quits it.

## Requirements

- macOS 14 or later.
- Swift toolchain with the Command Line Tools (Xcode is not needed).
- [BlackHole 2ch](https://github.com/ExistentialAudio/BlackHole) to send sounds to a microphone input. Without it the app still plays and previews sounds locally and shows a banner.

## Install BlackHole

```bash
brew install --cask blackhole-2ch
```

The installer asks for the admin password. A reboot may be needed, or `sudo killall coreaudiod` to reload the audio service.

## Build and run

```bash
scripts/build-app.sh
open build/Soundboard.app
```

The script builds in release mode, assembles `build/Soundboard.app` from `Support/Info.plist` and signs it ad hoc. It uses the Command Line Tools compiler with the macOS 26 SDK (see Troubleshooting). Extra arguments are passed to `swift build`.

## Usage

1. Add sounds with the + button or by dropping audio files on the window. Files are copied to `~/Library/Application Support/Soundboard/Sounds/`, the library is `~/Library/Application Support/Soundboard/library.json`.
2. Select a sound to rename it, trim it (drag the start and end bars on the waveform; a playhead follows playback), preview the trimmed range on your own output, record a shortcut or delete it.
3. Play with the play button, the Play button of the detail view, or the shortcut. A new sound replaces the one playing. Stop ends it.
4. In the game or Discord, select **BlackHole 2ch** as the microphone. Players hear your microphone and the sounds. You hear the sounds on the default output.

When the app is closed, the BlackHole microphone is silent: switch back to your real microphone.

Never set BlackHole as the system default input: the app would read its own output and create a feedback loop. Select it only inside the game or Discord.

Shortcuts are global (Carbon hot keys, no Accessibility permission) and can be single keys such as F-keys. Outside F-keys and numpad keys, a shortcut needs a modifier key. Escape alone cancels the recording. A shortcut needs a key combination that no other app has registered.

## Architecture

- Microphone engine: input node into a sink node, first channel only, read on the render thread by a sink node, into a lock-protected ring buffer (the render thread never waits for the lock).
- Output engine: output device set to BlackHole 2ch, a source node reading the ring buffer, and a player node for clips, both into the main mixer (which converts sample rates).
- Monitor engine: default output, started only while a sound plays.
- The ring buffer drops old samples when it grows too long and plays silence while it refills, which absorbs clock drift between the devices.
- BlackHole is found by name through Core Audio, and a property listener re-detects it when devices change. Changes of the default input or output restart the passthrough. No timers and no polling.

## Troubleshooting

### BlackHole 0.7.1 package signature verification failure

The installer of BlackHole 0.7.1 can fail its signature verification. See [ExistentialAudio/BlackHole#903](https://github.com/ExistentialAudio/BlackHole/issues/903) for the status and workarounds.

### Reset the microphone permission

```bash
tccutil reset Microphone io.github.olivierapex.soundboard
```

Then start the app again to get the prompt. Rebuilding changes the ad-hoc signature, so macOS may ask again.

### A shortcut does not fire

Another app registered the same key combination first, and macOS gives it to that app only. The detail view shows "Another app already uses this shortcut." (or "Another sound in this app..." for a duplicate inside Soundboard). Record a different combination.

### Build fails with `could not build module '_DarwinFoundation1'`

The Swift 6.1 toolchain from swiftly cannot read the macOS 27 SDK of the Command Line Tools. Use the Command Line Tools compiler (`/usr/bin/swift`, Swift 6.4). `scripts/build-app.sh` does this.

### Build fails with `external macro implementation type 'SwiftUIMacros.StateMacro' could not be found`

In the macOS 27 SDK, SwiftUI property wrappers such as `@State` are macros whose plugin ships only with Xcode. `scripts/build-app.sh` builds against the macOS 26 SDK (`SDKROOT`, override it if needed). The app still targets macOS 14.

### `ld: warning: search path ... CommandLineTools/Developer/... not found`

Harmless linker warnings caused by the Command Line Tools layout.

### `accessing build database ... disk I/O error`

Google Drive for desktop syncs `~/data` and hard-links files that it uploads (`~/data/.tmp.driveupload`). SQLite, which stores the build database, fails when its files are hard-linked during a build, so `swift build` reports this error and exits with code 1 even though it prints `Build complete!`. `scripts/build-app.sh` therefore builds in `~/Library/Caches/Soundboard/build`, outside the synced folder. Remove a stale `.build` folder left by earlier runs.
