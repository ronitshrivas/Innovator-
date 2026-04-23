// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:innovator/Innovator/constant/app_colors.dart';
// import 'package:innovator/Innovator/screens/Likes/Content-Like-Service.dart';

// // ─────────────────────────────────────────────────────────────────────────────
// // LikeButton — tap to like/unlike, long-press to pick any reaction
// // Behaviour matches LinkedIn:
// //   • Short tap   → toggles "Like" reaction on/off
// //   • Long press  → shows floating emoji picker above the button;
// //                   tap any reaction to apply it (replaces the current one)
// //   • Label + count shown beside the icon (pass showLabel: true)
// // ─────────────────────────────────────────────────────────────────────────────

// class LikeButton extends StatefulWidget {
//   final String contentId;
//   final bool initialLikeStatus;
//   final ContentLikeService likeService;
//   final Function(bool)? onLikeToggled;

//   /// Actual reaction type string from API ('like','love','angry',etc.)
//   /// Restores the correct emoji on first render
//   final String? initialReactionType;

//   /// Optional: display the reaction label + count inline
//   final bool showLabel;
//   final int initialCount;
//   final bool isReel;

//   const LikeButton({
//     Key? key,
//     required this.contentId,
//     required this.initialLikeStatus,
//     required this.likeService,
//     this.onLikeToggled,
//     this.initialReactionType,
//     this.showLabel = false,
//     this.initialCount = 0,
//     this.isReel = false,
//   }) : super(key: key);

//   @override
//   State<LikeButton> createState() => _LikeButtonState();
// }

// class _LikeButtonState extends State<LikeButton>
//     with SingleTickerProviderStateMixin {
//   // ── State ──────────────────────────────────────────────────────────────────
//   ReactionType? _currentReaction;
//   bool _isLoading = false;
//   late int _count;

//   // Reaction picker overlay
//   OverlayEntry? _overlayEntry;
//   final LayerLink _layerLink = LayerLink();

//   // Bounce animation for the icon on reaction change
//   late AnimationController _bounceCtrl;
//   late Animation<double> _bounceAnim;

//   // ── Lifecycle ──────────────────────────────────────────────────────────────
//   @override
//   void initState() {
//     super.initState();
//     // Restore actual reaction type from API (e.g. 'angry', 'love', 'like')
//     // Falls back to generic 'like' if type string is missing
//     if (widget.initialLikeStatus) {
//       _currentReaction =
//           widget.initialReactionType != null
//               ? ReactionTypeExtension.fromValue(widget.initialReactionType) ??
//                   ReactionType.like
//               : ReactionType.like;
//     } else {
//       _currentReaction = null;
//     }
//     _count = widget.initialCount;

//     _bounceCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 380),
//     );
//     _bounceAnim = TweenSequence([
//       TweenSequenceItem(
//         tween: Tween<double>(
//           begin: 1.0,
//           end: 1.45,
//         ).chain(CurveTween(curve: Curves.easeOut)),
//         weight: 40,
//       ),
//       TweenSequenceItem(
//         tween: Tween<double>(
//           begin: 1.45,
//           end: 0.88,
//         ).chain(CurveTween(curve: Curves.easeInOut)),
//         weight: 30,
//       ),
//       TweenSequenceItem(
//         tween: Tween<double>(
//           begin: 0.88,
//           end: 1.0,
//         ).chain(CurveTween(curve: Curves.elasticOut)),
//         weight: 30,
//       ),
//     ]).animate(_bounceCtrl);
//   }

//   @override
//   void dispose() {
//     _removeOverlay();
//     _bounceCtrl.dispose();
//     super.dispose();
//   }

//   // ── Tap: toggle Like ───────────────────────────────────────────────────────
//   Future<void> _handleTap() async {
//     if (_isLoading) return;
//     _removeOverlay();

//     // If already liked → remove; otherwise apply "like"
//     if (_currentReaction != null) {
//       await _applyReaction(null); // toggle off
//     } else {
//       await _applyReaction(ReactionType.like);
//     }
//   }

