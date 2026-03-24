import 'dart:developer';

import 'package:innovator/KMS/core/constants/api_constants.dart';
import 'package:innovator/KMS/core/constants/network/base_api_service.dart';
import 'package:innovator/KMS/core/constants/network/dio_client.dart';
import 'package:innovator/KMS/core/constants/service/token_service.dart';

class AuthService extends BaseApiService {
  AuthService() : super(dio: DioClient.authInstance);

  final TokenService _tokenService = TokenService();
    Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await post<Map<String, dynamic>>(
      ApiConstants.login,
      data: {'email': email, 'password': password},
    );

     final role = response['user']?['role'] as String?;
    if (role != null && role.isNotEmpty) {
      await _tokenService.saveRole(role);
      log('Role saved: $role');
    }

    return response;
  }

  Future<Map<String, dynamic>> register({
    required String userName,
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await post<Map<String, dynamic>>(
      ApiConstants.register,
      data: {
        'username': userName,
        'email': email,
        'password': password,
        'role': role,
      },
    );

    await _tokenService.saveRole(role);
    log('Role saved on register: $role');

    return response;
  }

  Future<void> logout() async {
    await _tokenService.clearTokens(); 
    log('Logged out — tokens and role cleared, Dio reset');
  }

  Future<bool> isLoggedIn() async {
    return await _tokenService.hasToken();
  }

  Future<String?> getSavedRole() async {
    return await _tokenService.getRole();
  }

  //   Future<Map<String, dynamic>> forgotPassword({required String email}) async {
  //   return await post(ApiConstants.forgotPassword, data: {'email': email});
  // }

  // Future<Map<String, dynamic>> validateCode({
  //   required String email,
  //   required String resetCode,
  //   required String newPassword,
  // }) async {
  //   return await post(
  //     ApiConstants.validateResetCode,
  //     data: {'email': email, 'resetCode': resetCode, 'newPassword': newPassword},
  //   );
  // }

  // Future<Map<String, dynamic>> resentCode({required String email}) async {
  //   return await post(ApiConstants.resendCode, data: {'email': email});
  // }

  // Future<Map<String, dynamic>> changePassword({
  //   required String currentPassword,
  //   required String newPassword,
  //   required String confirmPassword,
  // }) async {
  //   return await post(
  //     ApiConstants.changePassword,
  //     data: {
  //       'currentPassword': currentPassword,
  //       'newPassword': newPassword,
  //       'confirmPassword': confirmPassword,
  //     },
  //   );
  // }
}
