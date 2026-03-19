import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:flutter/foundation.dart';

class FollowService {
  static const String _baseUrl = 'http://182.93.94.210:3067/api/v1';
  static const String _checkUrl = 'http://182.93.94.210:3067/api/v1/check';

  static Future<Map<String, dynamic>> sendFollowRequest(String email) async {
    try {
      final authToken = AppData().accessToken;
      if (authToken == null || authToken.isEmpty) {
        throw Exception('User not authenticated');
      }

      final url = Uri.parse('$_baseUrl/follow');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'authorization': 'Bearer $authToken',
      };
      final body = jsonEncode({'email': email});

      debugPrint(' Sending follow request to: $email');
      debugPrint(' Follow API URL: $url');

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      debugPrint(' Follow API Response: ${response.statusCode}');
      debugPrint(' Follow Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        debugPrint('Follow request successful');
        return responseData;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 409) {
        throw Exception('You are already following this user.');
      } else {
        final errorBody =
            response.body.isNotEmpty ? response.body : 'Unknown error';
        throw Exception(
          'Failed to send follow request (${response.statusCode}): $errorBody',
        );
      }
    } catch (e) {
      debugPrint(' Follow request error: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        throw Exception('Network error. Please check your connection.');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> unfollowUser(String email) async {
    try {
      final authToken = AppData().accessToken;
      if (authToken == null || authToken.isEmpty) {
        throw Exception('User not authenticated');
      }

      final url = Uri.parse('$_baseUrl/follow');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'authorization': 'Bearer $authToken',
      };
      final body = jsonEncode({'email': email, 'action': 'unfollow'});

      debugPrint(' Sending unfollow request to: $email');
      debugPrint(' Unfollow API URL: $url');

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      debugPrint(' Unfollow API Response: ${response.statusCode}');
      debugPrint(' Unfollow Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        debugPrint('Unfollow request successful');
        return responseData;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 404) {
        throw Exception('User not found or not following.');
      } else {
        final errorBody =
            response.body.isNotEmpty ? response.body : 'Unknown error';
        throw Exception(
          'Failed to unfollow user (${response.statusCode}): $errorBody',
        );
      }
    } catch (e) {
      debugPrint(' Unfollow request error: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        throw Exception('Network error. Please check your connection.');
      }
      rethrow;
    }
  }

  static Future<bool> checkFollowStatus(String email) async {
    try {
      final authToken = AppData().accessToken;
      if (authToken == null || authToken.isEmpty) {
        throw Exception('User not authenticated');
      }

      final url = Uri.parse('$_checkUrl?email=${Uri.encodeComponent(email)}');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'authorization': 'Bearer $authToken',
      };

      debugPrint(' Checking follow status for: $email');
      debugPrint(' Check API URL: $url');

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 15));

      debugPrint(' Check API Response: ${response.statusCode}');
      debugPrint(' Check Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isFollowing = data['data']?['isFollowing'] ?? false;
        debugPrint('Follow status check successful: $isFollowing');
        return isFollowing;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        debugPrint(' Failed to check follow status: ${response.statusCode}');
        return false; // Default to not following on error
      }
    } catch (e) {
      debugPrint(' Check follow status error: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        debugPrint(
          ' Network error checking follow status, defaulting to false',
        );
        return false;
      }
      return false; // Default to not following on error
    }
  }

  /// Batch check follow status for multiple users
  static Future<Map<String, bool>> checkMultipleFollowStatus(
    List<String> emails,
  ) async {
    try {
      final authToken = AppData().accessToken;
      if (authToken == null || authToken.isEmpty) {
        throw Exception('User not authenticated');
      }

      final url = Uri.parse('$_baseUrl/follow/check-multiple');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'authorization': 'Bearer $authToken',
      };
      final body = jsonEncode({'emails': emails});

      debugPrint(' Checking follow status for ${emails.length} users');

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      debugPrint(' Batch check API Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final followStatuses = Map<String, bool>.from(data['data'] ?? {});
        debugPrint('Batch follow status check successful');
        return followStatuses;
      } else {
        debugPrint(
          ' Failed to batch check follow status: ${response.statusCode}',
        );
        return {}; // Return empty map on error
      }
    } catch (e) {
      debugPrint(' Batch check follow status error: $e');
      return {}; // Return empty map on error
    }
  }
}
