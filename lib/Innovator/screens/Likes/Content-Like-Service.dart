import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/constant/api_constants.dart';

// ── Reaction types matching backend REACTION_CHOICES ──────────────────────────
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

// ── API response model ─────────────────────────────────────────────────────────
class ReactionResult {
  final bool success;

  /// null means the reaction was removed (un-reacted)
  final ReactionType? reactionType;

  /// The reaction record id returned by the server (useful for DELETE)
  final String? reactionId;

  const ReactionResult({
    required this.success,
    this.reactionType,
    this.reactionId,
  });
}

class ContentLikeService {
  final AppData _appData = AppData();

  // Keep baseUrl param for backward-compat but always use _baseUrl internally
  ContentLikeService({String? baseUrl});

  // ── React to a post ──────────────────────────────────────────────────────────
  /// POST /api/reactions/  { "post": postId, "type": reactionType }
  /// If the user already has the same reaction the backend may toggle it off —
  /// handle both 200/201 (created) and 204 (removed) gracefully.
  Future<ReactionResult> react(String postId, ReactionType type) async {
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
        // Reaction removed (same type tapped again = toggle off)
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

  // ── Remove reaction ──────────────────────────────────────────────────────────
  /// DELETE /api/reactions/{reactionId}/
  Future<bool> removeReaction(String reactionId) async {
    final token = _appData.accessToken;
    if (token == null || token.isEmpty) return false;

    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.sendreaction}$reactionId/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      log(
        '[Reaction] DELETE /api/reactions/$reactionId/ → ${response.statusCode}',
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      log('[Reaction] removeReaction error: $e');
      return false;
    }
  }

  // ── Legacy compat wrappers ────────────────────────────────────────────────────
  Future<bool> toggleLike(String postId, bool isLiking) async {
    if (!isLiking) {
      // Best-effort: no reactionId at this point, just re-post same type to toggle off
      final r = await react(postId, ReactionType.like);
      return r.success;
    }
    final r = await react(postId, ReactionType.like);
    return r.success;
  }

  Future<bool> likeContent(String postId) => toggleLike(postId, true);
  Future<bool> unlikeContent(String postId) => toggleLike(postId, false);
}
