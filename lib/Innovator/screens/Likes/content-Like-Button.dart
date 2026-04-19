import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:innovator/Innovator/constant/app_colors.dart';
import 'package:innovator/Innovator/screens/Likes/Content-Like-Service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LikeButton — tap to like/unlike, long-press to pick any reaction
// Behaviour matches LinkedIn:
//   • Short tap   → toggles "Like" reaction on/off
//   • Long press  → shows floating emoji picker above the button;
//                   tap any reaction to apply it (replaces the current one)
//   • Label + count shown beside the icon (pass showLabel: true)
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

  const LikeButton({
    Key? key,
    required this.contentId,
    required this.initialLikeStatus,
    required this.likeService,
    this.onLikeToggled,
    this.initialReactionType,
    this.showLabel = false,
    this.initialCount = 0,
  }) : super(key: key);

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  ReactionType? _currentReaction;
  bool _isLoading = false;
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
    // Restore actual reaction type from API (e.g. 'angry', 'love', 'like')
    // Falls back to generic 'like' if type string is missing
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

  // ── Tap: toggle Like ───────────────────────────────────────────────────────
  Future<void> _handleTap() async {
    if (_isLoading) return;
    _removeOverlay();

    // If already liked → remove; otherwise apply "like"
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
  Future<void> _applyReaction(ReactionType? type) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final previous = _currentReaction;

    ReactionResult result;
    if (type == null) {
      // Remove: re-post same reaction to toggle off, or use removeReaction
      result = await widget.likeService.reactPost(
        widget.contentId,
        previous ?? ReactionType.like,
      );
      // A 204 / toggled-off means success with null type
      if (result.success) {
        _setReaction(null, previous);
      }
    } else {
      result = await widget.likeService.reactPost(widget.contentId, type);
      if (result.success) {
        _setReaction(result.reactionType ?? type, previous);
      }
    }

    if (mounted) setState(() => _isLoading = false);

    // Notify parent (true = has any reaction, false = no reaction)
    widget.onLikeToggled?.call(_currentReaction != null);
  }

  void _setReaction(ReactionType? newType, ReactionType? previous) {
    if (!mounted) return;
    setState(() {
      // Presence change only:
      //   null → type  → +1  (first reaction)
      //   type → null  → -1  (removed reaction)
      //   typeA → typeB → 0  (switching 👍→❤️: same count)
      if (newType != null && previous == null) {
        _count++;
      } else if (newType == null && previous != null) {
        _count = (_count - 1).clamp(0, 999999);
      }
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

    // Icon + colour based on current reaction
    final emoji = hasReaction ? reaction.emoji : null;
    final label = hasReaction ? reaction.label : 'Like';
    final iconColor =
        hasReaction ? _reactionColor(reaction) : Colors.grey.shade700;

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
                // Icon / emoji
                _isLoading
                    ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    )
                    : emoji != null
                    ? Text(
                      emoji,
                      style: const TextStyle(fontSize: 22, color: Colors.red),
                    )
                    : Icon(
                      Icons.thumb_up_alt_outlined,
                      color: iconColor,
                      size: 22,
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
        return const Color(0xFF0A66C2); // LinkedIn blue
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

  // Which emoji is being hovered/pressed
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
        // Transparent dismissal layer
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),
        ),

        // The picker pill, anchored above the button
        CompositedTransformFollower(
          link: widget.layerLink,
          showWhenUnlinked: false,
          // Offset: shift up by 64dp + some padding so it floats above the row
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
