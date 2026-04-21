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

// ════════════════════════════════════════════════════════════════════════════
// MODELS
// ════════════════════════════════════════════════════════════════════════════

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

// ════════════════════════════════════════════════════════════════════════════
// API SERVICE
// ════════════════════════════════════════════════════════════════════════════

class ReelsApiService {
  static const String _base = 'http://36.253.137.34:8005';
  static const String _reelsUrl = '$_base/api/reels/';

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
        (cursor != null && cursor.isNotEmpty)
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
        return ReelOperationResult(
          success: true,
          data: ReelModel.fromJson(
            json.decode(res.body) as Map<String, dynamic>,
          ),
        );
      }
      return ReelOperationResult(
        success: false,
        errorMessage: _parseError(res.body, res.statusCode),
      );
    } catch (_) {
      return const ReelOperationResult(
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
    } catch (_) {
      return const ReelOperationResult(
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
        return ReelOperationResult(
          success: true,
          data: ReelModel.fromJson(
            json.decode(res.body) as Map<String, dynamic>,
          ),
        );
      }
      return ReelOperationResult(
        success: false,
        errorMessage: _parseError(res.body, res.statusCode),
      );
    } catch (_) {
      return const ReelOperationResult(
        success: false,
        errorMessage: 'Network error. Please try again.',
      );
    }
  }

  static String _parseError(String body, int code) {
    try {
      final d = json.decode(body);
      if (d is Map) {
        final v = d['detail'] ?? d['message'] ?? d['error'];
        if (v != null) return v.toString();
      }
    } catch (_) {}
    return 'Something went wrong (code $code)';
  }
}

// ════════════════════════════════════════════════════════════════════════════
// RIVERPOD STATE
// ════════════════════════════════════════════════════════════════════════════

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
    final had = reel.currentUserReaction != null;
    final will = newReaction != null;
    reel.currentUserReaction = newReaction;
    if (!had && will) reel.reactionsCount++;
    if (had && !will)
      reel.reactionsCount = (reel.reactionsCount - 1).clamp(0, 999999);
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
    final old = list[idx].caption;
    list[idx].caption = newCaption;
    state = AsyncValue.data(List.from(list));
    final result = await ReelsApiService.editReel(
      reelId: reelId,
      caption: newCaption,
    );
    if (result.success) {
      if (result.data != null) list[idx].caption = result.data!.caption;
      state = AsyncValue.data(List.from(list));
      return null;
    }
    list[idx].caption = old;
    state = AsyncValue.data(List.from(list));
    return result.errorMessage;
  }

  Future<String?> deleteReel(String reelId) async {
    final result = await ReelsApiService.deleteReel(reelId);
    if (result.success) {
      state = AsyncValue.data(
        (state.value ?? []).where((r) => r.id != reelId).toList(),
      );
      return null;
    }
    return result.errorMessage;
  }

  Future<String?> repostReel(String reelId) async {
    final result = await ReelsApiService.repostReel(reelId);
    if (result.success && result.data != null) {
      state = AsyncValue.data([result.data!, ...(state.value ?? [])]);
      return null;
    }
    return result.errorMessage;
  }
}

final reelsFeedProvider =
    StateNotifierProvider<ReelsFeedNotifier, AsyncValue<List<ReelModel>>>(
      (ref) => ReelsFeedNotifier(),
    );

// ════════════════════════════════════════════════════════════════════════════
// CONTROLLER ENTRY — wraps lifecycle state alongside the controller
// ════════════════════════════════════════════════════════════════════════════

enum _CtrlState { idle, initializing, ready, error }

class _ControllerEntry {
  final NativeVideoPlayerController ctrl;
  _CtrlState state = _CtrlState.idle;
  bool urlLoaded = false;

  _ControllerEntry(this.ctrl);

  bool get isReady => state == _CtrlState.ready && urlLoaded;
}

// ════════════════════════════════════════════════════════════════════════════
// CONTROLLER POOL
//
// KEY DESIGN DECISIONS:
// ① The pool NEVER calls initialize() or loadUrl() — only the _ReelItemState
//    does that AFTER NativeVideoPlayer widget is mounted (post-frame).
// ② Each controller gets a unique integer id starting at 500 to avoid
//    collisions with any other players in the app.
// ③ Eviction: keep ±2 neighbours around currentIndex, dispose the rest.
//    This prevents unbounded ExoPlayer instances which cause OOM crashes.
// ④ The entry tracks _CtrlState so _ReelItemState never double-initializes.
// ════════════════════════════════════════════════════════════════════════════

