// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:innovator/elearning/api_calling_service/notification_service.dart';
// import 'package:innovator/elearning/model/notification_model.dart';

// final notificationServiceProvider = Provider<NotificationService>(
//   (ref) => NotificationService(),
// );

// // final notificationListProvider = FutureProvider<List<NotificationModel>>((
// //   ref,
// // ) async {
// //   final service = ref.watch(notificationServiceProvider);
// //   return await service.getNotifications();
// // });

// final notificationListProvider = FutureProvider<List<NotificationModel>>((ref) async {
//   final service = ref.watch(notificationServiceProvider);

//   final newList = await service.getNotifications();

//   final previous = ref.state.value ?? [];

//   final newItems = newList.where(
//     (n) => !previous.any((p) => p.id == n.id),
//   );

//   for (final n in newItems) {
//     showSystemNotification(n);
//   }

//   return newList;
// });

// final unreadCountProvider = Provider<AsyncValue<int>>((ref) {
//   return ref.watch(notificationListProvider).whenData(
//     (list) => list.where((n) => !n.isRead).length,
//   );
// });

// void showSystemNotification(NotificationModel n) {
//   final plugin = FlutterLocalNotificationsPlugin();

//   const androidDetails = AndroidNotificationDetails(
//     'high_importance_channel',
//     'High Importance Notifications',
//     importance: Importance.max,
//     priority: Priority.max,
//   );

//   plugin.show(
//     n.id.hashCode,
//     n.title,
//     n.message,
//     const NotificationDetails(android: androidDetails),
//   );
// }

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/elearning/api_calling_service/notification_service.dart';
import 'package:innovator/elearning/model/notification_model.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

class NotificationState {
  final List<NotificationModel> notifications;
  const NotificationState({required this.notifications});

  NotificationState copyWith({List<NotificationModel>? notifications}) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationService service;
  NotificationNotifier(this.service)
    : super(const NotificationState(notifications: []));

  final _plugin = FlutterLocalNotificationsPlugin();
    void markAllRead() {
    final updatedNotifications = state.notifications
        .map((n) => NotificationModel(
              id: n.id,
              title: n.title,
              message: n.message,
              notificationType: n.notificationType,
              isRead: true, // mark as read
              createdAt: n.createdAt,
              data: n.data,
            ))
        .toList();

    state = state.copyWith(notifications: updatedNotifications);
  }

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    await refresh();
  }

  Future<void> refresh() async {
    try {
      final newList = await service.getNotifications();

      final oldList = state.notifications;
      final newItems = newList.where((n) => !oldList.any((o) => o.id == n.id));

      for (final n in newItems) {
        showSystemNotification(n);
      }

      state = state.copyWith(notifications: newList);
    } catch (e) {}
  }

  void showSystemNotification(NotificationModel n) {
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.max,
    );

    _plugin.show(
      n.id.hashCode,
      n.title,
      n.message,
      const NotificationDetails(android: androidDetails),
    );
  }
}

final notificationListProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
      final service = ref.watch(notificationServiceProvider);
      final notifier = NotificationNotifier(service);
      notifier.init();
      return notifier;
    });

final unreadCountProvider = Provider<int>((ref) {
  final state = ref.watch(notificationListProvider);
  return state.notifications.where((n) => !n.isRead).length;
});
