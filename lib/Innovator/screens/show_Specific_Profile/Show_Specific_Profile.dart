import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/Authorization/Login.dart';
import 'package:innovator/Innovator/controllers/user_controller.dart';
import 'package:innovator/Innovator/screens/Feed/Inner_Homepage.dart';
import 'package:innovator/Innovator/screens/Follow/follow_Button.dart';
import 'package:flutter/services.dart';
import 'package:innovator/Innovator/screens/comment/comment_screen.dart';
import 'package:innovator/Innovator/screens/show_Specific_Profile/show_Specific_followers.dart';
import 'package:innovator/Innovator/widget/FloatingMenuwidget.dart';

import '../../controllers/State_Management_Profile.dart';
import '../../models/Feed_Content_Model.dart';

class SpecificUserProfilePage extends StatefulWidget {
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

late Size mq;

class _SpecificUserProfilePageState extends State<SpecificUserProfilePage>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final UserController _userController = UserController.to;
  late Future<Map<String, dynamic>> _profileFuture;
  final AppData _appData = AppData();
  bool _isRefreshing = false;
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Separate lists for regular content and videos
  final List<FeedContent> _regularContents = [];
  final List<FeedContent> _videoContents = [];
  final ScrollController _scrollController = ScrollController();

  bool _isLoadingContent = false;
  bool _isLoadingVideos = false;
  int _contentPage = 0;
  int _videoPage = 0;
  bool _hasError = false;
  String _errorMessage = '';
  bool _hasMoreContent = true;
  bool _hasMoreVideos = true;
  static const _loadTriggerThreshold = 500.0;
  bool isExpanded = false;

  // Privacy check methods
  bool _isPrivateAccount(Map<String, dynamic> profileData) {
    return profileData['isPrivate'] == true ||
        profileData['privateAccount'] == true;
  }

  bool _isFollowing(Map<String, dynamic> profileData) {
    return profileData['followed'] == true ||
        profileData['isFollowing'] == true;
  }

  bool _isCurrentUser(Map<String, dynamic> profileData) {
    return widget.userId == _appData.currentUserId ||
        profileData['email'] == _appData.currentUserEmail;
  }

  bool _canViewPrivateContent(Map<String, dynamic> profileData) {
    return _isCurrentUser(profileData) ||
        _isFollowing(profileData) ||
        !_isPrivateAccount(profileData);
  }