class _ControllerPool {
  static int _idSeed = 500;

  final Map<String, _ControllerEntry> _pool = {};

  _ControllerEntry allocate(ReelModel reel) {
    if (_pool.containsKey(reel.id)) return _pool[reel.id]!;
    final ctrl = NativeVideoPlayerController(
      id: _idSeed++,
      autoPlay: false,
      enableLooping: true,
      showNativeControls: false,
    );
    final entry = _ControllerEntry(ctrl);
    _pool[reel.id] = entry;
    developer.log('[Pool] ✅ Allocated id=${ctrl.id} for reel ${reel.id}');
    return entry;
  }

  _ControllerEntry? get(String reelId) => _pool[reelId];

  /// Pause ALL controllers except [activeReelId].
  /// This is the fix for audio bleeding between reels.
  void pauseAllExcept(String activeReelId) {
    for (final entry in _pool.entries) {
      if (entry.key != activeReelId && entry.value.isReady) {
        entry.value.ctrl.pause();
      }
    }
  }

  /// Hard-stop everything — called when leaving ReelsScreen.
  void stopAll() {
    for (final entry in _pool.values) {
      if (entry.isReady) {
        try {
          entry.ctrl.pause();
        } catch (_) {}
      }
    }
  }

  void evict(int currentIndex, List<ReelModel> reels, {int radius = 2}) {
    final toRemove = <String>[];
    for (final key in _pool.keys) {
      final idx = reels.indexWhere((r) => r.id == key);
      if (idx == -1 || (idx - currentIndex).abs() > radius) {
        toRemove.add(key);
      }
    }
    for (final key in toRemove) {
      developer.log('[Pool] 🗑 Evicting reel $key');
      try {
        _pool[key]?.ctrl.dispose();
      } catch (_) {}
      _pool.remove(key);
    }
  }

  void disposeAll() {
    for (final e in _pool.values) {
      try {
        e.ctrl.dispose();
      } catch (_) {}
    }
    _pool.clear();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// REELS SCREEN
// ════════════════════════════════════════════════════════════════════════════

class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen>
    with WidgetsBindingObserver {
  late final PageController _pageCtrl;
  final _pool = _ControllerPool();
  int _currentPage = 0;
  bool _isAnimating = false;

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageCtrl = PageController();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // ✅ FIX: stop all audio BEFORE disposing so nothing plays in background
    _pool.stopAll();
    _pool.disposeAll();
    _pageCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Pause ALL when app goes to background
      _pool.stopAll();
    } else if (state == AppLifecycleState.resumed) {
      // Only resume the active reel
      final reels = ref.read(reelsFeedProvider).value ?? [];
      if (_currentPage < reels.length) {
        final entry = _pool.get(reels[_currentPage].id);
        if (entry != null && entry.isReady) entry.ctrl.play();
      }
    }
  }

  // ── page navigation ───────────────────────────────────────────────────────

  void _goToPage(int page, List<ReelModel> reels) {
    if (_isAnimating || page < 0 || page >= reels.length) return;
    _isAnimating = true;
    _pageCtrl
        .animateToPage(
          page,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
        )
        .then((_) => _isAnimating = false);
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    ref.read(activeReelIndexProvider.notifier).state = index;

    final reels = ref.read(reelsFeedProvider).value ?? [];

    // ✅ FIX: pause ALL others immediately on page change — stops audio bleed
    _pool.pauseAllExcept(index < reels.length ? reels[index].id : '');

    _allocateAround(reels, index);
    _pool.evict(index, reels);

    if (index >= reels.length - 3) {
      ref.read(reelsFeedProvider.notifier).loadMore();
    }
  }

