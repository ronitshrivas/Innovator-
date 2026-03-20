// comment_Model.dart
// Maps the new API response from http://182.93.94.220:8005/api/comments/

class Comment {
  final String id;
  final String username;
  final String? avatar;
  final String postId;
  final String? parentId; // non-null = this is a reply
  final String content;
  final DateTime createdAt;
  // Replies are loaded separately via /api/replies/ but stored here after fetch
  List<Comment> replies;

  Comment({
    required this.id,
    required this.username,
    this.avatar,
    required this.postId,
    this.parentId,
    required this.content,
    required this.createdAt,
    this.replies = const [],
  });

  bool get isReply => parentId != null;

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? 'Unknown',
      avatar: json['avatar']?.toString(),
      postId: json['post']?.toString() ?? '',
      parentId: json['parent']?.toString(),
      content: json['content']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'avatar': avatar,
    'post': postId,
    'parent': parentId,
    'content': content,
    'created_at': createdAt.toIso8601String(),
  };
}
