import 'dart:async';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/Authorization/Login.dart';
import 'package:innovator/Innovator/constant/api_constants.dart';
import 'package:innovator/Innovator/constant/app_colors.dart';
import 'package:innovator/Innovator/controllers/user_controller.dart';
import 'package:innovator/Innovator/screens/Feed/Optimize%20Media/OptimizeMediaScreen.dart';
import 'package:innovator/Innovator/screens/Feed/Optimize%20Media/full_screen_image_viewer.dart';
import 'package:innovator/Innovator/screens/Feed/facebook_video_widget.dart';
import 'package:innovator/Innovator/screens/chatrrom/screen/chatlistscreen.dart';
import 'package:innovator/Innovator/widget/CustomizeFAB.dart';
import 'package:innovator/Innovator/widget/repost_button.dart';
import 'package:innovator/Innovator/screens/Feed/Repost/repost_list_screen.dart';
import 'package:innovator/Innovator/screens/Feed/Repost/sharedrepostcard.dart';
import 'package:innovator/Innovator/screens/Feed/Update%20Feed/API_Service.dart';
import 'package:innovator/Innovator/screens/Follow/follow_Button.dart';
import 'package:innovator/Innovator/screens/Likes/Content-Like-Service.dart';
import 'package:innovator/Innovator/screens/Likes/content-Like-Button.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:innovator/Innovator/screens/Likes/reaction_sheet_screen.dart';
import 'package:innovator/Innovator/screens/SHow_Specific_Profile/Show_Specific_Profile.dart';
import 'package:innovator/Innovator/screens/chatrrom/sound/soundplayer.dart';
import 'package:innovator/Innovator/screens/comment/comment_section.dart';
import 'package:innovator/Innovator/widget/Custom_refresh_Indicator.dart';
import 'dart:io';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';
import 'dart:developer' as developer;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../models/Feed_Content_Model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper classes
// ─────────────────────────────────────────────────────────────────────────────

class ContentResponse {
  final int status;
  final ContentData data;
  final dynamic error;
  final String message;

  ContentResponse({
    required this.status,
    required this.data,
    this.error,
    required this.message,
  });

  factory ContentResponse.fromJson(Map<String, dynamic> json) {
    return ContentResponse(
      status: json['status'] as int? ?? 200,
      data: ContentData.fromNewFeedApi(json['data'] ?? {}),
      error: json['error'],
      message: json['message'] as String? ?? '',
    );
  }
}

class FileTypeHelper {
  static bool isImage(String url) {
    try {
      final l = url.toLowerCase();
      return l.endsWith('.jpg') ||
          l.endsWith('.jpeg') ||
          l.endsWith('.png') ||
          l.endsWith('.gif') ||
          l.endsWith('.webp') ||
          l.contains('_thumb.jpg');
    } catch (_) {
      return false;
    }
  }

  static bool isVideo(String url) {
    try {
      final l = url.toLowerCase();
      return l.endsWith('.mp4') ||
          l.endsWith('.mov') ||
          l.endsWith('.avi') ||
          l.endsWith('.m3u8');
    } catch (_) {
      return false;
    }
  }

  static bool isPdf(String url) {
    try {
      return url.toLowerCase().endsWith('.pdf');
    } catch (_) {
      return false;
    }
  }

  static bool isWordDoc(String url) {
    try {
      final l = url.toLowerCase();
      return l.endsWith('.doc') || l.endsWith('.docx');
    } catch (_) {
      return false;
    }
  }
}

