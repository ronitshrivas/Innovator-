import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/Authorization/Login.dart';
import 'package:innovator/Innovator/controllers/user_controller.dart';
import 'package:innovator/ecommerce/screens/Shop/Shop_Page.dart';
import 'package:innovator/KMS/core/constants/service/auth_wrapper.dart';
import 'package:innovator/Innovator/screens/Eliza_ChatBot/Elizahomescreen.dart';
import 'package:innovator/Innovator/screens/Events/Events.dart';
import 'package:innovator/Innovator/screens/F&Q/F&Qscreen.dart';
import 'package:innovator/Innovator/screens/Privacy_Policy/privacy_screen.dart';
import 'package:innovator/Innovator/screens/Profile/profile_page.dart';
import 'package:innovator/Innovator/screens/Report/Report_screen.dart';
import 'package:innovator/Innovator/screens/Settings/settings.dart';
import 'package:innovator/Innovator/utils/Drawer/drawer_cache_manager.dart';
import 'package:innovator/elearning/screens/course_list_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ─────────────────────────────────────────────────────────────────────────────
// InstantCache — synchronous cache with change notifications
// ─────────────────────────────────────────────────────────────────────────────
class InstantCache {
  static Map<String, dynamic>? _data;
  static bool _isInitialized = false;

  /// Bump this whenever data changes so open drawers can react instantly.
  static final ValueNotifier<int> version = ValueNotifier(0);

  static void init() {
    if (!_isInitialized) {
      _reloadFromAppData();
      _isInitialized = true;
    }
  }

  static void _reloadFromAppData() {
    final userData = AppData().currentUser;
    if (userData == null) return;

    final photoUrl = userData['photo_url']?.toString() ?? '';
    final profileAvatar =
        (userData['profile'] as Map<String, dynamic>?)?['avatar']?.toString() ??
        '';
    final legacyPicture = userData['picture']?.toString() ?? '';

    _data = {
      'name':
          userData['full_name']?.toString()?.isNotEmpty == true
              ? userData['full_name'].toString()
              : userData['username']?.toString()?.isNotEmpty == true
              ? userData['username'].toString()
              : userData['name']?.toString() ?? 'User',
      'email': userData['email']?.toString() ?? '',
      'picture':
          photoUrl.isNotEmpty
              ? photoUrl
              : profileAvatar.isNotEmpty
              ? profileAvatar
              : legacyPicture.isNotEmpty
              ? legacyPicture
              : null,
    };
  }

  /// Get data synchronously — never null.
  static Map<String, dynamic> get() {
    init();
    return _data ?? {'name': 'User', 'email': '', 'picture': null};
  }

  /// Called after a successful avatar upload anywhere in the app.
  /// Re-reads AppData and notifies all open drawer instances.
  static void invalidate() {
    _isInitialized = false;
    _reloadFromAppData();
    _isInitialized = true;
    version.value++;
  }

  /// Manual update (e.g. from network fetch).
  static void update(Map<String, dynamic> newData) {
    _data = Map<String, dynamic>.from(newData);
    version.value++;
  }

