import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/Innovator/widget/Custom_refresh_Indicator.dart';
import 'package:innovator/elearning/model/notification_model.dart';
import 'package:innovator/elearning/provider/notificationProvider.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationListProvider);

    return Material(
      child: CustomRefreshIndicator(
        onRefresh: () => ref.refresh(notificationListProvider.future),
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Colors.white,
            title: Text(
              'Notifications',
              style: TextStyle(color: Colors.black87),
            ),
            centerTitle: false,
            leading: IconButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
            ),
            actions: [
              PopupMenuButton(
                iconColor: Colors.black87,
                color: Colors.white,
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: 'mark_all_read',
                        child: Text('Mark all as read'),
                      ),
                    ],
                onSelected: (value) {
                  if (value == 'mark_all_read') {
                    //  Mark all notifications functions here
                  }
                },
              ),
            ],
          ),
          body: notificationsAsync.when(
            loading: () => const _LoadingView(),
            error:
                (error, _) => _ErrorView(
                  message: error.toString(),
                  onRetry: () => ref.refresh(notificationListProvider),
                ),
            data:
                (notifications) =>
                    notifications.isEmpty
                        ? const _EmptyView()
                        : _NotificationList(notifications: notifications),
          ),
        ),
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList({required this.notifications});

  final List<NotificationModel> notifications;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const Divider(height: 0, indent: 72),
      itemBuilder: (context, index) {
        return _NotificationTile(notification: notifications[index]);
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final NotificationModel notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      tileColor: notification.isRead ? null : colorScheme.primary.withAlpha(13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              _iconForType(notification.notificationType),
              color: colorScheme.primary,
              size: 20,
            ),
          ),
          if (!notification.isRead)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.scaffoldBackgroundColor,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        notification.title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            notification.message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _timeAgo(notification.createdAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.outline,
            ),
          ),
        ],
      ),
      onTap: () {
        // Navigation here for the notification
      },
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'enrollment':
        return Icons.school_outlined;
      case 'announcement':
        return Icons.campaign_outlined;
      case 'reminder':
        return Icons.alarm_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'No notifications yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
