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

// ─────────────────────────────────────────────
//  Base URL for the new notification service
// ─────────────────────────────────────────────
const String _kBaseUrl = 'http://182.93.94.220:8005';

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

  // ─────────────────────────────────────────────
  //  FETCH  (initial load)
  //  GET /api/notifications/
  // ─────────────────────────────────────────────
  Future<void> fetchNotifications() async {
    if (isLoading) return;
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
        setState(() {
          notifications =
              jsonList.map((j) => NotificationModel.fromJson(j)).toList();
          // New API returns a flat list; pagination handled via offset if needed.
          hasMore =
              false; // Update when the API adds cursor/pagination support.
          nextCursor = null;
        });
      } else {
        throw Exception(
          'Failed to fetch notifications: ${response.statusCode}',
        );
      }
    } catch (e) {
      _showErrorSnackbar('Error fetching notifications');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ─────────────────────────────────────────────
  //  FETCH MORE  (pagination — ready for future cursor support)
  //  GET /api/notifications/?cursor=<nextCursor>
  // ─────────────────────────────────────────────
  Future<void> fetchMoreNotifications() async {
    if (isLoadingMore || !hasMore || nextCursor == null) return;
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
        setState(() {
          notifications.addAll(
            jsonList.map((j) => NotificationModel.fromJson(j)),
          );
          hasMore =
              jsonList.isNotEmpty; // adjust once API sends pagination meta
          nextCursor = null; // update when API returns nextCursor
        });
      } else {
        throw Exception(
          'Failed to fetch more notifications: ${response.statusCode}',
        );
      }
    } catch (e) {
      _showErrorSnackbar('Error fetching more notifications');
    } finally {
      setState(() => isLoadingMore = false);
    }
  }

  // ─────────────────────────────────────────────
  //  MARK AS READ (single)
  //  PATCH /api/notifications/<id>/
  // ─────────────────────────────────────────────
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
      _showErrorSnackbar('Error marking notification as read');
    }
  }

  // ─────────────────────────────────────────────
  //  MARK ALL AS READ
  //  PATCH /api/notifications/mark-all-read/
  // ─────────────────────────────────────────────
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
      _showErrorSnackbar('Error marking all notifications as read');
    }
  }

  // ─────────────────────────────────────────────
  //  DELETE (single)
  //  DELETE /api/notifications/<id>/
  // ─────────────────────────────────────────────
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
      _showErrorSnackbar('Error deleting notification');
    }
  }

  // ─────────────────────────────────────────────
  //  DELETE ALL
  //  DELETE /api/notifications/
  // ─────────────────────────────────────────────
  Future<void> deleteAllNotifications() async {
    if (notifications.isEmpty) return;
    final confirmed = await _showStylizedDialog();
    if (confirmed != true) return;

    setState(() => isDeletingAll = true);
    try {
      final token = AppData().accessToken;
      if (token == null) throw Exception('No authentication token found');

      final response = await http.delete(
        Uri.parse('$_kBaseUrl/api/notifications/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() => notifications.clear());
        _showSuccessSnackbar('All notifications deleted');
      } else {
        throw Exception(
          'Failed to delete all notifications: ${response.statusCode}',
        );
      }
    } catch (e) {
      _showErrorSnackbar('Error deleting all notifications');
    } finally {
      setState(() => isDeletingAll = false);
    }
  }

  // ─────────────────────────────────────────────
  //  HANDLE NOTIFICATION TAP
  //  POST /api/notifications/<id>/click/   (if available)
  //  Falls back to type-based routing otherwise.
  // ─────────────────────────────────────────────
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
        // ← FIX 2: silent return, no snackbar — avoids off-screen SnackBar crash
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
    debugPrint('senderId: ${notification.senderId}');
    debugPrint('senderUsername: ${notification.senderUsername}');

    if (notification.senderId == null || notification.senderId!.isEmpty) {
      _showErrorSnackbar('Unable to open chat: sender not found');
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

  // ─────────────────────────────────────────────
  //  FILTER
  // ─────────────────────────────────────────────
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

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text(
      //     'Notifications',
      //     style: TextStyle(color: Colors.white),
      //   ),
      //   actions: [
      //     if (notifications.isNotEmpty) ...[
      //       _buildHeaderAction(Icons.sync, 'Sync', () async {
      //         HapticFeedback.mediumImpact();
      //         await fetchNotifications();
      //         _showSuccessSnackbar('Synced with latest notifications');
      //       }),
      //       // _buildHeaderAction(
      //       //   Icons.mark_email_read,
      //       //   'Mark all read',
      //       //   markAllAsRead,
      //       // ),
      //       const SizedBox(width: 4),
      //       _buildHeaderAction(
      //         Icons.delete_sweep,
      //         'Delete all',
      //         deleteAllNotifications,
      //       ),
      //       const SizedBox(width: 8),
      //     ],
      //   ],
      // ),
      backgroundColor: Colors.grey[50],
      body: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: Icon(Icons.arrow_back_ios_new),
                alignment: Alignment.topLeft,
              ),
            ),
            //  _buildHeaderAction(),
            _buildFilterChips(),
            _buildNotificationList(),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  Widget _buildHeaderAction() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
        ),
        //child: Icon(Icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF48706) : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? const Color(0xFFF48706) : Colors.grey[300]!,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: const Color(0xFFF48706).withAlpha(30),
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
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationList() {
    if (isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF48706)),
          ),
        ),
      );
    }

    final displayed = filteredNotifications;

    if (displayed.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == displayed.length) return _buildLoadMoreIndicator();
        return _buildNotificationItem(displayed[index], index);
      }, childCount: displayed.length + (hasMore ? 1 : 0)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 50,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _selectedFilter == 'all'
                ? 'No notifications yet'
                : 'No $_selectedFilter notifications',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'all'
                ? "When you get notifications, they'll show up here"
                : 'Try switching to a different filter',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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

  Widget _buildNotificationItem(NotificationModel notification, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: _buildNotificationCard(notification),
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return Dismissible(
      key: Key(notification.id),
      background: _buildDismissBackground(
        Colors.blue,
        Icons.mark_email_read,
        'Mark as read',
      ),
      secondaryBackground: _buildDismissBackground(
        Colors.red,
        Icons.delete,
        'Delete',
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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Material(
          elevation: notification.isRead ? 1 : 3,
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _navigateToNotificationDetails(notification);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      notification.isRead
                          ? Colors.transparent
                          : const Color(0xFFF48706).withAlpha(30),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNotificationAvatar(notification),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNotificationContent(notification),
                        const SizedBox(height: 8),
                        _buildNotificationMeta(notification),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      _buildUnreadIndicator(notification),
                      const SizedBox(height: 8),
                      _buildNotificationTypeIndicator(notification),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDismissBackground(Color color, IconData icon, String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: Colors.white),
              ],
            ),
          ],
        ),
      ),
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

  Widget _buildNotificationAvatar(NotificationModel notification) {
    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _getNotificationColor(notification.type),
                _getNotificationColor(notification.type).withAlpha(70),
              ],
            ),
          ),
          child:
              notification.senderAvatar != null &&
                      notification.senderAvatar!.isNotEmpty
                  ? ClipOval(
                    child: Image.network(
                      notification.senderAvatar!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => _buildDefaultAvatar(notification),
                    ),
                  )
                  : _buildDefaultAvatar(notification),
        ),
        if (!notification.isRead)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDefaultAvatar(NotificationModel notification) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getNotificationColor(notification.type),
            _getNotificationColor(notification.type).withAlpha(70),
          ],
        ),
      ),
      child: Icon(
        _getNotificationIcon(notification.type),
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Widget _buildNotificationContent(NotificationModel notification) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row (e.g. "New Reaction!")
        if (notification.title != null && notification.title!.isNotEmpty)
          Text(
            notification.title!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _getNotificationColor(notification.type),
            ),
          ),
        const SizedBox(height: 2),
        // Message body (e.g. "ram reacted haha to your post.")
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 15,
              color: Colors.black87,
              fontWeight:
                  notification.isRead ? FontWeight.w400 : FontWeight.w600,
              height: 1.3,
            ),
            children: [
              if (notification.senderUsername != null)
                TextSpan(
                  text: '${notification.senderUsername} ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getNotificationColor(notification.type),
                  ),
                ),
              TextSpan(text: _stripUsername(notification)),
            ],
          ),
        ),
      ],
    );
  }

  /// Strips the leading username from the message since we render it separately.
  String _stripUsername(NotificationModel n) {
    final msg = n.message;
    final username = n.senderUsername;
    if (username != null && msg.startsWith(username)) {
      return msg.substring(username.length).trimLeft();
    }
    return msg;
  }

  Widget _buildNotificationMeta(NotificationModel notification) {
    final date = DateTime.parse(notification.createdAt).toLocal();
    final now = DateTime.now();
    final diff = now.difference(date);

    String timeAgo;
    if (diff.inMinutes < 1) {
      timeAgo = 'Just now';
    } else if (diff.inHours < 1) {
      timeAgo = '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      timeAgo = '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      timeAgo = '${diff.inDays}d ago';
    } else {
      timeAgo = DateFormat('MMM d, yyyy').format(date);
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            timeAgo,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getNotificationColor(notification.type).withAlpha(10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _getNotificationTypeLabel(notification.type),
            style: TextStyle(
              fontSize: 12,
              color: _getNotificationColor(notification.type),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnreadIndicator(NotificationModel notification) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: notification.isRead ? 0 : 12,
      height: notification.isRead ? 0 : 12,
      decoration: BoxDecoration(
        color: const Color(0xFFF48706),
        shape: BoxShape.circle,
        boxShadow:
            notification.isRead
                ? null
                : [
                  BoxShadow(
                    color: const Color(0xFFF48706).withAlpha(50),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
      ),
    );
  }

  Widget _buildNotificationTypeIndicator(NotificationModel notification) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _getNotificationColor(notification.type).withAlpha(10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getNotificationIcon(notification.type),
        size: 16,
        color: _getNotificationColor(notification.type),
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

  // ─────────────────────────────────────────────
  //  Dialogs & Snackbars
  // ─────────────────────────────────────────────
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

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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

  // ─────────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────────
  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'message':
      case 'chat_message': // ← ADD
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

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'message':
      case 'chat_message': // ← ADD
        return Colors.blue;
      case 'comment':
        return Colors.green;
      case 'like':
        return Colors.red;
      case 'friend_request':
        return Colors.purple;
      case 'mention':
        return const Color(0xFFF48706);
      case 'share':
        return Colors.teal;
      case 'follow':
        return Colors.indigo;
      default:
        return const Color(0xFFF48706);
    }
  }

  String _getNotificationTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'message':
      case 'chat_message': // ← ADD
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
}

// ─────────────────────────────────────────────────────────────────────────────
//  MODEL  —  maps the NEW API response shape
// ─────────────────────────────────────────────────────────────────────────────
//
//  New API field        Old API field
//  ─────────────────    ─────────────────
//  id                   _id
//  user                 (userId, not exposed in old model)
//  sender               sender._id  (now a plain UUID string)
//  sender_username      sender.name
//  sender_avatar        sender.picture
//  type                 type
//  title                (new)
//  message              content
//  related_post_id      data.contentId / data.postId
//  is_read              read
//  created_at           createdAt
//
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