  static void clear() {
    _data = null;
    _isInitialized = false;
    version.value++;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// InstantDrawerService
// ─────────────────────────────────────────────────────────────────────────────
class InstantDrawerService {
  static void show(BuildContext context) {
    InstantCache.init();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 120),
        reverseTransitionDuration: const Duration(milliseconds: 80),
        pageBuilder: (context, animation, _) {
          return _InstantDrawerOverlay(
            animation: animation,
            drawerWidth: math.min(
              MediaQuery.of(context).size.width * 0.8,
              300.0,
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InstantDrawerOverlay
// ─────────────────────────────────────────────────────────────────────────────
class _InstantDrawerOverlay extends StatelessWidget {
  final Animation<double> animation;
  final double drawerWidth;

  const _InstantDrawerOverlay({
    required this.animation,
    required this.drawerWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        onHorizontalDragUpdate: (details) {
          if (details.delta.dx < -8) Navigator.of(context).pop();
        },
        child: Stack(
          children: [
            // Backdrop
            AnimatedBuilder(
              animation: animation,
              builder:
                  (context, _) => Container(
                    color: Colors.black.withOpacity(0.5 * animation.value),
                  ),
            ),
            // Drawer panel
            AnimatedBuilder(
              animation: animation,
              builder:
                  (context, _) => Transform.translate(
                    offset: Offset(-drawerWidth * (1 - animation.value), 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: drawerWidth,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(28),
                            bottomRight: Radius.circular(28),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(8),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const TrueInstantDrawer(),
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TrueInstantDrawer
// ─────────────────────────────────────────────────────────────────────────────
class TrueInstantDrawer extends StatefulWidget {
  const TrueInstantDrawer({super.key});

  @override
  State<TrueInstantDrawer> createState() => _TrueInstantDrawerState();
}

class _TrueInstantDrawerState extends State<TrueInstantDrawer> {
  late String _userName;
  late String _userEmail;
  late String? _userPicture;
  bool _isRefreshing = false;
  bool _KMSEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadDataSynchronously();
    _KMSEnabled = false;

    // React to avatar/profile changes from anywhere in the app
    InstantCache.version.addListener(_onCacheUpdated);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _refreshInBackground();
    });
  }

  @override
  void dispose() {
    InstantCache.version.removeListener(_onCacheUpdated);
    super.dispose();
  }

  // ── Cache listener ──────────────────────────────────────────────────────────

  void _onCacheUpdated() {
    if (!mounted) return;
    final data = InstantCache.get();

    // Evict old URL from image cache before applying new one
    if (_userPicture != null && _userPicture!.isNotEmpty) {
      final oldUrl =
          _userPicture!.startsWith('http')
              ? _userPicture!
              : 'http://182.93.94.220:8005$_userPicture';
      imageCache.evict(CachedNetworkImageProvider(oldUrl));
    }

    setState(() {
      _userName = data['name'] ?? 'User';
      _userEmail = data['email'] ?? '';
      _userPicture = data['picture'];
    });
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  void _loadDataSynchronously() {
    final appData = AppData();
    final userData = appData.currentUser;

    _userName =
        userData?['full_name']?.toString()?.isNotEmpty == true
            ? userData!['full_name'].toString()
            : userData?['username']?.toString()?.isNotEmpty == true
            ? userData!['username'].toString()
            : userData?['name']?.toString() ?? 'User';

    _userEmail = userData?['email']?.toString() ?? '';

    final photoUrl = userData?['photo_url']?.toString() ?? '';
    final profileAvatar =
        (userData?['profile'] as Map<String, dynamic>?)?['avatar']
            ?.toString() ??
        '';
    final legacyPicture = userData?['picture']?.toString() ?? '';

    _userPicture =
        photoUrl.isNotEmpty
            ? photoUrl
            : profileAvatar.isNotEmpty
            ? profileAvatar
            : legacyPicture.isNotEmpty
            ? legacyPicture
            : null;

    // Seed cache so version listener has fresh data
    // InstantCache.update({
    //   'name': _userName,
    //   'email': _userEmail,
    //   'picture': _userPicture,
    // });
  }

  void _refreshInBackground() async {
    if (mounted) setState(() => _isRefreshing = true);
    try {
      //setState(() => _isRefreshing = true);

      // Layer 1: Hive persistent cache
      final persistentCache = await DrawerProfileCache.getCachedProfile();
      if (persistentCache != null && mounted) {
        final data = {
          'name': persistentCache.name,
          'email': persistentCache.email,
          'picture': persistentCache.picturePath,
        };
        _updateDisplayData(data);
        InstantCache.update(data);
      }

      // Layer 2: Network
      await _fetchFromNetwork();
    } catch (e) {
      developer.log('Background refresh failed: $e');
    } finally {
      if (mounted && _isRefreshing) setState(() => _isRefreshing = false);
    }
  }

  void _updateDisplayData(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      _userName = data['name'] ?? 'User';
      _userEmail = data['email'] ?? '';
      _userPicture = data['picture'];
    });
  }

  Future<void> _fetchFromNetwork() async {
    try {
      final authToken = AppData().accessToken;
      if (authToken == null) return;

      final response = await http
          .get(
            Uri.parse('http://182.93.94.220:8005/api/users/me/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && mounted) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;

        // Normalize new API shape → flat drawer data
        final profile = responseData['profile'] as Map<String, dynamic>? ?? {};

        final fullName = responseData['full_name']?.toString() ?? '';
        final username = responseData['username']?.toString() ?? '';
        final normalizedName =
            fullName.isNotEmpty
                ? fullName
                : username.isNotEmpty
                ? username
                : 'User';

        final avatarPath = profile['avatar']?.toString() ?? '';
        final photoUrl = responseData['photo_url']?.toString() ?? '';
        final normalizedPicture =
            photoUrl.isNotEmpty
                ? photoUrl
                : avatarPath.isNotEmpty
                ? avatarPath
                : null;

        final drawerData = {
          'name': normalizedName,
          'email': responseData['email']?.toString() ?? '',
          'picture': normalizedPicture,
        };

        // Update all layers
        InstantCache.update(drawerData);
        await AppData().updateUser(responseData);
        await DrawerProfileCache.cacheProfile(
          userId: responseData['id']?.toString() ?? '',
          name: normalizedName,
          email: responseData['email']?.toString() ?? '',
          picturePath: normalizedPicture,
        );

        _updateDisplayData(drawerData);
      }
    } catch (e) {
      developer.log('Network fetch failed: $e');
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => UserProfileScreen(
                        userId: AppData().currentUserId ?? '',
                      ),
                ),
              );
            },
            child: _buildHeader(),
          ),
          Expanded(child: _buildMenu()),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromRGBO(244, 135, 6, 1),
            Color.fromRGBO(244, 135, 6, 0.9),
            Color.fromRGBO(244, 135, 6, 1),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar with refresh indicator
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withAlpha(30),
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: _buildProfileImage(),
                  ),
                  if (_isRefreshing)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Color.fromRGBO(244, 135, 6, 1),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              const Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              _isRefreshing && _userName == 'User'
                  ? const SizedBox(
                    width: 100,
                    height: 20,
                    child: LinearProgressIndicator(
                      color: Colors.white70,
                      backgroundColor: Colors.white24,
                    ),
                  )
                  : Text(
                    _userName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter Thin',
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

              if (_userEmail.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    _userEmail,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 5),

              // KMS toggle
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _KMSEnabled
                          ? Icons.notifications_active
                          : Icons.notifications_off,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'KMS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _KMSEnabled,
                      onChanged: (value) {
                        setState(() => _KMSEnabled = value);
                        if (value) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AuthWrapper()),
                          );
                        }
                      },
                      inactiveTrackColor: Colors.white.withAlpha(20),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Profile image ───────────────────────────────────────────────────────────

  Widget _buildProfileImage() {
    const baseUrl = 'http://182.93.94.220:8005';
    String? resolvedUrl;
    if (_userPicture != null && _userPicture!.isNotEmpty) {
      resolvedUrl =
          _userPicture!.startsWith('http')
              ? _userPicture!
              : '$baseUrl$_userPicture';
    }
    final versionedUrl =
        resolvedUrl != null
            ? '$resolvedUrl?v=${InstantCache.version.value}'
            : null;

    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withAlpha(20),
      ),
      child:
          _isRefreshing && versionedUrl == null
              ? const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              )
              : versionedUrl != null
              ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: versionedUrl,
                  fit: BoxFit.cover,
                  width: 70,
                  height: 70,
                  placeholder:
                      (_, __) => const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                  errorWidget:
                      (_, __, ___) => const Icon(
                        Icons.person,
                        size: 35,
                        color: Colors.white,
                      ),
                ),
              )
              : const Icon(Icons.person, size: 35, color: Colors.white),
    );
  }

  // ── Menu ────────────────────────────────────────────────────────────────────

  Widget _buildMenu() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          _QuickMenuItem(
            icon: Icons.person_rounded,
            title: 'Profile',
            onTap: _goToProfile,
          ),
          _QuickMenuItem(
            icon: Icons.psychology_rounded,
            title: 'Eliza ChatBot',
            onTap: _goToEliza,
          ),
          _QuickMenuItem(
            icon: Icons.menu_book_rounded,
            title: 'E-Learning',
            onTap: _gotoelearning,
          ),
          _QuickMenuItem(
            icon: Icons.shop,
            title: 'Shop',
            onTap: _gotoecommerce,
          ),
          _QuickMenuItem(
            icon: Icons.event_available,
            title: 'Events',
            onTap: _goToEvents,
          ),
          _QuickMenuItem(
            icon: Icons.report_rounded,
            title: 'Reports',
            onTap: _goToReports,
          ),
          _QuickMenuItem(
            icon: Icons.privacy_tip_rounded,
            title: 'Privacy & Policy',
            onTap: _goToPrivacy,
          ),
          _QuickMenuItem(
            icon: Icons.settings,
            title: 'Settings',
            onTap: _goToSettings,
          ),
          _QuickMenuItem(
            icon: Icons.help_rounded,
            title: 'FAQ',
            onTap: _goToFAQ,
          ),
          const SizedBox(height: 20),
          _buildDivider(),
          _QuickMenuItem(
            icon: Icons.logout_rounded,
            title: 'Logout',
            onTap: _showLogout,
            isLogout: true,
          ),
          const SizedBox(height: 20),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.grey.shade300,
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(244, 135, 6, 1).withAlpha(10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.rocket_launch,
              color: Color.fromRGBO(244, 135, 6, 1),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Innovator App v:1.0.44',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              Text(
                'Pvt Ltd',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _goToProfile() => _quickNavigate(
    () => ProviderScope(
      child: UserProfileScreen(userId: AppData().currentUserId ?? ''),
    ),
  );
  void _goToEliza() => _quickNavigate(() => ElizaChatScreen());
  void _goToEvents() => _quickNavigate(() => EventsHomePage());
  void _gotoelearning() => _quickNavigate(() => const CourseListScreen());
  void _gotoecommerce() => _quickNavigate(() => const ShopPage());
  void _goToReports() => _quickNavigate(() => ReportsScreen());
  void _goToPrivacy() =>
      _quickNavigate(() => const ProviderScope(child: PrivacyPolicy()));
  void _goToSettings() => _quickNavigate(() => const SettingsScreen());
  void _goToFAQ() => _quickNavigate(() => const FAQScreen());

  void _quickNavigate(Widget Function() builder) {
    Navigator.of(context).pop();
    Navigator.push(context, MaterialPageRoute(builder: (_) => builder()));
  }

  // ── Logout ──────────────────────────────────────────────────────────────────

  void _showLogout() {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Logout Confirmation'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  AppData().clearAuthToken();
                  InstantCache.clear();
                  Navigator.of(dialogContext).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _performLogout(BuildContext dialogContext) async {
    try {
      developer.log('🚪 Starting logout...');
      Navigator.of(dialogContext).pop();
      AppData().clearAuthToken();

      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      _showGlobalLoading(true);
      await _executeOptimizedLogout();
      await Future.delayed(const Duration(milliseconds: 500));
      _showGlobalLoading(false);

      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
          settings: const RouteSettings(name: '/login'),
        ),
        (route) => false,
      );
    } catch (e) {
      developer.log('Error during logout: $e');
      _showGlobalLoading(false);
      try {
        await Future.delayed(const Duration(milliseconds: 300));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()),
          (route) => false,
        );
      } catch (navError) {
        developer.log('Emergency navigation failed: $navError');
      }
    }
  }

  void _showGlobalLoading(bool show) {
    if (show) {
      showDialog(
        context: navigatorKey.currentContext ?? context,
        barrierDismissible: false,
        builder:
            (context) => const Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Color.fromRGBO(244, 135, 6, 1),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Logging out...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
      );
    } else {
      if (navigatorKey.currentState?.canPop() ?? false) {
        navigatorKey.currentState?.pop();
      }
    }
  }

  Future<void> _executeOptimizedLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
    } catch (e) {
      developer.log('Firebase signout error: $e');
    }

    try {
      if (Get.isRegistered<UserController>()) {
        Get.delete<UserController>(force: true);
      }
    } catch (e) {
      developer.log('UserController clear error: $e');
    }

    try {
      await DrawerProfileCache.clearCache();
      await DefaultCacheManager().emptyCache();
    } catch (e) {
      developer.log('Cache clear error: $e');
    }

    InstantCache.clear();
    developer.log('Logout complete');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuickMenuItem
// ─────────────────────────────────────────────────────────────────────────────
class _QuickMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isLogout;

  const _QuickMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isLogout = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient:
                isLogout
                    ? LinearGradient(
                      colors: [
                        Colors.red.withAlpha(10),
                        Colors.red.withAlpha(20),
                      ],
                    )
                    : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      isLogout
                          ? Colors.red.withAlpha(10)
                          : const Color.fromRGBO(244, 135, 6, 1).withAlpha(10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color:
                      isLogout
                          ? Colors.red
                          : const Color.fromRGBO(244, 135, 6, 1),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isLogout ? Colors.red : Colors.grey.shade800,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Public interface & compatibility aliases
// ─────────────────────────────────────────────────────────────────────────────
class SmoothDrawerService {
  static void showLeftDrawer(BuildContext context) {
    InstantDrawerService.show(context);
  }
}

class CustomDrawer extends TrueInstantDrawer {
  const CustomDrawer({super.key});
}

class OptimizedCustomDrawer extends TrueInstantDrawer {
  const OptimizedCustomDrawer({super.key});
}

class ZeroLagDrawer extends TrueInstantDrawer {
  const ZeroLagDrawer({super.key});
}