//   // ── Long press: show picker ────────────────────────────────────────────────
//   void _handleLongPress() {
//     HapticFeedback.mediumImpact();
//     if (_overlayEntry != null) {
//       _removeOverlay();
//       return;
//     }
//     _showReactionPicker();
//   }

//   // ── Apply a reaction (null = remove) ──────────────────────────────────────
//   Future<void> _applyReaction(ReactionType? type) async {
//     if (_isLoading) return;
//     setState(() => _isLoading = true);

//     final previous = _currentReaction;

//     ReactionResult result;
//     if (type == null) {
//       result =
//           widget.isReel
//               ? await widget.likeService.reactReel(
//                 widget.contentId,
//                 previous ?? ReactionType.like,
//               )
//               : await widget.likeService.reactPost(
//                 widget.contentId,
//                 previous ?? ReactionType.like,
//               );
//       if (result.success) {
//         _setReaction(null, previous);
//       }
//     } else {
//       result =
//           widget.isReel
//               ? await widget.likeService.reactReel(widget.contentId, type)
//               : await widget.likeService.reactPost(widget.contentId, type);
//       if (result.success) {
//         _setReaction(result.reactionType ?? type, previous);
//       }
//     }

//     if (mounted) setState(() => _isLoading = false);

//     widget.onLikeToggled?.call(_currentReaction != null);
//   }

//   void _setReaction(ReactionType? newType, ReactionType? previous) {
//     if (!mounted) return;
//     setState(() {
//       // Presence change only:
//       //   null → type  → +1  (first reaction)
//       //   type → null  → -1  (removed reaction)
//       //   typeA → typeB → 0  (switching 👍→❤️: same count)
//       if (newType != null && previous == null) {
//         _count++;
//       } else if (newType == null && previous != null) {
//         _count = (_count - 1).clamp(0, 999999);
//       }
//       _currentReaction = newType;
//     });
//     _bounceCtrl.forward(from: 0);
//   }

//   // ── Overlay helpers ────────────────────────────────────────────────────────
//   void _showReactionPicker() {
//     final overlay = Overlay.of(context);
//     _overlayEntry = OverlayEntry(
//       builder:
//           (_) => _ReactionPickerOverlay(
//             layerLink: _layerLink,
//             onSelect: (type) {
//               _removeOverlay();
//               _applyReaction(type);
//             },
//             onDismiss: _removeOverlay,
//             currentReaction: _currentReaction,
//           ),
//     );
//     overlay.insert(_overlayEntry!);
//   }

//   void _removeOverlay() {
//     _overlayEntry?.remove();
//     _overlayEntry = null;
//   }

//   // ── UI ─────────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     final reaction = _currentReaction;
//     final hasReaction = reaction != null;

//     // Icon + colour based on current reaction
//     final emoji = hasReaction ? reaction.emoji : null;
//     final label = hasReaction ? reaction.label : 'Like';
//     final iconColor =
//         hasReaction ? _reactionColor(reaction) : Colors.grey.shade700;

//     return CompositedTransformTarget(
//       link: _layerLink,
//       child: GestureDetector(
//         onTap: _handleTap,
//         onLongPress: _handleLongPress,
//         behavior: HitTestBehavior.opaque,
//         child: AnimatedBuilder(
//           animation: _bounceAnim,
//           builder:
//               (context, child) =>
//                   Transform.scale(scale: _bounceAnim.value, child: child),
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//             child: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // Icon / emoji
//                 _isLoading
//                     ? SizedBox(
//                       width: 22,
//                       height: 22,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         color: iconColor,
//                       ),
//                     )
//                     : emoji != null
//                     ? Text(
//                       emoji,
//                       style: const TextStyle(fontSize: 22, color: Colors.red),
//                     )
//                     : Icon(
//                       Icons.thumb_up_alt_outlined,
//                       color: iconColor,
//                       size: 22,
//                     ),

