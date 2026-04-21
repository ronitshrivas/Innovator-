import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReelsPlayer {
  static const _channel = MethodChannel('reels_player');

  static Future<void> prepare(int slot, String url, String token) async {
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

  static Future<void> play(int slot) async {
    try {
      await _channel.invokeMethod('play', {'slot': slot});
    } catch (e) {
      debugPrint('[ReelsPlayer] play error: $e');
    }
  }

  static Future<void> pause(int slot) async {
    try {
      await _channel.invokeMethod('pause', {'slot': slot});
    } catch (e) {
      debugPrint('[ReelsPlayer] pause error: $e');
    }
  }

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

  static Future<void> release(int slot) async {
    try {
      await _channel.invokeMethod('release', {'slot': slot});
    } catch (e) {
      debugPrint('[ReelsPlayer] release error: $e');
    }
  }

  static Future<void> releaseAll() async {
    try {
      await _channel.invokeMethod('releaseAll');
    } catch (e) {
      debugPrint('[ReelsPlayer] releaseAll error: $e');
    }
  }
}

class ReelsSurfaceWidget extends StatelessWidget {
  final int slot;
  const ReelsSurfaceWidget({Key? key, required this.slot}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AndroidView(
      viewType: 'reels_surface_view',
      layoutDirection: TextDirection.ltr,
      creationParams: {'slot': slot},
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
