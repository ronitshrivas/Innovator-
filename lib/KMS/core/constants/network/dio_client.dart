import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:innovator/KMS/core/constants/api_constants.dart';
import 'package:innovator/KMS/core/constants/navigator_key.dart';
import 'package:innovator/KMS/core/constants/network/dio_interceptor.dart';
import 'package:innovator/KMS/screens/auth/login_screen.dart';


class DioClient {
  static Dio? _instance;
  static Dio? _authInstance;

  static Dio get instance {
    _instance ??= _createDio(ApiConstants.defaultTimeout);
    return _instance!;
  }

  static Dio get authInstance {
    _authInstance ??= _createDio(ApiConstants.authTimeout);
    return _authInstance!;
  }

  static Dio _createDio(Duration timeout) {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        sendTimeout: timeout,
      ),
    );

    dio.interceptors.add(
      AppInterceptor(
        onForceLogout: _handleForceLogout,
      ),
    );

    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
        logPrint: (obj) => log('$obj'),
      ),
    );

    return dio;
  }

  static void _handleForceLogout() {
    final context = kmsNavigatorKey.currentContext;
    if (context == null) {
      kmsNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const KmsLoginScreen()),
        (route) => false,
      );
      return;
    }

    showAdaptiveDialog(
      context: context,
      barrierDismissible: false, 
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        title: const Icon(
          Icons.lock_clock_rounded,
          size: 52,
          color: Colors.orange,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Session Expired',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your session has expired. Please login again to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: () {
                kmsNavigatorKey.currentState?.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const KmsLoginScreen(),
                  ),
                  (route) => false,
                );
              },
              child: const Text(
                'Login Again',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void reset() {
    _instance?.close();
    _authInstance?.close();
    _instance = null;
    _authInstance = null;
  }
}
