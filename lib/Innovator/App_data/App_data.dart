import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for auth state.
///
/// Key contract (must match Login.dart & ApiService):
///   'access_token'  — JWT access token
///   'refresh_token' — JWT refresh token
///   'user_data'     — JSON-encoded user object from login response
class AppData {
  static final AppData _instance = AppData._internal();
  factory AppData() => _instance;
  AppData._internal();

  // ── In-memory cache ──────────────────────────────────────────────────────
  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _currentUser;
  bool _isInitialized = false;
  SharedPreferences? _prefs;

  // ── SharedPreferences keys ───────────────────────────────────────────────
  // These MUST match the keys used in Login.dart and ApiService._getToken()
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserData = 'user_data';

  // ── Getters ──────────────────────────────────────────────────────────────
  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  /// The full user map saved at login (keys: id, username, full_name,
  /// email, role, gender, date_of_birth, address, phone_number)
  Map<String, dynamic>? get currentUser => _currentUser;

  String? get currentUserId => _currentUser?['id']?.toString();
  String? get currentUserName =>
      _currentUser?['full_name']?.toString() ??
      _currentUser?['username']?.toString();
  String? get currentUserEmail => _currentUser?['email']?.toString();
  String? get currentUserRole => _currentUser?['role']?.toString();

  // ── Initialisation ───────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _prefs ??= await SharedPreferences.getInstance();

      _accessToken = _prefs!.getString(keyAccessToken);
      _refreshToken = _prefs!.getString(keyRefreshToken);

      final raw = _prefs!.getString(keyUserData);
      if (raw != null && raw.isNotEmpty) {
        try {
          _currentUser = jsonDecode(raw) as Map<String, dynamic>;
        } catch (e) {
          developer.log('AppData: error parsing user_data: $e');
        }
      }

      _isInitialized = true;
      developer.log('AppData initialized — authenticated: $isAuthenticated');
      developer.log('AppData keys in prefs: ${_prefs!.getKeys()}');
    } catch (e) {
      developer.log('AppData initialize error: $e');
    }
  }

  // ── Setters (called by Login.dart after successful login) ─────────────────

  Future<void> saveLoginData({
    required String accessToken,
    required String refreshToken,
    required Map<String, dynamic> user,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _currentUser = user;

    _prefs ??= await SharedPreferences.getInstance();
    await Future.wait([
      _prefs!.setString(keyAccessToken, accessToken),
      _prefs!.setString(keyRefreshToken, refreshToken),
      _prefs!.setString(keyUserData, jsonEncode(user)),
    ]);
    developer.log('AppData: login data saved ✓');
  }

  /// Update a single field in the stored user map (e.g. after profile edit).
  Future<void> updateUserField(String field, dynamic value) async {
    _currentUser ??= {};
    _currentUser![field] = value;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(keyUserData, jsonEncode(_currentUser));
  }

  /// Replace the entire user map (e.g. after a full profile save).
  Future<void> updateUser(Map<String, dynamic> user) async {
    _currentUser = user;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(keyUserData, jsonEncode(user));
    developer.log('AppData: user data updated ✓');
  }

  /// Save a new access token (called by ApiService after a token refresh).
  Future<void> saveAccessToken(String token) async {
    _accessToken = token;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(keyAccessToken, token);
    developer.log('AppData: access token refreshed ✓');
  }

  // ── Compatibility helpers (mirrors old AppData API) ───────────────────────

  /// Alias for [saveAccessToken]. Kept for backward compatibility.
  Future<void> setAuthToken(String token) => saveAccessToken(token);

  /// Clears only the access token from memory and prefs.
  Future<void> clearAuthToken() async {
    _accessToken = null;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(keyAccessToken);
    developer.log('AppData: access token cleared ✓');
  }

  /// Alias for [updateUser]. Kept for backward compatibility.
  Future<void> setCurrentUser(Map<String, dynamic> userData) async {
    _currentUser = userData;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(keyUserData, jsonEncode(userData));
    developer.log('AppData: current user set ✓');
  }

  /// Clears only the user data from memory and prefs.
  Future<void> clearCurrentUser() async {
    _currentUser = null;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(keyUserData);
    developer.log('AppData: current user cleared ✓');
  }

  /// Update a single field on the stored user map.
  Future<void> updateCurrentUserField(String field, dynamic value) async {
    _currentUser ??= {};
    _currentUser![field] = value;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(keyUserData, jsonEncode(_currentUser));
  }

  /// Update the profile picture URL in the stored user map.
  Future<void> updateProfilePicture(String pictureUrl) async {
    await updateCurrentUserField('photo_url', pictureUrl);
  }

  /// Returns true if [userId] matches the currently logged-in user's id.
  bool isCurrentUser(String userId) {
    final id = _currentUser?['id']?.toString();
    return id != null && id == userId;
  }

  /// Returns true if [email] matches the currently logged-in user's email.
  bool isCurrentUserByEmail(String email) {
    final stored = _currentUser?['email']?.toString().trim().toLowerCase();
    return stored != null && stored == email.trim().toLowerCase();
  }

  // ── Logout ───────────────────────────────────────────────────────────────

  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
    _isInitialized = false;

    _prefs ??= await SharedPreferences.getInstance();
    await Future.wait([
      _prefs!.remove(keyAccessToken),
      _prefs!.remove(keyRefreshToken),
      _prefs!.remove(keyUserData),
      // Also clear remember-me credentials if stored
      _prefs!.remove('email'),
      _prefs!.remove('password'),
      _prefs!.remove('rememberMe'),
    ]);
    developer.log('AppData: logout complete ✓');
  }

  // ── Profile completeness check ────────────────────────────────────────────
  /// Returns true when all required profile fields are present and non-empty.
  /// Field names match the login API response:
  ///   full_name, email, phone_number, gender, date_of_birth, address
  bool get isProfileComplete {
    if (_currentUser == null) return false;
    final required = [
      'full_name',
      'email',
      'phone_number',
      'gender',
      'date_of_birth',
      'address',
    ];
    for (final key in required) {
      final val = _currentUser![key]?.toString().trim() ?? '';
      if (val.isEmpty) {
        developer.log('Profile incomplete — missing: $key');
        return false;
      }
    }
    return true;
  }
}
