import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ════════════════════════════════════════════════════════════════════════════
// ReelsPlayer — Dart wrapper around the native MethodChannel
//
// SLOT CONVENTION (always 3 slots):
//   slot 0 → previous reel  (kept alive for instant back-swipe)
//   slot 1 → current reel   (playing)
//   slot 2 → next reel      (pre-buffering silently in background)
//
// USAGE FLOW:
//   1. Feed loads  → prepare(1, currentUrl)  + prepare(2, nextUrl)
//   2. User swipes → play(1) [instant, already buffered]
//                  → prepare(2, newNextUrl)  [background buffer starts]
//   3. Leave screen → releaseAll()
// ════════════════════════════════════════════════════════════════════════════

class ReelsPlayer {
  static const _channel = MethodChannel('reels_player');

  /// Prepare a slot: load the URL and start buffering.
  /// Safe to call in advance — this is the key to zero-delay playback.
  static Future<void> prepare(int slot, String url, String token) async {
    assert(slot >= 0 && slot <= 2, 'slot must be 0, 1, or 2');
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

  /// Play a slot. Near-instant if prepare() was called first.
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

  /// Set volume for a slot. 0.0 = mute, 1.0 = full volume.
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

  /// Seek to a position in milliseconds.
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

  /// Release one slot (frees memory).
  static Future<void> release(int slot) async {
    try {
      await _channel.invokeMethod('release', {'slot': slot});
    } catch (e) {
      debugPrint('[ReelsPlayer] release error: $e');
    }
  }

  /// Release ALL slots. Call this when leaving the reels screen.
  static Future<void> releaseAll() async {
    try {
      await _channel.invokeMethod('releaseAll');
    } catch (e) {
      debugPrint('[ReelsPlayer] releaseAll error: $e');
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ReelsSurfaceWidget — embeds the native SurfaceView for one slot
// ════════════════════════════════════════════════════════════════════════════

class ReelsSurfaceWidget extends StatelessWidget {
  final int slot;

  const ReelsSurfaceWidget({Key? key, required this.slot}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // AndroidView embeds the native SurfaceView registered as "reels_surface_view"
    return AndroidView(
      viewType: 'reels_surface_view',
      layoutDirection: TextDirection.ltr,
      creationParams: {'slot': slot},
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
