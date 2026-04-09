import 'dart:developer';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/elearning/core/constants/api_constants.dart';
import 'package:innovator/elearning/core/constants/network/base_api_service.dart';
import 'package:innovator/elearning/core/constants/network/dio_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService extends ElearningBaseApiService {
  NotificationService() : super(dio: DioClient.instance);

  static const String _prefKey = 'elearning_fcm_token_id';

  /// Main method - Call this AFTER successful login
  Future<void> registerFcmToken(String token) async {
    try {
      final accessToken = AppData().accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        log('ElearningFCM: No access token, skipping registration');
        return;
      }

      final device = await deviceInfo();
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_prefKey);

      if (savedId == null) {
        await _createToken(token: token, device: device, prefs: prefs);
      } else {
        await _updateToken(
          id: savedId,
          token: token,
          device: device,
          prefs: prefs,
        );
      }
    } catch (e) {
      log('ElearningFCM: registerFcmToken error: $e');
    }
  }

  Future<void> _createToken({
    required String token,
    required String device,
    required SharedPreferences prefs,
  }) async {
    try {
      log('ElearningFCM: POSTing token to ${ElearningApi.fcmTokens}');
      
      final data = await post(
        ElearningApi.fcmTokens,
        data: {'token': token, 'device_name': device},
      );

      final id = data?['id']?.toString();
      if (id != null) {
        await prefs.setString(_prefKey, id);
        log('ElearningFCM: ✅ Token Created — id: $id');
      } else {
        log('ElearningFCM: Created but no ID returned');
      }
    } catch (e) {
      log('ElearningFCM: Create failed: $e');
      if (e is DioException) {
        log('Status: ${e.response?.statusCode} | Body: ${e.response?.data}');
      }
    }
  }

  Future<void> _updateToken({
    required String id,
    required String token,
    required String device,
    required SharedPreferences prefs,
  }) async {
    try {
      await patch(
        '${ElearningApi.fcmTokens}$id/',
        data: {'token': token, 'device_name': device},
      );
      log('ElearningFCM: ✅ Token Updated — id: $id');
    } catch (e) {
      log('ElearningFCM: Update failed: $e');
      
      if (e is DioException) {
        final status = e.response?.statusCode;
        if (status == 404) {
          log('ElearningFCM: Record not found (404), creating new one');
          await prefs.remove(_prefKey);
          await _createToken(token: token, device: device, prefs: prefs);
        } else if (status == 401) {
          log('ElearningFCM: Unauthorized - check access token');
        }
      }
    }
  }

  Future<void> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_prefKey);
      if (id != null) {
        await delete('${ElearningApi.fcmTokens}$id/');
        await prefs.remove(_prefKey);
        log('ElearningFCM: Token cleared successfully');
      }
    } catch (e) {
      log('ElearningFCM: clearToken error: $e');
    }
  }

  Future<String> deviceInfo() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        return '${a.manufacturer} ${a.model}';
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        return i.utsname.machine;
      }
    } catch (_) {}
    return 'Unknown Device';
  }
}