// CursorHelper — kept for compat (new API doesn't use cursors)
class CursorHelper {
  static bool isValidObjectId(String? cursor) {
    if (cursor == null || cursor.isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(cursor);
  }

  static String? extractObjectId(String? cursor) {
    if (cursor == null || cursor.isEmpty) return null;
    if (isValidObjectId(cursor)) return cursor;
    final m = RegExp(r'[0-9a-fA-F]{24}').firstMatch(cursor);
    if (m != null && isValidObjectId(m.group(0))) return m.group(0);
    return null;
  }

  static String? cleanCursor(String? cursor) {
    if (cursor == null || cursor.isEmpty || cursor == 'null') return null;
    if (isValidObjectId(cursor)) return cursor;
    return extractObjectId(cursor);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feed API Service — GET http://36.253.137.34:8005/api/posts/
// ─────────────────────────────────────────────────────────────────────────────

class FeedApiResponse {
  final int status;
  final Map<String, dynamic> data;
  final dynamic error;
  final String message;

  FeedApiResponse({
    required this.status,
    required this.data,
    this.error,
    required this.message,
  });

  factory FeedApiResponse.fromJson(Map<String, dynamic> json) {
    return FeedApiResponse(
      status: json['status'] as int? ?? 200,
      data: json['data'] as Map<String, dynamic>? ?? {},
      error: json['error'],
      message: json['message'] as String? ?? '',
    );
  }

  ContentData toContentData() => ContentData.fromNewFeedApi({'data': data});
}

class FeedApiService {
  //static const String baseUrl = 'http://36.253.137.34:8005';

  static Map<String, String> _headers() {
    final token = AppData().accessToken ?? '';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch feed posts with cursor-based pagination.
  ///
  /// First call: [cursor] = null  → GET /api/posts/
  /// Subsequent: [cursor] = full next URL returned by the server,
  ///             e.g. http://…/api/posts/?cursor=cD0yMDI2…
  ///
  /// Response shape:
  ///   { "next": "<url|null>", "previous": "<url|null>", "results": [...] }
  static Future<ContentData> fetchContents({
    String? cursor, // full "next" URL from previous response
    int limit = 20, // ignored — server controls page size (10)
    String contentType = 'normal',
    required BuildContext context,
  }) async {
    try {
      // If we have a cursor it IS the full next URL; otherwise use base endpoint
      final uri =
          cursor != null && cursor.isNotEmpty
              ? Uri.parse(cursor)
              : Uri.parse(ApiConstants.post);

      developer.log('[Feed] GET $uri');

      final response = await http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 30));

      developer.log('[Feed] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        return ContentData.fromNewFeedApi(decoded);
      } else if (response.statusCode == 401) {
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => LoginPage()),
            (_) => false,
          );
        }
        throw Exception('Authentication required');
      } else {
        throw Exception('Failed to load feed: \${response.statusCode}');
      }
    } catch (e) {
      developer.log('[Feed] fetchContents error: \$e');
      rethrow;
    }
  }

  /// Offset-based fallback — delegates to cursor fetch without a cursor.
  static Future<ContentData> fetchContentsWithOffset({
    int offset = 0,
    int limit = 20,
    String contentType = 'normal',
    required BuildContext context,
  }) => fetchContents(
    cursor: null,
    limit: limit,
    contentType: contentType,
    context: context,
  );

  /// No-op — kept for call-site compatibility.
  static Future<void> testCursorFormat() async {
    developer.log('[Feed] Cursor pagination handled by server (next URL)');
  }

  static Future<ContentData> refreshFeed({
    String contentType = 'normal',
    required BuildContext context,
  }) => fetchContents(
    cursor: null,
    limit: 20,
    contentType: contentType,
    context: context,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ContentData
// ─────────────────────────────────────────────────────────────────────────────

class ContentData {
  final List<FeedContent> contents;
  final bool hasMore;
  final String? nextCursor;

  const ContentData({
    required this.contents,
    required this.hasMore,
    this.nextCursor,
  });

  factory ContentData.fromNewFeedApi(dynamic rawJson) {
    try {
      List<dynamic> postList = [];
      String? nextCursor; // full URL for the next page
      bool hasMore = false;

      if (rawJson is List) {
        // Plain flat array (legacy responses)
        postList = rawJson;
      } else if (rawJson is Map<String, dynamic>) {
        // Cursor-paginated DRF response:
        //   { "next": "http://…?cursor=…", "previous": "…", "results": [...] }
        final rawNext = rawJson['next'];
        if (rawNext != null && rawNext.toString().isNotEmpty) {
          nextCursor = rawNext.toString(); // store full URL as cursor
          hasMore = true;
        }

        postList =
            rawJson['results'] as List? ??
            rawJson['data'] as List? ??
            rawJson['posts'] as List? ??
            [];
      }

      developer.log(
        '[Feed] Parsing ${postList.length} posts — '
        'hasMore: $hasMore — next: $nextCursor',
      );

      final contents =
          postList
              .whereType<Map<String, dynamic>>()
              .map((item) {
                try {
                  return FeedContent.fromNewApiPost(item);
                } catch (e) {
                  developer.log('[Feed] Parse error: $e');
                  return null;
                }
              })
              .whereType<FeedContent>()
              .where((c) => c.id.isNotEmpty)
              .toList();

      developer.log('[Feed] ✓ ${contents.length} valid posts');
      _cacheAuthors(contents);

      return ContentData(
        contents: contents,
        hasMore: hasMore,
        nextCursor: nextCursor,
      );
    } catch (e) {
      developer.log('[Feed] ContentData error: $e');
      return const ContentData(contents: [], hasMore: false);
    }
  }

  factory ContentData.fromJson(Map<String, dynamic> json) =>
      ContentData.fromNewFeedApi(json);

  static void _cacheAuthors(List<FeedContent> contents) {
    // Phase 1 — batch-insert every author from this page into the controller's
    // HashMap in a single O(n) pass.  Avatar URLs from the new API are already
    // absolute, so no URL-building is done here.  This runs synchronously
    // before the first frame is painted — same as Facebook's feed pre-loading.
    try {
      if (!Get.isRegistered<UserController>()) return;
      final uc = Get.find<UserController>();
      final userMaps =
          contents
              .map(
                (c) => <String, dynamic>{
                  'user_id': c.author.id,
                  'username': c.author.name,
                  'avatar': c.author.picture,
                },
              )
              .toList();
      uc.cacheFromFeedPosts(userMaps);
    } catch (_) {}
  }

  bool get isEmpty => contents.isEmpty;
  int get totalCount => contents.length;
}

// ─────────────────────────────────────────────────────────────────────────────
// Inner_HomePage
// ─────────────────────────────────────────────────────────────────────────────

class Inner_HomePage extends ConsumerStatefulWidget {
  const Inner_HomePage({Key? key}) : super(key: key);

  @override
  _Inner_HomePageState createState() => _Inner_HomePageState();
}

class _Inner_HomePageState extends ConsumerState<Inner_HomePage> {
  final List<FeedContent> _allContents = [];
  final ScrollController _scrollController = ScrollController();
  final AppData _appData = AppData();

  Set<int> _suggestedUsersShownAt = {};
  List<int> _suggestionPositions = [];

  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _hasMoreContent = false;
  String? _nextCursor;
  bool _isOnline = true;
  bool _isInitialLoad = true;
  bool _hasInitialData = false;
  bool _isLoadingMore = false;

  int _currentOffset = 0;
  bool _useCursorPagination = false;

  Timer? _scrollDebounce;
  bool _isNearBottom = false;
  double _lastScrollPosition = 0;
  static const double _scrollThreshold = 0.8;
  static const int _preloadDistance = 300;
  static const int _maxContentItems = 100;
  static const int _itemsToRemoveOnCleanup = 100;

  DateTime _lastLoadTime = DateTime.now();
  static const int _minimumLoadInterval = 500;
  static List<FeedContent> _cachedContents = [];
  static String? _cachedNextCursor;
  static bool _cachedHasMore = false;
  final Map<String, bool> _reactionState = {};

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<UserController>()) Get.put(UserController());
    // _requestNotificationPermission();
    _initializeInfiniteScroll();
    _checkConnectivity();
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> _initializeInfiniteScroll() async {
    try {
      await _appData.initialize();
      if (await _verifyToken()) {
        await _loadInitialContent();
        _setupScrollListener();
        _isInitialLoad = false;
        _hasInitialData = true;
      }
    } catch (e) {
      developer.log('Error initializing feed: $e');
      _handleError('Failed to initialize feed');
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      _scrollDebounce?.cancel();
      _scrollDebounce = Timer(
        const Duration(milliseconds: 150),
        _handleScrollEvent,
      );
    });
  }

  void _handleScrollEvent() {
    if (!_scrollController.hasClients ||
        _isLoading ||
        !_hasMoreContent ||
        _isLoadingMore)
      return;

    final position = _scrollController.position;
    final currentScroll = position.pixels;
    final maxScroll = position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final scrollPercentage = currentScroll / maxScroll;
    _isNearBottom = scrollPercentage >= _scrollThreshold;

    if (_shouldLoadMoreContent(currentScroll, maxScroll, scrollPercentage)) {
      _loadMoreContent();
    }
    _lastScrollPosition = currentScroll;
  }

  bool _shouldLoadMoreContent(
    double currentScroll,
    double maxScroll,
    double scrollPercentage,
  ) {
    if (_isLoading || !_hasMoreContent || _isLoadingMore) return false;
    final elapsed = DateTime.now().difference(_lastLoadTime);
    if (elapsed.inMilliseconds < _minimumLoadInterval) return false;
    if (scrollPercentage >= _scrollThreshold) return true;
    if (maxScroll - currentScroll <= _preloadDistance) return true;
    if (scrollPercentage >= 0.85) return true;
    if (_allContents.length < 20 && scrollPercentage >= 0.7) return true;
    return false;
  }

  void _preloadVisibleUsers() {
    // Phase 2 — parallel avatar prefetch using Future.wait.
    // All N images are fetched concurrently (not sequentially), so the entire
    // first screenful of avatars is ready before the user even scrolls —
    // the same technique Instagram uses for feed thumbnails.
    if (_allContents.isEmpty) return;
    try {
      final uc = Get.find<UserController>();
      final ids =
          _allContents
              .take(20)
              .map((c) => c.author.id)
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();
      if (ids.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => uc.prefetchAvatars(ids, context),
        );
      }
    } catch (e) {
      developer.log('prefetchAvatars error: $e');
    }
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> _loadInitialContent() async {
    developer.log('[Feed] Loading initial content...');
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    try {
      await FeedApiService.testCursorFormat();
      final data = await FeedApiService.fetchContents(
        cursor: null,
        limit: 20,
        contentType: 'normal',
        context: context,
      );
      if (mounted) {
        setState(() {
          _allContents.clear();
          _allContents.addAll(data.contents);
          _nextCursor = data.nextCursor; // full URL or null
          _hasMoreContent = data.hasMore;
          _isLoading = false;
          _currentOffset = data.contents.length;
          _useCursorPagination = true;
        });
        _preloadVisibleUsers();
        developer.log('[Feed] Initial: ${_allContents.length} posts');
      }
    } catch (e) {
      developer.log('[Feed] loadInitialContent error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreContent() async {
    if (_isLoading || !_hasMoreContent || _isLoadingMore) return;
    developer.log('[Feed] Loading more...');
    setState(() {
      _isLoading = true;
      _isLoadingMore = true;
      _hasError = false;
    });
    _lastLoadTime = DateTime.now();
    try {
      // Pass the full next-page URL returned by the server
      final data = await FeedApiService.fetchContents(
        cursor: _nextCursor,
        limit: 20,
        context: context,
      );
      if (mounted) {
        setState(() {
          _allContents.addAll(data.contents);
          _nextCursor = data.nextCursor; // update cursor for next page
          _hasMoreContent = data.hasMore;
          _isLoading = false;
          _isLoadingMore = false;
        });
        if (_allContents.length > _maxContentItems) _manageMemoryUsage();
      }
    } catch (e) {
      developer.log('[Feed] loadMoreContent error: $e');
      if (mounted)
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
    }
  }

  void _manageMemoryUsage() {
    if (_allContents.length <= _maxContentItems) return;
    final toRemove = (_allContents.length - _maxContentItems + 50).clamp(
      0,
      _itemsToRemoveOnCleanup,
    );
    if (toRemove <= 0) return;
    final scrollPos =
        _scrollController.hasClients ? _scrollController.position.pixels : 0.0;
    _allContents.removeRange(0, toRemove);
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          try {
            _scrollController.jumpTo(
              math.max(0.0, scrollPos - toRemove * 400.0),
            );
          } catch (_) {}
        }
      });
    }
  }

  Future<void> _refresh() async {
    developer.log('[Feed] Refreshing...');
    _suggestedUsersShownAt.clear();
    _suggestionPositions.clear();
    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    _nextCursor = null;
    _currentOffset = 0;
    _hasMoreContent = false;
    _useCursorPagination = false;
    _lastLoadTime = DateTime.now().subtract(const Duration(seconds: 2));

    try {
      final data = await FeedApiService.refreshFeed(
        contentType: 'normal',
        context: context,
      );
      if (mounted) {
        setState(() {
          _allContents.clear();
          _allContents.addAll(data.contents);
          _nextCursor = data.nextCursor;
          _hasMoreContent = data.hasMore;
          _isLoading = false;
          _currentOffset = data.contents.length;
        });
        developer.log('[Feed] Refreshed: ${_allContents.length} posts');
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    } catch (e) {
      developer.log('[Feed] refresh error: $e');
      _handleError('Failed to refresh feed');
    }
  }

  Future<void> _retryLoadWithDifferentParams() async {
    setState(() {
      _nextCursor = null;
      _currentOffset = 0;
      _hasMoreContent = true;
      _hasError = false;
      _useCursorPagination = true;
    });
    await _loadMoreContent();
  }

  void _handleError(String message) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _hasError = true;
        _errorMessage = message;
      });
    }
  }

  // ── Auth / Connectivity ────────────────────────────────────────────────────

  Future<bool> _verifyToken() async {
    try {
      if (_appData.accessToken == null || _appData.accessToken!.isEmpty) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Authentication required. Please login.';
        });
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => LoginPage()),
            (_) => false,
          );
        }
        return false;
      }
      return true;
    } catch (e) {
      developer.log('verifyToken error: $e');
      return false;
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (!mounted) return; // ← ADD THIS
      setState(() {
        _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      });
      if (_isOnline) _refresh();
    } on SocketException catch (_) {
      if (!mounted) return; // ← ADD THIS
      setState(() => _isOnline = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // final realtimeUnread = ref.watch(perFriendUnreadProvider);
    //final unreadCount = realtimeUnread.values.fold(0, (a, b) => a + b);
    final unreadCount = ref.watch(chatUnreadCountProvider);
    return Scaffold(
      backgroundColor: AppColors.whitecolor,
      body: CustomRefreshIndicator(
        onRefresh: _refresh,
        gifPath: 'animation/IdeaBulb.gif',
        child: _buildContent(),
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

  Widget _buildContent() {
    // Show shimmer skeleton on initial load AND during pull-to-refresh
    if ((_isInitialLoad || _isLoading) && _allContents.isEmpty) {
      return _buildShimmerList();
    }
    if (_hasError && _allContents.isEmpty) return _buildErrorState();
    return _buildInfiniteScrollList();
  }

  // Kept for API compat — actual initial load now uses _buildShimmerList()
  Widget _buildInitialLoadingState() => _buildShimmerList();
  // Returns a scrollable list of shimmer skeleton cards
  Widget _buildShimmerList() => const _ShimmerFeedList();

  Widget _buildErrorState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(
          'Oops! Something went wrong',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: AppColors.whitecolor,
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _retryLoadWithDifferentParams,
              icon: const Icon(Icons.replay),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: AppColors.whitecolor,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildInfiniteScrollList() {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                cacheExtent: 300.0,
                itemCount: _calculateTotalItemCount(),
                itemBuilder: (context, index) => _buildListItem(index),
              ),
            ),
          ],
        ),
        // During refresh when we already have content, show a thin
        // orange progress bar at the top instead of blocking the feed
        if (_isLoading && _allContents.isNotEmpty)
          const Positioned(top: 0, left: 0, right: 0, child: _FeedRefreshBar()),
      ],
    );
  }

  int _calculateTotalItemCount() {
    int n = _allContents.length;
    if (_isLoading) n++;
    if (_shouldShowEndMessage()) n++;
    n += _suggestionPositions.length;
    return n;
  }

  List<int> _getSuggestedUsersPositions() =>
      List.from(_suggestionPositions)..sort();

  int _getAdjustedContentIndex(int listIndex) {
    final positions = _getSuggestedUsersPositions();
    int count = 0;
    for (final pos in positions) {
      if (pos + count < listIndex)
        count++;
      else
        break;
    }
    return listIndex - count;
  }

  Widget _buildListItem(int index) {
    final adjusted = _getAdjustedContentIndex(index);
    if (adjusted < _allContents.length) {
      return buildContentItem(_allContents[adjusted], adjusted);
    }
    if (adjusted == _allContents.length && _isLoading) {
      return _buildLoadingIndicator();
    }
    // if (adjusted == _allContents.length && _shouldShowEndMessage()) {
    //   return _buildEndMessage();
    // }
    return const SizedBox.shrink();
  }

  Widget buildContentItem(FeedContent content, int index) {
    return RepaintBoundary(
      key: ValueKey(content.id),
      child: FeedItem(
        content: content,
        onLikeToggled: (hasReaction) {
          if (!mounted) return;
          setState(() {
            final hadReaction = _reactionState[content.id] ?? content.isLiked;
            // Only change count when presence changes (not on type switch 👍→❤️)
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
            // Update ALL posts by same author — not just this one card
            final authorId = content.author.id;
            for (final c in _allContents) {
              if (c.author.id == authorId) {
                c.isFollowed = isFollowed;
              }
            }
          });
        },
        onDeleted: () {
          if (mounted) setState(() => _allContents.remove(content));
        },
        onStatusUpdated: (newStatus) {
          if (mounted) setState(() => content.status = newStatus);
        },
        // onCommentAdded: () {
        //   if (mounted) setState(() => content.comments++);
        // },
      ),
    );
  }

  // Bottom-of-list indicator: shows 2 shimmer cards while loading more
  Widget _buildLoadingIndicator() =>
      Column(children: [const _ShimmerFeedCard(), const _ShimmerFeedCard()]);

  // Widget _buildEndMessage() => Container(
  //   padding: const EdgeInsets.all(20),
  //   child: Column(
  //     children: [
  //       Icon(Icons.check_circle_outline, color: Colors.grey[400], size: 32),
  //       const SizedBox(height: 8),
  //       Text(
  //         "You're all caught up!",
  //         style: TextStyle(
  //           color: Colors.grey[600],
  //           fontSize: 16,
  //           fontWeight: FontWeight.w500,
  //         ),
  //       ),
  //       Text(
  //         'No more posts to show',
  //         style: TextStyle(color: Colors.grey[400], fontSize: 12),
  //       ),
  //     ],
  //   ),
  // );

  bool _shouldShowEndMessage() =>
      !_isLoading && !_hasMoreContent && _allContents.isNotEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
