import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:innovator/Innovator/screens/Likes/Content-Like-Service.dart';
import 'dart:developer' as developer;

const String _kReactionBoxName = 'pending_reactions';

class HiveReactionQueue {
  HiveReactionQueue._();
  static final HiveReactionQueue instance = HiveReactionQueue._();

  late Box<Map> _box;
  bool _initialized = false;
  ContentLikeService? _likeService;
  StreamSubscription? _connectivitySub;
  bool _flushing = false;

  Future<void> init({ContentLikeService? service}) async {
    if (_initialized) {
      if (service != null) _likeService = service;
      return;
    }

    _box = await Hive.openBox<Map>(_kReactionBoxName);
    _initialized = true;

    if (service != null) _likeService = service;

    developer.log(
      '[HiveReactionQueue] Ready — ${_box.length} reactions loaded from disk',
    );

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any(
        (r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet,
      );
      if (isOnline && _box.isNotEmpty) {
        developer.log('[HiveReactionQueue] Network restored — flushing...');
        flush();
      }
    });

    if (_box.isNotEmpty) {
      developer.log(
        '[HiveReactionQueue] ${_box.length} leftover reactions from last session',
      );
    }
  }

  void setService(ContentLikeService service) {
    _likeService = service;
    if (_initialized && _box.isNotEmpty && !_flushing) {
      flush();
    }
  }

  Future<void> enqueue({
    required String contentId,
    required ReactionType? type,
    required bool isReel,
  }) async {
    final data = {
      'type': type?.name ?? '',
      'isReel': isReel,
      'queuedAt': DateTime.now().toIso8601String(),
    };

    await _box.put(contentId, data);

    developer.log(
      '[HiveReactionQueue] Saved to disk → $contentId : ${type?.name ?? "remove"}',
    );
  }

  Future<void> dequeue(String contentId) async {
    await _box.delete(contentId);
    developer.log('[HiveReactionQueue] Deleted from disk → $contentId');
  }

  bool hasPending(String contentId) =>
      _initialized && _box.containsKey(contentId);

  int get pendingCount => _initialized ? _box.length : 0;

  Future<void> flush() async {
    if (_flushing || _likeService == null || !_initialized) return;
    if (_box.isEmpty) return;

    _flushing = true;
    developer.log('[HiveReactionQueue] Flushing ${_box.length} reactions...');

    final keys = _box.keys.toList();

    for (final key in keys) {
      final raw = _box.get(key);
      if (raw == null) continue;

      final contentId = key as String;
      final typeStr = raw['type'] as String? ?? '';
      final isReel = raw['isReel'] as bool? ?? false;
      final reactionType =
          typeStr.isEmpty ? null : _reactionFromString(typeStr);

      try {
        ReactionResult result;

        if (reactionType == null) {
          result =
              isReel
                  ? await _likeService!.reactReel(contentId, ReactionType.like)
                  : await _likeService!.reactPost(contentId, ReactionType.like);
        } else {
          result =
              isReel
                  ? await _likeService!.reactReel(contentId, reactionType)
                  : await _likeService!.reactPost(contentId, reactionType);
        }

        if (result.success) {
          await _box.delete(key);
          developer.log('[HiveReactionQueue] ✓ Synced $contentId');
        } else {
          developer.log(
            '[HiveReactionQueue] ✗ Server rejected $contentId — will retry later',
          );
        }
      } catch (e) {
        developer.log('[HiveReactionQueue] ✗ Error syncing $contentId: $e');
      }
    }

    _flushing = false;
    developer.log('[HiveReactionQueue] Done. ${_box.length} still pending.');
  }

  ReactionType? _reactionFromString(String value) {
    try {
      return ReactionType.values.firstWhere((r) => r.name == value);
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    _connectivitySub?.cancel();
    await _box.close();
  }

  void debugPrint() {
    if (!_initialized || _box.isEmpty) {
      developer.log('[HiveReactionQueue] Queue is empty');
      return;
    }
    for (final key in _box.keys) {
      developer.log('[HiveReactionQueue] → $key : ${_box.get(key)}');
    }
  }
}
