
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:innovator/KMS/core/constants/api_constants.dart';
import 'package:innovator/KMS/core/constants/service/connectivity_service.dart';
import 'package:innovator/KMS/core/constants/service/token_service.dart';
import 'package:innovator/KMS/core/exceptions/app_exceptions.dart';
import 'package:innovator/KMS/core/utils/toast_utils.dart';

class AppInterceptor extends Interceptor {
  final TokenService _tokenService = TokenService();
  final ConnectivityService _connectivityService = ConnectivityService();

  // Prevents multiple simultaneous refresh calls
  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = [];

  // Endpoints that don't need an auth token attached
  static const _authEndpoints = [
    '/auth/sso/login/',
    '/auth/register/',
  ];

  // Update this to match your actual refresh endpoint
  static const _refreshEndpoint = '/auth/token/refresh/';

  // ─── Request ──────────────────────────────────────────────────────────────

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
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

    log('🚀 REQUEST[${options.method}] => PATH: ${options.path}');
    super.onRequest(options, handler);
  }

  // ─── Response ─────────────────────────────────────────────────────────────

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    log('✅ RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}');

    await _autoSaveToken(response);

    if (_shouldShowSuccessToast(response)) {
      final message = _extractMessage(response.data) ?? 'Success';
      ToastUtils.showSuccess(message);
    }

    super.onResponse(response, handler);
  }

  // ─── Error ────────────────────────────────────────────────────────────────

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    log('❌ ERROR[${err.response?.statusCode}] => PATH: ${err.requestOptions.path}');

    // Try to refresh token on 401 before failing
    if (err.response?.statusCode == 401 && !_isAuthEndpoint(err.requestOptions.path)) {
      final retried = await _handleTokenRefresh(err, handler);
      if (retried) return;
    }

    final exception = _handleError(err);
    ToastUtils.showError(exception.message);

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: exception,
        type: err.type,
        response: err.response,
      ),
    );
  }

  // ─── Token Refresh ────────────────────────────────────────────────────────

  /// Attempts to refresh the access token and retry the failed request.
  /// Returns true if the request was retried successfully.
  Future<bool> _handleTokenRefresh(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // If already refreshing, queue this request and wait
    if (_isRefreshing) {
      _pendingRequests.add(_PendingRequest(err, handler));
      return true;
    }

    _isRefreshing = true;

    try {
      final refreshToken = await _tokenService.getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        log('⚠️ No refresh token found — forcing logout');
        await _forceLogout();
        _isRefreshing = false;
        return false;
      }

      log('🔄 Access token expired — refreshing...');

      // Use a plain Dio (no interceptors) to avoid an infinite loop
      final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
      final response = await refreshDio.post(
        _refreshEndpoint,
        data: {'refresh': refreshToken},
      );

      final newAccessToken = response.data['access_token'] as String?;
      final newRefreshToken = response.data['refresh_token'] as String?;

      if (newAccessToken == null || newAccessToken.isEmpty) {
        log('⚠️ Refresh response did not include access_token — forcing logout');
        await _forceLogout();
        _isRefreshing = false;
        return false;
      }

      await _tokenService.saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );
      log('✅ Token refreshed and saved');

      // Retry the original request
      await _retryRequest(err.requestOptions, handler, newAccessToken);

      // Retry any queued requests that also 401'd during the refresh window
      for (final pending in _pendingRequests) {
        await _retryRequest(pending.error.requestOptions, pending.handler, newAccessToken);
      }

      _pendingRequests.clear();
      _isRefreshing = false;
      return true;
    } on DioException catch (e) {
      log('❌ Token refresh failed: ${e.message}');
      _pendingRequests.clear();
      _isRefreshing = false;
      await _forceLogout();
      return false;
    }
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

      log('🔁 Retried request succeeded: ${requestOptions.path}');
      handler.resolve(response);
    } catch (e) {
      log('❌ Retried request also failed: $e');
    }
  }

  Future<void> _forceLogout() async {
    await _tokenService.clearTokens();
    // TODO: Add your navigation to login screen here, e.g.:
    // NavigationService.instance.navigateToLogin();
    log('🔒 User force-logged out');
  }

  // ─── Auto-save Token ──────────────────────────────────────────────────────

  /// Reads access_token and refresh_token from login/register responses
  /// and saves them automatically — no manual save needed in AuthService.
  Future<void> _autoSaveToken(Response response) async {
    try {
      if (!_isAuthEndpoint(response.requestOptions.path)) return;

      final data = response.data;
      if (data is! Map<String, dynamic>) return;

      // Matches your API: { "access_token": "...", "refresh_token": "..." }
      final accessToken = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;

      if (accessToken != null && accessToken.isNotEmpty) {
        await _tokenService.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
        log('💾 Tokens saved — access_token: ✅ | refresh_token: ${refreshToken != null ? '✅' : '❌ not present'}');
      }
    } catch (e) {
      log('⚠️ _autoSaveToken error: $e');
    }
  }

  // ─── Error Handling ───────────────────────────────────────────────────────

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
        _forceLogout();
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
        return AppException(message ?? 'Error occurred (Code: $statusCode)', statusCode: statusCode);
    }
  }

  // ─── Message Extraction ───────────────────────────────────────────────────

  /// Handles all Django REST Framework error shapes:
  ///
  ///   Flat key      → {"detail": "Not found."}
  ///   Custom key    → {"message": "No user found with this email"}
  ///   Field error   → {"email": ["No user found with this email"]}
  ///   Non-field     → {"non_field_errors": ["Invalid credentials"]}
  String? _extractMessage(dynamic data) {
    if (data == null) return null;

    if (data is Map) {
      // 1. Check standard flat keys first
      final flat = data['message'] ?? data['detail'] ?? data['error'] ?? data['msg'];
      if (flat != null) return flat.toString();

      // 2. DRF non-field errors
      final nonField = data['non_field_errors'];
      if (nonField is List && nonField.isNotEmpty) {
        return nonField.first.toString();
      }

      // 3. DRF field-level errors — grab the first one found
      for (final value in data.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value is String) return value;
      }
    }

    if (data is String) return data;
    return null;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  bool _isAuthEndpoint(String path) {
    return _authEndpoints.any(
      (endpoint) => path.toLowerCase().contains(endpoint.toLowerCase()),
    );
  }

  bool _shouldShowSuccessToast(Response response) {
    return ['POST', 'PUT', 'DELETE', 'PATCH'].contains(response.requestOptions.method);
  }
}

// Holds a queued request that arrived while a token refresh was in progress
class _PendingRequest {
  final DioException error;
  final ErrorInterceptorHandler handler;
  _PendingRequest(this.error, this.handler);
}