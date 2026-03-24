// Feed_Content_Model.dart
// Maps new API response: GET http://182.93.94.220:8005/api/posts/
// Key new fields: user_id (UUID for follow), username, avatar (absolute URL)

class Author {
  final String id; // user_id UUID — used for follow/unfollow API
  final String name; // username — display name
  final String picture; // avatar URL (absolute)
  final String email; // empty for new API (not returned)

  Author({
    required this.id,
    required this.name,
    required this.picture,
    required this.email,
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      // Legacy API uses _id; new API uses user_id at post level
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name:
          json['name']?.toString() ?? json['username']?.toString() ?? 'Unknown',
      picture: json['picture']?.toString() ?? json['avatar']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'picture': picture,
    'email': email,
  };
}

class FeedContent {
  final String id;
  final Author author;
  String status;
  String description;
  final String type;
  final List<String> files;
  final List<String> mediaUrls;
  final List<Map<String, dynamic>> optimizedFiles;
  final String? thumbnailUrl;
  int likes;
  bool isLiked;
  String?
  currentUserReaction; // 'like','love','haha','wow','sad','angry','dislike','celebrate' or null
  int comments;
  bool isFollowed;
  final DateTime createdAt;
  final List<String> tags;

  FeedContent({
    required this.id,
    required this.author,
    required this.status,
    required this.description,
    required this.type,
    required this.files,
    required this.mediaUrls,
    required this.optimizedFiles,
    this.thumbnailUrl,
    required this.likes,
    required this.isLiked,
    this.currentUserReaction,
    required this.comments,
    required this.isFollowed,
    required this.createdAt,
    this.tags = const [],
  });

  // ── Legacy factory (old API) ──────────────────────────────────────────────
  factory FeedContent.fromJson(Map<String, dynamic> json) {
    // New API flat post shape — delegate to fromNewApiPost
    if (json.containsKey('user_id') || json.containsKey('username')) {
      return FeedContent.fromNewApiPost(json);
    }

    // Old API shape
    final author = Author.fromJson(
      json['author'] is Map<String, dynamic>
          ? json['author'] as Map<String, dynamic>
          : <String, dynamic>{},
    );

    final rawFiles = json['files'] as List<dynamic>? ?? [];
    final files =
        rawFiles.whereType<String>().where((f) => f.isNotEmpty).toList();

    final rawMedia = json['mediaUrls'] as List<dynamic>? ?? [];
    final mediaUrls =
        rawMedia.whereType<String>().where((u) => u.isNotEmpty).toList();

    final rawOpt = json['optimizedFiles'] as List<dynamic>? ?? [];
    final optimizedFiles = rawOpt.whereType<Map<String, dynamic>>().toList();

    return FeedContent(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      author: author,
      status: json['status']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? 'post',
      files: files,
      mediaUrls: mediaUrls,
      optimizedFiles: optimizedFiles,
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] == true,
      comments: (json['comments'] as num?)?.toInt() ?? 0,
      isFollowed: json['isFollowed'] == true,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      tags:
          (json['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ??
          [],
    );
  }

  // ── New API factory: maps GET /api/posts/ response ────────────────────────
  // Response fields:
  //   id, user_id, username, avatar,
  //   content, media[], category_names[],
  //   reactions_count, reaction_types[], current_user_reaction,
  //   comments_count, comments[], views_count,
  //   is_followed, created_at, updated_at
  factory FeedContent.fromNewApiPost(Map<String, dynamic> post) {
    final id = post['id']?.toString() ?? '';
    final userId = post['user_id']?.toString() ?? ''; // UUID for follow API
    final username = post['username']?.toString() ?? 'Unknown';
    final avatar = post['avatar']?.toString() ?? ''; // absolute URL or null
    final content = post['content']?.toString() ?? '';

    final categories =
        (post['category_names'] as List<dynamic>?)
            ?.map((c) => c.toString())
            .toList() ??
        <String>[];

    final reactCount = (post['reactions_count'] as num?)?.toInt() ?? 0;
    final isLiked = post['current_user_reaction'] != null;
    final currentUserReaction = post['current_user_reaction']?.toString();
    final commentCount = (post['comments_count'] as num?)?.toInt() ?? 0;

    // is_followed: API returns true/false — drives Follow/Following button label
    // Try both 'is_followed' and 'isFollowed' for forward compatibility
    final isFollowed =
        post['is_followed'] == true || post['isFollowed'] == true;

    final createdAt =
        DateTime.tryParse(post['created_at']?.toString() ?? '') ??
        DateTime.now();

    final type = categories.isNotEmpty ? categories.first : 'post';

    // Author: use user_id as id (needed for follow/unfollow), username as name
    final author = Author(
      id: userId, // UUID — passed to FollowButton.targetUserId
      name: username,
      picture: avatar, // absolute URL, no prefix needed
      email: '',
    );

    // Media: new API returns media[] [{id, file, media_type}]
    final files = <String>[];
    final rawMedia = post['media'];
    if (rawMedia is List) {
      for (final m in rawMedia) {
        if (m is Map) {
          final fileUrl = m['file']?.toString() ?? '';
          if (fileUrl.isNotEmpty) files.add(fileUrl);
        }
      }
    }

    return FeedContent(
      id: id,
      author: author,
      status: content,
      description: content,
      type: type,
      files: files,
      mediaUrls: List<String>.from(files),
      optimizedFiles: const [],
      thumbnailUrl: null,
      likes: reactCount,
      isLiked: isLiked,
      currentUserReaction: currentUserReaction,
      comments: commentCount,
      isFollowed: isFollowed, // ← now reads from API, not hardcoded false
      createdAt: createdAt,
      tags: List<String>.from(categories),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns a full URL — new API already returns absolute URLs, so this
  /// is a no-op for new posts. Kept for legacy optimizedFiles paths.
  String formatUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return 'http://182.93.94.220:8005${path.startsWith('/') ? '' : '/'}$path';
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'author': author.toJson(),
    'status': status,
    'description': description,
    'type': type,
    'files': files,
    'mediaUrls': mediaUrls,
    'optimizedFiles': optimizedFiles,
    'thumbnailUrl': thumbnailUrl,
    'likes': likes,
    'isLiked': isLiked,
    'comments': comments,
    'isFollowed': isFollowed,
    'createdAt': createdAt.toIso8601String(),
    'tags': tags,
  };
}
