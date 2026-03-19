import 'dart:async';

import 'package:get/get.dart';
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class UserController extends GetxController {
  static UserController get to => Get.find();

  // Current user data
  final Rx<String?> profilePicture = Rx<String?>(null);
  final Rx<String?> userName = Rx<String?>(null);
  RxInt profilePictureVersion = 0.obs;

  // OTHER USERS' PROFILE PICTURES CACHE
  final RxMap<String, String> _otherUsersProfilePictures =
      <String, String>{}.obs;
  final RxMap<String, int> _otherUsersPictureVersions = <String, int>{}.obs;
  final RxMap<String, String> _otherUsersNames = <String, String>{}.obs;

  // NEW: Cache metadata for better management
  final RxMap<String, DateTime> _cacheTimestamps = <String, DateTime>{}.obs;
  final RxSet<String> _preloadedUsers = <String>{}.obs;

  // NEW: Cache configuration
  static const Duration cacheValidDuration = Duration(hours: 2);
  static const int maxCacheSize = 200; // Maximum number of users to cache

  @override
  void onInit() {
    super.onInit();
    // Initialize from AppData
    final user = AppData().currentUser;
    if (user != null) {
      profilePicture.value = user['picture'];
      userName.value = user['name'];
    }

    // NEW: Start periodic cache cleanup
    _startCacheCleanup();
  }

  // ========== CURRENT USER METHODS ==========
  void updateProfilePicture(String newPath) {
    profilePicture.value = newPath;
    profilePictureVersion.value++;
    update();
  }

  void updateUserName(String? newName) {
    userName.value = newName;
    if (AppData().currentUser != null) {
      //AppData().updateCurrentUserField('name', newName);
    }
  }

  String? getFullProfilePicturePath() {
    return profilePicture.value != null
        ? 'http://182.93.94.210:3067${profilePicture.value}'
        : null;
  }

  // ========== ENHANCED OTHER USERS METHODS ==========

  /// Cache other user's profile picture with timestamp
  void cacheUserProfilePicture(
    String userId,
    String? pictureUrl,
    String? name,
  ) {
    if (userId.isEmpty) return;

    // ENHANCED: Manage cache size
    _manageCacheSize();

    if (pictureUrl != null && pictureUrl.isNotEmpty) {
      _otherUsersProfilePictures[userId] = pictureUrl;
      _otherUsersPictureVersions[userId] =
          DateTime.now().millisecondsSinceEpoch;
    }

    if (name != null && name.isNotEmpty) {
      _otherUsersNames[userId] = name;
    }

    // NEW: Record cache timestamp
    _cacheTimestamps[userId] = DateTime.now();

    debugPrint('👤 Cached user: $userId (${name ?? 'no name'})');
  }

  /// Get cached profile picture for other user
  String? getOtherUserProfilePicture(String userId) {
    if (!_isCacheValid(userId)) {
      return null;
    }
    return _otherUsersProfilePictures[userId];
  }

  /// Get cached name for other user
  String? getOtherUserName(String userId) {
    if (!_isCacheValid(userId)) {
      return null;
    }
    return _otherUsersNames[userId];
  }

  /// Get full profile picture URL for other user with version
  String? getOtherUserFullProfilePicturePath(String userId) {
    if (!_isCacheValid(userId)) {
      return null;
    }

    final picture = _otherUsersProfilePictures[userId];
    if (picture == null || picture.isEmpty) return null;

    final version = _otherUsersPictureVersions[userId] ?? 0;

    // Format URL properly
    String formattedUrl = picture;
    if (!picture.startsWith('http')) {
      formattedUrl =
          'http://182.93.94.210:3067${picture.startsWith('/') ? picture : '/$picture'}';
    }

    return '$formattedUrl?v=$version';
  }

  /// Update other user's profile picture (when you get real-time updates)
  void updateOtherUserProfilePicture(String userId, String? newPictureUrl) {
    if (newPictureUrl != null && newPictureUrl.isNotEmpty) {
      _otherUsersProfilePictures[userId] = newPictureUrl;
      _otherUsersPictureVersions[userId] =
          DateTime.now().millisecondsSinceEpoch;
      _cacheTimestamps[userId] = DateTime.now();
    } else {
      _removeUserFromCache(userId);
    }
    update(); // Trigger UI update
  }

  /// Bulk cache users data (call this when you fetch users list)
  void bulkCacheUsers(List<Map<String, dynamic>> users) {
    debugPrint('👥 Bulk caching ${users.length} users');

    for (var user in users) {
      final userId = user['_id'] ?? user['id'];
      final pictureUrl = user['picture'];
      final name = user['name'];

      if (userId != null && userId.toString().isNotEmpty) {
        cacheUserProfilePicture(userId.toString(), pictureUrl, name);
      }
    }
  }

  /// NEW: Preload images for visible users
  Future<void> preloadVisibleUsers(
    List<String> userIds,
    BuildContext context,
  ) async {
    final usersToPreload =
        userIds
            .where((id) => !_preloadedUsers.contains(id) && _isCacheValid(id))
            .toList();

    if (usersToPreload.isEmpty) return;

    debugPrint(' Preloading ${usersToPreload.length} user images');

    for (String userId in usersToPreload.take(10)) {
      // Limit concurrent preloads
      final imageUrl = getOtherUserFullProfilePicturePath(userId);
      if (imageUrl != null) {
        try {
          await precacheImage(CachedNetworkImageProvider(imageUrl), context);
          _preloadedUsers.add(userId);
        } catch (e) {
          debugPrint(' Failed to preload image for user $userId: $e');
        }
      }
    }
  }

  /// NEW: Check if cache is valid and not expired
  bool _isCacheValid(String userId) {
    final timestamp = _cacheTimestamps[userId];
    if (timestamp == null) return false;

    final now = DateTime.now();
    final isValid = now.difference(timestamp) < cacheValidDuration;

    if (!isValid) {
      _removeUserFromCache(userId);
    }

    return isValid;
  }

  /// NEW: Remove user from all caches
  void _removeUserFromCache(String userId) {
    _otherUsersProfilePictures.remove(userId);
    _otherUsersPictureVersions.remove(userId);
    _otherUsersNames.remove(userId);
    _cacheTimestamps.remove(userId);
    _preloadedUsers.remove(userId);
  }

  /// NEW: Manage cache size to prevent memory issues
  void _manageCacheSize() {
    if (_cacheTimestamps.length <= maxCacheSize) return;

    // Sort by timestamp and remove oldest entries
    final sortedEntries =
        _cacheTimestamps.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));

    final entriesToRemove = sortedEntries.take(20); // Remove 20 oldest

    for (final entry in entriesToRemove) {
      _removeUserFromCache(entry.key);
    }

    debugPrint(
      '🧹 Cleaned cache: removed ${entriesToRemove.length} old entries',
    );
  }

  /// NEW: Periodic cache cleanup
  void _startCacheCleanup() {
    Timer.periodic(Duration(minutes: 30), (timer) {
      _cleanExpiredCache();
    });
  }

  /// NEW: Clean expired cache entries
  void _cleanExpiredCache() {
    final now = DateTime.now();
    final expiredUsers = <String>[];

    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > cacheValidDuration) {
        expiredUsers.add(entry.key);
      }
    }

    for (final userId in expiredUsers) {
      _removeUserFromCache(userId);
    }

    if (expiredUsers.isNotEmpty) {
      debugPrint('🧹 Cleaned ${expiredUsers.length} expired cache entries');
    }
  }

  /// Check if user data is cached and valid
  bool isUserCached(String userId) {
    return _isCacheValid(userId) &&
        (_otherUsersProfilePictures.containsKey(userId) ||
            _otherUsersNames.containsKey(userId));
  }

  /// Clear cache for memory management
  void clearOtherUsersCache() {
    _otherUsersProfilePictures.clear();
    _otherUsersPictureVersions.clear();
    _otherUsersNames.clear();
    _cacheTimestamps.clear();
    _preloadedUsers.clear();
    debugPrint('🧹 Cleared all user cache');
  }

  /// NEW: Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'totalCached': _cacheTimestamps.length,
      'withPictures': _otherUsersProfilePictures.length,
      'withNames': _otherUsersNames.length,
      'preloaded': _preloadedUsers.length,
      'maxSize': maxCacheSize,
      'validDuration': cacheValidDuration.inHours,
    };
  }
}
