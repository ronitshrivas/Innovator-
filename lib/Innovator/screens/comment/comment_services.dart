// comment_services.dart
// All endpoints updated to http://182.93.94.220:8005

import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/models/comment_Model.dart';

class CommentService {
  static const String _base = 'http://182.93.94.220:8005';

  Map<String, String> _headers({bool json = true}) {
    final token = AppData().accessToken ?? '';
    return {
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Fetch top-level comments for a post ────────────────────────────────────
  // GET /api/comments/?post=<postId>
  // The API returns a list (or a paginated wrapper — handled both ways).
  Future<List<Comment>> getComments(String postId, {int page = 0}) async {
    try {
      final uri = Uri.parse('$_base/api/comments/').replace(
        queryParameters: {
          'post': postId,
          if (page > 0) 'page': page.toString(),
        },
      );
      final response = await http.get(uri, headers: _headers(json: false));
      log('[Comment] GET $uri → ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> raw =
            decoded is List
                ? decoded
                : (decoded['results'] ?? decoded['data'] ?? []);
        return raw
            .whereType<Map<String, dynamic>>()
            .map(Comment.fromJson)
            .toList();
      } else {
        throw Exception('getComments failed: ${response.statusCode}');
      }
    } catch (e) {
      log('[Comment] getComments error: $e');
      rethrow;
    }
  }

  // ── Fetch replies for a comment ────────────────────────────────────────────
  // GET /api/replies/?parent=<commentId>  (assumed; adjust if endpoint differs)
  Future<List<Comment>> getReplies(String commentId) async {
    try {
      final uri = Uri.parse(
        '$_base/api/replies/',
      ).replace(queryParameters: {'parent': commentId});
      final response = await http.get(uri, headers: _headers(json: false));
      log('[Comment] GET $uri → ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> raw =
            decoded is List
                ? decoded
                : (decoded['results'] ?? decoded['data'] ?? []);
        return raw
            .whereType<Map<String, dynamic>>()
            .map(Comment.fromJson)
            .toList();
      } else {
        return [];
      }
    } catch (e) {
      log('[Comment] getReplies error: $e');
      return [];
    }
  }

  // ── Add a top-level comment ────────────────────────────────────────────────
  // POST /api/comments/  { "post": postId, "content": text }
  Future<Comment> addComment({
    required String postId,
    required String content,
  }) async {
    final response = await http.post(
      Uri.parse('$_base/api/comments/'),
      headers: _headers(),
      body: jsonEncode({'post': postId, 'content': content}),
    );
    log(
      '[Comment] POST /api/comments/ → ${response.statusCode}: ${response.body}',
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Comment.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw Exception('addComment failed: ${response.statusCode}');
  }

  // ── Add a reply to a comment ───────────────────────────────────────────────
  // POST /api/replies/  { "parent": commentId, "content": text }
  Future<Comment> addReply({
    required String parentCommentId,
    required String content,
  }) async {
    final response = await http.post(
      Uri.parse('$_base/api/replies/'),
      headers: _headers(),
      body: jsonEncode({'parent': parentCommentId, 'content': content}),
    );
    log(
      '[Comment] POST /api/replies/ → ${response.statusCode}: ${response.body}',
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Comment.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw Exception('addReply failed: ${response.statusCode}');
  }

  // ── Edit a comment ─────────────────────────────────────────────────────────
  // PATCH /api/comments/<id>/  { "content": newText }
  Future<Comment> updateComment({
    required String commentId,
    required String content,
  }) async {
    final response = await http.patch(
      Uri.parse('$_base/api/comments/$commentId/'),
      headers: _headers(),
      body: jsonEncode({'content': content}),
    );
    log('[Comment] PATCH /api/comments/$commentId/ → ${response.statusCode}');
    if (response.statusCode == 200) {
      return Comment.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw Exception('updateComment failed: ${response.statusCode}');
  }

  // ── Delete a comment ───────────────────────────────────────────────────────
  // DELETE /api/comments/<id>/
  Future<void> deleteComment(String commentId) async {
    final response = await http.delete(
      Uri.parse('$_base/api/comments/$commentId/'),
      headers: _headers(json: false),
    );
    log('[Comment] DELETE /api/comments/$commentId/ → ${response.statusCode}');
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('deleteComment failed: ${response.statusCode}');
    }
  }
}
