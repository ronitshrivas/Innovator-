// follow_Button.dart
// Short tap  → toggles Follow / Unfollow
// Long press → (future: reaction picker)
//
// Accepts both UUID and username as targetUserId.
// FollowService resolves username → UUID automatically if needed.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:innovator/Innovator/constant/app_colors.dart';
import 'package:innovator/Innovator/screens/Follow/follow-Service.dart';

class FollowButton extends StatefulWidget {
  /// The target user's identifier — UUID preferred, username accepted.
  /// FollowService will resolve username → UUID via the API if needed.
  final String targetUserId;

  /// Kept for backward compatibility. NOT used for API calls.
  final String? targetUserEmail;

  final VoidCallback? onFollowSuccess;
  final VoidCallback? onUnfollowSuccess;
  final bool initialFollowStatus;
  final double? size;

  const FollowButton({
    Key? key,
    required this.targetUserId,
    this.targetUserEmail,
    this.onFollowSuccess,
    this.onUnfollowSuccess,
    this.initialFollowStatus = false,
    this.size,
  }) : super(key: key);

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton>
    with SingleTickerProviderStateMixin {
  late bool _isFollowing;
  bool _isLoading = false;

  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    // Trust the feed API's is_followed value — no extra API call needed.
    // The feed response already includes is_followed per post.
    _isFollowing = widget.initialFollowStatus;

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.90,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _scaleCtrl;
  }

  @override
  void didUpdateWidget(FollowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If parent updates initialFollowStatus (e.g. after Riverpod state change),
    // sync local state to match.
    if (oldWidget.initialFollowStatus != widget.initialFollowStatus) {
      setState(() => _isFollowing = widget.initialFollowStatus);
    }
  }

  // ── Tap ────────────────────────────────────────────────────────────────
  Future<void> _handleTap() async {
    if (_isLoading) return;

    // Bounce animation
    await _scaleCtrl.reverse();
    _scaleCtrl.forward();

    setState(() => _isLoading = true);
    try {
      if (_isFollowing) {
        await _unfollow();
      } else {
        await _follow();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _follow() async {
    try {
      await FollowService.sendFollowRequest(widget.targetUserId);
      if (!mounted) return;
      setState(() => _isFollowing = true);
      widget.onFollowSuccess?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'You are now following this user',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    }
  }

  Future<void> _unfollow() async {
    try {
      await FollowService.unfollowUser(widget.targetUserId);
      if (!mounted) return;
      setState(() => _isFollowing = false);
      widget.onUnfollowSuccess?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'You unfollowed this user',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.grey.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg.replaceFirst('Exception: ', ''),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        // HitTestBehavior.opaque absorbs the tap so it never bubbles up
        // to parent GestureDetectors (prevents accidental navigation).
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_isLoading) _handleTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: _isFollowing ? Colors.transparent : Colors.blue.shade600,
            border: Border.all(
              color: _isFollowing ? Colors.green : Colors.blue.shade600,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child:
              _isLoading
                  ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _isFollowing ? Colors.green : AppColors.whitecolor,
                    ),
                  )
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isFollowing ? Icons.check : Icons.person_add,
                        size: 14,
                        color:
                            _isFollowing ? Colors.green : AppColors.whitecolor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isFollowing ? 'Following' : 'Follow',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color:
                              _isFollowing
                                  ? Colors.green
                                  : AppColors.whitecolor,
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}
