import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/Authorization/Login.dart';
import 'package:innovator/Innovator/constant/api_constants.dart';
import 'package:innovator/Innovator/constant/app_colors.dart';
import 'package:innovator/Innovator/screens/Feed/Inner_Homepage.dart';
import 'package:innovator/Innovator/screens/Feed/Optimize%20Media/full_screen_image_viewer.dart';
import 'package:innovator/Innovator/screens/Follow/follow_Button.dart';
import 'package:innovator/Innovator/screens/chatrrom/screen/chatlistscreen.dart';
import 'package:innovator/Innovator/screens/comment/comment_screen.dart';
import 'package:innovator/Innovator/screens/show_Specific_Profile/show_Specific_followers.dart';
import 'package:innovator/Innovator/controllers/user_controller.dart';
import 'package:innovator/Innovator/widget/CustomizeFAB.dart';
import 'dart:developer' as developer;

import '../../models/Feed_Content_Model.dart';

class SpecificUserProfilePage extends ConsumerStatefulWidget {
  final String userId;
  final String? scrollToPostId;
  final bool? openComments;
  final String? highlightCommentId;

  const SpecificUserProfilePage({
    Key? key,
    required this.userId,
    this.scrollToPostId,
    this.openComments,
    this.highlightCommentId,
  }) : super(key: key);

  @override
  _SpecificUserProfilePageState createState() =>
      _SpecificUserProfilePageState();
}

