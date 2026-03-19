import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/models/Shop_cart_model.dart';

class ApiService {
  static const String baseUrl = 'http://182.93.94.210:3067/api/v1';
  final AppData appData = AppData();

  Future<CartListResponse> getCartList() async {
    final url = Uri.parse('$baseUrl/list-carts');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'authorization': 'Bearer ${appData.accessToken}',
      },
    );

    if (response.statusCode == 200) {
      return CartListResponse.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load cart list: ${response.statusCode}');
    }
  }

  Future<void> deleteCartItem(String itemId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/delete-cart/$itemId'),
      headers: {
        'authorization': 'Bearer ${appData.accessToken}',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete cart item');
    }
  }

  Future<CheckoutResponse> checkout({
    required CustomerInfo customerInfo,
    required double paidAmount,
    File? paymentProof,
    String? notes,
    bool isCod = false,
    required String paymentMethod,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/checkout');

      if (isCod) {
        final body = {
          'customerName': customerInfo.name,
          'customerPhone': customerInfo.phone,
          'customerAddress': customerInfo.address,
          'paidAmount': paidAmount.toString(),
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          'isCod': 'true',
          'paymentMethod': paymentMethod,
        };

        final response = await http.post(
          url,
          headers: {
            'authorization': 'Bearer ${appData.accessToken}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode(body),
        );

        return _handleCheckoutResponse(response);
      }

      if (paymentProof == null) {
        throw Exception('Payment proof is required for online payment');
      }

      if (!await paymentProof.exists()) {
        throw Exception('Payment proof file does not exist');
      }

      final fileSize = await paymentProof.length();
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('File size too large. Maximum 10MB allowed.');
      }

      final mimeType = lookupMimeType(paymentProof.path);
      debugPrint('Detected MIME type: $mimeType');
      if (mimeType == null || !_isValidImageMimeType(mimeType)) {
        throw Exception(
          'Invalid file type. Only JPEG, PNG, GIF, and WebP images are allowed.',
        );
      }

      var request = http.MultipartRequest('POST', url);
      request.headers.addAll({
        'authorization': 'Bearer ${appData.accessToken}',
        'Accept': 'application/json',
      });

      request.fields.addAll({
        'customerName': customerInfo.name,
        'customerPhone': customerInfo.phone,
        'customerAddress': customerInfo.address,
        'paidAmount': paidAmount.toString(),
        'isCod': 'false',
        'paymentMethod': paymentMethod,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });

      final multipartFile = await http.MultipartFile.fromPath(
        'paymentProof',
        paymentProof.path,
        contentType: MediaType.parse(mimeType),
      );
      request.files.add(multipartFile);

      debugPrint('Sending request to: $url');
      debugPrint('Request fields: ${request.fields}');
      debugPrint(
        'File: ${paymentProof.path.split('/').last}, Size: $fileSize bytes',
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout:
            () =>
                throw Exception(
                  'Request timeout. Please check your internet connection.',
                ),
      );

      final response = await http.Response.fromStream(streamedResponse);
      return _handleCheckoutResponse(response);
    } catch (e) {
      if (e.toString().contains('Checkout error:')) rethrow;
      throw Exception('Checkout error: ${e.toString()}');
    }
  }

  CheckoutResponse _handleCheckoutResponse(http.Response response) {
    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response body: ${response.body}');

    if (response.statusCode == 201 || response.statusCode == 200) {
      if (response.headers['content-type']?.contains('application/json') ==
          true) {
        return CheckoutResponse.fromJson(json.decode(response.body));
      } else {
        throw Exception('Server returned non-JSON response: ${response.body}');
      }
    } else {
      String errorMessage =
          'Checkout failed with status ${response.statusCode}';
      try {
        if (response.body.contains('<!DOCTYPE html>')) {
          final match = RegExp(
            r'<pre>(.*?)</pre>',
            dotAll: true,
          ).firstMatch(response.body);
          if (match != null) {
            errorMessage =
                match
                    .group(1)!
                    .replaceAll('<br>', '\n')
                    .replaceAll('&nbsp;', ' ')
                    .replaceAll(RegExp(r'<[^>]*>'), '')
                    .trim()
                    .split('\n')
                    .first;
          }
        } else {
          final errorData = json.decode(response.body);
          errorMessage =
              errorData['message'] ??
              errorData['error']?['error'] ??
              errorMessage;
        }
      } catch (_) {
        if (response.body.isNotEmpty && response.body.length < 500) {
          errorMessage = response.body;
        }
      }
      throw Exception(errorMessage);
    }
  }

  bool _isValidImageMimeType(String mimeType) {
    const validTypes = [
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/gif',
      'image/webp',
    ];
    return validTypes.contains(mimeType.toLowerCase());
  }
}