  void _allocateAround(List<ReelModel> reels, int index) {
    final from = max(0, index - 1);
    final to = min(reels.length - 1, index + 2);
    for (int i = from; i <= to; i++) {
      if (reels[i].hasVideo) _pool.allocate(reels[i]);
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(reelsFeedProvider);

    // Allocate controllers when new data arrives
    ref.listen<AsyncValue<List<ReelModel>>>(reelsFeedProvider, (_, next) {
      next.whenData((reels) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _allocateAround(reels, _currentPage);
        });
      });
    });

    return PopScope(
      // ✅ FIX: stop all audio when user presses back
      onPopInvoked: (_) => _pool.stopAll(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: feedState.when(
          loading: () => const _ReelsShimmer(),
          error:
              (e, _) => _ReelsError(
                onRetry: () => ref.read(reelsFeedProvider.notifier).refresh(),
              ),
          data: (reels) {
            if (reels.isEmpty) return _buildEmpty();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _allocateAround(reels, _currentPage);
            });

            return RawGestureDetector(
              gestures: {
                VerticalDragGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      VerticalDragGestureRecognizer
                    >(() => VerticalDragGestureRecognizer(), (inst) {
                      double start = 0;
                      inst.onStart = (d) => start = d.globalPosition.dy;
                      inst.onEnd = (d) {
                        if (_isAnimating) return;
                        final delta = start - d.globalPosition.dy;
                        final v = d.primaryVelocity ?? 0;
                        if (delta > 60 || v < -400)
                          _goToPage(_currentPage + 1, reels);
                        if (delta < -60 || v > 400)
                          _goToPage(_currentPage - 1, reels);
                      };
                    }),
              },
              child: PageView.builder(
                controller: _pageCtrl,
                scrollDirection: Axis.vertical,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: _onPageChanged,
                itemCount: reels.length,
                itemBuilder: (ctx, i) {
                  final reel = reels[i];
                  final entry = reel.hasVideo ? _pool.allocate(reel) : null;
                  return _ReelItem(
                    key: ValueKey(reel.id),
                    reel: reel,
                    isActive: i == _currentPage,
                    entry: entry,
                    pool: _pool,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
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
          onPressed: () => ref.read(reelsFeedProvider.notifier).refresh(),
          child: const Text('Refresh', style: TextStyle(color: Colors.orange)),
        ),
      ],
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// SINGLE REEL ITEM
//
// INITIALIZATION SEQUENCE (the ONLY correct order for NativeVideoPlayer):
//
//  Frame N   → NativeVideoPlayer widget inserted into Flutter tree
//              → platform view factory called → native surface created
//              → plugin registers channel "native_video_player_controller_<id>"
//
//  Frame N+1 → addPostFrameCallback fires → _initAndPlay() starts
//              → await ctrl.initialize()   ← NOW channel exists → no MissingPluginException
//              → await ctrl.loadUrl(...)
//              → _attachStreams()
//              → ctrl.play()  (only if isActive)
//
// Any deviation (initializing before mount, or attaching streams before
// initialize) causes MissingPluginException.
// ════════════════════════════════════════════════════════════════════════════

class _ReelItem extends ConsumerStatefulWidget {
  final ReelModel reel;
  final bool isActive;
  final _ControllerEntry? entry;
  final _ControllerPool pool;

  const _ReelItem({
    Key? key,
    required this.reel,
    required this.isActive,
    required this.entry,
    required this.pool,
  }) : super(key: key);

  @override
  ConsumerState<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends ConsumerState<_ReelItem>
    with SingleTickerProviderStateMixin {
  // ── playback ──────────────────────────────────────────────────────────────
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _isSeeking = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<PlayerActivityState>? _stateSub;

  // ── UI ────────────────────────────────────────────────────────────────────
  bool _showControls = false;
  bool _showComments = false;
  bool _viewRecorded = false;

  // ── heart burst ───────────────────────────────────────────────────────────
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;
  late Animation<double> _heartOpacity;
  bool _showHeart = false;
  Offset _heartPos = Offset.zero;

  // ── reaction overlay ──────────────────────────────────────────────────────
  OverlayEntry? _reactionOverlay;
  final LayerLink _reactionLink = LayerLink();
  final ContentLikeService _likeService = ContentLikeService(
    baseUrl: 'http://36.253.137.34:8005',
  );

  // ── init guard ────────────────────────────────────────────────────────────
  bool _initStarted = false;

  NativeVideoPlayerController? get _ctrl => widget.entry?.ctrl;
  _ControllerEntry? get _entry => widget.entry;

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initHeartAnim();
    // Post-frame: NativeVideoPlayer widget is now mounted → safe to initialize
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initAndPlay();
    });
  }

  @override
  void didUpdateWidget(_ReelItem old) {
    super.didUpdateWidget(old);

    // Controller instance swapped by pool
    if (old.entry?.ctrl != widget.entry?.ctrl) {
      _detachStreams();
      _initStarted = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initAndPlay();
      });
      return;
    }

    // Active flag changed
    if (widget.isActive != old.isActive) {
      if (widget.isActive) {
        // ✅ Pause everything else first
        widget.pool.pauseAllExcept(widget.reel.id);
        if (_entry?.isReady == true) {
          _ctrl?.play();
        } else if (!_initStarted) {
          _initAndPlay();
        }
        if (!_viewRecorded) {
          _viewRecorded = true;
          ReelsApiService.recordView(widget.reel.id);
        }
      } else {
        // ✅ FIX: Always pause when scrolled away — stops audio bleed
        _ctrl?.pause();
        _removeReactionOverlay();
      }
    }
  }

  @override
  void dispose() {
    _detachStreams();
    _heartCtrl.dispose();
    _removeReactionOverlay();
    // ✅ Pool owns controller — pause but do NOT dispose here
    try {
      _ctrl?.pause();
    } catch (_) {}
    super.dispose();
  }

  // ── core init sequence ────────────────────────────────────────────────────

  Future<void> _initAndPlay() async {
    final entry = _entry;
    final ctrl = _ctrl;
    if (ctrl == null || entry == null || !mounted) return;

    // Already ready → just play if active
    if (entry.isReady) {
      if (widget.isActive) {
        widget.pool.pauseAllExcept(widget.reel.id);
        ctrl.play();
      }
      return;
    }

    // Guard: only one initialization attempt at a time
    if (entry.state == _CtrlState.initializing || _initStarted) return;
    _initStarted = true;
    entry.state = _CtrlState.initializing;

    try {
      developer.log(
        '[ReelItem] 🚀 initialize() reel=${widget.reel.id} ctrl=${ctrl.id}',
      );

      // ────────────────────────────────────────────────────────────────────
      // CRITICAL: The NativeVideoPlayer widget must be fully laid out and
      // its platform view registered before initialize() is called.
      // addPostFrameCallback already gives us one frame; we wait one more
      // to be absolutely safe on slower devices.
      // ────────────────────────────────────────────────────────────────────
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;

      await ctrl.initialize();
      if (!mounted) return;

      final url = widget.reel.bestVideoUrl!;
      final token = AppData().accessToken ?? '';
      final hdrs =
          token.isNotEmpty
              ? <String, String>{'Authorization': 'Bearer $token'}
              : null;

      developer.log('[ReelItem] 📡 loadUrl($url)');
      await ctrl.loadUrl(url: url, headers: hdrs);
      if (!mounted) return;

      // Mark entry ready BEFORE attaching streams
      entry.state = _CtrlState.ready;
      entry.urlLoaded = true;
      _attachStreams(ctrl);

      if (_isMuted) ctrl.setVolume(0.0);

      if (widget.isActive) {
        // Pause all others before playing
        widget.pool.pauseAllExcept(widget.reel.id);
        ctrl.play();
        if (!_viewRecorded) {
          _viewRecorded = true;
          ReelsApiService.recordView(widget.reel.id);
        }
      }

      if (mounted) setState(() {});
    } catch (e, st) {
      developer.log('[ReelItem] ❌ init error: $e\n$st');
      if (_entry != null) _entry!.state = _CtrlState.error;
      _initStarted = false;
    }
  }

  // ── stream management ─────────────────────────────────────────────────────

  void _attachStreams(NativeVideoPlayerController ctrl) {
    _detachStreams();
    _posSub = ctrl.positionStream.listen((p) {
      if (mounted && !_isSeeking) setState(() => _position = p);
    });
    _durSub = ctrl.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _stateSub = ctrl.playerStateStream.listen((s) {
      if (mounted)
        setState(() => _isPlaying = s == PlayerActivityState.playing);
    });
  }

  void _detachStreams() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _posSub = _durSub = _stateSub = null;
  }

  // ── heart animation ───────────────────────────────────────────────────────

  void _initHeartAnim() {
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heartScale = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
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
          end: 0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_heartCtrl);
    _heartOpacity = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 80),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_heartCtrl);
  }

  // ── gestures ──────────────────────────────────────────────────────────────

  void _onTap() {
    _removeReactionOverlay();
    if (_entry?.isReady != true) return;
    if (_isPlaying) {
      _ctrl?.pause();
    } else {
      widget.pool.pauseAllExcept(widget.reel.id);
      _ctrl?.play();
    }
    _flashControls();
  }

  void _flashControls() {
    if (mounted) setState(() => _showControls = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onDoubleTap(TapDownDetails d) {
    HapticFeedback.mediumImpact();
    _removeReactionOverlay();
    setState(() {
      _heartPos = d.localPosition;
      _showHeart = true;
    });
    _heartCtrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _showHeart = false);
    });
    if (!widget.reel.isLiked) _applyReaction(ReactionType.like);
  }

  void _onLongPressStart(LongPressStartDetails _) => _ctrl?.pause();
  void _onLongPressEnd(LongPressEndDetails _) {
    if (widget.isActive && _entry?.isReady == true) {
      widget.pool.pauseAllExcept(widget.reel.id);
      _ctrl?.play();
    }
  }

  void _seekTo(double frac) {
    if (_entry?.isReady != true) return;
    final target = Duration(
      milliseconds: (_duration.inMilliseconds * frac).round(),
    );
    _ctrl?.seekTo(target);
    if (mounted) setState(() => _position = target);
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _ctrl?.setVolume(_isMuted ? 0.0 : 1.0);
  }

  // ── reactions ─────────────────────────────────────────────────────────────

  Future<void> _applyReaction(ReactionType type) async {
    final reel = widget.reel;
    final same = reel.currentUserReaction == type.value;
    final notifier = ref.read(reelsFeedProvider.notifier);
    notifier.applyReaction(reel.id, (reel.isLiked && same) ? null : type.value);
    final result = await _likeService.reactReel(reel.id, type);
    notifier.applyReaction(
      reel.id,
      result.success ? result.reactionType?.value : reel.currentUserReaction,
    );
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
            layerLink: _reactionLink,
            currentReaction: widget.reel.currentReactionType,
            onSelect: (t) {
              _removeReactionOverlay();
              _applyReaction(t);
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

  // ── options ───────────────────────────────────────────────────────────────

  bool _isMe() =>
      AppData().isMe(widget.reel.userId) ||
      AppData().isMe(widget.reel.username);

  void _showOptions() {
    _ctrl?.pause();
    _removeReactionOverlay();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _ReelOptionsSheet(
            isOwner: _isMe(),
            reel: widget.reel,
            onEdit: _isMe() ? _showEditDialog : null,
            onDelete: _isMe() ? _confirmDelete : null,
            onRepost: !_isMe() ? _doRepost : null,
          ),
    ).then((_) {
      if (widget.isActive && mounted && _entry?.isReady == true) {
        widget.pool.pauseAllExcept(widget.reel.id);
        _ctrl?.play();
      }
    });
  }

  void _showEditDialog() {
    final tc = TextEditingController(text: widget.reel.caption);
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
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
              controller: tc,
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
                onPressed: () => Navigator.pop(context),
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
                  final cap = tc.text.trim();
                  Navigator.pop(context);
                  final err = await ref
                      .read(reelsFeedProvider.notifier)
                      .editReel(widget.reel.id, cap);
                  if (mounted) {
                    _showSnack(err ?? 'Caption updated!', isError: err != null);
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
          (_) => AlertDialog(
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
              'This reel will be permanently deleted. This cannot be undone.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
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
                  Navigator.pop(context);
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
    if (mounted) {
      _showSnack(err ?? 'Reposted successfully!', isError: err != null);
    }
  }

  void _shareReel() => Share.share(
    'Check out this reel by @${widget.reel.username}!\n${widget.reel.bestVideoUrl ?? ''}',
  );

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

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final ctrl = _ctrl;

    if (ctrl != null) {
      return NativeVideoPlayer(
        controller: ctrl,
        overlayBuilder: (_, __) => _buildOverlay(size),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [_buildThumb(size), _buildOverlay(size)],
    );
  }

  Widget _buildOverlay(Size size) => Stack(
    fit: StackFit.expand,
    children: [
      // ── gesture layer ─────────────────────────────────────────────────
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
      _buildActionBar(),
      _buildProgress(size),
      if (_showControls) _buildPauseIndicator(),
      if (_showHeart) _buildHeartBurst(),
      // Loading overlay until ready
      if (_entry?.isReady != true) _buildLoader(),
      if (_showComments) _buildCommentsSheet(),
    ],
  );

  Widget _buildLoader() => Positioned.fill(
    child: IgnorePointer(
      child: Center(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            shape: BoxShape.circle,
          ),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildThumb(Size size) {
    final t = widget.reel.thumbnail;
    if (t != null && t.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: t,
        fit: BoxFit.cover,
        width: size.width,
        height: size.height,
        placeholder: (_, __) => const ColoredBox(color: Colors.black),
        errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
      );
    }
    return const ColoredBox(color: Colors.black);
  }

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
          onPressed: () {
            // ✅ FIX: stop audio before popping
            widget.pool.stopAll();
            Navigator.maybePop(context);
          },
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
              if (!_isMe())
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

  Widget _buildRepostBadge() => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        const Icon(Icons.repeat_rounded, color: Colors.white70, size: 14),
        const SizedBox(width: 4),
        Text(
          'Reposted from @${widget.reel.sharedReelDetails!.username}',
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

  Widget _buildAvatar() {
    final url = widget.reel.avatar;
    final init =
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
                  placeholder: (_, __) => _avatarFb(init),
                  errorWidget: (_, __, ___) => _avatarFb(init),
                )
                : _avatarFb(init),
      ),
    );
  }

  Widget _avatarFb(String c) => Container(
    color: Colors.grey.shade700,
    alignment: Alignment.center,
    child: Text(
      c,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
  );

  Widget _buildActionBar() {
    final reel = widget.reel;
    final reaction = reel.currentReactionType;
    final hasReaction = reaction != null;
    return Positioned(
      right: 8,
      bottom: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CompositedTransformTarget(
            link: _reactionLink,
            child: GestureDetector(
              onTap:
                  () => _applyReaction(
                    hasReaction ? reaction : ReactionType.like,
                  ),
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
                                reaction.emoji,
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
                    _fmt(reel.reactionsCount),
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
          _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: _fmt(reel.commentsCount),
            onTap: () => setState(() => _showComments = !_showComments),
          ),
          const SizedBox(height: 20),
          if (!_isMe()) ...[
            _ActionButton(
              icon: Icons.repeat_rounded,
              label: 'Repost',
              onTap: _doRepost,
            ),
            const SizedBox(height: 20),
          ],
          _ActionButton(
            icon: Icons.send_rounded,
            label: 'Share',
            onTap: _shareReel,
          ),
          IconButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.white,
              size: 24,
            ),
            onPressed: _showOptions,
          ),
          const SizedBox(height: 20),
          _ActionButton(
            icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            label: '',
            onTap: _toggleMute,
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(Size size) {
    final total = _duration.inMilliseconds;
    final pos = _position.inMilliseconds.clamp(0, total > 0 ? total : 1);
    final frac = total > 0 ? pos / total : 0.0;
    return Positioned(
      bottom: 52,
      left: 0,
      right: 0,
      child: GestureDetector(
        onHorizontalDragStart: (_) => setState(() => _isSeeking = true),
        onHorizontalDragUpdate: (d) {
          _seekTo(d.localPosition.dx.clamp(0.0, size.width) / size.width);
        },
        onHorizontalDragEnd: (_) => setState(() => _isSeeking = false),
        onTapDown:
            (d) =>
                _seekTo(d.localPosition.dx.clamp(0.0, size.width) / size.width),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 20,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(height: 2, color: Colors.white24),
              FractionallySizedBox(
                widthFactor: frac.clamp(0.0, 1.0),
                child: Container(height: 2, color: Colors.white),
              ),
              Positioned(
                left: (frac * size.width - 6).clamp(0.0, size.width - 12),
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

  Widget _buildPauseIndicator() => Center(
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

  Widget _buildHeartBurst() => Positioned(
    left: _heartPos.dx - 48,
    top: _heartPos.dy - 48,
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

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n > 0 ? '$n' : '';
  }
}

// ════════════════════════════════════════════════════════════════════════════
// OPTIONS SHEET
// ════════════════════════════════════════════════════════════════════════════

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
  Widget build(BuildContext context) => Container(
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
          _Tile(
            icon: Icons.edit_rounded,
            label: 'Edit Caption',
            onTap: () {
              Navigator.pop(context);
              onEdit?.call();
            },
          ),
          _Tile(
            icon: Icons.delete_outline_rounded,
            label: 'Delete Reel',
            color: Colors.redAccent,
            onTap: () {
              Navigator.pop(context);
              onDelete?.call();
            },
          ),
        ] else
          _Tile(
            icon: Icons.repeat_rounded,
            label: 'Repost',
            onTap: () {
              Navigator.pop(context);
              onRepost?.call();
            },
          ),
        _Tile(
          icon: Icons.close_rounded,
          label: 'Cancel',
          color: Colors.white54,
          onTap: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Tile({
    required this.icon,
    required this.label,
    this.color = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
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

// ════════════════════════════════════════════════════════════════════════════
// REACTION PICKER
// ════════════════════════════════════════════════════════════════════════════

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
  late Animation<double> _scale, _fade;
  ReactionType? _hovered;
  static const _list = ReactionType.values;

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
    const itemH = 52.0;
    final pillH = _list.length * itemH + 16;
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
                    children: _list.map((r) => _item(r, itemH)).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _item(ReactionType r, double h) {
    final active = widget.currentReaction == r;
    final hov = _hovered == r;
    return GestureDetector(
      onTap: () => widget.onSelect(r),
      onTapDown: (_) => setState(() => _hovered = r),
      onTapCancel: () => setState(() => _hovered = null),
      child: SizedBox(
        width: 56,
        height: h,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (active)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
              ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: hov ? 1.4 : (active ? 1.15 : 1.0)),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              builder: (_, s, c) => Transform.scale(scale: s, child: c),
              child: Text(r.emoji, style: const TextStyle(fontSize: 26)),
            ),
            if (hov)
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

// ════════════════════════════════════════════════════════════════════════════
// ACTION BUTTON
// ════════════════════════════════════════════════════════════════════════════

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
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    await _ctrl.reverse();
    _ctrl.forward();
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _tap,
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

// ════════════════════════════════════════════════════════════════════════════
// INLINE FOLLOW BUTTON
// ════════════════════════════════════════════════════════════════════════════

class _InlineFollowButton extends StatelessWidget {
  final ReelModel reel;
  final ValueChanged<bool> onFollowChanged;
  const _InlineFollowButton({
    required this.reel,
    required this.onFollowChanged,
  });

  @override
  Widget build(BuildContext context) => FollowButton(
    targetUserId: reel.userId,
    initialFollowStatus: reel.isFollowed,
    onFollowSuccess: () {
      reel.isFollowed = true;
      onFollowChanged(true);
    },
    onUnfollowSuccess: () {
      reel.isFollowed = false;
      onFollowChanged(false);
    },
  );
}

// ════════════════════════════════════════════════════════════════════════════
// EXPANDABLE CAPTION
// ════════════════════════════════════════════════════════════════════════════

class _ExpandableCaption extends StatefulWidget {
  final String caption;
  const _ExpandableCaption({required this.caption});

  @override
  State<_ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<_ExpandableCaption> {
  bool _exp = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => _exp = !_exp),
    child: AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: RichText(
        maxLines: _exp ? null : 2,
        overflow: _exp ? TextOverflow.visible : TextOverflow.ellipsis,
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
            if (!_exp)
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

// ════════════════════════════════════════════════════════════════════════════
// SHIMMER + ERROR
// ════════════════════════════════════════════════════════════════════════════

class _ReelsShimmer extends StatelessWidget {
  const _ReelsShimmer();

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: Colors.grey.shade900,
    highlightColor: Colors.grey.shade700,
    period: const Duration(milliseconds: 1400),
    child: Container(color: Colors.black),
  );
}

class _ReelsError extends StatelessWidget {
  final VoidCallback onRetry;
  const _ReelsError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
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