class _SpecificUserProfilePageState
    extends ConsumerState<SpecificUserProfilePage>
    with TickerProviderStateMixin {
  final AppData _appData = AppData();
  late Future<Map<String, dynamic>> _profileFuture;
  bool _isRefreshing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Posts come directly from GET /api/users/{id}/ response["posts"]
  List<FeedContent> _posts = [];
  final ScrollController _scrollController = ScrollController();
  bool isExpanded = false;
  final Map<String, bool> _reactionState = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _profileFuture = _fetchUserProfile();
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.scrollToPostId != null && _posts.isNotEmpty) {
        _scrollToPost(widget.scrollToPostId!);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Single API call: GET /api/users/{id}/ ─────────────────────────────────
  // Response includes { ..., "posts": [...] }
  // We parse the posts array directly — no second feed call needed.

  Future<Map<String, dynamic>> _fetchUserProfile() async {
    try {
      final token = _appData.accessToken ?? '';
      final response = await http
          .get(
            Uri.parse('${ApiConstants.fetchotheruserprofile}${widget.userId}/'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      developer.log(
        '[SpecificProfile] GET /api/users/${widget.userId}/ → ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        // Parse posts from the "posts" field in the profile response
        final rawPosts = data['posts'] as List<dynamic>? ?? [];
        final parsed =
            rawPosts
                .whereType<Map<String, dynamic>>()
                .map((p) {
                  try {
                    return FeedContent.fromNewApiPost(p);
                  } catch (e) {
                    developer.log('[SpecificProfile] post parse error: $e');
                    return null;
                  }
                })
                .whereType<FeedContent>()
                .where((c) => c.id.isNotEmpty)
                .toList();

        if (mounted) setState(() => _posts = parsed);

        // Cache avatar in UserController
        try {
          if (Get.isRegistered<UserController>()) {
            final uc = Get.find<UserController>();
            final avatar = data['profile']?['avatar']?.toString() ?? '';
            uc.cacheUserProfilePicture(
              widget.userId,
              avatar.isNotEmpty ? avatar : null,
              data['full_name']?.toString() ??
                  data['username']?.toString() ??
                  '',
            );
          }
        } catch (_) {}

        return data;
      } else if (response.statusCode == 401) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => LoginPage()),
            (_) => false,
          );
        }
        throw Exception('Authentication required');
      } else {
        throw Exception('Failed to load profile (${response.statusCode})');
      }
    } catch (e) {
      developer.log('[SpecificProfile] fetchUserProfile error: $e');
      rethrow;
    }
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _isRefreshing = true;
      _posts = [];
    });
    try {
      _profileFuture = _fetchUserProfile();
      await _profileFuture;
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _scrollToPost(String postId) {
    final index = _posts.indexWhere((c) => c.id == postId);
    if (index != -1 && _scrollController.hasClients) {
      _scrollController.animateTo(
        (index * 500.0).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      if (widget.openComments == true) {
        Future.delayed(const Duration(milliseconds: 600), () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CommentScreen(postId: postId)),
          );
        });
      }
    }
  }

  // ── Field helpers ─────────────────────────────────────────────────────────

  String _name(Map<String, dynamic> d) {
    final fn = d['full_name']?.toString().trim() ?? '';
    return fn.isNotEmpty ? fn : d['username']?.toString() ?? 'Unknown';
  }

  String? _avatar(Map<String, dynamic> d) {
    final raw = d['profile']?['avatar']?.toString() ?? '';
    if (raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    return '${ApiConstants.userBase}$raw';
  }

  String _followersCount(Map<String, dynamic> d) =>
      (d['followers_count'] ?? d['profile']?['followers_count'] ?? 0)
          .toString();

  String _followingCount(Map<String, dynamic> d) =>
      (d['following_count'] ?? d['profile']?['following_count'] ?? 0)
          .toString();

  String? _bio(Map<String, dynamic> d) {
    final b = d['profile']?['bio']?.toString().trim() ?? '';
    return b.isNotEmpty ? b : null;
  }

  String? _gender(Map<String, dynamic> d) =>
      d['profile']?['gender']?.toString();
  String? _dob(Map<String, dynamic> d) =>
      d['profile']?['date_of_birth']?.toString();
  String? _address(Map<String, dynamic> d) =>
      d['profile']?['address']?.toString();

  String? _occupation(Map<String, dynamic> d) {
    final o = d['profile']?['occupation']?.toString().trim() ?? '';
    return o.isNotEmpty ? o : null;
  }

  String? _education(Map<String, dynamic> d) =>
      d['profile']?['education']?.toString();
  String? _hobbies(Map<String, dynamic> d) =>
      d['hobbies']?.toString() ?? d['profile']?['hobbies']?.toString();

  bool _isCurrentUser(Map<String, dynamic> d) =>
      widget.userId == _appData.currentUserId ||
      d['email']?.toString() == _appData.currentUserEmail;

  bool isFollowing(Map<String, dynamic> d) =>
      d['is_followed'] as bool? ?? false;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final unreadCount = ref.watch(chatUnreadCountProvider);

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF0A0A0A) : AppColors.whitecolor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDarkMode ? Brightness.light : Brightness.dark,
        ),
        leading: IconButton(
          iconSize: 25,
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDarkMode ? AppColors.whitecolor : Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        color: Theme.of(context).primaryColor,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !_isRefreshing) {
              return _buildLoadingView();
            }
            if (snapshot.hasError)
              return _buildErrorView(snapshot.error.toString());
            if (!snapshot.hasData) {
              return const Center(child: Text('No profile data available'));
            }

            final profileData = snapshot.data!;

            return AnimatedBuilder(
              animation: _fadeAnimation,
              builder:
                  (_, __) => FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: HeroMode(
                        enabled: false,
                        child: CustomScrollView(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: _buildProfileHeader(profileData),
                            ),
                            SliverToBoxAdapter(
                              child: _buildProfileStats(profileData),
                            ),
                            SliverToBoxAdapter(
                              child: _buildPersonalInfo(profileData),
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 30),
                            ),

                            // Posts section header
                            SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        const Text(
                                          'Posts',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${_posts.length} posts',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(),
                                ],
                              ),
                            ),

                            // Only this user's posts from profile response
                            if (_posts.isNotEmpty)
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => HeroMode(
                                    enabled: false,
                                    child: _buildPostItem(_posts[index]),
                                  ),
                                  childCount: _posts.length,
                                ),
                              )
                            else
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 48,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.article_outlined,
                                        size: 56,
                                        color: Colors.grey[300],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No posts yet',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            const SliverToBoxAdapter(
                              child: SizedBox(height: 100),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            );
          },
        ),
      ),
      floatingActionButton: CountBadgeFAB(
        count: unreadCount, // ← real-time total
        gifAsset: 'animation/chaticon.gif',
        backgroundColor: Colors.transparent,
        onPressed: () {
          ref.read(mutualFriendsProvider.notifier).refresh();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatListScreen()),
          ).then((_) {
            ref.invalidate(mutualFriendsProvider);
            //ref.read(mutualFriendsProvider.notifier).refresh();
          });
        },
      ),
    );
  }

  // ── Profile header ─────────────────────────────────────────────────────────

  Widget _buildProfileHeader(Map<String, dynamic> profileData) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final isCurrentUser = _isCurrentUser(profileData);
    final name = _name(profileData);
    final avatarUrl = _avatar(profileData);
    final bio = _bio(profileData);
    final isFollowing = profileData['is_following'] as bool? ?? false;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            // Avatar with gradient ring
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withAlpha(70)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withAlpha(30),
                    blurRadius: 20,
                    spreadRadius: 5,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => FullScreenImageViewer(
                            imageUrl: '$avatarUrl',
                            tag: name,
                          ),
                    ),
                  );
                },
                child: _buildAvatar(avatarUrl, name, radius: 70),
              ),
            ),

            const SizedBox(height: 12),

            // Name + Follow button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.whitecolor : Colors.black,
                    ),
                  ),
                ),
                if (!isCurrentUser) ...[
                  const SizedBox(width: 12),
                  FollowButton(
                    targetUserId:
                        profileData['id']?.toString() ?? widget.userId,
                    initialFollowStatus:
                        profileData['is_followed'] as bool? ?? false,
                    onFollowSuccess: () => _refreshProfile(),
                    onUnfollowSuccess: () => _refreshProfile(),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 4),

            // @username
            Text(
              '@${profileData['username'] ?? ''}',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),

            const SizedBox(height: 8),

            // Role badge
            if ((profileData['role']?.toString().trim() ?? '').isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withAlpha(80)],
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  profileData['role'].toString().toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.whitecolor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),

            if (bio != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  bio,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDarkMode ? AppColors.whitecolor : Colors.black87,
                    //fontStyle: FontStyle.italic,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String name, {double radius = 40}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade300,
        child: Text(
          initial,
          style: TextStyle(
            fontSize: radius * 0.55,
            fontWeight: FontWeight.bold,
            color: AppColors.whitecolor,
          ),
        ),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatarUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder:
            (_, __) => CircleAvatar(
              radius: radius,
              backgroundColor: Colors.grey.shade200,
              child: Text(
                initial,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
        errorWidget:
            (_, __, ___) => CircleAvatar(
              radius: radius,
              backgroundColor: Colors.grey.shade300,
              child: Text(
                initial,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.whitecolor,
                ),
              ),
            ),
      ),
    );
  }

  // ── Stats ──────────────────────────────────────────────────────────────────

  Widget _buildProfileStats(Map<String, dynamic> profileData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              _followersCount(profileData),
              'Followers',
              Icons.people_outline,
              Colors.blue,
              onTap: () => showFollowersFollowingDialog(context, widget.userId),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: _buildStatCard(
              _followingCount(profileData),
              'Following',
              Icons.person_add_outlined,
              Colors.green,
              onTap: () => showFollowersFollowingDialog(context, widget.userId),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: _buildStatCard(
              '${_posts.length}',
              'Posts',
              Icons.grid_on,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: AppColors.whitecolor,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 5),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Personal info ─────────────────────────────────────────────────────────

  Widget _buildPersonalInfo(Map<String, dynamic> profileData) {
    final gender = _gender(profileData);
    final dob = _dob(profileData);
    final address = _address(profileData);
    final occupation = _occupation(profileData);
    final education = _education(profileData);
    final hobbies = _hobbies(profileData);

    final hasAny =
        gender != null ||
        address != null ||
        dob != null ||
        occupation != null ||
        education != null ||
        hobbies != null;
    if (!hasAny) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 15),
              const Text(
                'Personal Information',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 5),
          if (address != null && address.isNotEmpty)
            _buildInfoRow(
              Icons.location_on_outlined,
              null,
              address,
              Colors.purple,
            ),
          if (gender != null && gender.isNotEmpty)
            _buildInfoRow(Icons.person_outline, null, gender, Colors.teal),
          if (isExpanded) ...[
            if (dob != null && dob.isNotEmpty)
              _buildInfoRow(
                Icons.cake_outlined,
                null,
                _formatDate(dob),
                Colors.pink,
              ),
            if (occupation != null && occupation.isNotEmpty)
              _buildInfoRow(
                Icons.work_outline,
                null,
                'Works as $occupation',
                Colors.orange,
              ),
            if (education != null && education.isNotEmpty)
              _buildInfoRow(
                Icons.school_outlined,
                null,
                'Studies $education',
                Colors.indigo,
              ),
            if (hobbies != null && hobbies.isNotEmpty)
              _buildInfoRow(
                Icons.star_outline,
                'Hobbies',
                hobbies,
                Colors.amber,
              ),
          ],
          TextButton(
            onPressed: () => setState(() => isExpanded = !isExpanded),
            child: Text(
              isExpanded
                  ? 'See Less Information ...'
                  : 'See More Information ...',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String? label,
    String value,
    Color color,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null) ...[
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? AppColors.whitecolor : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Post item ─────────────────────────────────────────────────────────────

  Widget _buildPostItem(FeedContent content) {
    return HeroMode(
      // ← ADD THIS
      enabled: false, // ← ADD THIS
      child: RepaintBoundary(
        key: ValueKey(content.id),
        child: FeedItem(
          content: content,
          onLikeToggled: (hasReaction) {
            if (!mounted) return;
            setState(() {
              final hadReaction = _reactionState[content.id] ?? content.isLiked;
              if (hasReaction && !hadReaction) {
                content.likes = (content.likes + 1).clamp(0, 999999);
              } else if (!hasReaction && hadReaction) {
                content.likes = (content.likes - 1).clamp(0, 999999);
              }
              content.isLiked = hasReaction;
              _reactionState[content.id] = hasReaction;
            });
          },
          onFollowToggled: (isFollowed) {
            if (!mounted) return;
            setState(() {
              for (final p in _posts) {
                if (p.author.id == content.author.id) p.isFollowed = isFollowed;
              }
            });
          },
          onDeleted: () {
            if (mounted) setState(() => _posts.remove(content));
          },
          onStatusUpdated: (newStatus) {
            if (mounted) setState(() => content.status = newStatus);
          },
          onCommentAdded: () {
            if (mounted) setState(() => content.comments++);
          },
        ),
      ), // ← ADD THIS
    ); // ← ADD THIS
  }

  // ── Loading / error ───────────────────────────────────────────────────────

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withAlpha(10),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Profile...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Oops! Something went wrong',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Unable to load profile information',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _refreshProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  color: AppColors.whitecolor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Not provided';
    try {
      final date = DateTime.parse(dateString);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateString;
    }
  }
}
