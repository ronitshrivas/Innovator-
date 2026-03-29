 import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:innovator/KMS/core/constants/api_constants.dart'; 
import 'dio_interceptor.dart';

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

    dio.interceptors.add(AppInterceptor());

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

  static void reset() {
    _instance?.close();
    _authInstance?.close();
    _instance = null;
    _authInstance = null;
  }
}