// FeedItem
// ─────────────────────────────────────────────────────────────────────────────

class FeedItem extends StatefulWidget {
  final FeedContent content;
  final Function(bool) onLikeToggled;
  final Function(bool) onFollowToggled;
  final VoidCallback? onDeleted;
  final Function(String)? onStatusUpdated;
  final VoidCallback? onCommentAdded;

  const FeedItem({
    Key? key,
    required this.content,
    required this.onLikeToggled,
    required this.onFollowToggled,
    this.onDeleted,
    this.onStatusUpdated,
    this.onCommentAdded,
  }) : super(key: key);

  @override
  State<FeedItem> createState() => _FeedItemState();
}

class _FeedItemState extends State<FeedItem>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  static const int _maxLinesCollapsed = 3;
  bool _hasRecordedView = false;
  late AnimationController _controller;
  late String formattedTimeAgo;
  bool _showComments = false;
  // final List<RepostEntry> _entries = [];

  final ContentLikeService likeService = ContentLikeService(
    baseUrl: 'http://36.253.137.34:8005',
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    formattedTimeAgo = _formatTimeAgo(widget.content.createdAt);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordView());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _mapReportReason(String uiReason) {
    const Map<String, String> reasonMap = {
      'Spam': 'spam',
      'Harassment': 'harassment',
      'Inappropriate content': 'inappropriate_content',
      'Fake account': 'fake_account',
      'Copyright violation': 'copyright_violation',
      'Other': 'other',
    };
    return reasonMap[uiReason] ?? uiReason.toLowerCase().replaceAll(' ', '_');
  }

  String _formatTimeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays > 365) return '${(d.inDays / 365).floor()} years ago';
    if (d.inDays > 30) return '${(d.inDays / 30).floor()} months ago';
    if (d.inDays > 0) return '${d.inDays} days ago';
    if (d.inHours > 0) return '${d.inHours} hours ago';
    if (d.inMinutes > 0) return '${d.inMinutes} minutes ago';
    return 'Just now';
  }

  Future<bool> _checkConnectivity() async {
    try {
      final res = await Connectivity().checkConnectivity();
      return res.contains(ConnectivityResult.wifi) ||
          res.contains(ConnectivityResult.mobile) ||
          res.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }

  Future<void> _recordView() async {
    if (_hasRecordedView || !await _checkConnectivity()) return;
    _hasRecordedView = true;
    try {
      final token = AppData().accessToken;
      if (token == null || token.isEmpty) return;
      final response = await http
          .post(
            Uri.parse('${ApiConstants.recordview}${widget.content.id}/view/'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 401) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()),
          (_) => false,
        );
      }
    } catch (e) {
      _hasRecordedView = false;
      developer.log('recordView error: $e');
    }
  }

  bool _isAuthorCurrentUser() {
    return AppData().isMe(widget.content.author.id) ||
        AppData().isCurrentUserByUsername(widget.content.author.name);
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'innovation':
        return Colors.amber.shade700;
      case 'idea':
        return Colors.teal.shade600;
      case 'project':
        return Colors.indigo.shade600;
      case 'question':
        return Colors.orange.shade600;
      case 'announcement':
        return Colors.deepPurple.shade600;
      case 'fun':
        return Colors.pink.shade500;
      case 'technology':
        return Colors.blue.shade600;
      case 'other':
        return Colors.grey.shade600;
      default:
        return Colors.blueGrey.shade600;
    }
  }

  // ── Avatar ────────────────────────────────────────────────────────────────

  Widget _buildAuthorAvatar() {
    // Single source of truth: post['avatar'] field, already absolute URL.
    // Same logic for every user — own or other. No controller, no cache lookup.
    // CachedNetworkImage handles memory + disk caching with its own stable key.
    final avatarUrl =
        widget.content.author.picture.isNotEmpty
            ? widget.content.author.picture
            : null;
    final initial =
        widget.content.author.name.isNotEmpty
            ? widget.content.author.name[0].toUpperCase()
            : '?';

    if (avatarUrl == null) {
      // No avatar in API response — show initial letter
      return CircleAvatar(
        backgroundColor: Colors.grey.shade300,
        child: Text(
          initial,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.whitecolor,
            fontSize: 16,
          ),
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatarUrl,
        cacheKey: 'feed_avatar_${widget.content.author.id}',
        // width: 44,
        // height: 44,
        fit: BoxFit.cover,
        // memCacheWidth: 88,
        // memCacheHeight: 88,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder:
            (ctx, url) => CircleAvatar(
              backgroundColor: Colors.grey.shade200,
              child: Text(
                initial,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        errorWidget:
            (ctx, url, err) => CircleAvatar(
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

  // ── Main build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isOwnContent = _isAuthorCurrentUser();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        // border: Border(
        //   top: BorderSide(color: Colors.grey.shade200, width: 1.0),
        //   bottom: BorderSide(color: Colors.grey.shade200, width: 1.0),
        // ),
        color: AppColors.whitecolor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20.0),
          bottomRight: Radius.circular(20.0),
          topLeft: Radius.circular(5.0),
          topRight: Radius.circular(5.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 20.0,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => FullScreenImageViewer(
                            imageUrl: widget.content.author.picture,
                            tag:
                                'avatar_${widget.content.author.id}_${widget.content.id}',
                          ),
                    ),
                  );
                },
                child: Hero(
                  tag:
                      'avatar_${widget.content.author.id}_${widget.content.id}',
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color.fromRGBO(244, 135, 6, 1),
                          Color.fromRGBO(255, 204, 0, 1),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orangeAccent.shade100,
                          blurRadius: 12.0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(2.0),
                    child: _buildAuthorAvatar(),
                  ),
                ),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: GestureDetector(
                  onTap:
                      () => Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (ctx, a, _) => SpecificUserProfilePage(
                                userId: widget.content.author.id,
                              ),
                          transitionsBuilder:
                              (ctx, a, _, child) => SlideTransition(
                                position: a.drive(
                                  Tween(
                                    begin: const Offset(1.0, 0.0),
                                    end: Offset.zero,
                                  ),
                                ),
                                child: child,
                              ),
                        ),
                      ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            FittedBox(
                              child: Text(
                                widget.content.author.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16.0,
                                  fontFamily: 'InterThin',
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              width: 4.0,
                              height: 4.0,
                              decoration: BoxDecoration(
                                color: _getTypeColor(widget.content.type),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 8.0),
                            if (!isOwnContent) ...[
                              // GestureDetector here absorbs taps so the
                              // parent's onTap (navigate to profile) is NOT
                              // triggered when the Follow button is pressed.
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap:
                                    () {}, // absorb — FollowButton handles its own tap
                                child: FollowButton(
                                  targetUserId: widget.content.author.id,
                                  initialFollowStatus:
                                      widget.content.isFollowed,
                                  onFollowSuccess: () {
                                    SoundPlayer().FollowSound();
                                    developer.log(
                                      'Follow success: \${widget.content.author.name}',
                                    );
                                    if (mounted) {
                                      setState(
                                        () => widget.content.isFollowed = true,
                                      );
                                      widget.onFollowToggled(true);
                                    }
                                  },
                                  onUnfollowSuccess: () {
                                    SoundPlayer().FollowSound();
                                    developer.log(
                                      'Unfollow success: \${widget.content.author.name}',
                                    );
                                    if (mounted) {
                                      setState(
                                        () => widget.content.isFollowed = false,
                                      );
                                      widget.onFollowToggled(false);
                                    }
                                  },
                                ),
                              ),
                            ],
                            const Spacer(),
                            InkWell(
                              borderRadius: BorderRadius.circular(12.0),
                              onTap: () {
                                if (_isAuthorCurrentUser()) {
                                  _showQuickSuggestions(context);
                                } else {
                                  _showQuickspecificSuggestions(context);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.more_vert_rounded,
                                  color: Colors.grey.shade600,
                                  size: 20.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          const SizedBox(width: 4.0),
                          Text(
                            formattedTimeAgo,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 2.0,
                            ),
                            child: Text(
                              widget.content.type.toUpperCase(),
                              style: TextStyle(
                                color: _getTypeColor(widget.content.type),
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.7,
                                fontFamily: 'InterThin',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Content
          if (widget.content.status.isNotEmpty)
            Container(
              padding: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                bottom: widget.content.files.isNotEmpty ? 8.0 : 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final span = TextSpan(
                        text: widget.content.status,
                        style: const TextStyle(
                          fontSize: 15.0,
                          fontFamily: 'InterThin',
                        ),
                      );
                      final tp = TextPainter(
                        text: span,
                        maxLines: _maxLinesCollapsed,
                        textDirection: TextDirection.ltr,
                      )..layout(maxWidth: constraints.maxWidth);
                      final needsToggle = tp.didExceedMaxLines;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: _LinkifyText(
                              text: widget.content.status,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.6,
                                fontStyle: FontStyle.normal,
                                fontFamily: 'InterThin',
                              ),
                              maxLines: _isExpanded ? null : _maxLinesCollapsed,
                              overflow:
                                  _isExpanded ? null : TextOverflow.ellipsis,
                            ),
                          ),
                          if (needsToggle)
                            InkWell(
                              onTap:
                                  () => setState(
                                    () => _isExpanded = !_isExpanded,
                                  ),
                              child: Text(
                                _isExpanded ? 'See Less' : 'See More',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

          // Media
          if (widget.content.isRepost &&
              widget.content.sharedPostDetails != null)
            SharedPostCard(details: widget.content.sharedPostDetails!),

          // Own media (only shown when NOT a repost)
          if (!widget.content.isRepost && widget.content.files.isNotEmpty)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 1.0),
              child: _buildMediaPreview(),
            ),
          const SizedBox(height: 10.0),
          Divider(
            color: Colors.grey.shade300,
            endIndent: 10,
            indent: 10,
            height: 1.0,
            thickness: 1.0,
          ),
          const SizedBox(height: 10),

          // Action bar
          Padding(
            padding: EdgeInsets.only(
              right: 10,
              left: 10,
              bottom: 13,
              // top: 10,
            ),
            child: Row(
              //mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  children: [
                    LikeButton(
                      contentId: widget.content.id,
                      initialLikeStatus: widget.content.isLiked,
                      likeService: likeService,
                      initialReactionType: widget.content.currentUserReaction,
                      onLikeToggled: (isLiked) {
                        widget.onLikeToggled(isLiked);
                        SoundPlayer().playlikeSound();
                      },
                    ),
                    //const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _showReactionsList(context),
                      child: Text(
                        '${widget.content.likes} Likes',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                          fontSize: 11.0,
                        ),
                      ),
                    ),
                    //_buildReactionBubbles(),
                  ],
                ),
                const SizedBox(width: 30),
                Row(
                  children: [
                    InkWell(
                      onTap:
                          () => setState(() => _showComments = !_showComments),
                      child: Image.asset(
                        'assets/icon/comment.png',
                        color:
                            _showComments
                                ? Colors.blue.shade700
                                : Colors.grey.shade800,
                        width: 25,
                        height: 25,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${widget.content.comments} Comments',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                        fontSize: 11.0,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 20),
                Row(
                  children: [
                    RepostButton(
                      postId: widget.content.id,
                      authorName: widget.content.author.name,
                      content: widget.content.status,
                      authorAvatar:
                          widget.content.author.picture.isNotEmpty
                              ? widget.content.author.picture
                              : null,
                      onViewReposts: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => RepostsListScreen(
                                  postId: widget.content.id,
                                  originalAuthorName:
                                      widget.content.author.name,
                                ),
                          ),
                        );
                      },
                    ),
                    // CountPill(count: _entries.length),
                    //CountPill(count: widget.content., label: 'Reposts'),
                  ],
                ),
                const Spacer(),
                InkWell(
                  onTap: () => _showShareOptions(context),
                  child: Image.asset(
                    'assets/icon/send.png',
                    width: 20,
                    height: 20,
                  ),
                ),
              ],
            ),
          ),

          // Comments
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child:
                _showComments
                    ? Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20.0),
                          bottomRight: Radius.circular(20.0),
                        ),
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: CommentSection(
                        contentId: widget.content.id,

                        // onCommentAdded: () {
                        //   setState(() => widget.content.comments++);
                        //   widget.onCommentAdded?.call();
                        // },
                        onCommentCountChanged: (delta) {
                          setState(
                            () =>
                                widget.content.comments =
                                    (widget.content.comments + delta).clamp(
                                      0,
                                      999999,
                                    ),
                          );
                        },
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _showReactionsList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => reeactionsheet(postId: widget.content.id),
    );
  }

  // ── Media ─────────────────────────────────────────────────────────────────

  Widget _buildMediaPreview() {
    final hasOptimizedImages = widget.content.optimizedFiles.any(
      (f) => f['type'] == 'image',
    );

    if (hasOptimizedImages) {
      final imageUrls =
          widget.content.optimizedFiles
              .where((f) => f['type'] == 'image')
              .map((f) => f['original'] ?? f['url'] ?? f['thumbnail'])
              .where((url) => url != null)
              .map((url) => widget.content.formatUrl(url))
              .toList();
      if (imageUrls.isNotEmpty) return _buildImageGallery(imageUrls);
    }

    final mediaUrls = widget.content.mediaUrls;
    if (mediaUrls.isEmpty) return const SizedBox.shrink();

    if (mediaUrls.length == 1) {
      final fileUrl = mediaUrls.first;
      if (FileTypeHelper.isImage(fileUrl)) return _buildSingleImage(fileUrl);
      if (FileTypeHelper.isVideo(fileUrl)) {
        return FacebookVideoWidget(
          url: fileUrl,
          thumbnailUrl: widget.content.thumbnailUrl,
          startMuted: true,
          looping: true,
        );
      }
      if (FileTypeHelper.isPdf(fileUrl)) {
        return _buildDocumentPreview(
          fileUrl,
          'PDF Document',
          Icons.picture_as_pdf,
          Colors.red,
        );
      }
      if (FileTypeHelper.isWordDoc(fileUrl)) {
        return _buildDocumentPreview(
          fileUrl,
          'Word Document',
          Icons.description,
          Colors.blue,
        );
      }
    }
    return _buildImageGallery(mediaUrls);
  }

  Widget _buildSingleImage(String url) => GestureDetector(
    onTap: () => _showMediaGallery(context, [url], 0),
    child: Container(
      width: double.infinity,
      alignment: Alignment.center,
      child: CachedNetworkImage(
        filterQuality: FilterQuality.high,
        imageUrl: url,
        fit: BoxFit.contain,
        memCacheWidth: (MediaQuery.of(context).size.width * 1.5).toInt(),
        placeholder:
            (_, __) => Container(
              height: 250,
              color: Colors.grey[300],
              child: Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Image.asset(
                    'animation/IdeaBulb.gif',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
        errorWidget:
            (_, __, ___) => Container(
              height: 250,
              color: Colors.grey[300],
              child: const Icon(Icons.error),
            ),
      ),
    ),
  );

  Widget _buildImageGallery(List<String> urls) {
    if (urls.length == 1) return _buildSingleImage(urls[0]);
    if (urls.length == 2) {
      return Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 2),
              child: _buildGridImage(urls[0], 0, urls),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 2),
              child: _buildGridImage(urls[1], 1, urls),
            ),
          ),
        ],
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 4.0,
          mainAxisSpacing: 4.0,
          childAspectRatio: 1.0,
        ),
        itemCount: urls.length > 4 ? 4 : urls.length,
        itemBuilder: (context, index) {
          if (index == 3 && urls.length > 4) {
            return GestureDetector(
              onTap: () => _showMediaGallery(context, urls, index),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildGridImage(urls[index], index, urls),
                  Container(
                    color: Colors.black.withAlpha(60),
                    child: Center(
                      child: Text(
                        '+${urls.length - 4}',
                        style: const TextStyle(
                          color: AppColors.whitecolor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return _buildGridImage(urls[index], index, urls);
        },
      ),
    );
  }

  Widget _buildGridImage(String url, int index, List<String> allUrls) =>
      GestureDetector(
        onTap: () => _showMediaGallery(context, allUrls, index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            alignment: Alignment.center,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              memCacheWidth: (MediaQuery.of(context).size.width * 0.75).toInt(),
              placeholder:
                  (_, __) => Container(
                    color: Colors.grey[300],
                    child: Center(
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: Image.asset(
                          'animation/IdeaBulb.gif',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
              errorWidget:
                  (_, __, ___) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.error, color: AppColors.whitecolor),
                  ),
            ),
          ),
        ),
      );

  Widget _buildDocumentPreview(
    String fileUrl,
    String label,
    IconData icon,
    Color color,
  ) => GestureDetector(
    onTap: () => _showMediaGallery(context, [fileUrl], 0),
    child: Container(
      height: 180.0,
      width: double.infinity,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: color),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[800])),
        ],
      ),
    ),
  );

  void _showMediaGallery(
    BuildContext context,
    List<String> mediaUrls,
    int initialIndex,
  ) {
    final selectedUrl = mediaUrls[initialIndex];
    if (FileTypeHelper.isVideo(selectedUrl)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => FacebookFullscreenPage(
                // ← correct widget
                url: selectedUrl,
                thumbnailUrl: widget.content.thumbnailUrl,
              ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => OptimizedMediaGalleryScreen(
              mediaUrls: mediaUrls,
              initialIndex: initialIndex,
            ),
      ),
    );
  }

  // ── Share ─────────────────────────────────────────────────────────────────

  void _showShareOptions(BuildContext context) {
    final shareTextController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => Container(
            decoration: const BoxDecoration(
              color: AppColors.whitecolor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Share Post',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: shareTextController,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  _buildShareOption(
                    icon: Icons.link,
                    title: 'Copy Link',
                    subtitle: 'Copy post link to clipboard',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      _shareContent(shareTextController.text);
                    },
                  ),
                  _buildShareOption(
                    icon: Icons.share,
                    title: 'Share via Apps',
                    subtitle: 'Share using other apps',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      _shareViaApps();
                    },
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) => ListTile(
    leading: CircleAvatar(
      backgroundColor: color.withAlpha(10),
      child: Icon(icon, color: color),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
    subtitle: Text(
      subtitle,
      style: TextStyle(color: Colors.grey[600], fontSize: 12),
    ),
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
  );

  Future<void> _shareContent(String? shareText) async {
    try {
      final token = AppData().accessToken;
      if (token == null || token.isEmpty) {
        Get.snackbar(
          'Error',
          'Authentication required to share content',
          backgroundColor: Colors.red,
          colorText: AppColors.whitecolor,
        );
        return;
      }
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black26,
        builder:
            (_) => const Center(
              child: SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: Color.fromRGBO(244, 135, 6, 1),
                  strokeWidth: 3,
                ),
              ),
            ),
      );
      final response = await http.post(
        Uri.parse(ApiConstants.post),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'content': shareText ?? '',
          'shared_post': widget.content.id,
        }),
      );
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppColors.whitecolor,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Post shared successfully',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      developer.log('shareContent error: $e');
    }
  }

  void _shareViaApps() async {
    try {
      final shareText =
          'Check out this post by ${widget.content.author.name}: '
          '${widget.content.status}';
      await Share.share(shareText);
    } catch (e) {
      developer.log('shareViaApps error: $e');
    }
  }

  // ── Owner context menu ────────────────────────────────────────────────────

  void _showQuickSuggestions(BuildContext context) {
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (_) => Container(
            decoration: BoxDecoration(
              color: AppColors.whitecolor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.edit, color: Color(0xFFF48706)),
                  title: const Text('Edit content'),
                  onTap: () => Navigator.pop(context, 'edit'),
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete post'),
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
                ListTile(
                  leading: const Icon(Icons.copy, color: Colors.blue),
                  title: const Text('Copy content'),
                  onTap: () => Navigator.pop(context, 'copy'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    ).then((value) async {
      if (value == 'edit') await _handleEditContent();
      if (value == 'delete') await _handleDeleteContent();
      if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: widget.content.status));
        Get.snackbar(
          'Copied',
          'Content copied to clipboard',
          backgroundColor: Colors.green.withAlpha(80),
          colorText: AppColors.whitecolor,
          duration: const Duration(seconds: 1),
        );
      }
    });
  }

  // ── Viewer context menu ───────────────────────────────────────────────────

  void _showQuickspecificSuggestions(BuildContext context) {
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (_) => Container(
            decoration: BoxDecoration(
              color: AppColors.whitecolor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.copy, color: Colors.blue),
                  title: const Text('Copy content'),
                  onTap: () => Navigator.pop(context, 'copy'),
                ),
                ListTile(
                  leading: const Icon(Icons.flag, color: Colors.orange),
                  title: const Text('Report'),
                  onTap: () => Navigator.pop(context, 'report'),
                ),
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: const Text('Block'),
                  onTap: () => Navigator.pop(context, 'block'),
                ),
                const SizedBox(height: 25),
              ],
            ),
          ),
    ).then((value) {
      if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: widget.content.status));
        Get.snackbar('Copied', 'Content copied to clipboard');
      } else if (value == 'report') {
        _reportUser();
      } else if (value == 'block') {
        _blockUser();
      }
    });
  }

  // ── Edit ──────────────────────────────────────────────────────────────────

  Future<void> _handleEditContent() async {
    final controller = TextEditingController(text: widget.content.status);
    final result = await showDialog<String>(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.edit, color: Color(0xFFF48706)),
                SizedBox(width: 8),
                Text('Edit Content'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    maxLines: 8,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Update your content',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFF48706),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.trim().isEmpty) {
                    Get.snackbar(
                      'Error',
                      'Content cannot be empty',
                      backgroundColor: Colors.red,
                      colorText: AppColors.whitecolor,
                    );
                    return;
                  }
                  Navigator.pop(context, controller.text.trim());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF48706),
                  foregroundColor: AppColors.whitecolor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (result == null ||
        result.trim().isEmpty ||
        result == widget.content.status)
      return;

    // Use native showDialog so Navigator.pop is safe (avoids GetX snackbar crash)
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black26,
      builder: (_) => const _SaveLoadingDialog(),
    );

    final success = await ApiService.updateContent(
      widget.content.id,
      result.trim(),
      context: context,
    );

    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    if (!mounted) return;

    if (success) {
      widget.onStatusUpdated?.call(result.trim());
      setState(() => widget.content.status = result.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.whitecolor, size: 18),
              SizedBox(width: 10),
              Text(
                'Content updated successfully',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.whitecolor, size: 18),
              SizedBox(width: 10),
              Text(
                'Failed to update. Please try again.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _handleDeleteContent() async {
    // ── Step 1: confirm ────────────────────────────────────────────────────
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade600,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Delete Post',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to delete this post?',
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  'This action cannot be undone.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: AppColors.whitecolor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Yes, Delete',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    // ── Step 2: loading overlay using Flutter's native showDialog ──────────
    // Using showDialog (Navigator-based) instead of Get.dialog so that
    // Navigator.pop(context) is safe and won't crash GetX snackbar state.
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black26,
      builder: (_) => const _DeleteLoadingDialog(),
    );

    // ── Step 3: call API ───────────────────────────────────────────────────
    final success = await ApiService.deleteFiles(
      widget.content.id,
      context: context,
    );

    // ── Step 4: close loading dialog safely ────────────────────────────────
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    if (!mounted) return;

    // ── Step 5: result feedback ────────────────────────────────────────────
    if (success) {
      widget.onDeleted?.call(); // remove from feed list immediately
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.whitecolor, size: 18),
              SizedBox(width: 10),
              Text(
                'Post deleted successfully',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.whitecolor, size: 18),
              SizedBox(width: 10),
              Text(
                'Failed to delete post. Please try again.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Report user ───────────────────────────────────────────────────────────

  Future<void> _reportUser() async {
    String? selectedReason;
    String description = '';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Report User',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Why are you reporting ${widget.content.author.name}?',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Reason:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...[
                          'Spam',
                          'Harassment',
                          'Inappropriate content',
                          'Fake account',
                          'Copyright violation',
                          'Other',
                        ]
                        .map(
                          (reason) => RadioListTile<String>(
                            title: Text(reason),
                            value: reason,
                            groupValue: selectedReason,
                            onChanged:
                                (v) => setState(() => selectedReason = v),
                            contentPadding: EdgeInsets.zero,
                          ),
                        )
                        .toList(),
                    const SizedBox(height: 16),
                    Text(
                      'Additional details (optional):',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Provide more details about this report...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      maxLines: 3,
                      onChanged: (v) => description = v,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      selectedReason != null
                          ? () => Navigator.of(context).pop({
                            'reason': selectedReason!,
                            'description': description,
                          })
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: AppColors.whitecolor,
                  ),
                  child: const Text('Report'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await _submitReport(result['reason']!, result['description']!);
    }
  }

  Future<void> _submitReport(String reason, String description) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black26,
        builder:
            (_) => Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 48),
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.whitecolor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: Image.asset(
                          'animation/IdeaBulb.gif',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Submitting report...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      );

      final token = AppData().accessToken;
      if (token == null || token.isEmpty) {
        Navigator.of(context).pop();
        Get.snackbar(
          'Error',
          'Authentication required to report user',
          backgroundColor: Colors.red,
          colorText: AppColors.whitecolor,
          icon: const Icon(Icons.error, color: AppColors.whitecolor),
        );
        return;
      }

      // POST /api/users/<userId>/report/
      // User ID goes in the URL. Body: reason + description only.
      final response = await http
          .post(
            Uri.parse(
              '${ApiConstants.reportuser}${widget.content.author.id}/report/',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'reason': _mapReportReason(reason),
              'description': description.isNotEmpty ? description : reason,
            }),
          )
          .timeout(const Duration(seconds: 30));

      Navigator.of(context).pop();

      if (response.statusCode == 200 || response.statusCode == 201) {
        developer.log('Report submitted: ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppColors.whitecolor,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Report submitted successfully',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else if (response.statusCode == 401) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()),
          (_) => false,
        );
      } else {
        final errData =
            response.body.isNotEmpty
                ? jsonDecode(response.body) as Map<String, dynamic>
                : {};
        final msg = errData['message']?.toString() ?? 'Failed to submit report';
        developer.log('Report failed: ${response.statusCode} ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.of(context).pop();
      developer.log('submitReport error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Network error. Please check your connection.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ── Block user ────────────────────────────────────────────────────────────

  Future<void> _blockUser() async {
    String? selectedReason;
    String description = '';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Block User',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Are you sure you want to block '
                      '${widget.content.author.name}?',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Blocked users won't be able to see your posts or contact you.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Reason for blocking:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...[
                          'Spamming my posts',
                          'Harassment',
                          'Inappropriate behavior',
                          'Fake account',
                          'Unwanted contact',
                          'Other',
                        ]
                        .map(
                          (reason) => RadioListTile<String>(
                            title: Text(reason),
                            value: reason,
                            groupValue: selectedReason,
                            onChanged:
                                (v) => setState(() => selectedReason = v),
                            contentPadding: EdgeInsets.zero,
                          ),
                        )
                        .toList(),
                    const SizedBox(height: 16),
                    Text(
                      'Additional details (optional):',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Provide more details...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      maxLines: 2,
                      onChanged: (v) => description = v,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      selectedReason != null
                          ? () => Navigator.of(context).pop({
                            'reason': selectedReason!,
                            'description': description,
                          })
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: AppColors.whitecolor,
                  ),
                  child: const Text('Block User'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await _submitBlockUser(result['reason']!, result['description']!);
    }
  }

  Future<void> _submitBlockUser(String reason, String description) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black26,
        builder:
            (_) => Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 48),
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.whitecolor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: Image.asset(
                          'animation/IdeaBulb.gif',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Blocking user...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      );

      final token = AppData().accessToken;
      if (token == null || token.isEmpty) {
        Navigator.of(context).pop();
        Get.snackbar(
          'Error',
          'Authentication required to block user',
          backgroundColor: Colors.red,
          colorText: AppColors.whitecolor,
          icon: const Icon(Icons.error, color: AppColors.whitecolor),
        );
        return;
      }

      final requestBody = {
        'reason': description.isNotEmpty ? description : reason,
      };

      developer.log('Blocking user: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            Uri.parse(
              '${ApiConstants.blockuser}${widget.content.author.id}/block/',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      Navigator.of(context).pop();

      developer.log('Block response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final msg =
            data['message']?.toString() ??
            'Successfully blocked ${widget.content.author.name}';
        Get.snackbar(
          'User Blocked',
          msg,
          backgroundColor: Colors.green,
          colorText: AppColors.whitecolor,
          icon: const Icon(Icons.block, color: AppColors.whitecolor),
          duration: const Duration(seconds: 3),
        );
      } else if (response.statusCode == 401) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()),
          (_) => false,
        );
      } else if (response.statusCode == 409) {
        final data =
            response.body.isNotEmpty
                ? jsonDecode(response.body) as Map<String, dynamic>
                : {};
        final msg = data['message']?.toString() ?? 'User is already blocked';
        Get.snackbar(
          'Already Blocked',
          msg,
          backgroundColor: Colors.orange,
          colorText: AppColors.whitecolor,
          icon: const Icon(Icons.info, color: AppColors.whitecolor),
        );
      } else {
        final data =
            response.body.isNotEmpty
                ? jsonDecode(response.body) as Map<String, dynamic>
                : {};
        final msg = data['message']?.toString() ?? 'Failed to block user';
        Get.snackbar(
          'Error',
          msg,
          backgroundColor: Colors.red,
          colorText: AppColors.whitecolor,
          icon: const Icon(Icons.error, color: AppColors.whitecolor),
        );
        developer.log('Block failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.of(context).pop();
      developer.log('submitBlockUser error: $e');
      Get.snackbar(
        'Error',
        'Network error. Please check your connection.',
        backgroundColor: Colors.red,
        colorText: AppColors.whitecolor,
        icon: const Icon(Icons.error, color: AppColors.whitecolor),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FullscreenVideoPage
// ─────────────────────────────────────────────────────────────────────────────

class FullscreenVideoPage extends StatefulWidget {
  final String url;
  final String? thumbnail;
  const FullscreenVideoPage({Key? key, required this.url, this.thumbnail})
    : super(key: key);
  @override
  State<FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<FullscreenVideoPage>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isPlaying = false;
  bool _isMuted = true;
  bool _disposed = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterFullscreen();
    _initController();
    _startHideControlsTimer();
  }

  Future<void> _enterFullscreen() async =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  Future<void> _exitFullscreen() async =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  Future<void> _initController() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await _controller!.setLooping(false);
      await _controller!.setVolume(0.0);
      await _controller!.initialize();
      if (_disposed) return;
      setState(() {
        _initialized = true;
        _isPlaying = true;
        _isMuted = true;
      });
      _controller!.play();
    } catch (e) {
      developer.log('FullscreenVideoPage init error: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _hideControlsTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller?.pause();
    _controller?.dispose();
    _controller = null;
    _exitFullscreen();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_controller == null || _disposed) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive)
      _controller!.pause();
    else if (state == AppLifecycleState.resumed && _isPlaying)
      _controller!.play();
  }

  void _togglePlayPause() {
    if (_controller == null || !_initialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
    _showControlsTemporarily();
  }

  void _toggleMute() {
    if (_controller == null || !_initialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
    _showControlsTemporarily();
  }

  void _showControlsTemporarily() {
    setState(() => _showControls = true);
    _startHideControlsTimer();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) setState(() => _showControls = false);
    });
  }

  void _onScreenTap() {
    if (_showControls)
      _togglePlayPause();
    else
      _showControlsTemporarily();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child:
                  _initialized && _controller != null
                      ? AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      )
                      : (widget.thumbnail != null
                          ? CachedNetworkImage(
                            imageUrl: widget.thumbnail!,
                            fit: BoxFit.contain,
                            placeholder:
                                (_, __) => Center(
                                  child: Image.asset('animation/IdeaBulb.gif'),
                                ),
                          )
                          : Center(
                            child: Image.asset('animation/IdeaBulb.gif'),
                          )),
            ),
            Positioned.fill(
              child: GestureDetector(
                onTap: _onScreenTap,
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),
            AnimatedOpacity(
              opacity: _showControls || !_isPlaying ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, left: 8, right: 8),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.arrow_back,
                              color: AppColors.whitecolor,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!_isPlaying)
              Center(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      size: 50,
                      color: AppColors.whitecolor,
                    ),
                  ),
                ),
              ),
            AnimatedOpacity(
              opacity: _showControls || !_isPlaying ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _toggleMute,
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isMuted ? Icons.volume_off : Icons.volume_up,
                              color: AppColors.whitecolor,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AutoPlayVideoWidget
// ─────────────────────────────────────────────────────────────────────────────

class AutoPlayVideoWidget extends StatefulWidget {
  final String url;
  final double? height;
  final double? width;
  final String? thumbnailUrl;

  const AutoPlayVideoWidget({
    required this.url,
    this.thumbnailUrl,
    this.height,
    this.width,
    Key? key,
  }) : super(key: key);

  @override
  State<AutoPlayVideoWidget> createState() => AutoPlayVideoWidgetState();
}

class AutoPlayVideoWidgetState extends State<AutoPlayVideoWidget>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isMuted = true;
  bool _disposed = false;
  Timer? _initTimer;
  bool _isPlaying = true;
  final String videoId = UniqueKey().toString();
  static final Map<String, AutoPlayVideoWidgetState> _activeVideos = {};

  @override
  bool get wantKeepAlive => true;

  void _safeSetState(VoidCallback fn) {
    if (mounted && !_disposed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_disposed) setState(fn);
      });
    }
  }

  void pauseVideo() {
    if (_controller != null && !_disposed && _initialized) {
      _controller!.pause();
      _safeSetState(() => _isPlaying = false);
    }
  }

  void playVideo() {
    if (_controller != null && !_disposed && _initialized) {
      _controller!.play();
      _safeSetState(() => _isPlaying = true);
    }
  }

  void muteVideo() {
    if (_controller != null && !_disposed && _initialized) {
      _controller!
          .setVolume(0.0)
          .then((_) {
            _safeSetState(() => _isMuted = true);
          })
          .catchError((e) {
            developer.log('Error muting video: $e');
          });
    }
  }

  void unmuteVideo() {
    if (_controller != null && !_disposed && _initialized) {
      _controller!.setVolume(1.0);
      _safeSetState(() => _isMuted = false);
    }
  }

  bool get isMuted => _isMuted;
  bool get isPlaying => _isPlaying;
  bool get isInitialized => _initialized;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activeVideos[videoId] = this;
  }

  void _initializeVideoPlayer() {
    if (_disposed) return;
    _initTimer = Timer(const Duration(seconds: 30), () {
      if (!_initialized && !_disposed) _handleInitializationError();
    });
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
    );
    _controller!
      ..setLooping(true)
      ..setVolume(0.0)
      ..initialize()
          .then((_) {
            _initTimer?.cancel();
            if (!_disposed) {
              _safeSetState(() => _initialized = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_disposed) _controller!.play();
              });
            }
          })
          .catchError((error) {
            _initTimer?.cancel();
            if (!_disposed) _handleInitializationError();
          });
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (!mounted || _disposed) return;
    final visibleFraction = info.visibleFraction;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disposed) return;
      if (visibleFraction > 0.7) {
        if (!_initialized && !_disposed && _controller == null) {
          try {
            _initializeVideoPlayer();
          } catch (e) {
            developer.log('Error initializing video: $e');
          }
        }
        _activeVideos[videoId] = this;
        _muteOtherVideos();
        if (_initialized &&
            _controller != null &&
            !_controller!.value.isPlaying &&
            _isPlaying) {
          _controller!.play();
        }
      } else if (visibleFraction < 0.5) {
        _activeVideos.remove(videoId);
        if (_initialized &&
            _controller != null &&
            _controller!.value.isPlaying) {
          _controller!.pause();
          developer.log(
            'Video paused (visibility: ${visibleFraction.toStringAsFixed(2)})',
          );
        }
      }
    });
  }

  void _muteOtherVideos() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final entry in _activeVideos.entries) {
        if (entry.key != videoId &&
            entry.value.mounted &&
            !entry.value._disposed) {
          entry.value._controller?.pause();
          entry.value._controller?.setVolume(0.0);
          entry.value._safeSetState(() {
            entry.value._isMuted = true;
            entry.value._isPlaying = false;
          });
        }
      }
    });
  }

  static void pauseAllAutoPlayVideos() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final entry in _activeVideos.entries) {
        if (entry.value.mounted && !entry.value._disposed) {
          entry.value._controller?.pause();
          entry.value._controller?.setVolume(0.0);
          entry.value._safeSetState(() {
            entry.value._isMuted = true;
            entry.value._isPlaying = false;
          });
        }
      }
    });
  }

  static void resumeAllAutoPlayVideos() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final entry in _activeVideos.entries) {
        if (entry.value._initialized &&
            entry.value.mounted &&
            !entry.value._disposed) {
          entry.value._controller?.play();
          entry.value._controller?.setVolume(0.0);
          entry.value._safeSetState(() {
            entry.value._isPlaying = true;
            entry.value._isMuted = true;
          });
        }
      }
    });
  }

  void _handleInitializationError([Object? error]) {
    _safeSetState(() => _initialized = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_controller == null || _disposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disposed) return;
      switch (state) {
        case AppLifecycleState.paused:
        case AppLifecycleState.inactive:
          _controller!.pause();
          break;
        case AppLifecycleState.resumed:
          if (_initialized && mounted && _isPlaying) _controller!.play();
          break;
        case AppLifecycleState.detached:
        case AppLifecycleState.hidden:
          _controller!.pause();
          break;
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _activeVideos.remove(videoId);
    _initTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void _openFullscreen() {
    if (!mounted || _controller == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => FullscreenVideoPage(
              url: widget.url,
              thumbnail: widget.thumbnailUrl,
            ),
      ),
    );
  }

  void _toggleMute() {
    if (_controller == null || _disposed || !_initialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return VisibilityDetector(
      key: Key(videoId),
      onVisibilityChanged: _handleVisibilityChanged,
      child: Container(
        height: widget.height ?? MediaQuery.of(context).size.height,
        width: widget.width ?? MediaQuery.of(context).size.width,
        color: AppColors.whitecolor,
        child:
            !_initialized || _controller == null
                ? _buildLoadingOrThumbnail()
                : _buildVideoPlayer(),
      ),
    );
  }

  Widget _buildLoadingOrThumbnail() {
    if (widget.thumbnailUrl != null) {
      return CachedNetworkImage(
        imageUrl: widget.thumbnailUrl!,
        fit: BoxFit.cover,
        placeholder:
            (_, __) => Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: Image.asset(
                  'animation/IdeaBulb.gif',
                  fit: BoxFit.contain,
                ),
              ),
            ),
        errorWidget:
            (_, __, ___) => Container(
              color: Colors.grey,
              child: const Center(
                child: Icon(Icons.videocam_off, color: AppColors.whitecolor),
              ),
            ),
      );
    }
    return Center(
      child: SizedBox(
        width: 40,
        height: 40,
        child: Image.asset('animation/IdeaBulb.gif', fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = _controller!.value.size;
        final aspectRatio = size.width / size.height;
        double targetWidth = constraints.maxWidth;
        double targetHeight = constraints.maxWidth / aspectRatio;
        if (targetHeight > constraints.maxHeight) {
          targetHeight = constraints.maxHeight;
          targetWidth = constraints.maxHeight * aspectRatio;
        }
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: _openFullscreen,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: targetWidth,
                  height: targetHeight,
                  child: VideoPlayer(_controller!),
                ),
              ),
              if (!_isPlaying)
                IgnorePointer(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      size: 50,
                      color: AppColors.whitecolor,
                    ),
                  ),
                ),
              Positioned(
                top: 16,
                right: 16,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.fullscreen,
                      color: AppColors.whitecolor,
                      size: 20,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: GestureDetector(
                  onTap: _toggleMute,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.whitecolor.withAlpha(30),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: AppColors.whitecolor,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer skeleton widgets — Facebook-style feed loading
// Uses the `shimmer` package (add to pubspec: shimmer: ^3.0.0)
// ─────────────────────────────────────────────────────────────────────────────

// Import note: add this to your imports section at the top:
//   import 'package:shimmer/shimmer.dart';

/// Grey rounded rectangle — skeleton building block.
class _SBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const _SBox({this.width, required this.height, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.whitecolor,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Circle skeleton — for avatars.
class _SCircle extends StatelessWidget {
  final double size;
  const _SCircle(this.size);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.whitecolor,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Single shimmer post card — no-media variant (text-only post).
/// Exactly mirrors the real FeedItem header + 3 text lines + action bar.
class _ShimmerCardTextOnly extends StatelessWidget {
  const _ShimmerCardTextOnly();

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(child: _PostSkeleton(showMedia: false));
  }
}

/// Single shimmer post card — with-media variant (post with image).
class _ShimmerCardWithMedia extends StatelessWidget {
  const _ShimmerCardWithMedia();

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(child: _PostSkeleton(showMedia: true));
  }
}

/// Wraps a skeleton child in the shimmer sweep effect.
class _ShimmerWrapper extends StatelessWidget {
  final Widget child;
  const _ShimmerWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8E8E8),
      highlightColor: const Color(0xFFF8F8F8),
      period: const Duration(milliseconds: 1200),
      child: child,
    );
  }
}

