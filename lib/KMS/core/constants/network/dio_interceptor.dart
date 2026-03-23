import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:innovator/KMS/core/constants/api_constants.dart';
import 'package:innovator/KMS/core/constants/service/connectivity_service.dart';
import 'package:innovator/KMS/core/constants/service/token_service.dart';
import 'package:innovator/KMS/core/exceptions/app_exceptions.dart';
import 'package:innovator/KMS/core/utils/toast_utils.dart';

class AppInterceptor extends Interceptor {
  final TokenService _tokenService = TokenService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final VoidCallback? onForceLogout;
  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = [];
  AppInterceptor({this.onForceLogout});

  static const _authEndpoints = ['/auth/sso/login/', '/auth/register/'];

  static const _refreshEndpoint = '/auth/token/refresh/';

  // Request

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_connectivityService.isConnected) {
      return handler.reject(
        DioException(
          requestOptions: options,
          error: NetworkException(),
          type: DioExceptionType.connectionError,
        ),
      );
    }

    if (!_isAuthEndpoint(options.path)) {
      final token = await _tokenService.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    options.headers['Content-Type'] = 'application/json';
    options.headers['Accept'] = 'application/json';

    log(' REQUEST[${options.method}] => PATH: ${options.path}');
    super.onRequest(options, handler);
  }

  // Response

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    log(
      'RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}',
    );

    await _autoSaveToken(response);

    if (_shouldShowSuccessToast(response)) {
      final message = _extractMessage(response.data) ?? 'Success';
      ToastUtils.showSuccess(message);
    }

    super.onResponse(response, handler);
  }

  // Error

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    log(
      'ERROR[${err.response?.statusCode}] => PATH: ${err.requestOptions.path}',
    );

    if (err.response?.statusCode == 401 &&
        !_isAuthEndpoint(err.requestOptions.path)) {
      final retried = await _handleTokenRefresh(err, handler);
      if (retried) return;
    }

    final exception = _handleError(err);

    if (err.response?.statusCode != 404) {
      ToastUtils.showError(exception.message);
    }

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: exception,
        type: err.type,
        response: err.response,
      ),
    );
  }

  // token Refresh

  Future<bool> _handleTokenRefresh(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (_isRefreshing) {
      _pendingRequests.add(_PendingRequest(err, handler));
      return true;
    }

    _isRefreshing = true;

    try {
      final refreshToken = await _tokenService.getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        log('No refresh token found — forcing logout');
        _rejectAllPending();
        await _forceLogout();
        return false;
      }

      log('Access token expired — refreshing...');

      final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
      final response = await refreshDio.post(
        _refreshEndpoint,
        data: {'refresh': refreshToken},
      );

      final newAccessToken = response.data['access_token'] as String?;
      final newRefreshToken = response.data['refresh_token'] as String?;

      if (newAccessToken == null || newAccessToken.isEmpty) {
        log('Refresh response did not include access_token — forcing logout');
        _rejectAllPending();
        await _forceLogout();
        return false;
      }

      await _tokenService.saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );
      log('Token refreshed and saved');

      await _retryRequest(err.requestOptions, handler, newAccessToken);

      for (final pending in _pendingRequests) {
        await _retryRequest(
          pending.error.requestOptions,
          pending.handler,
          newAccessToken,
        );
      }

      _pendingRequests.clear();
      return true;
    } catch (e) {
      log('Token refresh failed');
      log("$e");
      _rejectAllPending();

      await _forceLogout();
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  void _rejectAllPending() {
    for (final pending in _pendingRequests) {
      pending.handler.reject(
        DioException(
          requestOptions: pending.error.requestOptions,
          error: UnauthorizedException('Session expired. Please login again.'),
          type: DioExceptionType.badResponse,
        ),
      );
    }
    _pendingRequests.clear();
  }

  Future<void> _retryRequest(
    RequestOptions requestOptions,
    ErrorInterceptorHandler handler,
    String newToken,
  ) async {
    try {
      requestOptions.headers['Authorization'] = 'Bearer $newToken';

      final retryDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
      final response = await retryDio.request(
        requestOptions.path,
        data: requestOptions.data,
        queryParameters: requestOptions.queryParameters,
        options: Options(
          method: requestOptions.method,
          headers: requestOptions.headers,
        ),
      );

      log('Retried request succeeded: ${requestOptions.path}');
      handler.resolve(response);
    } catch (e) {
      log('Retried request also failed: $e');
      handler.reject(
        DioException(
          requestOptions: requestOptions,
          error: AppException('Request failed after token refresh'),
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  Future<void> _forceLogout() async {
    await _tokenService.clearTokens();
    log('User force-logged out — tokens cleared');
    onForceLogout?.call();
  }

  //  saving token auto

  Future<void> _autoSaveToken(Response response) async {
    try {
      if (!_isAuthEndpoint(response.requestOptions.path)) return;

      final data = response.data;
      if (data is! Map<String, dynamic>) return;

      final accessToken = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;
      final role = data['user']?['role'] as String?;

      if (accessToken != null && accessToken.isNotEmpty) {
        await _tokenService.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
        log('Access_token saved: $accessToken');
        log(
          'Refresh_token saved: ${refreshToken != null ? '$refreshToken' : 'No refresh token found'}',
        );
        log('Role: ${role ?? 'No role found'}');
      }
    } catch (e) {
      log(' AutoSaveToken error: $e');
    }
  }

  // Handle error

  AppException _handleError(DioException error) {
    if (!_connectivityService.isConnected) return NetworkException();

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException();
      case DioExceptionType.connectionError:
        return NetworkException();
      case DioExceptionType.badResponse:
        return _handleStatusCode(error.response);
      case DioExceptionType.cancel:
        return AppException('Request cancelled');
      default:
        return AppException('Something went wrong. Please try again.');
    }
  }

  AppException _handleStatusCode(Response? response) {
    final statusCode = response?.statusCode ?? 0;
    final message = _extractMessage(response?.data);

    switch (statusCode) {
      case 400:
        return BadRequestException(message ?? 'Invalid request');
      case 401:
        return UnauthorizedException(message ?? 'Session expired');
      case 403:
        return AppException(message ?? 'Access denied', statusCode: 403);
      case 404:
        return NotFoundException(message ?? 'Resource not found');
      case 422:
        return AppException(message ?? 'Validation failed', statusCode: 422);
      case 500:
      case 502:
      case 503:
        return ServerException(message ?? 'Server error');
      default:
        return AppException(
          message ?? 'Error occurred (Code: $statusCode)',
          statusCode: statusCode,
        );
    }
  }

  //Message Extraction

  String? _extractMessage(dynamic data) {
    if (data == null) return null;

    if (data is Map) {
      final flat =
          data['message'] ?? data['detail'] ?? data['error'] ?? data['msg'];
      if (flat != null) return flat.toString();

      final nonField = data['non_field_errors'];
      if (nonField is List && nonField.isNotEmpty) {
        return nonField.first.toString();
      }

      for (final value in data.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value is String) return value;
      }
    }

    if (data is String) return data;
    return null;
  }

  // Helper
  bool _isAuthEndpoint(String path) {
    return _authEndpoints.any(
      (endpoint) => path.toLowerCase().contains(endpoint.toLowerCase()),
    );
  }

  bool _shouldShowSuccessToast(Response response) {
    return [
      'POST',
      'PUT',
      'DELETE',
      'PATCH',
    ].contains(response.requestOptions.method);
  }
}

class _PendingRequest {
  final DioException error;
  final ErrorInterceptorHandler handler;
  _PendingRequest(this.error, this.handler);
}
