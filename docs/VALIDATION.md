# Validation record

Validated on 2026-09-05 with Flutter 3.47.2 and Dart 3.13.2.

## Completed

- `flutter analyze --no-pub`: **no issues found**.
- `flutter test --no-pub --dart-define=RELAY_CAPTURE=true`: **10 tests passed**.
- Flutter engine render captures at 390×844 and 320×720 logical pixels.
- Visual review of inbox, light/dark conversation, settings, onboarding, OTP,
  profile setup, contact/group creation, and recording states.
- Native iOS and Android runner generation, with Relay launcher icons.

The ten test cases cover:

1. Inbox, conversation navigation, themes, and settings rendering.
2. Rapid sends, unique message IDs, simulated receipts, separate histories.
3. A long press surviving the recording UI, with one send on release.
4. Slide-to-cancel, slide-to-lock, and release behavior while locked.
5. Clearing a timeline then inserting new messages.
6. Onboarding/country selection at a small phone width.
7. Keyboard-inset resizing keeping the composer in the available viewport.
8. Inbox search/filters and creating/opening a local group.
9. Playback pause, seek, and speed state retention.
10. Capturing a sequence of coordinated message and recording animations.

The last test is opt-in with `RELAY_CAPTURE=true`. Normal `flutter test` runs
nine tests and skips this capture-only test.

## Scope of the evidence

The preview screens are actual Flutter test-engine renders, not native OS
screenshots. The OS status bar and software keyboard are not rendered by the
harness. The motion MP4 contains 255 sampled frames encoded at 30 fps. It
illustrates choreography and does not measure physical-device performance.

No iOS IPA or Android APK was built here, and no physical-device 60/120 Hz
profile was performed. The included runner projects are ready for your local
Flutter toolchain. Use `flutter run --profile` on a connected phone to assess
frame timing, keyboard behavior, native navigation, and haptics.

Real microphone capture/playback, server transport, SMS authentication,
media upload, persistent settings, and backups are deliberately outside this
UI prototype. Those behaviors cannot be inferred from passing these tests.