  // Combined list for display
  List<FeedContent> get _allContents {
    List<FeedContent> combined = [];
    combined.addAll(_regularContents);
    combined.addAll(_videoContents);
    // Sort by createdAt (newest first)
    combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return combined;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    _initializeFeed();
    _scrollController.addListener(_scrollListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.scrollToPostId != null && _allContents.isNotEmpty) {
        _scrollToPost(widget.scrollToPostId!);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeFeed() {
    // Load both content types initially
    _loadRegularContent();
    _loadVideoContent();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - _loadTriggerThreshold) {
      // Load more from both APIs if available
      if (_hasMoreContent && !_isLoadingContent) {
        _loadRegularContent();
      }
      if (_hasMoreVideos && !_isLoadingVideos) {
        _loadVideoContent();
      }
    }
  }

  // Fetch regular content (non-video) from getUserContent API
  Future<void> _loadRegularContent() async {
    if (_isLoadingContent || !_hasMoreContent) return;

    setState(() {
      _isLoadingContent = true;
      _hasError = false;
    });

    try {
      final String? authToken = _appData.accessToken;
      if (authToken == null || authToken.isEmpty) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Authentication required. Please login.';
        });
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()),
          (route) => false,
        );
        return;
      }

      final url =
          'http://182.93.94.210:3067/api/v1/getUserContent/${widget.userId}?page=$_contentPage';

      debugPrint('📝 Fetching regular content from: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'authorization': 'Bearer $authToken',
            },
          )
          .timeout(Duration(seconds: 30));

      debugPrint(
        '📝 Regular Content API Response Status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 200 && data['data'] != null) {
          final List<dynamic> contentList = data['data']['contents'] ?? [];

          // Filter OUT video content - only get non-video content
          final List<FeedContent> newContents =
              contentList
                  .where((item) => item['contentType'] != 'video')
                  .map((item) => FeedContent.fromJson(item))
                  .toList();

          debugPrint(
            '📝 Loaded ${newContents.length} regular contents (non-video)',
          );

          final pagination = data['data']['pagination'];

          setState(() {
            _regularContents.addAll(newContents);
            _contentPage++;
            _hasMoreContent = pagination['hasMore'] ?? false;
          });
        }
      } else if (response.statusCode == 401) {
        await _handleUnauthorizedError();
      } else {
        debugPrint(' Regular content error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint(' Error loading regular content: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Error loading content: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoadingContent = false;
      });
    }
  }

  // Fetch video content from getUserVideoContents API
  Future<void> _loadVideoContent() async {
    if (_isLoadingVideos || !_hasMoreVideos) return;

    setState(() {
      _isLoadingVideos = true;
      _hasError = false;
    });

    try {
      final String? authToken = _appData.accessToken;
      if (authToken == null || authToken.isEmpty) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Authentication required. Please login.';
        });
        return;
      }

      final url =
          'http://182.93.94.210:3067/api/v1/getUserVideoContents/${widget.userId}?page=$_videoPage';

      debugPrint('🎥 Fetching video content from: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'authorization': 'Bearer $authToken',
            },
          )
          .timeout(Duration(seconds: 30));

      debugPrint(
        '🎥 Video Content API Response Status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 200 && data['data'] != null) {
          final List<dynamic> contentList = data['data']['contents'] ?? [];

          // Only get video content
          final List<FeedContent> newVideos =
              contentList
                  .where((item) => item['contentType'] == 'video')
                  .map((item) => FeedContent.fromJson(item))
                  .toList();

          debugPrint('🎥 Loaded ${newVideos.length} video contents');

          final pagination = data['data']['pagination'];

          if (mounted) {
            setState(() {
              _videoContents.addAll(newVideos);
              _videoPage++;
              _hasMoreVideos = pagination['hasMore'] ?? false;
            });

            // Force rebuild after adding videos
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {});
              }
            });
          }
        }
      } else if (response.statusCode == 401) {
        await _handleUnauthorizedError();
      } else {
        debugPrint(' Video content error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint(' Error loading video content: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error loading videos: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingVideos = false;
        });
      }
    }
  }

  Future<void> _handleUnauthorizedError() async {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
      (route) => false,
    );
  }

  Future<void> _refreshFeed() async {
    setState(() {
      _regularContents.clear();
      _videoContents.clear();
      _contentPage = 0;
      _videoPage = 0;
      _hasError = false;
      _hasMoreContent = true;
      _hasMoreVideos = true;
    });

    // Load both types
    await Future.wait([_loadRegularContent(), _loadVideoContent()]);
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      _profileFuture = _fetchUserProfile();
      await _profileFuture;
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _fetchUserProfile() async {
    try {
      debugPrint(' Fetching profile for userId: ${widget.userId}');
      debugPrint(' Auth token present: ${_appData.accessToken != null}');

      final response = await http
          .get(
            Uri.parse(
              'http://182.93.94.210:3067/api/v1/stalk-profile/${widget.userId}',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'authorization': 'Bearer ${_appData.accessToken}',
            },
          )
          .timeout(
            Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timed out after 30 seconds');
            },
          );

      debugPrint(' Profile API Response Status: ${response.statusCode}');
      debugPrint(
        ' Profile API Response Body: ${response.body.substring(0, math.min(500, response.body.length))}',
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);

        if (responseBody['data'] == null) {
          throw Exception('No profile data in response');
        }

        final profileData = responseBody['data'];
        debugPrint('Profile data loaded successfully');
        debugPrint('Profile keys: ${profileData.keys.toList()}');

        // Cache user data
        if (profileData['_id'] != _appData.currentUserId) {
          _userController.cacheUserProfilePicture(
            profileData['_id'] ?? widget.userId,
            profileData['picture'],
            profileData['name'],
          );

          final imageUrl = _userController.getOtherUserFullProfilePicturePath(
            profileData['_id'] ?? widget.userId,
          );
          if (imageUrl != null && mounted) {
            _userController.preloadVisibleUsers([
              profileData['_id'] ?? widget.userId,
            ], context);
          }
        }

        return profileData;
      } else if (response.statusCode == 404) {
        throw Exception('User not found (404)');
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed (401)');
      } else {
        throw Exception(
          'Failed to load profile: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint(' Error fetching profile: $e');
      debugPrint(' Stack trace: ${StackTrace.current}');
      throw Exception('Error fetching profile: $e');
    }
  }

  void _scrollToPost(String postId) {
    final index = _allContents.indexWhere((content) => content.id == postId);
    if (index != -1 && _scrollController.hasClients) {
      final position = _scrollController.position;
      final itemExtent = 500.0;
      final targetOffset = index * itemExtent;

      _scrollController.animateTo(
        targetOffset.clamp(0.0, position.maxScrollExtent),
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );

      if (widget.openComments == true) {
        Future.delayed(Duration(milliseconds: 600), () {
          _openCommentsForPost(postId, widget.highlightCommentId);
        });
      }
    }
  }

  void _openCommentsForPost(String postId, String? highlightCommentId) {
    final post = _allContents.firstWhere((content) => content.id == postId);

    if (post != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CommentScreen(postId: postId)),
      );
    }
  }

  Widget _buildContentItem(int index) {
    final content = _allContents[index];
    return RepaintBoundary(
      key: ValueKey(
        '${content.id}_${content.createdAt.millisecondsSinceEpoch}',
      ),
      child: FeedItem(
        content: content,
        onLikeToggled: (isLiked) {
          setState(() {
            content.isLiked = isLiked;
            content.likes += isLiked ? 1 : -1;
          });
        },
        onFollowToggled: (isFollowed) {
          setState(() {
            content.isFollowed = isFollowed;
          });
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return (_isLoadingContent || _isLoadingVideos)
        ? const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        )
        : const SizedBox.shrink();
  }

  Widget _buildFeedErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _refreshFeed, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFeedView() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No posts available'),
            const SizedBox(height: 8),
            Text(
              'Regular: ${_regularContents.length} | Videos: ${_videoContents.length}',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshFeed,
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    mq = MediaQuery.of(context).size;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDarkMode ? const Color(0xFF0A0A0A) : Colors.white,
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
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await _refreshProfile();
              await _refreshFeed();
            },
            color: Theme.of(context).primaryColor,
            child: FutureBuilder<Map<String, dynamic>>(
              future: _profileFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !_isRefreshing) {
                  return _buildLoadingView();
                } else if (snapshot.hasError) {
                  return _buildErrorView(snapshot.error.toString());
                } else if (!snapshot.hasData) {
                  return const Center(child: Text('No profile data available'));
                }

                final profileData = snapshot.data!;
                final canViewPrivateContent = _canViewPrivateContent(
                  profileData,
                );

                return AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: CustomScrollView(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: _buildProfileHeader(profileData, context),
                            ),

                            if (canViewPrivateContent) ...[
                              SliverToBoxAdapter(
                                child: _buildProfileInfo(profileData, context),
                              ),
                              SliverToBoxAdapter(
                                child: _buildPersonalInfo(profileData, context),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 30),
                              ),
                              SliverToBoxAdapter(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Divider(),
                                    Padding(
                                      padding: EdgeInsets.only(
                                        right: 10,
                                        left: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Posts',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Spacer(),
                                          Text(
                                            '${_allContents.length} total',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Divider(),
                                  ],
                                ),
                              ),
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    if (index == _allContents.length) {
                                      return _buildLoadingIndicator();
                                    }
                                    return _buildContentItem(index);
                                  },
                                  childCount:
                                      _allContents.length +
                                      ((_hasMoreContent || _hasMoreVideos)
                                          ? 1
                                          : 0),
                                ),
                              ),
                            ] else ...[
                              SliverToBoxAdapter(
                                child: _buildPrivateAccountView(
                                  profileData,
                                  context,
                                ),
                              ),
                            ],

                            if (_hasError && canViewPrivateContent)
                              SliverFillRemaining(child: _buildFeedErrorView()),
                            if (_allContents.isEmpty &&
                                !_isLoadingContent &&
                                !_isLoadingVideos &&
                                !_hasError &&
                                canViewPrivateContent)
                              SliverFillRemaining(child: _buildEmptyFeedView()),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 100),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // FloatingMenuWidget(),
        ],
      ),
    );
  }

  Widget _buildPrivateAccountView(
    Map<String, dynamic> profileData,
    BuildContext context,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color:
                isDarkMode
                    ? Colors.black.withAlpha(30)
                    : Colors.grey.withAlpha(10),
            blurRadius: 20,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor.withAlpha(10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_outline, size: 60, color: primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            'This Account is Private',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Follow ${profileData['name'] ?? 'this user'} to see their photos, videos and activity.',
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  isDarkMode
                      ? Colors.grey[800]?.withAlpha(30)
                      : Colors.grey[100],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPrivateStatItem(
                  '${profileData['followers']?.toString() ?? '0'}',
                  'Followers',
                  Icons.people_outline,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                ),
                _buildPrivateStatItem(
                  '${profileData['followings']?.toString() ?? '0'}',
                  'Following',
                  Icons.person_add_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateStatItem(String count, String label, IconData icon) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
        const SizedBox(height: 8),
        Text(
          count,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(
    Map<String, dynamic> profileData,
    BuildContext context,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final isCurrentUser = _isCurrentUser(profileData);
    final canViewPrivateContent = _canViewPrivateContent(profileData);

    if (!isCurrentUser) {
      _userController.cacheUserProfilePicture(
        widget.userId,
        profileData['picture'],
        profileData['name'],
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
              child: InstantProfilePicture(
                userId: widget.userId,
                radius: 70,
                profileData: profileData,
                fallbackName: profileData['name'],
                cacheIfMissing: true,
                showBorder: false,
              ),
            ),
            if (profileData['isVerified'] == true)
              Positioned(
                bottom: 1,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            if (_isPrivateAccount(profileData) && !canViewPrivateContent)
              Positioned(
                bottom: 1,
                left: 5,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock, color: Colors.white, size: 20),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  profileData['name'] ?? 'No name',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: FollowButton(
                    targetUserEmail: profileData['email'],
                    initialFollowStatus: profileData['followed'] ?? false,
                    onFollowSuccess: () => _refreshProfile(),
                    onUnfollowSuccess: () => _refreshProfile(),
                    targetUserId: profileData['_id'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLevelBadge(profileData['level']),
                SizedBox(width: 30),
                TextButton.icon(
                  onPressed: () {
                    //  _navigateToChat(profileData);
                  },
                  label: Text(
                    'Message',
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                  icon: Icon(
                    Icons.message_outlined,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(
              height:
                  (profileData['bio'] != null && profileData['bio'].isNotEmpty)
                      ? 2
                      : 12,
            ),
            if ((profileData['bio'] != null && profileData['bio'].isNotEmpty) &&
                canViewPrivateContent)
              Text(
                profileData['bio'],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelBadge(String? level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_getLevelColor(level), _getLevelColor(level).withAlpha(80)],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: _getLevelColor(level).withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getLevelIcon(level), size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            level?.toUpperCase() ?? 'NO LEVEL',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo(
    Map<String, dynamic> profileData,
    BuildContext context,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                profileData['followers']?.toString() ?? '0',
                'Followers',
                Icons.people_outline,
                Colors.blue,
                onTap:
                    () => showFollowersFollowingDialog(context, widget.userId),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildStatCard(
                profileData['followings']?.toString() ?? '0',
                'Following',
                Icons.person_add_outlined,
                Colors.green,
                onTap:
                    () => showFollowersFollowingDialog(context, widget.userId),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildStatCard(
                profileData['achievements'] != null ? '1' : '0',
                'Achievements',
                Icons.emoji_events_outlined,
                Colors.orange,
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
      ],
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
        color: Colors.white,
        elevation: 0,
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
    );
  }

  // void _navigateToChat(Map<String, dynamic> profileData) {
  //   try {
  //    // final FireChatController chatController = Get.find<FireChatController>();

  //     final Map<String, dynamic> receiverUser = {
  //       'userId': profileData['_id'] ?? widget.userId,
  //       '_id': profileData['_id'] ?? widget.userId,
  //       'uid': profileData['_id'] ?? widget.userId,
  //       'name': profileData['name'] ?? 'Unknown User',
  //       'email': profileData['email'] ?? '',
  //       'photoURL': profileData['picture'] != null && profileData['picture'].isNotEmpty
  //           ? 'http://182.93.94.210:3067${profileData['picture']}'
  //           : null,
  //       'picture': profileData['picture'],
  //       'isOnline': profileData['isOnline'] ?? false,
  //       'lastSeen': profileData['lastSeen'],
  //     };

  //     chatController.addUserToRecent(receiverUser);
  //     chatController.navigateToChat(receiverUser);

  //     Get.snackbar(
  //       'Opening Chat',
  //       'Starting conversation with ${profileData['name'] ?? 'user'}',
  //       snackPosition: SnackPosition.BOTTOM,
  //       backgroundColor: const Color.fromRGBO(244, 135, 6, 1),
  //       colorText: Colors.white,
  //       duration: const Duration(seconds: 1),
  //       margin: const EdgeInsets.all(16),
  //       borderRadius: 8,
  //     );
  //   } catch (e) {
  //     print('Error navigating to chat: $e');

  //     Get.snackbar(
  //       'Error',
  //       'Unable to open chat. Please try again.',
  //       snackPosition: SnackPosition.BOTTOM,
  //       backgroundColor: Colors.red.withAlpha(80),
  //       colorText: Colors.white,
  //       duration: const Duration(seconds: 2),
  //       margin: const EdgeInsets.all(16),
  //       borderRadius: 8,
  //     );
  //   }
  // }

  Widget _buildPersonalInfo(
    Map<String, dynamic> profileData,
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.only(
          right: 20.0,
          left: 20.0,
          top: 10.0,
          bottom: 10.0,
        ),
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
            if (profileData['location'] != null &&
                profileData['location'].isNotEmpty)
              _buildInfoRow(
                Icons.location_on_outlined,
                null,
                profileData['location'],
                Colors.purple,
              ),
            if (profileData['gender'] != null)
              _buildInfoRow(
                Icons.person_outline,
                null,
                profileData['gender'],
                Colors.teal,
              ),
            if (isExpanded) ...[
              if (profileData['dob'] != null)
                _buildInfoRow(
                  Icons.cake_outlined,
                  null,
                  _formatDate(profileData['dob']),
                  Colors.pink,
                ),
              if (profileData['profession'] != null &&
                  profileData['profession'].isNotEmpty)
                _buildInfoRow(
                  Icons.work_outline,
                  null,
                  'Works as ${profileData['profession']}',
                  Colors.orange,
                ),
              if (profileData['education'] != null &&
                  profileData['education'].isNotEmpty)
                _buildInfoRow(
                  Icons.school_outlined,
                  null,
                  'Studies ${profileData['education']}',
                  Colors.indigo,
                ),
              if (profileData['achievements'] != null &&
                  profileData['achievements'].isNotEmpty)
                _buildInfoRow(
                  Icons.emoji_events_outlined,
                  'Achievements',
                  profileData['achievements'],
                  Colors.amber,
                ),
            ],
            TextButton(
              onPressed: () {
                setState(() {
                  isExpanded = !isExpanded;
                });
              },
              child: Text(
                isExpanded
                    ? 'See Less Information ...'
                    : 'See More Information ...',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String? label,
    String value,
    Color color, {
    VoidCallback? onTap,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: GestureDetector(
        onTap: onTap,
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
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String? text, String type) {
    if (text != null && text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$type copied to clipboard')));
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Not provided';
    try {
      final date = DateTime.parse(dateString);
      final months = [
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
    } catch (e) {
      return dateString;
    }
  }

  Color _getLevelColor(String? level) {
    switch (level?.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      case 'expert':
        return Colors.purple;
      default:
        return Colors.brown;
    }
  }

  IconData _getLevelIcon(String? level) {
    switch (level?.toLowerCase()) {
      case 'beginner':
        return Icons.looks_one;
      case 'intermediate':
        return Icons.looks_two;
      case 'advanced':
        return Icons.looks_3;
      case 'expert':
        return Icons.star;
      default:
        return Icons.star;
    }
  }
}
