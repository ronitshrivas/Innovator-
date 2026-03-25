import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:innovator/ecommerce/core/constants/api_constants.dart';
import 'dio_interceptor.dart';

class DioClient {
  static Dio? _instance;
  static Dio? _authInstance;

  static Dio get instance {
    _instance ??= _createDio(EcommerApi.defaultTimeout);
    return _instance!;
  }

  static Dio _createDio(Duration timeout) {
    final dio = Dio(
      BaseOptions(
        baseUrl: EcommerApi.baseUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        sendTimeout: timeout,
      ),
    );

    dio.interceptors.add(AuthInterceptor(dio));

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
