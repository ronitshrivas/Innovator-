import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/screens/chatrrom/screen/chatscreen.dart';
import 'package:innovator/ecommerce/screens/Shop/Shop_Page.dart';
import 'package:innovator/innovator_home.dart';
import 'package:innovator/Innovator/screens/show_Specific_Profile/Show_Specific_Profile.dart';
import 'package:intl/intl.dart';
import 'package:innovator/Innovator/screens/Feed/post_detail_screen.dart';

const String _kBaseUrl = 'http://36.253.137.34:8005';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  List<NotificationModel> notifications = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  String? nextCursor;
  bool hasMore = true;
  bool isDeletingAll = false;
  String _selectedFilter = 'all';

  late AnimationController _fabAnimationController;
  late AnimationController _headerAnimationController;
  late Animation<double> _fabAnimation;
  late Animation<Offset> _headerSlideAnimation;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
    _scrollController.addListener(_scrollListener);

    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: Curves.easeOutBack,
      ),
    );

    _headerAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _fabAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fabAnimationController.dispose();
    _headerAnimationController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        hasMore &&
        !isLoadingMore) {
      fetchMoreNotifications();
    }
  }

  Future<void> fetchNotifications() async {
    if (isLoading) return;
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final token = AppData().accessToken;
      if (token == null) throw Exception('No authentication token found');

      final response = await http.get(
        Uri.parse('$_kBaseUrl/api/notifications/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          notifications =
              jsonList.map((j) => NotificationModel.fromJson(j)).toList();
          hasMore = false;
          nextCursor = null;
        });
      } else {
        throw Exception(
          'Failed to fetch notifications: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      // _showErrorSnackbar('Error fetching notifications');
    } finally {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchMoreNotifications() async {
    if (isLoadingMore || !hasMore || nextCursor == null) return;
    if (!mounted) return;
    setState(() => isLoadingMore = true);

    try {
      final token = AppData().accessToken;
      if (token == null) throw Exception('No authentication token found');

      final response = await http.get(
        Uri.parse('$_kBaseUrl/api/notifications/?cursor=$nextCursor'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          notifications.addAll(
            jsonList.map((j) => NotificationModel.fromJson(j)),
          );
          hasMore = jsonList.isNotEmpty;
          nextCursor = null;
        });
      } else {
        throw Exception(
          'Failed to fetch more notifications: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      // _showErrorSnackbar('Error fetching more notifications');
    } finally {
      if (!mounted) return;
      setState(() => isLoadingMore = false);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final token = AppData().accessToken;
      if (token == null) throw Exception('No authentication token found');

      final response = await http.post(
        Uri.parse('$_kBaseUrl/api/notifications/$notificationId/mark-as-read/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          final index = notifications.indexWhere((n) => n.id == notificationId);
          if (index != -1) {
            notifications[index] = notifications[index].copyWith(isRead: true);
          }
        });
      } else {
        throw Exception(
          'Failed to mark notification as read: ${response.statusCode}',
        );
      }
    } catch (e) {
      //_showErrorSnackbar('Error marking notification as read');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final token = AppData().accessToken;
      if (token == null) throw Exception('No authentication token found');

      final response = await http.post(
        Uri.parse('$_kBaseUrl/api/notifications/mark-all-as-read/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        final unreadCount = notifications.where((n) => !n.isRead).length;
        if (unreadCount > 0) {
          setState(() {
            notifications =
                notifications.map((n) => n.copyWith(isRead: true)).toList();
          });
          _showSuccessSnackbar('All notifications marked as read');
        } else {
          _showInfoSnackbar('No unread notifications to mark');
        }
      } else {
        throw Exception('Failed to mark all as read: ${response.statusCode}');
      }
    } catch (e) {
      //_showErrorSnackbar('Error marking all notifications as read');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      final token = AppData().accessToken;
      if (token == null) throw Exception('No authentication token found');

      final response = await http.delete(
        Uri.parse('$_kBaseUrl/api/notifications/$notificationId/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(
          () => notifications.removeWhere((n) => n.id == notificationId),
        );
        _showSuccessSnackbar('Notification deleted');
      } else {
        throw Exception(
          'Failed to delete notification: ${response.statusCode}',
        );
      }
    } catch (e) {
      //_showErrorSnackbar('Error deleting notification');
    }
  }

  void _navigateToNotificationDetails(NotificationModel notification) async {
    if (!notification.isRead) markAsRead(notification.id);

    switch (notification.type.toLowerCase()) {
      case 'like':
      case 'comment':
      case 'share':
      case 'mention':
        if (notification.relatedPostId != null) {
          _navigateToSpecificFeedPost(
            notification.relatedPostId!,
            action: notification.type.toLowerCase(),
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => Homepage()),
            (route) => false,
          );
        }
        break;

      // ← FIX 1: add 'chat_message' alongside 'message'
      case 'message':
      case 'chat_message':
      case 'new_message':
        _navigateToChat(notification);
        break;

      case 'friend_request':
      case 'follow':
        if (notification.senderId != null) {
          _navigateToProfile(notification.senderId!);
        }
        break;

      case 'shop':
        Navigator.push(context, MaterialPageRoute(builder: (_) => ShopPage()));
        break;

      default:
        break;
    }
  }

  void _navigateToSpecificFeedPost(String contentId, {String? action}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => NewFeedPostDetailScreen(
              postId: contentId,
              highlightAction: action,
            ),
      ),
    );
  }

  void _navigateToChat(NotificationModel notification) {
    if (notification.senderId == null || notification.senderId!.isEmpty) {
      //_showErrorSnackbar('Unable to open chat: sender not found');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ChatScreen(
              otherUserId: notification.senderId!,
              otherUserName: notification.senderUsername ?? 'Unknown',
              otherUserAvatar: notification.senderAvatar ?? '',
              isOnline: false,
            ),
      ),
    );
  }

  void _navigateToProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpecificUserProfilePage(userId: userId),
      ),
    );
  }

  List<NotificationModel> get filteredNotifications {
    switch (_selectedFilter) {
      case 'unread':
        return notifications.where((n) => !n.isRead).toList();
      case 'messages':
        return notifications
            .where((n) => n.type.toLowerCase() == 'message')
            .toList();
      case 'interactions':
        return notifications
            .where(
              (n) => [
                'like',
                'comment',
                'share',
                'mention',
              ].contains(n.type.toLowerCase()),
            )
            .toList();
      default:
        return notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayed = filteredNotifications;

    return Material(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          title: const Text(
            'Notifications',
            style: TextStyle(color: Colors.black87),
          ),
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          ),
          actions: [
            PopupMenuButton<String>(
              iconColor: Colors.black87,
              color: Colors.white,
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'mark_all_read',
                      child: Text('Mark all as read'),
                    ),
                    const PopupMenuItem(
                      value: 'refresh',
                      child: Text('Refresh'),
                    ),
                  ],
              onSelected: (value) {
                switch (value) {
                  case 'mark_all_read':
                    markAllAsRead();
                    break;
                  case 'refresh':
                    HapticFeedback.mediumImpact();
                    fetchNotifications();
                    break;
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            _buildFilterChips(),
            Expanded(
              child:
                  isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFF48706),
                          ),
                        ),
                      )
                      : displayed.isEmpty
                      ? _buildEmptyState()
                      : _buildNotificationList(displayed),
            ),
          ],
        ),
        floatingActionButton: _buildFloatingActionButtons(),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', 'all'),
            _buildFilterChip('Unread', 'unread'),
            _buildFilterChip('Messages', 'messages'),
            _buildFilterChip('Interactions', 'interactions'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color:
                isSelected ? theme.colorScheme.primary : Colors.grey.shade300,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withAlpha(40),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationList(List<NotificationModel> displayed) {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: displayed.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 0, indent: 72),
      itemBuilder: (context, index) {
        if (index == displayed.length) return _buildLoadMoreIndicator();
        return _buildNotificationTile(displayed[index]);
      },
    );
  }

  Widget _buildNotificationTile(NotificationModel notification) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dismissible(
      key: Key(notification.id),
      background: _buildDismissBackground(
        Colors.blue,
        Icons.mark_email_read,
        'Mark as read',
        MainAxisAlignment.start,
      ),
      secondaryBackground: _buildDismissBackground(
        Colors.red,
        Icons.delete,
        'Delete',
        MainAxisAlignment.end,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          if (!notification.isRead) markAsRead(notification.id);
          return false;
        } else {
          return await _showDeleteConfirmation();
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          deleteNotification(notification.id);
        }
      },
      child: ListTile(
        tileColor:
            notification.isRead ? null : colorScheme.primary.withAlpha(13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: colorScheme.primaryContainer,
              backgroundImage:
                  (notification.senderAvatar != null &&
                          notification.senderAvatar!.isNotEmpty)
                      ? NetworkImage(notification.senderAvatar!)
                      : null,
              child:
                  (notification.senderAvatar == null ||
                          notification.senderAvatar!.isEmpty)
                      ? Icon(
                        _getNotificationIcon(notification.type),
                        color: colorScheme.primary,
                        size: 20,
                      )
                      : null,
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
          notification.title?.isNotEmpty == true
              ? notification.title!
              : _getNotificationTypeLabel(notification.type),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight:
                notification.isRead ? FontWeight.normal : FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            if (notification.senderUsername?.isNotEmpty == true)
              Text(
                notification.senderUsername!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
          HapticFeedback.lightImpact();
          _navigateToNotificationDetails(notification);
        },
      ),
    );
  }

  Widget _buildDismissBackground(
    Color color,
    IconData icon,
    String label,
    MainAxisAlignment alignment,
  ) {
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: alignment,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
            _selectedFilter == 'all'
                ? 'No notifications yet'
                : 'No $_selectedFilter notifications',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            _selectedFilter == 'all'
                ? "When you get notifications, they'll show up here"
                : 'Try switching to a different filter',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Center(
        child:
            isLoadingMore
                ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF48706)),
                )
                : ElevatedButton(
                  onPressed: fetchMoreNotifications,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFF48706),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text('Load more'),
                ),
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (notifications.any((n) => !n.isRead))
          ScaleTransition(
            scale: _fabAnimation,
            child: FloatingActionButton.small(
              onPressed: markAllAsRead,
              backgroundColor: Colors.green,
              heroTag: 'markAllRead',
              child: const Icon(Icons.done_all, color: Colors.white),
            ),
          ),
        const SizedBox(height: 12),
        ScaleTransition(
          scale: _fabAnimation,
          child: FloatingActionButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              fetchNotifications();
            },
            backgroundColor: const Color(0xFFF48706),
            heroTag: 'refresh',
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Future<bool?> _showStylizedDialog() {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withAlpha(60),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_sweep,
                        color: Colors.red,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Delete All Notifications',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This action cannot be undone. All your notifications will be permanently deleted.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogButton(
                            'Cancel',
                            Colors.grey[100]!,
                            Colors.grey[700]!,
                            () => Navigator.pop(context, false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDialogButton(
                            'Delete All',
                            Colors.red,
                            Colors.white,
                            () => Navigator.pop(context, true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
          child: child,
        );
      },
    );
  }

  Future<bool> _showDeleteConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Delete Notification'),
            content: const Text(
              'Are you sure you want to delete this notification?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  Widget _buildDialogButton(
    String text,
    Color bgColor,
    Color textColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _timeAgo(String createdAt) {
    final date = DateTime.parse(createdAt).toLocal();
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(date);
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'message':
      case 'chat_message':
        return Icons.chat_bubble_outline;
      case 'comment':
        return Icons.mode_comment_outlined;
      case 'like':
        return Icons.favorite_outline;
      case 'friend_request':
        return Icons.person_add_outlined;
      case 'mention':
        return Icons.alternate_email;
      case 'share':
        return Icons.share_outlined;
      case 'follow':
        return Icons.person_add_alt_1_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _getNotificationTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'message':
      case 'chat_message':
        return 'Message';
      case 'comment':
        return 'Comment';
      case 'like':
        return 'Like';
      case 'friend_request':
        return 'Friend Request';
      case 'mention':
        return 'Mention';
      case 'share':
        return 'Share';
      case 'follow':
        return 'Follow';
      default:
        return type;
    }
  }

  // String _getNotificationTypeLabel(String type) {
  //   switch (type.toLowerCase()) {
  //     case 'message':
  //     case 'chat_message': // ← ADD
  //       return 'Message';
  //     case 'comment':
  //       return 'Comment';
  //     case 'like':
  //       return 'Like';
  //     case 'friend_request':
  //       return 'Friend Request';
  //     case 'mention':
  //       return 'Mention';
  //     case 'share':
  //       return 'Share';
  //     case 'follow':
  //       return 'Follow';
  //     default:
  //       return type;
  //   }
  // }
}

class NotificationModel {
  final String id;
  final String? userId;
  final String? senderId;
  final String? senderUsername;
  final String? senderAvatar;
  final String type;
  final String? title;
  final String message;
  final String? relatedPostId;
  final bool isRead;
  final String createdAt;

  NotificationModel({
    required this.id,
    this.userId,
    this.senderId,
    this.senderUsername,
    this.senderAvatar,
    required this.type,
    this.title,
    required this.message,
    this.relatedPostId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user'] as String?,
      senderId: json['sender'] as String?,
      senderUsername: json['sender_username'] as String?,
      senderAvatar: json['sender_avatar'] as String?,
      type: json['type'] as String,
      title: json['title'] as String?,
      message: json['message'] as String,
      relatedPostId: json['related_post_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] as String,
    );
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? senderId,
    String? senderUsername,
    String? senderAvatar,
    String? type,
    String? title,
    String? message,
    String? relatedPostId,
    bool? isRead,
    String? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      senderId: senderId ?? this.senderId,
      senderUsername: senderUsername ?? this.senderUsername,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      relatedPostId: relatedPostId ?? this.relatedPostId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
