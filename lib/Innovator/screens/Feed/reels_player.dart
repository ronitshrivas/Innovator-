import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ════════════════════════════════════════════════════════════════════════════
// ReelsPlayer — Dart wrapper around the native MethodChannel
//
// SLOT CONVENTION (3 ExoPlayer instances, 1 shared surface):
//   slot 0 → previous reel  (pre-buffered, no surface)
//   slot 1 → current reel   (playing, has the display surface)
//   slot 2 → next reel      (pre-buffered, no surface)
//
// SURFACE SWITCHING FLOW:
//   1. Feed loads     → prepare(0, url0) + prepare(1, url1)
//                     → switchSurface(0)   ← surface → slot 0
//                     → play(0)
//   2. User swipes    → pause(oldSlot)
//                     → switchSurface(newSlot)   ← moves surface instantly
//                     → play(newSlot)
//                     → prepare(nextSlot, nextUrl)
//   3. Leave screen   → releaseAll()
// ════════════════════════════════════════════════════════════════════════════

class ReelsPlayer {
  static const _channel = MethodChannel('reels_player');

  /// Prepare a slot: load URL and start buffering (no surface needed).
  static Future<void> prepare(int slot, String url, String token) async {
    assert(slot >= 0 && slot <= 2);
    try {
      await _channel.invokeMethod('prepare', {
        'slot': slot,
        'url': url,
        'token': token,
      });
    } catch (e) {
      debugPrint('[ReelsPlayer] prepare error: $e');
    }
  }

  /// Switch the shared display surface to a given slot.
  /// Call this BEFORE play() when changing reels.
  static Future<void> switchSurface(int slot) async {
    assert(slot >= 0 && slot <= 2);
    try {
      await _channel.invokeMethod('switchSurface', {'slot': slot});
    } catch (e) {
      debugPrint('[ReelsPlayer] switchSurface error: $e');
    }
  }

  /// Play a slot (must have called switchSurface first for the video to appear).
  static Future<void> play(int slot) async {
    try {
      await _channel.invokeMethod('play', {'slot': slot});
    } catch (e) {
      debugPrint('[ReelsPlayer] play error: $e');
    }
  }

  /// Pause a slot.
  static Future<void> pause(int slot) async {
    try {
      await _channel.invokeMethod('pause', {'slot': slot});
    } catch (e) {
      debugPrint('[ReelsPlayer] pause error: $e');
    }
  }

  /// Set volume (0.0 = mute, 1.0 = full).
  static Future<void> setVolume(int slot, double volume) async {
    try {
      await _channel.invokeMethod('setVolume', {
        'slot': slot,
        'volume': volume,
      });
    } catch (e) {
      debugPrint('[ReelsPlayer] setVolume error: $e');
    }
  }

  /// Seek to positionMs.
  static Future<void> seekTo(int slot, int positionMs) async {
    try {
      await _channel.invokeMethod('seekTo', {
        'slot': slot,
        'positionMs': positionMs,
      });
    } catch (e) {
      debugPrint('[ReelsPlayer] seekTo error: $e');
    }
  }

  /// Release one slot.
  static Future<void> release(int slot) async {
    try {
      await _channel.invokeMethod('release', {'slot': slot});
    } catch (e) {
      debugPrint('[ReelsPlayer] release error: $e');
    }
  }

  /// Release ALL slots. Call when leaving the reels screen.
  static Future<void> releaseAll() async {
    try {
      await _channel.invokeMethod('releaseAll');
    } catch (e) {
      debugPrint('[ReelsPlayer] releaseAll error: $e');
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ReelsSurfaceWidget — THE single shared display surface.
//
// Only ONE of these should ever exist in the widget tree.
// It is always mounted (never removed), so the SurfaceView surface is
// never destroyed. ExoPlayers share this surface via switchSurface().
// ════════════════════════════════════════════════════════════════════════════

class ReelsSurfaceWidget extends StatelessWidget {
  const ReelsSurfaceWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AndroidView(
      viewType: 'reels_surface_view',
      layoutDirection: TextDirection.ltr,
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
