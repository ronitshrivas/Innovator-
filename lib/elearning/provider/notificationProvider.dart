import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/elearning/api_calling_service/notification_service.dart';
import 'package:innovator/elearning/model/notification_model.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final notificationListProvider = FutureProvider<List<NotificationModel>>((
  ref,
) async {
  final service = ref.watch(notificationServiceProvider);
  return await service.getNotifications();
});
final unreadCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(notificationListProvider).whenData(
    (list) => list.where((n) => !n.isRead).length,
  );
});