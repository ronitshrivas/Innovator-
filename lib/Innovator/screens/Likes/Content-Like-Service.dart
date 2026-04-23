import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/constant/api_constants.dart';
 
enum ReactionType { like, love, haha, wow, sad, angry, dislike, celebrate }

extension ReactionTypeExtension on ReactionType {
  String get value {
    switch (this) {
      case ReactionType.like:
        return 'like';
      case ReactionType.love:
        return 'love';
      case ReactionType.haha:
        return 'haha';
      case ReactionType.wow:
        return 'wow';
      case ReactionType.sad:
        return 'sad';
      case ReactionType.angry:
        return 'angry';
      case ReactionType.dislike:
        return 'dislike';
      case ReactionType.celebrate:
        return 'celebrate';
    }
  }

  String get emoji {
    switch (this) {
      case ReactionType.like:
        return '👍';
      case ReactionType.love:
        return '❤️';
      case ReactionType.haha:
        return '😂';
      case ReactionType.wow:
        return '😮';
      case ReactionType.sad:
        return '😢';
      case ReactionType.angry:
        return '😡';
      case ReactionType.dislike:
        return '👎';
      case ReactionType.celebrate:
        return '🎉';
    }
  }

  String get label {
    switch (this) {
      case ReactionType.like:
        return 'Like';
      case ReactionType.love:
        return 'Love';
      case ReactionType.haha:
        return 'Haha';
      case ReactionType.wow:
        return 'Wow';
      case ReactionType.sad:
        return 'Sad';
      case ReactionType.angry:
        return 'Angry';
      case ReactionType.dislike:
        return 'Dislike';
      case ReactionType.celebrate:
        return 'Celebrate';
    }
  }

  static ReactionType? fromValue(String? value) {
    if (value == null) return null;
    for (final r in ReactionType.values) {
      if (r.value == value) return r;
    }
    return null;
  }
}
 
class ReactionResult {
  final bool success;
 
  final ReactionType? reactionType;
 
  final String? reactionId;

  const ReactionResult({
    required this.success,
    this.reactionType,
    this.reactionId,
  });
}

class ContentLikeService {
  final AppData _appData = AppData();
 
  ContentLikeService({String? baseUrl}); 
  Future<ReactionResult> reactPost(String postId, ReactionType type) async {
    final token = _appData.accessToken;
    if (token == null || token.isEmpty) {
      log('[Reaction] No auth token');
      return const ReactionResult(success: false);
    }

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.sendreaction),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'post': postId, 'type': type.value}),
      );

      log(
        '[Reaction] POST /api/reactions/ → ${response.statusCode}: ${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ReactionResult(
          success: true,
          reactionType: ReactionTypeExtension.fromValue(
            data['type']?.toString(),
          ),
          reactionId: data['id']?.toString(),
        );
      } else if (response.statusCode == 204) { 
        return const ReactionResult(success: true, reactionType: null);
      } else {
        log('[Reaction] Unexpected status ${response.statusCode}');
        return const ReactionResult(success: false);
      }
    } catch (e) {
      log('[Reaction] Error: $e');
      return const ReactionResult(success: false);
    }
  }

  Future<ReactionResult> reactReel(String postId, ReactionType type) async {
    final token = _appData.accessToken;
    if (token == null || token.isEmpty) {
      log('[Reaction] No auth token');
      return const ReactionResult(success: false);
    }

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.sendreaction),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'reel': postId, 'type': type.value}),
      );

      log(
        '[Reaction] POST /api/reactions/ → ${response.statusCode}: ${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ReactionResult(
          success: true,
          reactionType: ReactionTypeExtension.fromValue(
            data['type']?.toString(),
          ),
          reactionId: data['id']?.toString(),
        );
      } else if (response.statusCode == 204) { 
        return const ReactionResult(success: true, reactionType: null);
      } else {
        log('[Reaction] Unexpected status ${response.statusCode}');
        return const ReactionResult(success: false);
      }
    } catch (e) {
      log('[Reaction] Error: $e');
      return const ReactionResult(success: false);
    }
  }
 
 
  Future<bool> toggleLike(String postId, bool isLiking) async {
    if (!isLiking) { 
      final r = await reactPost(postId, ReactionType.like);
      return r.success;
    }
    final r = await reactPost(postId, ReactionType.like);
    return r.success;
  }

  Future<bool> likeContent(String postId) => toggleLike(postId, true);
  Future<bool> unlikeContent(String postId) => toggleLike(postId, false);
}
