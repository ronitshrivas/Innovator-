import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:better_native_video_player/better_native_video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/screens/comment/comment_section.dart';
import 'package:innovator/Innovator/screens/Follow/follow_Button.dart';
import 'package:innovator/Innovator/screens/Likes/Content-Like-Service.dart';
import 'package:innovator/Innovator/screens/SHow_Specific_Profile/Show_Specific_Profile.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class ReelModel {
  final String id;
  final String userId;
  final String username;
  final String avatar;
  String caption;
  final String? videoUrl;
  final String? hlsUrl;
  final String? thumbnail;
  int viewsCount;
  int reactionsCount;
  String? currentUserReaction;
  bool isFollowed;
  int commentsCount;
  final DateTime createdAt;

  final String? sharedReelId;
  final ReelModel? sharedReelDetails;

  ReelModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatar,
    required this.caption,
    this.videoUrl,
    this.hlsUrl,
    this.thumbnail,
    required this.viewsCount,
    required this.reactionsCount,
    this.currentUserReaction,
    required this.isFollowed,
    required this.commentsCount,
    required this.createdAt,
    this.sharedReelId,
    this.sharedReelDetails,
  });

  bool get hasVideo =>
      (hlsUrl != null && hlsUrl!.isNotEmpty) ||
      (videoUrl != null && videoUrl!.isNotEmpty);

  String? get bestVideoUrl =>
      (hlsUrl != null && hlsUrl!.isNotEmpty) ? hlsUrl : videoUrl;

  bool get isLiked => currentUserReaction != null;
  bool get isRepost => sharedReelId != null;

  ReactionType? get currentReactionType =>
      ReactionTypeExtension.fromValue(currentUserReaction);

  factory ReelModel.fromJson(Map<String, dynamic> j) => ReelModel(
    id: j['id']?.toString() ?? '',
    userId: j['user_id']?.toString() ?? '',
    username: j['username']?.toString() ?? '',
    avatar: j['avatar']?.toString() ?? '',
    caption: j['caption']?.toString() ?? '',
    videoUrl: j['video']?.toString(),
    hlsUrl: j['hls_playlist_url']?.toString(),
    thumbnail: j['thumbnail']?.toString(),
    viewsCount: (j['views_count'] as num?)?.toInt() ?? 0,
    reactionsCount:
        (j['reactions_count'] as num?)?.toInt() ??
        (j['like_count'] as num?)?.toInt() ??
        0,
    currentUserReaction: j['current_user_reaction']?.toString(),
    isFollowed: j['is_followed'] == true,
    commentsCount: (j['comments_count'] as num?)?.toInt() ?? 0,
    createdAt:
        DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
    sharedReelId: j['shared_reel']?.toString(),
    sharedReelDetails:
        j['shared_reel_details'] != null
            ? ReelModel.fromJson(
              j['shared_reel_details'] as Map<String, dynamic>,
            )
            : null,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// REEL OPERATION RESULT
// ─────────────────────────────────────────────────────────────────────────────

class ReelOperationResult {
  final bool success;
  final String? errorMessage;
  final ReelModel? data;

  const ReelOperationResult({
    required this.success,
    this.errorMessage,
    this.data,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// API SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class ReelsApiService {
  static const String _baseUrl = 'http://182.93.94.220:8005';
  static const String _reelsUrl = '$_baseUrl/api/reels/';

  static Map<String, String> _headers() {
    final token = AppData().accessToken ?? '';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<ReelsFeed> fetchReels({String? cursor}) async {
    final uri =
        cursor != null && cursor.isNotEmpty
            ? Uri.parse(cursor)
            : Uri.parse(_reelsUrl);
    developer.log('[Reels] GET $uri');
    final res = await http
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 200) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      final results =
          (data['results'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(ReelModel.fromJson)
              .where((r) => r.hasVideo)
              .toList();
      return ReelsFeed(
        reels: results,
        nextCursor: data['next']?.toString(),
        hasMore: data['next'] != null,
      );
    }
    throw Exception('Reels fetch failed: ${res.statusCode}');
  }

  static Future<void> recordView(String reelId) async {
    try {
      await http
          .post(Uri.parse('$_reelsUrl$reelId/view/'), headers: _headers())
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  static Future<ReelOperationResult> editReel({
    required String reelId,
    required String caption,
  }) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$_reelsUrl$reelId/'),
            headers: _headers(),
            body: json.encode({'caption': caption}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        return ReelOperationResult(
          success: true,
          data: ReelModel.fromJson(data),
        );
      }
      return ReelOperationResult(
        success: false,
        errorMessage: _parseError(res.body, res.statusCode),
      );
    } catch (e) {
      return ReelOperationResult(
        success: false,
        errorMessage: 'Network error. Please try again.',
      );
    }
  }

  static Future<ReelOperationResult> deleteReel(String reelId) async {
    try {
      final res = await http
          .delete(Uri.parse('$_reelsUrl$reelId/'), headers: _headers())
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 204 || res.statusCode == 200) {
        return const ReelOperationResult(success: true);
      }
      return ReelOperationResult(
        success: false,
        errorMessage: _parseError(res.body, res.statusCode),
      );
    } catch (e) {
      return ReelOperationResult(
        success: false,
        errorMessage: 'Network error. Please try again.',
      );
    }
  }

  static Future<ReelOperationResult> repostReel(String reelId) async {
    try {
      final res = await http
          .post(Uri.parse('$_reelsUrl$reelId/repost/'), headers: _headers())
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        return ReelOperationResult(
          success: true,
          data: ReelModel.fromJson(data),
        );
      }
      return ReelOperationResult(
        success: false,
        errorMessage: _parseError(res.body, res.statusCode),
      );
    } catch (e) {
      return ReelOperationResult(
        success: false,
        errorMessage: 'Network error. Please try again.',
      );
    }
  }

  static String _parseError(String body, int statusCode) {
    try {
      final data = json.decode(body);
      if (data is Map) {
        final detail = data['detail'] ?? data['message'] ?? data['error'];
        if (detail != null) return detail.toString();
      }
    } catch (_) {}
    return 'Something went wrong (code $statusCode)';
  }
}

class ReelsFeed {
  final List<ReelModel> reels;
  final String? nextCursor;
  final bool hasMore;
  const ReelsFeed({
    required this.reels,
    this.nextCursor,
    required this.hasMore,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// RIVERPOD PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final activeReelIndexProvider = StateProvider<int>((ref) => 0);

class ReelsFeedNotifier extends StateNotifier<AsyncValue<List<ReelModel>>> {
  ReelsFeedNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  String? _nextCursor;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  Future<void> _load() async {
    try {
      final feed = await ReelsApiService.fetchReels();
      _nextCursor = feed.nextCursor;
      _hasMore = feed.hasMore;
      state = AsyncValue.data(feed.reels);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    _nextCursor = null;
    _hasMore = true;
    state = const AsyncValue.loading();
    await _load();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _nextCursor == null) return;
    _isLoadingMore = true;
    try {
      final current = state.value ?? [];
      final feed = await ReelsApiService.fetchReels(cursor: _nextCursor);
      _nextCursor = feed.nextCursor;
      _hasMore = feed.hasMore;
      state = AsyncValue.data([...current, ...feed.reels]);
    } catch (e) {
      developer.log('[Reels] loadMore error: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  void applyReaction(String reelId, String? newReaction) {
    final list = state.value;
    if (list == null) return;
    final idx = list.indexWhere((r) => r.id == reelId);
    if (idx == -1) return;
    final reel = list[idx];
    final hadReaction = reel.currentUserReaction != null;
    final willHaveReaction = newReaction != null;
    reel.currentUserReaction = newReaction;
    if (!hadReaction && willHaveReaction) {
      reel.reactionsCount++;
    } else if (hadReaction && !willHaveReaction) {
      reel.reactionsCount = (reel.reactionsCount - 1).clamp(0, 999999);
    }
    state = AsyncValue.data(List.from(list));
  }

  void updateFollow(String userId, bool isFollowed) {
    final list = state.value;
    if (list == null) return;
    for (final r in list) {
      if (r.userId == userId) r.isFollowed = isFollowed;
    }
    state = AsyncValue.data(List.from(list));
  }

  void incrementComments(String reelId) {
    final list = state.value;
    if (list == null) return;
    final idx = list.indexWhere((r) => r.id == reelId);
    if (idx != -1) list[idx].commentsCount++;
    state = AsyncValue.data(List.from(list));
  }

  void decrementComments(String reelId) {
    final list = state.value;
    if (list == null) return;
    final idx = list.indexWhere((r) => r.id == reelId);
    if (idx != -1) {
      list[idx].commentsCount = (list[idx].commentsCount - 1).clamp(0, 999999);
    }
    state = AsyncValue.data(List.from(list));
  }

  Future<String?> editReel(String reelId, String newCaption) async {
    final list = state.value;
    if (list == null) return 'No data';
    final idx = list.indexWhere((r) => r.id == reelId);
    if (idx == -1) return 'Reel not found';
    final oldCaption = list[idx].caption;
    list[idx].caption = newCaption;
    state = AsyncValue.data(List.from(list));
    final result = await ReelsApiService.editReel(
      reelId: reelId,
      caption: newCaption,
    );
    if (result.success) {
      if (result.data != null) {
        list[idx].caption = result.data!.caption;
        state = AsyncValue.data(List.from(list));
      }
      return null;
    } else {
      list[idx].caption = oldCaption;
      state = AsyncValue.data(List.from(list));
      return result.errorMessage;
    }
  }

  Future<String?> deleteReel(String reelId) async {
    final result = await ReelsApiService.deleteReel(reelId);
    if (result.success) {
      final list = state.value ?? [];
      state = AsyncValue.data(list.where((r) => r.id != reelId).toList());
      return null;
    }
    return result.errorMessage;
  }

  Future<String?> repostReel(String reelId) async {
    final result = await ReelsApiService.repostReel(reelId);
    if (result.success && result.data != null) {
      final list = state.value ?? [];
      state = AsyncValue.data([result.data!, ...list]);
      return null;
    }
    return result.errorMessage;
  }
}

final reelsFeedProvider =
    StateNotifierProvider<ReelsFeedNotifier, AsyncValue<List<ReelModel>>>(
      (ref) => ReelsFeedNotifier(),
    );

// ─────────────────────────────────────────────────────────────────────────────
// NATIVE CONTROLLER POOL
// Pre-warms NativeVideoPlayerController instances using ExoPlayer (Android)
// so every reel plays instantly with zero startup lag.
// ─────────────────────────────────────────────────────────────────────────────

class _NativeControllerPool {
  final Map<String, NativeVideoPlayerController> _pool = {};
  final Set<String> _loading = {};

  // Start IDs high to avoid conflict with other players in the app
  int _idCounter = 100;

  /// Returns the ready controller for [reelId], or null if still loading.
  NativeVideoPlayerController? get(String reelId) => _pool[reelId];

  /// Pre-initializes and buffers the video for [reel].
  /// [onReady] is called on the calling isolate when the controller is ready.
  /// Safe to call multiple times — no-op if already loading/loaded.
  Future<void> preload(ReelModel reel, {VoidCallback? onReady}) async {
    if (_pool.containsKey(reel.id) || _loading.contains(reel.id)) return;
    if (!reel.hasVideo) return;

    _loading.add(reel.id);
    developer.log('[Pool] Preloading reel ${reel.id}');

    final ctrl = NativeVideoPlayerController(
      id: _idCounter++,
      autoPlay: false,
      // enableLooping: true,
      enableLooping: false,
      showNativeControls: false, // We render our own Flutter controls
    );

    try {
      // initialize() creates the native ExoPlayer/AVPlayer instance
      await ctrl.initialize();

      final url = reel.bestVideoUrl!;
      final token = AppData().accessToken ?? '';
      final headers =
          token.isNotEmpty
              ? <String, String>{'Authorization': 'Bearer $token'}
              : null;

      // loadUrl() triggers ExoPlayer to start fetching + buffering immediately
      await ctrl.loadUrl(url: url, headers: headers);

      _pool[reel.id] = ctrl;
      developer.log('[Pool] Ready: reel ${reel.id}');
      onReady?.call();
    } catch (e) {
      developer.log('[Pool] Error preloading ${reel.id}: $e');
      ctrl.dispose();
    } finally {
      _loading.remove(reel.id);
    }
  }

  /// Disposes controllers that are more than [keepRadius] positions away
  /// from [currentIndex] to free memory.
  void evictDistant(
    int currentIndex,
    List<ReelModel> reels, {
    int keepRadius = 3,
  }) {
    final toEvict = <String>[];
    for (final entry in _pool.entries) {
      final idx = reels.indexWhere((r) => r.id == entry.key);
      if (idx < 0 || (idx - currentIndex).abs() > keepRadius) {
        toEvict.add(entry.key);
      }
    }
    for (final id in toEvict) {
      developer.log('[Pool] Evicting reel $id');
      _pool.remove(id)?.dispose();
    }
  }

  void disposeAll() {
    for (final ctrl in _pool.values) ctrl.dispose();
    _pool.clear();
    _loading.clear();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REELS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen>
    with WidgetsBindingObserver {
  late PageController _pageController;
  final _pool = _NativeControllerPool();
  int _currentPage = 0;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _pool.disposeAll();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// Pre-warms controllers for current reel + 2 ahead + 1 behind.
  /// Calls setState when any controller becomes ready, so the item
  /// gets a non-null controller and starts playing immediately.
  void _preloadAround(List<ReelModel> reels, int index) {
    final from = max(0, index - 1);
    final to = min(reels.length - 1, index + 2);
    for (int i = from; i <= to; i++) {
      _pool.preload(
        reels[i],
        onReady: () {
          if (mounted) setState(() {}); // hand ready controller to _ReelItem
        },
      );
    }
    _pool.evictDistant(index, reels);
  }

  void _goToPage(int page, List<ReelModel> reels) {
    if (_isAnimating) return;
    if (page < 0 || page >= reels.length) return;
    _isAnimating = true;
    _pageController
        .animateToPage(
          page,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        )
        .then((_) => _isAnimating = false);
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    ref.read(activeReelIndexProvider.notifier).state = index;
    final reels = ref.read(reelsFeedProvider).value ?? [];
    _preloadAround(reels, index);
    if (index >= reels.length - 3) {
      ref.read(reelsFeedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(reelsFeedProvider);

    // Kick off preloading whenever feed data arrives / changes
    ref.listen<AsyncValue<List<ReelModel>>>(reelsFeedProvider, (_, next) {
      next.whenData((reels) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _preloadAround(reels, _currentPage);
        });
      });
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: feedState.when(
        loading: () => const _ReelsShimmer(),
        error:
            (e, _) => _ReelsError(
              onRetry: () => ref.read(reelsFeedProvider.notifier).refresh(),
            ),
        data: (reels) {
          if (reels.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.video_library_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No reels yet',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed:
                        () => ref.read(reelsFeedProvider.notifier).refresh(),
                    child: const Text(
                      'Refresh',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            );
          }

          return RawGestureDetector(
            gestures: {
              VerticalDragGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    VerticalDragGestureRecognizer
                  >(() => VerticalDragGestureRecognizer(), (instance) {
                    double dragStart = 0;
                    instance.onStart = (details) {
                      dragStart = details.globalPosition.dy;
                    };
                    instance.onEnd = (details) {
                      if (_isAnimating) return;
                      final dragDelta = dragStart - details.globalPosition.dy;
                      final velocity = details.primaryVelocity ?? 0;
                      if (dragDelta > 60 || velocity < -400) {
                        _goToPage(_currentPage + 1, reels);
                      } else if (dragDelta < -60 || velocity > 400) {
                        _goToPage(_currentPage - 1, reels);
                      }
                    };
                  }),
            },
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: _onPageChanged,
              itemCount: reels.length,
              itemBuilder: (context, index) {
                return _ReelItem(
                  key: ValueKey(reels[index].id),
                  reel: reels[index],
                  isActive: index == _currentPage,
                  // Pass pre-warmed controller — null shows thumbnail until ready
                  controller: _pool.get(reels[index].id),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SINGLE REEL ITEM
// Receives a pre-warmed NativeVideoPlayerController from the pool.
// When controller is non-null and isActive=true, video plays instantly.
// ─────────────────────────────────────────────────────────────────────────────

class _ReelItem extends ConsumerStatefulWidget {
  final ReelModel reel;
  final bool isActive;
  final NativeVideoPlayerController? controller;

  const _ReelItem({
    Key? key,
    required this.reel,
    required this.isActive,
    required this.controller,
  }) : super(key: key);

  @override
  ConsumerState<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends ConsumerState<_ReelItem>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // ── Playback state (driven by controller streams) ─────────────────────────
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isMuted = false;
  bool _isSeeking = false;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<PlayerActivityState>? _stateSub;

  // ── UI state ──────────────────────────────────────────────────────────────
  bool _showControls = false;
  bool _showComments = false;
  bool _viewRecorded = false;

  // ── Heart burst animation ─────────────────────────────────────────────────
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;
  late Animation<double> _heartOpacity;
  bool _showHeartBurst = false;
  Offset _heartPosition = Offset.zero;

  // ── Reaction overlay ──────────────────────────────────────────────────────
  OverlayEntry? _reactionOverlay;
  final LayerLink _reactionLayerLink = LayerLink();

  final ContentLikeService _likeService = ContentLikeService(
    baseUrl: 'http://182.93.94.220:8005',
  );

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initHeartAnimation();
    _attachController(widget.controller);
  }

  @override
  void didUpdateWidget(_ReelItem old) {
    super.didUpdateWidget(old);

    // Controller changed (pool finished loading) → re-subscribe
    if (old.controller != widget.controller) {
      _detachController();
      _attachController(widget.controller);
    }

    // Active state changed → play / pause
    if (widget.isActive != old.isActive) {
      if (widget.isActive) {
        widget.controller?.play();
        if (!_viewRecorded) {
          _viewRecorded = true;
          ReelsApiService.recordView(widget.reel.id);
        }
      } else {
        widget.controller?.pause();
        _removeReactionOverlay();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detachController();
    _heartCtrl.dispose();
    _removeReactionOverlay();
    // Note: we do NOT dispose the controller here — the pool owns it.
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      widget.controller?.pause();
    } else if (state == AppLifecycleState.resumed && widget.isActive) {
      widget.controller?.play();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONTROLLER ATTACHMENT
  // ─────────────────────────────────────────────────────────────────────────

  // void _attachController(NativeVideoPlayerController? ctrl) {
  //   if (ctrl == null) return;

  //   // Seed current values synchronously
  //   // _position = ctrl.currentPosition;
  //   // _duration = ctrl.duration;

  //   // Stream subscriptions for live updates
  //   _positionSub = ctrl.positionStream.listen((pos) {
  //     if (mounted && !_isSeeking) setState(() => _position = pos);
  //   });
  //   _durationSub = ctrl.durationStream.listen((dur) {
  //     if (mounted) setState(() => _duration = dur);
  //   });
  //   _stateSub = ctrl.playerStateStream.listen((s) {
  //     if (mounted) {
  //       setState(() => _isPlaying = s == PlayerActivityState.playing);
  //     }
  //   });

  //   // Apply mute preference if user changed it before controller was ready
  //   if (_isMuted) ctrl.setVolume(0.0);

  //   // Auto-play if this is the active reel
  //   if (widget.isActive) {
  //     ctrl.play();
  //     if (!_viewRecorded) {
  //       _viewRecorded = true;
  //       ReelsApiService.recordView(widget.reel.id);
  //     }
  //   }
  // }


  void _attachController(NativeVideoPlayerController? ctrl) {
  if (ctrl == null) return;

  // ❌ REMOVE THESE — currentPosition and duration don't exist as properties
  // _position = ctrl.currentPosition;
  // _duration = ctrl.duration;

  _positionSub = ctrl.positionStream.listen((pos) {
    if (mounted && !_isSeeking) setState(() => _position = pos);
  });

  _durationSub = ctrl.durationStream.listen((dur) {
    if (mounted) setState(() => _duration = dur);
  });

   _stateSub = ctrl.playerStateStream.listen((state) {
    if (mounted) {
      setState(() => _isPlaying = state == PlayerActivityState.playing);
    }
  });

  if (_isMuted) ctrl.setVolume(0.0);

  if (widget.isActive) {
    ctrl.play();
    if (!_viewRecorded) {
      _viewRecorded = true;
      ReelsApiService.recordView(widget.reel.id);
    }
  }
}

  void _detachController() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _positionSub = null;
    _durationSub = null;
    _stateSub = null;
  }

  void _initHeartAnimation() {
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heartScale = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.6,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.6,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_heartCtrl);
    _heartOpacity = TweenSequence([
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 80),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_heartCtrl);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GESTURE HANDLERS
  // ─────────────────────────────────────────────────────────────────────────

  void _onTap() {
    _removeReactionOverlay();
    final ctrl = widget.controller;
    if (ctrl == null) return;
    if (_isPlaying) {
      ctrl.pause();
    } else {
      ctrl.play();
    }
    _flashControls();
  }

  void _flashControls() {
    if (mounted) setState(() => _showControls = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onDoubleTap(TapDownDetails details) {
    HapticFeedback.mediumImpact();
    _removeReactionOverlay();
    setState(() {
      _heartPosition = details.localPosition;
      _showHeartBurst = true;
    });
    _heartCtrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _showHeartBurst = false);
    });
    if (!widget.reel.isLiked) {
      _applyReaction(ReactionType.like);
    }
  }

  void _onLongPressStart(LongPressStartDetails _) => widget.controller?.pause();

  void _onLongPressEnd(LongPressEndDetails _) {
    if (widget.isActive) widget.controller?.play();
  }

  void _seekTo(double fraction) {
    final ctrl = widget.controller;
    if (ctrl == null) return;
    final target = Duration(
      milliseconds: (_duration.inMilliseconds * fraction).round(),
    );
    ctrl.seekTo(target);
    if (mounted) setState(() => _position = target);
  }

  void _toggleMute() {
    _isMuted = !_isMuted;
    widget.controller?.setVolume(_isMuted ? 0.0 : 1.0);
    setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REACTION LOGIC
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _applyReaction(ReactionType type) async {
    final reel = widget.reel;
    final isSameType = reel.currentUserReaction == type.value;
    final previousReaction = reel.currentUserReaction;

    if (isSameType) {
      ref.read(reelsFeedProvider.notifier).applyReaction(reel.id, null);

      final result = await _likeService.reactReel(reel.id, type);

      if (result.success) {
        ref.read(reelsFeedProvider.notifier).applyReaction(reel.id, null);
      } else {
        ref
            .read(reelsFeedProvider.notifier)
            .applyReaction(reel.id, previousReaction);
      }
    } else {
      ref.read(reelsFeedProvider.notifier).applyReaction(reel.id, type.value);

      final result = await _likeService.reactReel(reel.id, type);
      if (result.success) {
        final serverType = result.reactionType?.value;
        ref.read(reelsFeedProvider.notifier).applyReaction(reel.id, serverType);
      } else {
        ref
            .read(reelsFeedProvider.notifier)
            .applyReaction(reel.id, reel.currentUserReaction);
      }
    }
  }

  void _showReactionPicker() {
    if (_reactionOverlay != null) {
      _removeReactionOverlay();
      return;
    }
    HapticFeedback.mediumImpact();
    _reactionOverlay = OverlayEntry(
      builder:
          (_) => _VerticalReactionPicker(
            layerLink: _reactionLayerLink,
            currentReaction: widget.reel.currentReactionType,
            onSelect: (type) {
              _removeReactionOverlay();
              _applyReaction(type);
            },
            onDismiss: _removeReactionOverlay,
          ),
    );
    Overlay.of(context).insert(_reactionOverlay!);
  }

  void _removeReactionOverlay() {
    _reactionOverlay?.remove();
    _reactionOverlay = null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MORE OPTIONS
  // ─────────────────────────────────────────────────────────────────────────

  void _showMoreOptions() {
    widget.controller?.pause();
    _removeReactionOverlay();
    final isOwner = _isCurrentUser();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => _ReelOptionsSheet(
            isOwner: isOwner,
            reel: widget.reel,
            onEdit: isOwner ? () => _showEditDialog() : null,
            onDelete: isOwner ? () => _confirmDelete() : null,
            onRepost: !isOwner ? () => _doRepost() : null,
          ),
    ).then((_) {
      if (widget.isActive && mounted) widget.controller?.play();
    });
  }

  void _showEditDialog() {
    final ctrl = TextEditingController(text: widget.reel.caption);
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Edit Caption',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: TextField(
              controller: ctrl,
              maxLines: 4,
              minLines: 1,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Write a caption…',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF48706),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  final newCaption = ctrl.text.trim();
                  Navigator.pop(ctx);
                  final err = await ref
                      .read(reelsFeedProvider.notifier)
                      .editReel(widget.reel.id, newCaption);
                  if (err != null && mounted) {
                    _showSnack(err, isError: true);
                  } else if (mounted) {
                    _showSnack('Caption updated!');
                  }
                },
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Delete Reel',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: const Text(
              'This reel will be permanently deleted. This action cannot be undone.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final err = await ref
                      .read(reelsFeedProvider.notifier)
                      .deleteReel(widget.reel.id);
                  if (err != null && mounted) _showSnack(err, isError: true);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _doRepost() async {
    _showSnack('Reposting…');
    final err = await ref
        .read(reelsFeedProvider.notifier)
        .repostReel(widget.reel.id);
    if (err != null && mounted) {
      _showSnack(err, isError: true);
    } else if (mounted) {
      _showSnack('Reposted successfully!');
    }
  }

  void _shareReel() {
    Share.share(
      'Check out this reel by @${widget.reel.username}!\n'
      '${widget.reel.bestVideoUrl ?? ''}',
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFFF48706),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool _isCurrentUser() =>
      AppData().isMe(widget.reel.userId) ||
      AppData().isMe(widget.reel.username);

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final ctrl = widget.controller;

    // When the pool has a ready controller, use NativeVideoPlayer.
    // The overlayBuilder hosts ALL our Flutter UI on top of the native surface.
    if (ctrl != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          NativeVideoPlayer(controller: ctrl),
          _buildOverlay(size),
        ],
      );
    }

    // Controller not ready yet — show thumbnail + overlay
    return Stack(
      fit: StackFit.expand,
      children: [
      _buildThumbnailFallback(size), _buildOverlay(size)],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // OVERLAY  (all Flutter UI rendered on top of the native video)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOverlay(Size size) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Transparent gesture detector fills the full screen
        Positioned.fill(
          child: GestureDetector(
            onTap: _onTap,
            onDoubleTapDown: _onDoubleTap,
            onDoubleTap: () {},
            onLongPressStart: _onLongPressStart,
            onLongPressEnd: _onLongPressEnd,
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),
        ),

        _buildGradients(),
        _buildTopBar(),
        _buildBottomLeft(size),
        _buildActionBar(size),
        _buildProgressBar(size),

        if (_showControls) _buildPlayPauseIndicator(),
        if (_showHeartBurst) _buildHeartBurst(),
        if (_showComments) _buildCommentsSheet(),
      ],
    );
  }

  // ── Thumbnail fallback (shown while controller is loading) ────────────────

  Widget _buildThumbnailFallback(Size size) {
    final thumb = widget.reel.thumbnail;
    if (thumb != null && thumb.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: thumb,
        fit: BoxFit.cover,
        width: size.width,
        height: size.height,
        placeholder: (_, __) => const ColoredBox(color: Colors.black),
        errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
      );
    }
    return Container(
      color: Colors.black,
      child: const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            color: Colors.white54,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  // ── Gradients ─────────────────────────────────────────────────────────────

  Widget _buildGradients() => Stack(
    children: [
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 120,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.5), Colors.transparent],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        height: 320,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withOpacity(0.8), Colors.transparent],
            ),
          ),
        ),
      ),
    ],
  );

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() => Positioned(
    top: MediaQuery.of(context).padding.top + 8,
    left: 8,
    right: 16,
    child: Row(
      children: [
        IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 22,
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        const Spacer(),
        const Text(
          'Reels',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const Spacer(),
      ],
    ),
  );

  // ── Bottom-left (user info + caption) ─────────────────────────────────────

  Widget _buildBottomLeft(Size size) => Positioned(
    bottom: 70,
    left: 12,
    right: 80,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.reel.isRepost && widget.reel.sharedReelDetails != null)
          _buildRepostBadge(),
        GestureDetector(
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) =>
                          SpecificUserProfilePage(userId: widget.reel.userId),
                ),
              ),
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.reel.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    shadows: [Shadow(blurRadius: 4)],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              if (!_isCurrentUser())
                _InlineFollowButton(
                  reel: widget.reel,
                  onFollowChanged:
                      (v) => ref
                          .read(reelsFeedProvider.notifier)
                          .updateFollow(widget.reel.userId, v),
                ),
            ],
          ),
        ),
        if (widget.reel.caption.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ExpandableCaption(caption: widget.reel.caption),
        ],
      ],
    ),
  );

  Widget _buildRepostBadge() {
    final original = widget.reel.sharedReelDetails!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.repeat_rounded, color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          Text(
            'Reposted from @${original.username}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              shadows: [Shadow(blurRadius: 3)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final url = widget.reel.avatar;
    final initial =
        widget.reel.username.isNotEmpty
            ? widget.reel.username[0].toUpperCase()
            : '?';
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: ClipOval(
        child:
            url.isNotEmpty
                ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _avatarFallback(initial),
                  errorWidget: (_, __, ___) => _avatarFallback(initial),
                )
                : _avatarFallback(initial),
      ),
    );
  }

  Widget _avatarFallback(String initial) => Container(
    color: Colors.grey.shade700,
    alignment: Alignment.center,
    child: Text(
      initial,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
  );

  // ── Right action bar ──────────────────────────────────────────────────────

  Widget _buildActionBar(Size size) {
    final reel = widget.reel;
    final currentReaction = reel.currentReactionType;
    final hasReaction = currentReaction != null;

    return Positioned(
      right: 8,
      bottom: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Like / Reaction
          CompositedTransformTarget(
            link: _reactionLayerLink,
            child: GestureDetector(
              onTap:
                  () =>
                      hasReaction
                          ? _applyReaction(currentReaction)
                          : _applyReaction(ReactionType.like),
              onLongPress: _showReactionPicker,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child:
                          hasReaction
                              ? Text(
                                currentReaction.emoji,
                                style: const TextStyle(fontSize: 28),
                              )
                              : const Icon(
                                Icons.favorite_border_rounded,
                                color: Colors.white,
                                size: 30,
                                shadows: [Shadow(blurRadius: 6)],
                              ),
                    ),
                  ),
                  Text(
                    _formatCount(reel.reactionsCount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 4)],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Comment
          _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: _formatCount(reel.commentsCount),
            onTap: () => setState(() => _showComments = !_showComments),
          ),

          const SizedBox(height: 20),

          // Repost (non-owners)
          if (!_isCurrentUser()) ...[
            _ActionButton(
              icon: Icons.repeat_rounded,
              label: 'Repost',
              onTap: _doRepost,
            ),
            const SizedBox(height: 20),
          ],

          // Share
          _ActionButton(
            icon: Icons.send_rounded,
            label: 'Share',
            onTap: _shareReel,
          ),

          // More options
          IconButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.white,
              size: 24,
            ),
            onPressed: _showMoreOptions,
          ),

          const SizedBox(height: 20),

          // Mute
          _ActionButton(
            icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            label: '',
            onTap: _toggleMute,
          ),
        ],
      ),
    );
  }

  // ── Progress bar ──────────────────────────────────────────────────────────

  Widget _buildProgressBar(Size size) {
    final total = _duration.inMilliseconds;
    final pos = _position.inMilliseconds.clamp(0, total > 0 ? total : 1);
    final fraction = total > 0 ? pos / total : 0.0;

    return Positioned(
      bottom: 52,
      left: 0,
      right: 0,
      child: GestureDetector(
        onHorizontalDragStart: (_) => setState(() => _isSeeking = true),
        onHorizontalDragUpdate: (d) {
          final dx = d.localPosition.dx.clamp(0.0, size.width);
          _seekTo(dx / size.width);
        },
        onHorizontalDragEnd: (_) => setState(() => _isSeeking = false),
        onTapDown: (d) {
          final dx = d.localPosition.dx.clamp(0.0, size.width);
          _seekTo(dx / size.width);
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 20,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(height: 2, color: Colors.white24),
              FractionallySizedBox(
                widthFactor: fraction.clamp(0.0, 1.0),
                child: Container(height: 2, color: Colors.white),
              ),
              Positioned(
                left: (fraction * size.width - 6).clamp(0.0, size.width - 12),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Play/pause indicator ──────────────────────────────────────────────────

  Widget _buildPlayPauseIndicator() => Center(
    child: AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 42,
        ),
      ),
    ),
  );

  // ── Heart burst ───────────────────────────────────────────────────────────

  Widget _buildHeartBurst() => Positioned(
    left: _heartPosition.dx - 48,
    top: _heartPosition.dy - 48,
    child: IgnorePointer(
      child: AnimatedBuilder(
        animation: _heartCtrl,
        builder:
            (_, __) => Opacity(
              opacity: _heartOpacity.value,
              child: Transform.scale(
                scale: _heartScale.value,
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 96,
                  shadows: [
                    Shadow(color: Colors.red, blurRadius: 20),
                    Shadow(blurRadius: 8),
                  ],
                ),
              ),
            ),
      ),
    ),
  );

  // ── Comments sheet ────────────────────────────────────────────────────────

  Widget _buildCommentsSheet() => Positioned(
    bottom: 0,
    left: 0,
    right: 0,
    height: MediaQuery.of(context).size.height * 0.6,
    child: GestureDetector(
      onTap: () {},
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Spacer(),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showComments = false),
                    child: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),

            Expanded(
              child: CommentSection(
                contentId: widget.reel.id,
                isReel: true,

                onCommentCountChanged: (delta) {
                  if (delta > 0) {
                    ref
                        .read(reelsFeedProvider.notifier)
                        .incrementComments(widget.reel.id);
                  } else {
                    ref
                        .read(reelsFeedProvider.notifier)
                        .decrementComments(widget.reel.id);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count > 0 ? '$count' : '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REEL OPTIONS BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _ReelOptionsSheet extends StatelessWidget {
  final bool isOwner;
  final ReelModel reel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRepost;

  const _ReelOptionsSheet({
    required this.isOwner,
    required this.reel,
    this.onEdit,
    this.onDelete,
    this.onRepost,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (isOwner) ...[
            _OptionTile(
              icon: Icons.edit_rounded,
              label: 'Edit Caption',
              onTap: () {
                Navigator.pop(context);
                onEdit?.call();
              },
            ),
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete Reel',
              color: Colors.redAccent,
              onTap: () {
                Navigator.pop(context);
                onDelete?.call();
              },
            ),
          ] else ...[
            _OptionTile(
              icon: Icons.repeat_rounded,
              label: 'Repost',
              onTap: () {
                Navigator.pop(context);
                onRepost?.call();
              },
            ),
          ],
          _OptionTile(
            icon: Icons.close_rounded,
            label: 'Cancel',
            color: Colors.white54,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    this.color = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VERTICAL REACTION PICKER OVERLAY
// ─────────────────────────────────────────────────────────────────────────────

class _VerticalReactionPicker extends StatefulWidget {
  final LayerLink layerLink;
  final ReactionType? currentReaction;
  final void Function(ReactionType) onSelect;
  final VoidCallback onDismiss;

  const _VerticalReactionPicker({
    required this.layerLink,
    required this.currentReaction,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<_VerticalReactionPicker> createState() =>
      _VerticalReactionPickerState();
}

class _VerticalReactionPickerState extends State<_VerticalReactionPicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;
  ReactionType? _hovered;

  static const _reactions = ReactionType.values;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double itemH = 52.0;
    final double pillH = _reactions.length * itemH + 16;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),
        ),
        CompositedTransformFollower(
          link: widget.layerLink,
          showWhenUnlinked: false,
          offset: Offset(-68, -(pillH / 2) + 22),
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        _reactions.map((r) => _buildItem(r, itemH)).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItem(ReactionType r, double itemH) {
    final isActive = widget.currentReaction == r;
    final isHovered = _hovered == r;
    final targetScale = isHovered ? 1.4 : (isActive ? 1.15 : 1.0);

    return GestureDetector(
      onTap: () => widget.onSelect(r),
      onTapDown: (_) => setState(() => _hovered = r),
      onTapCancel: () => setState(() => _hovered = null),
      child: SizedBox(
        width: 56,
        height: itemH,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (isActive)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
              ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: targetScale),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              builder:
                  (_, scale, child) =>
                      Transform.scale(scale: scale, child: child),
              child: Text(r.emoji, style: const TextStyle(fontSize: 26)),
            ),
            if (isHovered)
              Positioned(
                left: -72,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    r.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
// ACTION BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.iconColor = Colors.white,
    required this.label,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.9,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _ctrl.reverse();
    _ctrl.forward();
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _handleTap,
    behavior: HitTestBehavior.opaque,
    child: ScaleTransition(
      scale: _ctrl,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.icon,
            color: widget.iconColor,
            size: 30,
            shadows: const [Shadow(blurRadius: 6)],
          ),
          if (widget.label.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 4)],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE FOLLOW BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _InlineFollowButton extends StatefulWidget {
  final ReelModel reel;
  final ValueChanged<bool> onFollowChanged;
  const _InlineFollowButton({
    required this.reel,
    required this.onFollowChanged,
  });

  @override
  State<_InlineFollowButton> createState() => _InlineFollowButtonState();
}

class _InlineFollowButtonState extends State<_InlineFollowButton> {
  @override
  Widget build(BuildContext context) {
    return FollowButton(
      targetUserId: widget.reel.userId,
      initialFollowStatus: widget.reel.isFollowed,
      onFollowSuccess: () {
        widget.reel.isFollowed = true;
        widget.onFollowChanged(true);
      },
      onUnfollowSuccess: () {
        widget.reel.isFollowed = false;
        widget.onFollowChanged(false);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPANDABLE CAPTION
// ─────────────────────────────────────────────────────────────────────────────

class _ExpandableCaption extends StatefulWidget {
  final String caption;
  const _ExpandableCaption({required this.caption});

  @override
  State<_ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<_ExpandableCaption> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: RichText(
          maxLines: _expanded ? null : 2,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          text: TextSpan(
            children: [
              TextSpan(
                text: widget.caption,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.45,
                  shadows: [Shadow(blurRadius: 4)],
                ),
              ),
              if (!_expanded)
                const TextSpan(
                  text: ' more',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER LOADING
// ─────────────────────────────────────────────────────────────────────────────

class _ReelsShimmer extends StatelessWidget {
  const _ReelsShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade900,
      highlightColor: Colors.grey.shade700,
      period: const Duration(milliseconds: 1400),
      child: Container(color: Colors.black),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────────────────────────────────────

class _ReelsError extends StatelessWidget {
  final VoidCallback onRetry;
  const _ReelsError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white54, size: 56),
          const SizedBox(height: 16),
          const Text(
            'Could not load reels',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF48706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
