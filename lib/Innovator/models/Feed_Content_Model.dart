// Feed_Content_Model.dart
// Adds FeedContent.fromNewApiPost() to map the new API response.
// All existing fields and constructors are preserved.
// Now with Flutter Riverpod support via copyWith method.

class Author {
  final String id;
  final String name;
  final String picture;
  final String email;

  Author({
    required this.id,
    required this.name,
    required this.picture,
    required this.email,
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name:
          json['name']?.toString() ?? json['username']?.toString() ?? 'Unknown',
      picture: json['picture']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'picture': picture,
    'email': email,
  };

  Author copyWith({String? id, String? name, String? picture, String? email}) {
    return Author(
      id: id ?? this.id,
      name: name ?? this.name,
      picture: picture ?? this.picture,
      email: email ?? this.email,
    );
  }
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
    required this.comments,
    required this.isFollowed,
    required this.createdAt,
    this.tags = const [],
  });

  // ── Existing factory (old API) ────────────────────────────────────────────
  factory FeedContent.fromJson(Map<String, dynamic> json) {
    final author = Author.fromJson(
      json['author'] is Map<String, dynamic>
          ? json['author'] as Map<String, dynamic>
          : <String, dynamic>{},
    );

    final rawFiles = json['files'] as List<dynamic>? ?? [];
    final List<String> files =
        rawFiles.whereType<String>().where((f) => f.isNotEmpty).toList();

    final rawMedia = json['mediaUrls'] as List<dynamic>? ?? [];
    final List<String> mediaUrls =
        rawMedia.whereType<String>().where((u) => u.isNotEmpty).toList();

    final rawOpt = json['optimizedFiles'] as List<dynamic>? ?? [];
    final List<Map<String, dynamic>> optimizedFiles =
        rawOpt.whereType<Map<String, dynamic>>().toList();

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

  // ── NEW factory: maps GET /api/posts/ response ────────────────────────────
  // New API fields:
  //   id, username, content,
  //   media[]  → [{id, file (URL), media_type}]   (supports multiple files)
  //   category_names[], reactions_count, current_user_reaction,
  //   comments_count, comments[], created_at, updated_at
  factory FeedContent.fromNewApiPost(Map<String, dynamic> post) {
    final id = post['id']?.toString() ?? '';
    final username = post['username']?.toString() ?? 'Unknown';
    final content = post['content']?.toString() ?? '';
    final categories =
        (post['category_names'] as List<dynamic>?)
            ?.map((c) => c.toString())
            .toList() ??
        <String>[];
    final reactCount = (post['reactions_count'] as num?)?.toInt() ?? 0;
    final isLiked = post['current_user_reaction'] != null;
    final commentCount = (post['comments_count'] as num?)?.toInt() ?? 0;
    final createdAt =
        DateTime.tryParse(post['created_at']?.toString() ?? '') ??
        DateTime.now();

    // First category becomes the post "type" (used for colour/label display)
    final type = categories.isNotEmpty ? categories.first : 'post';

    // Author — new API has only username, no id/picture/email
    final author = Author(id: username, name: username, picture: '', email: '');

    // ── Media: new API returns media[] [{id, file, media_type}] ──────────
    // Old API had a single 'image' field — both are supported for fallback.
    final files = <String>[];
    final rawMedia = post['media'];
    if (rawMedia is List && rawMedia.isNotEmpty) {
      for (final m in rawMedia) {
        if (m is Map) {
          final fileUrl = m['file']?.toString() ?? '';
          if (fileUrl.isNotEmpty) files.add(fileUrl);
        }
      }
    } else {
      // Fallback: old single 'image' field
      final imageUrl = post['image']?.toString();
      if (imageUrl != null && imageUrl.isNotEmpty) files.add(imageUrl);
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
      comments: commentCount,
      isFollowed: false,
      createdAt: createdAt,
      tags: List<String>.from(categories),
    );
  }

  // ── Helpers (unchanged) ───────────────────────────────────────────────────

  /// Prepend base URL to relative paths.
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

  // ── Copy with method for Riverpod state updates ─────────────────────────
  FeedContent copyWith({
    String? id,
    Author? author,
    String? status,
    String? description,
    String? type,
    List<String>? files,
    List<String>? mediaUrls,
    List<Map<String, dynamic>>? optimizedFiles,
    String? thumbnailUrl,
    int? likes,
    bool? isLiked,
    int? comments,
    bool? isFollowed,
    DateTime? createdAt,
    List<String>? tags,
  }) {
    return FeedContent(
      id: id ?? this.id,
      author: author ?? this.author,
      status: status ?? this.status,
      description: description ?? this.description,
      type: type ?? this.type,
      files: files ?? this.files,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      optimizedFiles: optimizedFiles ?? this.optimizedFiles,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      comments: comments ?? this.comments,
      isFollowed: isFollowed ?? this.isFollowed,
      createdAt: createdAt ?? this.createdAt,
      tags: tags ?? this.tags,
    );
  }
}
