// API_Service.dart
// Update:  PATCH  http://182.93.94.220:8005/api/posts/<id>/  (multipart)
// Delete:  DELETE http://182.93.94.220:8005/api/posts/<id>/

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/Authorization/Login.dart';

class ApiService {
  static const String _base = 'http://182.93.94.220:8005';

  // ── Auth header (no Content-Type — multipart sets its own boundary) ────────
  static Map<String, String> _authHeader() {
    final token = AppData().accessToken ?? '';
    return {
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ── JSON header (used for JSON-only requests) ─────────────────────────────
  static Map<String, String> _jsonHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ..._authHeader(),
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UPDATE POST
  // PATCH /api/posts/<id>/
  // Body: multipart/form-data
  //   content        (text)  — post text
  //   uploaded_media (file)  — optional new image/video
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> updateContent(
    String postId,
    String content, {
    File? mediaFile, // optional: attach a new image / video
    BuildContext? context,
  }) async {
    try {
      debugPrint('[ApiService] PATCH /api/posts/$postId/');

      final uri = Uri.parse('$_base/api/posts/$postId/');
      final request =
          http.MultipartRequest('PATCH', uri)
            ..headers.addAll(_authHeader())
            ..fields['content'] = content;

      if (mediaFile != null) {
        final filename = path.basename(mediaFile.path);
        final ext = filename.split('.').last.toLowerCase();
        final mimeType = _mimeType(ext);

        request.files.add(
          http.MultipartFile(
            'uploaded_media',
            http.ByteStream(mediaFile.openRead()),
            await mediaFile.length(),
            filename: filename,
            contentType: MediaType.parse(mimeType),
          ),
        );

        debugPrint('[ApiService] Attaching media: $filename ($mimeType)');
      }

      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamed);

      debugPrint(
        '[ApiService] Update ${response.statusCode}: ${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else if (response.statusCode == 401) {
        _redirectToLogin(context);
        return false;
      } else {
        debugPrint('[ApiService] Update failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[ApiService] updateContent error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELETE POST
  // DELETE /api/posts/<id>/
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> deleteFiles(
    String postId, {
    BuildContext? context,
  }) async {
    try {
      debugPrint('[ApiService] DELETE /api/posts/$postId/');

      final response = await http
          .delete(
            Uri.parse('$_base/api/posts/$postId/'),
            headers: _authHeader(),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint(
        '[ApiService] Delete ${response.statusCode}: ${response.body}',
      );

      if (response.statusCode == 200 ||
          response.statusCode == 204 ||
          response.statusCode == 202) {
        return true;
      } else if (response.statusCode == 401) {
        _redirectToLogin(context);
        return false;
      } else {
        debugPrint('[ApiService] Delete failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[ApiService] deleteFiles error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  static String _mimeType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      default:
        return 'image/jpeg';
    }
  }

  static void _redirectToLogin(BuildContext? context) {
    if (context != null && context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginPage()),
        (route) => false,
      );
    }
  }
}
