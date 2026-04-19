import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/Authorization/Login.dart';
import 'package:innovator/Innovator/constant/app_colors.dart';
import 'package:innovator/Innovator/models/Feed_Content_Model.dart';
import 'package:innovator/Innovator/screens/Feed/Inner_Homepage.dart';

class NewFeedPostDetailScreen extends StatefulWidget {
  final String postId;
  final String? highlightAction; // 'like', 'comment', 'repost'

  const NewFeedPostDetailScreen({
    Key? key,
    required this.postId,
    this.highlightAction,
  }) : super(key: key);

  @override
  State<NewFeedPostDetailScreen> createState() =>
      _NewFeedPostDetailScreenState();
}

class _NewFeedPostDetailScreenState extends State<NewFeedPostDetailScreen> {
  FeedContent? _post;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchPost();
  }

  Future<void> _fetchPost() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final token = AppData().accessToken;
      if (token == null || token.isEmpty) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => LoginPage()),
            (_) => false,
          );
        }
        return;
      }

      // New API: GET /api/posts/<id>/
      final response = await http
          .get(
            Uri.parse('http://36.253.137.34:8005/api/posts/${widget.postId}/'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        // The endpoint returns a single post object (same shape as results[])
        final post = FeedContent.fromNewApiPost(
          decoded is Map<String, dynamic> ? decoded : decoded,
        );
        setState(() {
          _post = post;
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()),
          (_) => false,
        );
      } else if (response.statusCode == 404) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Post not found or has been deleted.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load post (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = 'Network error. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Post',
          style: TextStyle(
            color: AppColors.whitecolor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromRGBO(244, 135, 6, 1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.whitecolor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Color.fromRGBO(244, 135, 6, 1),
          ),
        ),
      );
    }

    if (_hasError || _post == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage.isNotEmpty ? _errorMessage : 'Failed to load post',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchPost,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(244, 135, 6, 1),
                foregroundColor: AppColors.whitecolor,
              ),
            ),
          ],
        ),
      );
    }

    // Reuse your existing FeedItem widget — it already handles
    // likes, comments, reposts, media, share, edit, delete, follow, etc.
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          // Optional: highlight banner when coming from a notification
          if (widget.highlightAction != null)
            // _buildHighlightBanner(widget.highlightAction!),
            FeedItem(
              content: _post!,
              onLikeToggled: (isLiked) {
                if (!mounted) return;
                setState(() {
                  _post!.isLiked = isLiked;
                  _post!.likes =
                      isLiked
                          ? (_post!.likes + 1).clamp(0, 999999)
                          : (_post!.likes - 1).clamp(0, 999999);
                });
              },
              onFollowToggled: (isFollowed) {
                if (!mounted) return;
                setState(() => _post!.isFollowed = isFollowed);
              },
              onDeleted: () {
                if (mounted) Navigator.pop(context);
              },
              onStatusUpdated: (newStatus) {
                if (mounted) setState(() => _post!.status = newStatus);
              },
              onCommentAdded: () {
                if (mounted) setState(() => _post!.comments++);
              },
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHighlightBanner(String action) {
    final config = _bannerConfig(action);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: config['color'] as Color,
      child: Row(
        children: [
          Icon(config['icon'] as IconData, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            config['text'],
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _bannerConfig(String action) {
    switch (action) {
      case 'like':
        return {
          'color': Colors.red.shade400,
          'icon': Icons.favorite,
          //'text': 'Someone reacted to this post',
        };
      case 'comment':
        return {
          'color': Colors.blue.shade500,
          'icon': Icons.mode_comment,
          'text': 'Someone commented on this post',
        };
      case 'repost':
      case 'share':
        return {
          'color': Colors.green.shade500,
          'icon': Icons.repeat,
          'text': 'Someone reposted this',
        };
      default:
        return {
          'color': const Color.fromRGBO(244, 135, 6, 1),
          'icon': Icons.notifications,
          'text': 'You have a new notification on this post',
        };
    }
  }
}
