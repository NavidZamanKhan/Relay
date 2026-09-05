import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// RELAY MOTION: HOW TO REUSE THIS IN THE PRODUCTION APP
///
/// BLoC owns the destination (a message exists, recording is locked). Flutter
/// controllers own the journey between those states. Never emit 120 animation
/// values per second through the chat BLoC: doing so couples the timeline to a
/// control's paint loop and makes unrelated widgets rebuild.
///
/// An entrance has two jobs. SizeTransition makes ROOM for the new row; a small
/// transform settles the bubble into that room. A transform by itself cannot
/// move its siblings, so a plain fade/slide produces a full-height jump first.
/// See RelayMessageList for the stable-ID insertion and reverse scroll anchor.
///
/// This is a native-inspired specification, not Apple's or Telegram's private
/// animation code. Measure the final result on physical hardware in profile
/// mode. At 60 Hz each UI/raster pipeline stage should stay below ~16.7 ms;
/// at 120 Hz aim below ~8.3 ms. Avoid shader warm-up and image decode on send.
abstract final class RelayMotion {
  static const instant = Duration(milliseconds: 100);
  static const quick = Duration(milliseconds: 170);
  static const messageInsert = Duration(milliseconds: 280);
  static const standard = Duration(milliseconds: 300);
  static const expressive = Duration(milliseconds: 420);
  static const enter = Cubic(.16, .84, .30, 1);
  static const messageEnter = Cubic(.22, .80, .24, 1);
  static const exit = Cubic(.4, 0, .8, .35);
  static const spring = Cubic(.20, 1.04, .30, 1);

  /// Native route implementations retain interactive back gestures and their
  /// interruption behavior. A custom PageRouteBuilder with a short fade looks
  /// simple but loses the platform's edge-swipe transition coordinator.
  static PageRoute<T> route<T>(Widget page) =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? CupertinoPageRoute<T>(builder: (_) => page)
      : MaterialPageRoute<T>(builder: (_) => page);

  static Duration duration(BuildContext context, Duration normal) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : normal;

  /// One animation, one clock: row growth and bubble travel use the SAME curve.
  /// Initial history receives AlwaysStoppedAnimation(1) from AnimatedList and
  /// appears immediately. Delivery receipts update inside stable keyed rows.
  static Widget messageInsertion({
    required Animation<double> animation,
    required Widget child,
    required bool isMine,
  }) {
    // CurveTween has no listener lifecycle of its own. It is safe to create
    // while building, unlike allocating unmanaged AnimationControllers here.
    final progress = animation.drive(CurveTween(curve: messageEnter));
    return SizeTransition(
      sizeFactor: progress,
      alignment: Alignment.bottomCenter,
      child: AnimatedBuilder(
        animation: progress,
        child: child,
        builder: (_, stableChild) {
          final t = progress.value;
          return Opacity(
            opacity: (.45 + .55 * t).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset((isMine ? 4 : -4) * (1 - t), 16 * (1 - t)),
              child: Transform.scale(
                scale: .97 + .03 * t,
                alignment: isMine
                    ? Alignment.bottomRight
                    : Alignment.bottomLeft,
                child: stableChild,
              ),
            ),
          );
        },
      ),
    );
  }
}
