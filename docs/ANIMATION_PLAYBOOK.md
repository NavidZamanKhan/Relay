# Relay motion: implementation guide

The reference is in three heavily commented files:
`relay_motion.dart`, `relay_message_list.dart`, and `message_composer.dart`.
This document explains how to carry the same behavior into the production app.

## One semantic transition, one coordinated animation

BLoC says that a message exists. `AnimatedList` supplies the progress for that
new row. `SizeTransition` opens exactly the space the row needs while a small
translation and scale settle the bubble into place. Both use one curve.

A translation by itself does not change layout: the new row occupies its full
height immediately and pushes history away before the bubble finishes moving.
That was a concrete defect in the earlier implementation. The height expansion
is essential, and necessarily incurs layout work for the inserting row. It is
not accurate to describe the entire insertion as compositor-only.

| Token | Duration | Use |
| --- | ---: | --- |
| `instant` | 100 ms | Control tint changes |
| `quick` | 170 ms | Icon changes and compact component transitions |
| `messageInsert` | 280 ms | Row expansion and bubble arrival |
| `standard` | 300 ms | Programmatic return to the latest messages |
| `expressive` | 420 ms | Onboarding transition |

The message curve is `Cubic(.22, .80, .24, 1)`.
During its progress t, bubble opacity is `.45 + .55*t`, scale is
`.97 + .03*t`, and travel is `16*(1-t)` logical pixels vertically plus
four logical pixels toward the sender's side. There is no overshoot on the row.
Most motion happens early and decelerates into a quiet finish.

These values are this prototype's design specification. They are not Apple's
or Telegram's proprietary timing values, and do not prove equivalent performance.

## Stable identities

Messages are chronological in BLoC. The timeline holds only a newest-first
visual cache. A state change is reconciled by ID:

1. Existing IDs keep their elements and select their updated message model.
2. New IDs call `insertItem(0)` once each.
3. Delivery changes update the receipt inside the same row.
4. Replacing or clearing history also replaces the AnimatedList key so its
   internal item count agrees with the new cache.

Do not put a self-starting entrance controller inside every message. Receipt,
typing, or playback updates would replay existing entrances. Never key a
message by its delivery state, timestamp label, or list index.

## Keyboard and scroll position

The list uses `reverse: true`. The latest edge is at offset zero. At the latest
messages, normal Scaffold keyboard resizing keeps that edge against the
composer without chasing a changing maximum scroll extent.

Do not add a second independent AnimatedPadding for the keyboard. It will lag
behind the platform inset and create a visible gap or a double movement.
Scrolling dismisses the keyboard through a drag-start notification.

When reading history, an incoming insertion remembers the prior scroll offset
and maximum extent. Post-layout metrics compensate for the newly added height.
An intentional user drag releases this temporary anchor immediately. Sending
an outgoing message while reading history returns to the latest edge.

For production pagination, extend reconciliation to prepend older pages and
preserve an identified visible row plus its intra-row offset. The prototype's
reconciliation is optimized for append, receipt refresh, and full clear; it is
not a general-purpose diff algorithm for arbitrary reordering/deletions.

## Recording: keep the gesture recognizer alive

The microphone GestureDetector stays in the same element slot while idle,
holding, and locked. Only its appearance changes. Replacing the entire
composer during `onLongPressStart` disposes the recognizer that must receive
`onLongPressMoveUpdate` and `onLongPressEnd`.

The pointer contract is:

- Long press starts a simulated recording after Flutter recognizes the hold.
- Horizontal travel of 110 logical pixels to the left cancels.
- Vertical travel of 72 logical pixels upwards locks.
- A latched lock/cancel decision fires once, with one haptic acknowledgement.
- Releasing a held, unlocked note sends once.
- Releasing a locked note leaves it recording.
- Tap the arrow to send, or the trash icon to discard a locked note.
- A tap on an idle microphone is an accessible hands-free shortcut.
- Navigating away or putting the app in the background cancels the recording.

Raw finger displacement goes through a local ValueNotifier directly to a
transform. The semantic events go to BLoC. Pointer samples never rebuild the
message timeline. The recorder waveform uses `CustomPainter(repaint: clock)`
inside a RepaintBoundary, so it repaints without rebuilding the composer.

When wiring `record`, let a recording repository own permission, capture,
interruption, temporary file cleanup, and codec selection. The BLoC event/state
contract can stay intact. Do not send the message until a valid file exists.

## Voice playback

The demo retains the selected note ID when paused and preserves its progress.
A stopwatch measures elapsed time; the simulation normalizes that elapsed time
by the selected note's duration and playback speed. UI progress events arrive
about every 80 ms; a linear tween fills the visual interval between events.
The scrubber clamps values to [0,1], and 1× / 1.5× / 2× controls change the rate.

Production progress must come from the audio player's actual position stream.
Do not infer played position by incrementing a UI timer. Cache the waveform's
sample envelope and repaint only progress, not its geometry, on playback ticks.

## Reduced motion and lifecycle

Message insertion, composer icon/size transitions, and waveform interpolation
use zero duration when reduced motion is enabled. The recording waveform stops
its repeating controller. Controllers and timers are disposed with their owner.
The prototype also cancels recording on lifecycle interruption.

Navigation uses CupertinoPageRoute on iOS and MaterialPageRoute on Android,
retaining the framework's native transition and back behavior. Native route
transitions have platform-owned durations; the `standard` token is not a claim
that the two native route implementations have identical timing.

## Performance validation on physical phones

Run `flutter run --profile`, warm the first conversation, then inspect DevTools
while sending consecutive short and long messages, opening the keyboard,
scrolling during incoming messages, scrubbing audio, and locking a recording.

At 60 Hz aim below approximately 16.7 ms per UI/raster pipeline stage; at 120 Hz
approximately 8.3 ms. Look for slow frames, repeated image decoding, unnecessary
parent rebuilds, and work running on the UI isolate. The automated render
captures do not measure those physical-device frame budgets.

Official references:
- https://docs.flutter.dev/perf/best-practices
- https://docs.flutter.dev/perf/ui-performance
- https://api.flutter.dev/flutter/widgets/AnimatedList-class.html
