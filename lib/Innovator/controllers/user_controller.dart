import 'dart:async';

import 'package:get/get.dart';
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

// ── API base URLs ─────────────────────────────────────────────────────────────
/// New API server — handles current user profile & avatar uploads.
const String _newApiBase = 'http://182.93.94.220:8005';

/// Legacy API server — handles feed, followers, following, other users.
const String _legacyApiBase = 'http://182.93.94.210:3067';

class UserController extends GetxController {
  static UserController get to => Get.find();

  // ── Current user ────────────────────────────────────────────────────────────
  final Rx<String?> profilePicture = Rx<String?>(null);
  final Rx<String?> userName = Rx<String?>(null);
  RxInt profilePictureVersion = 0.obs;

  // ── Other users cache ───────────────────────────────────────────────────────
  final RxMap<String, String> _otherUsersProfilePictures =
      <String, String>{}.obs;
  final RxMap<String, int> _otherUsersPictureVersions = <String, int>{}.obs;
  final RxMap<String, String> _otherUsersNames = <String, String>{}.obs;

  // Cache metadata
  final RxMap<String, DateTime> _cacheTimestamps = <String, DateTime>{}.obs;
  final RxSet<String> _preloadedUsers = <String>{}.obs;

  // Cache configuration
  static const Duration cacheValidDuration = Duration(hours: 2);
  static const int maxCacheSize = 200;

  @override
  void onInit() {
    super.onInit();
    final user = AppData().currentUser;
    if (user != null) {
      // New API stores the avatar under 'photo_url'; fall back to legacy 'picture'
      profilePicture.value =
          user['photo_url']?.toString() ?? user['picture']?.toString();
      userName.value =
          user['full_name']?.toString() ?? user['name']?.toString();
    }
    _startCacheCleanup();
  }

  // ── Current user methods ────────────────────────────────────────────────────

  void updateProfilePicture(String newPath) {
    profilePicture.value = newPath;
    profilePictureVersion.value++;
    update();
  }

  void updateUserName(String? newName) {
    userName.value = newName;
  }

  /// Returns a fully-qualified URL for the **current user's** avatar.
  ///
  /// The new API (`_newApiBase`) serves the current user's avatar.
  /// If the stored path is already absolute it is returned as-is.
  String? getFullProfilePicturePath() {
    final pic = profilePicture.value;
    if (pic == null || pic.isEmpty) return null;

    // Already an absolute URL — return directly.
    if (pic.startsWith('http://') || pic.startsWith('https://')) return pic;

    // Relative path — prefix with the new API base.
    return '$_newApiBase${pic.startsWith('/') ? pic : '/$pic'}';
  }

  // ── Other users cache methods ───────────────────────────────────────────────

  /// Cache another user's profile picture + name with a timestamp.
  void cacheUserProfilePicture(
    String userId,
    String? pictureUrl,
    String? name,
  ) {
    if (userId.isEmpty) return;
    _manageCacheSize();

    if (pictureUrl != null && pictureUrl.isNotEmpty) {
      _otherUsersProfilePictures[userId] = pictureUrl;
      _otherUsersPictureVersions[userId] =
          DateTime.now().millisecondsSinceEpoch;
    }
    if (name != null && name.isNotEmpty) {
      _otherUsersNames[userId] = name;
    }
    _cacheTimestamps[userId] = DateTime.now();

    debugPrint('👤 Cached user: $userId (${name ?? 'no name'})');
  }

  /// Get cached profile picture path for another user (raw, may be relative).
  String? getOtherUserProfilePicture(String userId) {
    if (!_isCacheValid(userId)) return null;
    return _otherUsersProfilePictures[userId];
  }

  /// Get cached display name for another user.
  String? getOtherUserName(String userId) {
    if (!_isCacheValid(userId)) return null;
    return _otherUsersNames[userId];
  }

  /// Returns a fully-qualified, versioned URL for another user's avatar.
  ///
  /// Other users still come from the legacy API (`_legacyApiBase`).
  String? getOtherUserFullProfilePicturePath(String userId) {
    if (!_isCacheValid(userId)) return null;

    final picture = _otherUsersProfilePictures[userId];
    if (picture == null || picture.isEmpty) return null;

    final version = _otherUsersPictureVersions[userId] ?? 0;

    String formattedUrl = picture;
    if (!picture.startsWith('http://') && !picture.startsWith('https://')) {
      formattedUrl =
          '$_legacyApiBase${picture.startsWith('/') ? picture : '/$picture'}';
    }

    return '$formattedUrl?v=$version';
  }

