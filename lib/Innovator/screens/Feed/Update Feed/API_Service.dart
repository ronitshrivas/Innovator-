import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/Authorization/Login.dart';

class ApiService {
  static const String baseUrl = 'http://182.93.94.210:3067/api/v1';

  // Get headers with auth token if available
  static Map<String, String> _getHeaders() {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = AppData().accessToken;
    if (token != null && token.isNotEmpty) {
      headers['authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // Update content by ID
  static Future<bool> updateContent(
    String id,
    String status, {
    BuildContext? context,
  }) async {
    try {
      debugPrint(' Updating content: $id');
      debugPrint('📝 New status: $status');

      final response = await http
          .put(
            Uri.parse('$baseUrl/update-contents/$id'),
            headers: _getHeaders(),
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint(' Update response status: ${response.statusCode}');
      debugPrint(' Update response body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('Content updated successfully');
        return true;
      } else if (response.statusCode == 401) {
        debugPrint(' Unauthorized - redirecting to login');
        if (context != null && context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => LoginPage()),
            (route) => false,
          );
        }
        return false;
      } else {
        debugPrint(' Update content failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint(' Error updating content: $e');
      return false;
    }
  }

  // Delete content/files
  static Future<bool> deleteFiles(
    String postId, {
    BuildContext? context,
  }) async {
    try {
      debugPrint('🗑️ Deleting content: $postId');

      final response = await http
          .delete(
            Uri.parse('$baseUrl/delete-content/$postId'),
            headers: _getHeaders(),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint(' Delete response status: ${response.statusCode}');
      debugPrint(' Delete response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('Content deleted successfully');
        return true;
      } else if (response.statusCode == 401) {
        debugPrint(' Unauthorized - redirecting to login');
        if (context != null && context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => LoginPage()),
            (route) => false,
          );
        }
        return false;
      } else {
        debugPrint(' Delete files failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint(' Error deleting files: $e');
      return false;
    }
  }
}
