// import 'dart:developer';

// import 'package:dio/dio.dart';
// import 'package:flutter/foundation.dart';
// import 'package:get/get_connect/http/src/response/client_response.dart';
// import 'package:innovator/ecommerce/core/constants/api_constants.dart';
// import 'package:innovator/ecommerce/core/constants/network/dio_interceptor.dart';

// class DioClient {
//   static final DioClient _instance = DioClient._internal();
//   factory DioClient() => _instance;
//   late final Dio dio;
//   DioClient._internal() {
//     dio = Dio(
//       BaseOptions(
//         baseUrl: EcommerApi.baseUrl,
//         connectTimeout: EcommerApi.defaultTimeout,
//         receiveTimeout: EcommerApi.defaultTimeout,
//         sendTimeout: EcommerApi.uploadTimeout,
//         headers: {
//           HttpHeaders.contentTypeHeader: 'application/json',
//           HttpHeaders.acceptHeader: 'application/json',
//         },
//       ),
//     );
//     dio.interceptors.addAll([
//       AuthInterceptor(dio),
//       if (kDebugMode)
//         LogInterceptor(
//           request: true,
//           requestBody: true,
//           logPrint: (object) => log('$object'),
//         ),
//     ]);
//   }
// }

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