  /// Update another user's cached picture (e.g. from a real-time event).
  void updateOtherUserProfilePicture(String userId, String? newPictureUrl) {
    if (newPictureUrl != null && newPictureUrl.isNotEmpty) {
      _otherUsersProfilePictures[userId] = newPictureUrl;
      _otherUsersPictureVersions[userId] =
          DateTime.now().millisecondsSinceEpoch;
      _cacheTimestamps[userId] = DateTime.now();
    } else {
      _removeUserFromCache(userId);
    }
    update();
  }

  /// Bulk-cache a list of user maps (call when fetching a users list).
  void bulkCacheUsers(List<Map<String, dynamic>> users) {
    debugPrint('👥 Bulk caching ${users.length} users');
    for (final user in users) {
      final userId = user['_id'] ?? user['id'];
      final pictureUrl = user['picture'];
      final name = user['name'];
      if (userId != null && userId.toString().isNotEmpty) {
        cacheUserProfilePicture(userId.toString(), pictureUrl, name);
      }
    }
  }

  /// Preload images for a set of visible user IDs.
  Future<void> preloadVisibleUsers(
    List<String> userIds,
    BuildContext context,
  ) async {
    final toPreload =
        userIds
            .where((id) => !_preloadedUsers.contains(id) && _isCacheValid(id))
            .toList();

    if (toPreload.isEmpty) return;
    debugPrint('🖼 Preloading ${toPreload.length} user images');

    for (final userId in toPreload.take(10)) {
      final imageUrl = getOtherUserFullProfilePicturePath(userId);
      if (imageUrl != null) {
        try {
          await precacheImage(CachedNetworkImageProvider(imageUrl), context);
          _preloadedUsers.add(userId);
        } catch (e) {
          debugPrint('⚠ Failed to preload image for user $userId: $e');
        }
      }
    }
  }

  /// Returns true if cached data for [userId] exists and has not expired.
  bool isUserCached(String userId) {
    return _isCacheValid(userId) &&
        (_otherUsersProfilePictures.containsKey(userId) ||
            _otherUsersNames.containsKey(userId));
  }

  /// Wipe the entire other-users cache (call on logout or memory pressure).
  void clearOtherUsersCache() {
    _otherUsersProfilePictures.clear();
    _otherUsersPictureVersions.clear();
    _otherUsersNames.clear();
    _cacheTimestamps.clear();
    _preloadedUsers.clear();
    debugPrint('🧹 Cleared all user cache');
  }

  /// Cache statistics for debugging.
  Map<String, dynamic> getCacheStats() => {
    'totalCached': _cacheTimestamps.length,
    'withPictures': _otherUsersProfilePictures.length,
    'withNames': _otherUsersNames.length,
    'preloaded': _preloadedUsers.length,
    'maxSize': maxCacheSize,
    'validDurationHours': cacheValidDuration.inHours,
  };

  // ── Private helpers ─────────────────────────────────────────────────────────

  bool _isCacheValid(String userId) {
    final timestamp = _cacheTimestamps[userId];
    if (timestamp == null) return false;
    final isValid = DateTime.now().difference(timestamp) < cacheValidDuration;
    if (!isValid) _removeUserFromCache(userId);
    return isValid;
  }

  void _removeUserFromCache(String userId) {
    _otherUsersProfilePictures.remove(userId);
    _otherUsersPictureVersions.remove(userId);
    _otherUsersNames.remove(userId);
    _cacheTimestamps.remove(userId);
    _preloadedUsers.remove(userId);
  }

  void _manageCacheSize() {
    if (_cacheTimestamps.length <= maxCacheSize) return;
    final oldest =
        _cacheTimestamps.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    for (final entry in oldest.take(20)) {
      _removeUserFromCache(entry.key);
    }
    debugPrint('🧹 Cache trimmed: removed 20 oldest entries');
  }

  void _startCacheCleanup() {
    Timer.periodic(const Duration(minutes: 30), (_) => _cleanExpiredCache());
  }

  void _cleanExpiredCache() {
    final now = DateTime.now();
    final expired =
        _cacheTimestamps.entries
            .where((e) => now.difference(e.value) > cacheValidDuration)
            .map((e) => e.key)
            .toList();
    for (final id in expired) {
      _removeUserFromCache(id);
    }
    if (expired.isNotEmpty) {
      debugPrint('🧹 Expired ${expired.length} cache entries');
    }
  }
}
