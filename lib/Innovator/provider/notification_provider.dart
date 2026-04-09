import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/App_data/App_data.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final String? imageUrl;
  final String? senderUsername;
  final String? relatedPostId;
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.imageUrl,
    this.senderUsername,
    this.relatedPostId,
    required this.createdAt,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      title:
          json['title'] as String? ??
          json['sender_username'] as String? ??
          'New Notification',
      body: json['message'] as String? ?? '',
      type: json['type'] as String? ?? '',
      imageUrl: json['sender_avatar'] as String?,
      senderUsername: json['sender_username'] as String?,
      relatedPostId: json['related_post_id'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AppNotification && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────────────────────────────────────────
// ISOLATE MESSAGES
// ─────────────────────────────────────────────────────────────────────────────

class _PollRequest {
  final SendPort replyPort;
  final String authToken;
  final String url;
  _PollRequest(this.replyPort, this.authToken, this.url);
}

class _PollResult {
  final List<Map<String, dynamic>> notifications;
  final String? error;
  _PollResult({this.notifications = const [], this.error});
}

// ─────────────────────────────────────────────────────────────────────────────
// ISOLATE ENTRY POINT — runs on a background thread
// No Flutter SDK here. Pure Dart + http only.
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _pollIsolateEntry(SendPort mainPort) async {
  final receivePort = ReceivePort();
  mainPort.send(receivePort.sendPort); // handshake

  await for (final msg in receivePort) {
    if (msg is _PollRequest) {
      try {
        final response = await http
            .get(
              Uri.parse(msg.url),
              headers: {'Authorization': 'Bearer ${msg.authToken}'},
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          // Your API returns a flat JSON array
          final decoded = jsonDecode(response.body);
          final List<dynamic> list =
              decoded is List
                  ? decoded
                  : (decoded as Map<String, dynamic>?)?['results']
                          as List<dynamic>? ??
                      [];
          msg.replyPort.send(
            _PollResult(
              notifications: list.whereType<Map<String, dynamic>>().toList(
                growable: false,
              ),
            ),
          );
        } else {
          msg.replyPort.send(_PollResult(error: 'HTTP ${response.statusCode}'));
        }
      } catch (e) {
        msg.replyPort.send(_PollResult(error: e.toString()));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE
// ─────────────────────────────────────────────────────────────────────────────

class NotificationState {
  final Queue<AppNotification> displayQueue; // waiting to be shown
  final AppNotification? current; // currently showing banner
  final int unreadCount; // badge number

  NotificationState({
    Queue<AppNotification>? displayQueue,
    this.current,
    this.unreadCount = 0,
  }) : displayQueue = displayQueue ?? Queue<AppNotification>();

  NotificationState copyWith({
    Queue<AppNotification>? displayQueue,
    AppNotification? current,
    bool clearCurrent = false,
    int? unreadCount,
  }) {
    return NotificationState(
      displayQueue: displayQueue ?? this.displayQueue,
      current: clearCurrent ? null : (current ?? this.current),
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

class NotificationNotifier extends Notifier<NotificationState> {
  static const String _apiUrl = 'http://182.93.94.220:8005/api/notifications/';
  static const Duration _foregroundInterval = Duration(seconds: 8);
  static const Duration _backgroundInterval = Duration(seconds: 30);

  Isolate? _isolate;
  SendPort? _isolateSendPort;
  ReceivePort? _mainReceivePort;
  Timer? _pollingTimer;

  // O(1) lookup, bounded to 200 IDs — prevents showing same notification twice
  final LinkedHashSet<String> _seenIds = LinkedHashSet();

  @override
  NotificationState build() {
    ref.onDispose(_teardown);
    return NotificationState();
  }

  // ── PUBLIC API ─────────────────────────────────────────────────────────────

  /// Call after login. Spawns isolate and starts 8-second polling.
  Future<void> startPolling() async {
    await _spawnIsolate();
    _startTimer(_foregroundInterval);
    _triggerPoll(); // immediate check, don't wait
  }

  /// Call from homepage.dart didChangeAppLifecycleState:
  ///   resumed → setAppActive(true)  → 8s polling
  ///   paused  → setAppActive(false) → 30s polling
  void setAppActive(bool isActive) {
    _startTimer(isActive ? _foregroundInterval : _backgroundInterval);
    if (isActive) _triggerPoll(); // check immediately when user opens app
  }

  /// Call on logout.
  void stopPolling() => _teardown();

  /// Called by the banner widget when it times out or user swipes it away.
  /// Shows the next queued notification (if any).
  void dismissCurrent() {
    final queue = Queue<AppNotification>.from(state.displayQueue);
    if (queue.isEmpty) {
      state = state.copyWith(clearCurrent: true);
      return;
    }
    final next = queue.removeFirst();
    state = state.copyWith(current: next, displayQueue: queue);
  }

  /// Call when user taps the banner — decrements badge count.
  void markRead(String id) {
    if (state.unreadCount > 0) {
      state = state.copyWith(unreadCount: state.unreadCount - 1);
    }
  }

  /// Inject a notification directly (used for FCM foreground messages).
  /// Skips the HTTP poll — shows immediately.
  void injectNotification(AppNotification notification) {
    if (_seenIds.contains(notification.id)) return;
    _seenIds.add(notification.id);
    if (_seenIds.length > 200) _seenIds.remove(_seenIds.first);

    final queue = Queue<AppNotification>.from(state.displayQueue);
    AppNotification? current = state.current;

    if (current == null) {
      current = notification;
    } else {
      queue.addLast(notification);
    }

    state = state.copyWith(
      current: current,
      displayQueue: queue,
      unreadCount: state.unreadCount + 1,
    );
  }

  /// Call on logout — clears all state and history.
  void clearAll() {
    _seenIds.clear();
    state = NotificationState();
  }

  // ── ISOLATE LIFECYCLE ──────────────────────────────────────────────────────

  Future<void> _spawnIsolate() async {
    if (_isolate != null) return;

    _mainReceivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _pollIsolateEntry,
      _mainReceivePort!.sendPort,
      debugName: 'NotificationPollIsolate',
    );

    final completer = Completer<SendPort>();
    final sub = _mainReceivePort!.listen((msg) {
      if (msg is SendPort && !completer.isCompleted) {
        completer.complete(msg);
      } else if (msg is _PollResult) {
        _handlePollResult(msg);
      }
    });
    ref.onDispose(sub.cancel);

    _isolateSendPort = await completer.future;
    developer.log('[NotificationProvider] Isolate spawned ✓');
  }

  void _startTimer(Duration interval) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) => _triggerPoll());
    developer.log(
      '[NotificationProvider] Polling every ${interval.inSeconds}s',
    );
  }

  void _triggerPoll() {
    final token = AppData().accessToken;
    if (token == null || token.isEmpty || _isolateSendPort == null) return;

    final replyPort = ReceivePort();
    replyPort.listen((msg) {
      if (msg is _PollResult) _handlePollResult(msg);
      replyPort.close();
    });

    _isolateSendPort!.send(_PollRequest(replyPort.sendPort, token, _apiUrl));
  }

  void _handlePollResult(_PollResult result) {
    if (result.error != null) {
      developer.log('[NotificationProvider] Poll error: ${result.error}');
      return;
    }

    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));

    final newOnes = result.notifications
        .map((j) => AppNotification.fromJson(j))
        .where(
          (n) =>
              !n.isRead &&
              !_seenIds.contains(n.id) &&
              n.createdAt.isAfter(cutoff),
        )
        .toList(growable: false);

    if (newOnes.isEmpty) return;

    for (final n in newOnes) {
      _seenIds.add(n.id);
    }
    while (_seenIds.length > 200) {
      _seenIds.remove(_seenIds.first);
    }

    final queue = Queue<AppNotification>.from(state.displayQueue);
    AppNotification? current = state.current;

    for (final n in newOnes) {
      if (current == null) {
        current = n;
      } else {
        queue.addLast(n);
      }
    }

    state = state.copyWith(
      current: current,
      displayQueue: queue,
      unreadCount: state.unreadCount + newOnes.length,
    );

    developer.log(
      '[NotificationProvider] ${newOnes.length} new notification(s)',
    );
  }

  void _teardown() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _mainReceivePort?.close();
    _mainReceivePort = null;
    _isolateSendPort = null;
    developer.log('[NotificationProvider] Torn down');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS — use the most specific one to avoid unnecessary rebuilds
// ─────────────────────────────────────────────────────────────────────────────

/// Main provider. Use notificationProvider.notifier to call methods.
final notificationProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(
      NotificationNotifier.new,
    );

/// Use ONLY in InAppNotificationOverlay.
/// Rebuilds ONLY when the banner changes — all other screens unaffected.
final currentNotificationProvider = Provider<AppNotification?>((ref) {
  return ref.watch(notificationProvider.select((s) => s.current));
});

/// Use wherever you show a badge (bottom nav, app bar icon).
/// Rebuilds ONLY when the number changes.
final notificationBadgeProvider = Provider<int>((ref) {
  return ref.watch(notificationProvider.select((s) => s.unreadCount));
});