/// The actual skeleton layout — matches FeedItem pixel-for-pixel.
class _PostSkeleton extends StatelessWidget {
  final bool showMedia;
  const _PostSkeleton({required this.showMedia});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.whitecolor,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1.0),
          bottom: BorderSide(color: Colors.grey.shade200, width: 3.0),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
          topLeft: Radius.circular(5),
          topRight: Radius.circular(5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header row: avatar · name + timestamp · follow pill ──────
            Row(
              children: [
                // Avatar with orange ring (matches real card)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.grey.shade300, Colors.grey.shade200],
                    ),
                  ),
                  child: const _SCircle(40),
                ),
                const SizedBox(width: 10),

                // Name + timestamp
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SBox(width: w * 0.32, height: 13, radius: 4),
                      const SizedBox(height: 6),
                      _SBox(width: w * 0.20, height: 10, radius: 4),
                    ],
                  ),
                ),

                // Follow button pill
                _SBox(width: 76, height: 26, radius: 20),
                const SizedBox(width: 8),
                // More (⋮) button
                const _SCircle(20),
              ],
            ),

            const SizedBox(height: 12),

            // ── Text content lines ────────────────────────────────────────
            _SBox(width: w * 0.85, height: 12, radius: 4),
            const SizedBox(height: 7),
            _SBox(width: w * 0.72, height: 12, radius: 4),
            const SizedBox(height: 7),
            _SBox(width: w * 0.52, height: 12, radius: 4),

            if (showMedia) ...[
              const SizedBox(height: 12),
              // ── Media block — proportional to screen, like a real image ─
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: _SBox(
                  width: double.infinity,
                  // Aspect ratio ~4:3 matches typical portrait photos
                  height: (w - 16) * 0.72,
                  radius: 4,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ── Divider ───────────────────────────────────────────────────
            Container(
              height: 1,
              color: Colors.grey.shade200,
              margin: const EdgeInsets.symmetric(horizontal: 2),
            ),

            const SizedBox(height: 12),

            // ── Action bar: like · comment · share ────────────────────────
            Row(
              children: [
                // Like icon + count
                const _SCircle(18),
                const SizedBox(width: 6),
                _SBox(width: 48, height: 11, radius: 4),

                const SizedBox(width: 20),

                // Comment icon + count
                const _SCircle(18),
                const SizedBox(width: 6),
                _SBox(width: 62, height: 11, radius: 4),

                const Spacer(),

                // Share icon
                const _SCircle(18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Full shimmer feed list — alternates text-only and with-media cards
/// to match the real feed's mixed content, just like Facebook does.
class _ShimmerFeedList extends StatelessWidget {
  const _ShimmerFeedList();

  @override
  Widget build(BuildContext context) {
    // Pattern: media, text-only, media, text-only, media
    // This matches the typical feed density without making all cards huge
    const pattern = [true, false, true, false, true];
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: pattern.length,
      itemBuilder:
          (_, i) =>
              _ShimmerWrapper(child: _PostSkeleton(showMedia: pattern[i])),
    );
  }
}

/// Convenience aliases used in Inner_HomePage
typedef _ShimmerFeedCard = _ShimmerCardTextOnly;

/// Thin orange progress bar pinned to screen top during refresh
/// when the list already has content (no skeleton overlay needed).
class _FeedRefreshBar extends StatelessWidget {
  const _FeedRefreshBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: LinearProgressIndicator(
        value: null,
        backgroundColor: const Color.fromRGBO(244, 135, 6, 0.15),
        valueColor: const AlwaysStoppedAnimation<Color>(
          Color.fromRGBO(244, 135, 6, 1),
        ),
        minHeight: 3,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading dialogs — native Flutter (no GetX) to avoid snackbar state crashes
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteLoadingDialog extends StatelessWidget {
  const _DeleteLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 48),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.whitecolor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Image.asset('animation/IdeaBulb.gif', fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
            Text(
              'Deleting post...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade400),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveLoadingDialog extends StatelessWidget {
  const _SaveLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 48),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.whitecolor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Image.asset('animation/IdeaBulb.gif', fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
            Text(
              'Saving changes...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color.fromRGBO(244, 135, 6, 1),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LinkifyText
// ─────────────────────────────────────────────────────────────────────────────

class _LinkifyText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const _LinkifyText({
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final RegExp urlRegExp = RegExp(
      r'(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );
    final RegExp hashtagRegExp = RegExp(
      r'(#[a-zA-Z0-9_]+)',
      caseSensitive: false,
    );

    final List<InlineSpan> spans = [];
    final List<_TextMatch> allMatches = [];

    allMatches.addAll(
      urlRegExp.allMatches(text).map((m) => _TextMatch(m, 'url')),
    );
    allMatches.addAll(
      hashtagRegExp.allMatches(text).map((m) => _TextMatch(m, 'hashtag')),
    );
    allMatches.sort((a, b) => a.match.start.compareTo(b.match.start));

    final List<_TextMatch> filteredMatches = [];
    for (int i = 0; i < allMatches.length; i++) {
      bool shouldAdd = true;
      for (int j = 0; j < filteredMatches.length; j++) {
        if (_matchesOverlap(allMatches[i].match, filteredMatches[j].match)) {
          shouldAdd = false;
          break;
        }
      }
      if (shouldAdd) filteredMatches.add(allMatches[i]);
    }

    int lastMatchEnd = 0;
    for (final matchWithType in filteredMatches) {
      final match = matchWithType.match;
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: style,
          ),
        );
      }
      final matchText = match.group(0)!;
      if (matchWithType.type == 'url') {
        spans.add(
          TextSpan(
            text: matchText,
            style:
                style?.copyWith(
                  color: Colors.blue.shade600,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w500,
                ) ??
                TextStyle(
                  color: Colors.blue.shade600,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w500,
                ),
            recognizer:
                TapGestureRecognizer()
                  ..onTap = () async {
                    final uri = Uri.parse(matchText);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open link')),
                      );
                    }
                  },
          ),
        );
      } else if (matchWithType.type == 'hashtag') {
        spans.add(
          TextSpan(
            text: matchText,
            style:
                style?.copyWith(
                  color: Colors.purple.shade600,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ) ??
                TextStyle(
                  color: Colors.purple.shade600,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
            recognizer:
                TapGestureRecognizer()
                  ..onTap = () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hashtag tapped: $matchText'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
          ),
        );
      }
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd), style: style));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }

  bool _matchesOverlap(RegExpMatch match1, RegExpMatch match2) =>
      match1.start < match2.end && match1.end > match2.start;
}

class _TextMatch {
  final RegExpMatch match;
  final String type;
  _TextMatch(this.match, this.type);
}

extension DateTimeExtension on DateTime {
  String timeAgo() {
    final difference = DateTime.now().difference(this);
    if (difference.inDays > 365)
      return '${(difference.inDays / 365).floor()} year(s) ago';
    if (difference.inDays > 30)
      return '${(difference.inDays / 30).floor()} month(s) ago';
    if (difference.inDays > 0) return '${difference.inDays} day(s) ago';
    if (difference.inHours > 0) return '${difference.inHours} hour(s) ago';
    if (difference.inMinutes > 0)
      return '${difference.inMinutes} minute(s) ago';
    return 'Just now';
  }
}