//                 if (widget.showLabel) ...[
//                   const SizedBox(width: 5),
//                   AnimatedDefaultTextStyle(
//                     duration: const Duration(milliseconds: 200),
//                     style: TextStyle(
//                       fontSize: 12,
//                       fontWeight: FontWeight.w600,
//                       color: iconColor,
//                     ),
//                     child: Text(
//                       widget.showLabel && _count > 0
//                           ? '$label · $_count'
//                           : label,
//                     ),
//                   ),
//                 ],
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Color _reactionColor(ReactionType r) {
//     switch (r) {
//       case ReactionType.like:
//         return const Color(0xFF0A66C2); // LinkedIn blue
//       case ReactionType.love:
//         return Colors.red.shade500;
//       case ReactionType.haha:
//         return Colors.amber.shade600;
//       case ReactionType.wow:
//         return Colors.amber.shade700;
//       case ReactionType.sad:
//         return Colors.amber.shade700;
//       case ReactionType.angry:
//         return Colors.orange.shade700;
//       case ReactionType.dislike:
//         return Colors.grey.shade600;
//       case ReactionType.celebrate:
//         return Colors.deepOrange.shade500;
//     }
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Reaction Picker Overlay
// // Appears above the button, floats as a pill — identical UX to LinkedIn
// // ─────────────────────────────────────────────────────────────────────────────

// class _ReactionPickerOverlay extends StatefulWidget {
//   final LayerLink layerLink;
//   final void Function(ReactionType) onSelect;
//   final VoidCallback onDismiss;
//   final ReactionType? currentReaction;

//   const _ReactionPickerOverlay({
//     required this.layerLink,
//     required this.onSelect,
//     required this.onDismiss,
//     this.currentReaction,
//   });

//   @override
//   State<_ReactionPickerOverlay> createState() => _ReactionPickerOverlayState();
// }

// class _ReactionPickerOverlayState extends State<_ReactionPickerOverlay>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _ctrl;
//   late Animation<double> _scaleAnim;
//   late Animation<double> _fadeAnim;

//   // Which emoji is being hovered/pressed
//   ReactionType? _hovered;

//   static const _reactions = ReactionType.values;

//   @override
//   void initState() {
//     super.initState();
//     _ctrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 260),
//     );
//     _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
//     _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
//     _ctrl.forward();
//   }

//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         // Transparent dismissal layer
//         Positioned.fill(
//           child: GestureDetector(
//             onTap: widget.onDismiss,
//             behavior: HitTestBehavior.translucent,
//             child: Container(color: Colors.transparent),
//           ),
//         ),

//         // The picker pill, anchored above the button
//         CompositedTransformFollower(
//           link: widget.layerLink,
//           showWhenUnlinked: false,
//           // Offset: shift up by 64dp + some padding so it floats above the row
//           offset: const Offset(-16, -58),
//           child: FadeTransition(
//             opacity: _fadeAnim,
//             child: ScaleTransition(
//               scale: _scaleAnim,
//               alignment: Alignment.bottomLeft,
//               child: Material(
//                 color: Colors.transparent,
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 6,
//                   ),
//                   decoration: BoxDecoration(
//                     color: AppColors.whitecolor,
//                     borderRadius: BorderRadius.circular(50),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.18),
//                         blurRadius: 20,
//                         offset: const Offset(0, 6),
//                         spreadRadius: 1,
//                       ),
//                     ],
//                   ),
//                   child: SingleChildScrollView(
//                     scrollDirection: Axis.horizontal,
//                     physics: const NeverScrollableScrollPhysics(),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children:
//                           _reactions.map((r) => _buildReactionItem(r)).toList(),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildReactionItem(ReactionType r) {
//     final isActive = widget.currentReaction == r;
//     final isHovered = _hovered == r;

//     final targetScale = isHovered ? 1.5 : (isActive ? 1.15 : 1.0);
//     final targetY = isHovered ? -10.0 : (isActive ? -3.0 : 0.0);

//     return GestureDetector(
//       onTap: () => widget.onSelect(r),
//       onTapDown: (_) => setState(() => _hovered = r),
//       onTapCancel: () => setState(() => _hovered = null),
//       child: TweenAnimationBuilder<double>(
//         tween: Tween<double>(begin: 1.0, end: targetScale),
//         duration: const Duration(milliseconds: 280),
//         curve: Curves.elasticOut,
//         builder: (context, scale, child) {
//           return TweenAnimationBuilder<double>(
//             tween: Tween<double>(begin: 0.0, end: targetY),
//             duration: const Duration(milliseconds: 200),
//             curve: Curves.easeOutBack,
//             builder: (context, dy, _) {
//               return Transform.translate(
//                 offset: Offset(0, dy),
//                 child: Transform.scale(scale: scale, child: child),
//               );
//             },
//           );
//         },
//         child: Container(
//           margin: EdgeInsets.zero,
//           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
//           child: Stack(
//             alignment: Alignment.center,
//             clipBehavior: Clip.none,
//             children: [
//               Text(
//                 r.emoji,
//                 style: TextStyle(
//                   fontSize: isActive ? 20 : 18,
//                   color: Colors.red,
//                 ),
//               ),
//               if (isHovered)
//                 Positioned(
//                   bottom: 30,
//                   left: -10,
//                   right: -10,
//                   child: Center(
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 6,
//                         vertical: 2,
//                       ),
//                       decoration: BoxDecoration(
//                         color: Colors.black87,
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Text(
//                         r.label,
//                         style: const TextStyle(
//                           color: AppColors.whitecolor,
//                           fontSize: 9,
//                           fontWeight: FontWeight.w600,
//                           letterSpacing: 0.3,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }




import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:innovator/Innovator/constant/app_colors.dart';
import 'package:innovator/Innovator/screens/Likes/Content-Like-Service.dart';
import 'dart:developer' as developer;

// ─────────────────────────────────────────────────────────────────────────────
// PendingReactionQueue  — singleton that holds reactions that failed due to
// no connectivity and retries them when the network comes back.
// ─────────────────────────────────────────────────────────────────────────────

class _PendingReaction {
  final String contentId;
  final ReactionType? type; // null = remove reaction
  final bool isReel;
  final DateTime queuedAt;

  _PendingReaction({
    required this.contentId,
    required this.type,
    required this.isReel,
    required this.queuedAt,
  });
}

class ReactionQueue {
  ReactionQueue._();
  static final ReactionQueue instance = ReactionQueue._();

  // contentId → latest pending reaction (later queues overwrite earlier ones
  // for the same post — only the last intent matters)
  final Map<String, _PendingReaction> _queue = {};

  ContentLikeService? _likeService;
  StreamSubscription? _connectivitySub;
  bool _flushing = false;

  /// Call once at app startup (or lazily on first use).
  void init(ContentLikeService service) {
    _likeService = service;
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any(
        (r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet,
      );
      if (isOnline && _queue.isNotEmpty) {
        _flush();
      }
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
  }

  /// Enqueue or overwrite a pending reaction for [contentId].
  void enqueue({
    required String contentId,
    required ReactionType? type,
    required bool isReel,
  }) {
    _queue[contentId] = _PendingReaction(
      contentId: contentId,
      type: type,
      isReel: isReel,
      queuedAt: DateTime.now(),
    );
    developer.log('[ReactionQueue] Queued reaction for $contentId → $type');
  }

  /// Remove a pending reaction (called when online call succeeds immediately).
  void dequeue(String contentId) {
    _queue.remove(contentId);
  }

  bool hasPending(String contentId) => _queue.containsKey(contentId);

  Future<void> _flush() async {
    if (_flushing || _likeService == null) return;
    _flushing = true;

    final entries = Map<String, _PendingReaction>.from(_queue);
    for (final entry in entries.entries) {
      final pending = entry.value;
      try {
        ReactionResult result;
        if (pending.type == null) {
          result =
              pending.isReel
                  ? await _likeService!.reactReel(
                    pending.contentId,
                    ReactionType.like,
                  )
                  : await _likeService!.reactPost(
                    pending.contentId,
                    ReactionType.like,
                  );
        } else {
          result =
              pending.isReel
                  ? await _likeService!.reactReel(
                    pending.contentId,
                    pending.type!,
                  )
                  : await _likeService!.reactPost(
                    pending.contentId,
                    pending.type!,
                  );
        }
        if (result.success) {
          _queue.remove(entry.key);
          developer.log(
            '[ReactionQueue] Flushed reaction for ${pending.contentId}',
          );
        }
      } catch (e) {
        developer.log(
          '[ReactionQueue] Flush error for ${pending.contentId}: $e',
        );
        // Keep in queue — will retry on next connectivity event
      }
    }

    _flushing = false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LikeButton — tap to like/unlike, long-press to pick any reaction
// Behaviour matches LinkedIn:
//   • Short tap   → toggles "Like" reaction on/off
//   • Long press  → shows floating emoji picker above the button;
//                   tap any reaction to apply it (replaces the current one)
//   • Label + count shown beside the icon (pass showLabel: true)
//   • Optimistic UI — reacts instantly; reverts if API fails while online
//   • Offline queue — reaction is queued and synced when network returns
// ─────────────────────────────────────────────────────────────────────────────

class LikeButton extends StatefulWidget {
  final String contentId;
  final bool initialLikeStatus;
  final ContentLikeService likeService;
  final Function(bool)? onLikeToggled;

  /// Actual reaction type string from API ('like','love','angry',etc.)
  /// Restores the correct emoji on first render
  final String? initialReactionType;

  /// Optional: display the reaction label + count inline
  final bool showLabel;
  final int initialCount;
  final bool isReel;

  const LikeButton({
    Key? key,
    required this.contentId,
    required this.initialLikeStatus,
    required this.likeService,
    this.onLikeToggled,
    this.initialReactionType,
    this.showLabel = false,
    this.initialCount = 0,
    this.isReel = false,
  }) : super(key: key);

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  ReactionType? _currentReaction;

  /// True while an API call is in-flight (used only to debounce rapid taps —
  /// NOT shown to the user as a spinner).
  bool _isApiInFlight = false;

  late int _count;

  // Reaction picker overlay
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  // Bounce animation for the icon on reaction change
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Initialise the singleton queue with the service reference
    ReactionQueue.instance.init(widget.likeService);

    // Restore reaction state from API response
    if (widget.initialLikeStatus) {
      _currentReaction =
          widget.initialReactionType != null
              ? ReactionTypeExtension.fromValue(widget.initialReactionType) ??
                  ReactionType.like
              : ReactionType.like;
    } else {
      _currentReaction = null;
    }
    _count = widget.initialCount;

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _bounceAnim = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.45,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.45,
          end: 0.88,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.88,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
    ]).animate(_bounceCtrl);
  }

  @override
  void dispose() {
    _removeOverlay();
    _bounceCtrl.dispose();
    super.dispose();
  }

  // ── Connectivity check ─────────────────────────────────────────────────────
  Future<bool> _isOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any(
        (r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet,
      );
    } catch (_) {
      return false;
    }
  }

  // ── Tap: toggle Like ───────────────────────────────────────────────────────
  Future<void> _handleTap() async {
    if (_isApiInFlight) return;
    _removeOverlay();

    if (_currentReaction != null) {
      await _applyReaction(null); // toggle off
    } else {
      await _applyReaction(ReactionType.like);
    }
  }

  // ── Long press: show picker ────────────────────────────────────────────────
  void _handleLongPress() {
    HapticFeedback.mediumImpact();
    if (_overlayEntry != null) {
      _removeOverlay();
      return;
    }
    _showReactionPicker();
  }

  // ── Apply a reaction (null = remove) ──────────────────────────────────────
  //
  // Flow:
  //  1. Capture previous state
  //  2. Apply optimistic update IMMEDIATELY (user sees instant feedback)
  //  3. Check connectivity
  //     a. Online  → call API
  //        • Success → dequeue if pending, notify parent
  //        • Failure → revert optimistic update, keep in queue
  //     b. Offline → enqueue for later sync, notify parent with optimistic value
  //
  Future<void> _applyReaction(ReactionType? type) async {
    if (_isApiInFlight) return;

    final previous = _currentReaction;

    // ── Step 2: Optimistic update (instant, no loading indicator) ─────────
    _updateLocalState(type, previous);
    widget.onLikeToggled?.call(_currentReaction != null);

    _isApiInFlight = true;

    try {
      final online = await _isOnline();

      if (!online) {
        // ── Offline path ─────────────────────────────────────────────────
        developer.log(
          '[LikeButton] Offline — queuing reaction for ${widget.contentId}',
        );
        ReactionQueue.instance.enqueue(
          contentId: widget.contentId,
          type: type,
          isReel: widget.isReel,
        );
        // Keep the optimistic state — UI already looks correct
        return;
      }

      // ── Online path ──────────────────────────────────────────────────────
      ReactionResult result;
      if (type == null) {
        // Remove reaction
        result =
            widget.isReel
                ? await widget.likeService.reactReel(
                  widget.contentId,
                  previous ?? ReactionType.like,
                )
                : await widget.likeService.reactPost(
                  widget.contentId,
                  previous ?? ReactionType.like,
                );
      } else {
        // Add / change reaction
        result =
            widget.isReel
                ? await widget.likeService.reactReel(widget.contentId, type)
                : await widget.likeService.reactPost(widget.contentId, type);
      }

      if (result.success) {
        // Sync the reaction type returned by server (may differ from local)
        if (type != null && result.reactionType != null) {
          if (mounted) {
            setState(() => _currentReaction = result.reactionType);
          }
        }
        // Remove from offline queue if it was sitting there
        ReactionQueue.instance.dequeue(widget.contentId);
        developer.log(
          '[LikeButton] API success for ${widget.contentId} → $type',
        );
      } else {
        // ── API returned error while online → revert ─────────────────────
        developer.log(
          '[LikeButton] API error for ${widget.contentId} — reverting',
        );
        _updateLocalState(previous, type);
        widget.onLikeToggled?.call(_currentReaction != null);
      }
    } catch (e) {
      // ── Network exception (timeout, etc.) → treat as offline ────────────
      developer.log('[LikeButton] Exception: $e — queuing as offline');
      ReactionQueue.instance.enqueue(
        contentId: widget.contentId,
        type: type,
        isReel: widget.isReel,
      );
      // Keep optimistic state
    } finally {
      if (mounted) setState(() => _isApiInFlight = false);
    }
  }

  /// Purely updates local count + reaction state and plays bounce animation.
  /// Does NOT call setState by itself for the flag — caller manages that.
  void _updateLocalState(ReactionType? newType, ReactionType? previous) {
    if (!mounted) return;
    setState(() {
      if (newType != null && previous == null) {
        _count++; // first reaction added
      } else if (newType == null && previous != null) {
        _count = (_count - 1).clamp(0, 999999); // reaction removed
      }
      // switching reaction type (e.g. 👍 → ❤️) doesn't change count
      _currentReaction = newType;
    });
    _bounceCtrl.forward(from: 0);
  }

  // ── Overlay helpers ────────────────────────────────────────────────────────
  void _showReactionPicker() {
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder:
          (_) => _ReactionPickerOverlay(
            layerLink: _layerLink,
            onSelect: (type) {
              _removeOverlay();
              _applyReaction(type);
            },
            onDismiss: _removeOverlay,
            currentReaction: _currentReaction,
          ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final reaction = _currentReaction;
    final hasReaction = reaction != null;

    final emoji = hasReaction ? reaction.emoji : null;
    final label = hasReaction ? reaction.label : 'Like';
    final iconColor =
        hasReaction ? _reactionColor(reaction) : Colors.grey.shade700;

    // Show a subtle "pending sync" indicator on the icon when offline-queued
    final hasPending = ReactionQueue.instance.hasPending(widget.contentId);

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _handleTap,
        onLongPress: _handleLongPress,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _bounceAnim,
          builder:
              (context, child) =>
                  Transform.scale(scale: _bounceAnim.value, child: child),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Icon / emoji — NO loading indicator, ever ──────────────
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    emoji != null
                        ? Text(
                          emoji,
                          style: TextStyle(
                            fontSize: 22,
                            // Slightly muted while pending sync (subtle cue)
                            color:
                                hasPending
                                    ? iconColor.withOpacity(0.65)
                                    : iconColor,
                          ),
                        )
                        : Icon(
                          Icons.thumb_up_alt_outlined,
                          color:
                              hasPending
                                  ? iconColor.withOpacity(0.65)
                                  : iconColor,
                          size: 22,
                        ),

                    // Tiny dot to signal "will sync when online"
                    if (hasPending)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade400,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                if (widget.showLabel) ...[
                  const SizedBox(width: 5),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                    ),
                    child: Text(
                      widget.showLabel && _count > 0
                          ? '$label · $_count'
                          : label,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _reactionColor(ReactionType r) {
    switch (r) {
      case ReactionType.like:
        return const Color(0xFF0A66C2);
      case ReactionType.love:
        return Colors.red.shade500;
      case ReactionType.haha:
        return Colors.amber.shade600;
      case ReactionType.wow:
        return Colors.amber.shade700;
      case ReactionType.sad:
        return Colors.amber.shade700;
      case ReactionType.angry:
        return Colors.orange.shade700;
      case ReactionType.dislike:
        return Colors.grey.shade600;
      case ReactionType.celebrate:
        return Colors.deepOrange.shade500;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reaction Picker Overlay
// Appears above the button, floats as a pill — identical UX to LinkedIn
// ─────────────────────────────────────────────────────────────────────────────

class _ReactionPickerOverlay extends StatefulWidget {
  final LayerLink layerLink;
  final void Function(ReactionType) onSelect;
  final VoidCallback onDismiss;
  final ReactionType? currentReaction;

  const _ReactionPickerOverlay({
    required this.layerLink,
    required this.onSelect,
    required this.onDismiss,
    this.currentReaction,
  });

  @override
  State<_ReactionPickerOverlay> createState() => _ReactionPickerOverlayState();
}

class _ReactionPickerOverlayState extends State<_ReactionPickerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  ReactionType? _hovered;

  static const _reactions = ReactionType.values;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          offset: const Offset(-16, -58),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              alignment: Alignment.bottomLeft,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.whitecolor,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children:
                          _reactions.map((r) => _buildReactionItem(r)).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReactionItem(ReactionType r) {
    final isActive = widget.currentReaction == r;
    final isHovered = _hovered == r;

    final targetScale = isHovered ? 1.5 : (isActive ? 1.15 : 1.0);
    final targetY = isHovered ? -10.0 : (isActive ? -3.0 : 0.0);

    return GestureDetector(
      onTap: () => widget.onSelect(r),
      onTapDown: (_) => setState(() => _hovered = r),
      onTapCancel: () => setState(() => _hovered = null),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1.0, end: targetScale),
        duration: const Duration(milliseconds: 280),
        curve: Curves.elasticOut,
        builder: (context, scale, child) {
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: targetY),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            builder: (context, dy, _) {
              return Transform.translate(
                offset: Offset(0, dy),
                child: Transform.scale(scale: scale, child: child),
              );
            },
          );
        },
        child: Container(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Text(
                r.emoji,
                style: TextStyle(
                  fontSize: isActive ? 20 : 18,
                  color: Colors.red,
                ),
              ),
              if (isHovered)
                Positioned(
                  bottom: 30,
                  left: -10,
                  right: -10,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        r.label,
                        style: const TextStyle(
                          color: AppColors.whitecolor,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
