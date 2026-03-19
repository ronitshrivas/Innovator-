import 'dart:developer' as developer;
import 'dart:math' as math;
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
import 'package:innovator/KMS/core/constants/service/auth_wrapper.dart';
import 'package:innovator/KMS/screens/auth/login_screen.dart';
import 'package:innovator/KMS/screens/auth/signup_screen.dart';
import 'package:innovator/main.dart';
import 'package:innovator/Innovator/screens/Eliza_ChatBot/Elizahomescreen.dart';
import 'package:innovator/Innovator/screens/Events/Events.dart';
import 'package:innovator/Innovator/screens/F&Q/F&Qscreen.dart';
import 'package:innovator/Innovator/screens/Privacy_Policy/privacy_screen.dart';
import 'package:innovator/Innovator/screens/Profile/profile_page.dart';
import 'package:innovator/Innovator/screens/Report/Report_screen.dart';
import 'package:innovator/Innovator/screens/Settings/settings.dart';
import 'package:innovator/Innovator/utils/Drawer/drawer_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Synchronous-only cache for instant access
class InstantCache {
  static Map<String, dynamic>? _data;
  static bool _isInitialized = false;

  // Initialize with current AppData - called once at app start
  static void init() {
    if (!_isInitialized) {
      final appData = AppData().currentUser;
      if (appData != null) {
        _data = Map<String, dynamic>.from(appData);
      }
      _isInitialized = true;
    }
  }

  // Get data synchronously (never null - returns default if empty)
  static Map<String, dynamic> get() {
    init(); // Ensure initialized
    return _data ?? {'name': 'User', 'email': '', 'picture': null};
  }

  static void update(Map<String, dynamic> newData) {
    _data = Map<String, dynamic>.from(newData);
  }

  static void clear() {
    _data = null;
    _isInitialized = false;
  }
}

// INSTANT drawer service - zero async operations
class InstantDrawerService {
  static void show(BuildContext context) {
    // Pre-initialize cache before showing drawer
    InstantCache.init();

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 120), // Even faster
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
            // Drawer
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

// Truly instant drawer - no async operations in initState or build
class TrueInstantDrawer extends StatefulWidget {
  const TrueInstantDrawer({super.key});

  @override
  State<TrueInstantDrawer> createState() => _TrueInstantDrawerState();
}

class _TrueInstantDrawerState extends State<TrueInstantDrawer> {
  // Display data - populated synchronously
  late String _userName;
  late String _userEmail;
  late String? _userPicture;
  bool _isRefreshing = false;
  bool _KMSEnabled = false; // Move here and initialize to false

  @override
  void initState() {
    super.initState();
    // CRITICAL: Only synchronous operations here
    _loadDataSynchronously();
    _KMSEnabled = false; // Explicitly set to false on init

    // Start background refresh AFTER drawer is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshInBackground();
    });
  }

  void _loadDataSynchronously() {
    // Get cached data instantly - never blocks
    final data = InstantCache.get();
    _userName = data['name'] ?? 'User';
    _userEmail = data['email'] ?? '';
    _userPicture = data['picture'];
  }

  void _refreshInBackground() async {
    // This runs AFTER the drawer is already open
    try {
      setState(() => _isRefreshing = true);

      // Try persistent cache first
      final persistentCache = await DrawerProfileCache.getCachedProfile();
      if (persistentCache != null && mounted) {
        final data = {
          'name': persistentCache.name,
          'email': persistentCache.email,
          'picture': persistentCache.picturePath,
        };
        _updateData(data);
        InstantCache.update(data);
      }

      // Then try network
      await _fetchFromNetwork();
    } catch (e) {
      developer.log('Background refresh failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _updateData(Map<String, dynamic> data) {
    if (mounted) {
      setState(() {
        _userName = data['name'] ?? 'User';
        _userEmail = data['email'] ?? '';
        _userPicture = data['picture'];
      });
    }
  }

  Future<void> _fetchFromNetwork() async {
    try {
      final authToken = AppData().accessToken;
      if (authToken == null) return;

      final response = await http
          .get(
            Uri.parse('http://182.93.94.210:3067/api/v1/user-profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && mounted) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 200 && responseData['data'] != null) {
          final userData = responseData['data'];

          // Update all storage
          InstantCache.update(userData);
          AppData().updateUser(userData);
          await DrawerProfileCache.cacheProfile(
            userId: userData['_id'] ?? '',
            name: userData['name'] ?? '',
            email: userData['email'] ?? '',
            picturePath: userData['picture'],
          );

          _updateData(userData);
        }
      }
    } catch (e) {
      developer.log('Network fetch failed: $e');
    }
  }

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
                      (context) => UserProfileScreen(
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

  //bool _KMSEnabled = false;

  Widget _buildHeader() {
    return Container(
      // height: MediaQuery.of(context).size.height * 0.34,
      // width: MediaQuery.of(context).size.width * 0.68,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEB6B46), Color(0xFFFF8A65), Color(0xFFEB6B46)],
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
              // Profile picture
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
                  // Refresh indicator
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
                            color: Color(0xFFEB6B46),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Welcome text
              const Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),

              Text(
                _userName,
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

              // Email
              if (_userEmail.isNotEmpty) ...[
                Container(
                  padding: EdgeInsets.only(
                    right: 10,
                    left: 10,
                    top: 0,
                    bottom: 0,
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                // decoration: BoxDecoration(
                //   color: Colors.white.withAlpha(15),
                //   borderRadius: BorderRadius.circular(20),
                //   //border: Border.all(color: Colors.white.withAlpha(30)),
                // ),
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
                      // activeColor: Colors.white,
                      //activeTrackColor: Colors.green,
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

  Widget _buildProfileImage() {
    const baseUrl = 'http://182.93.94.210:3067';

    // NO HERO WIDGET - Simple Container to avoid conflicts
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withAlpha(20),
        image:
            _userPicture != null && _userPicture!.isNotEmpty
                ? DecorationImage(
                  image: CachedNetworkImageProvider('$baseUrl$_userPicture'),
                  fit: BoxFit.cover,
                  onError: (exception, stackTrace) {
                    // Handle error silently
                  },
                )
                : null,
      ),
      child:
          _userPicture == null || _userPicture!.isEmpty
              ? const Icon(Icons.person, size: 35, color: Colors.white)
              : null,
    );
  }

  Widget _buildMenu() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          // _QuickMenuItem(icon: Icons.app_blocking_sharp, title: 'KMS', onTap: (){
          //                     showDialog(
          //   context: context,
          //   builder: (dialogContext) => AlertDialog(
          //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          //     backgroundColor: Colors.white,
          //     title: const Text(
          //       '🚀 Coming Soon',
          //       style: TextStyle(
          //         fontSize: 20,
          //         fontWeight: FontWeight.bold,
          //         color: Color(0xFFEB6B46),
          //       ),
          //       textAlign: TextAlign.center,
          //     ),
          //     content: Column(
          //       mainAxisSize: MainAxisSize.min,
          //       children: [
          //         Container(
          //           padding: const EdgeInsets.all(20),
          //           decoration: BoxDecoration(
          //             gradient: const LinearGradient(
          //               colors: [Color(0xFFEB6B46), Color(0xFFFF8A65)],
          //             ),
          //             borderRadius: BorderRadius.circular(15),
          //           ),
          //           child: const Text(
          //             '📊',
          //             style: TextStyle(fontSize: 60),
          //             textAlign: TextAlign.center,
          //           ),
          //         ),
          //         const SizedBox(height: 20),
          //         const Text(
          //           'Knowledge Management System',
          //           style: TextStyle(
          //             fontSize: 16,
          //             fontWeight: FontWeight.w600,
          //             color: Colors.grey,
          //           ),
          //           textAlign: TextAlign.center,
          //         ),
          //         const SizedBox(height: 15),
          //         Container(
          //           padding: const EdgeInsets.all(12),
          //           decoration: BoxDecoration(
          //             color: Colors.blue.withAlpha(10),
          //             borderRadius: BorderRadius.circular(10),
          //             border: Border.all(
          //               color: Colors.blue.withAlpha(30),
          //               width: 1,
          //             ),
          //           ),
          //           child: const Text(
          //             '✨ We\'re working on something amazing! The KMS feature will help you manage and organize knowledge efficiently.\n\n💡 Stay tuned for updates!',
          //             style: TextStyle(
          //               fontSize: 14,
          //               color: Colors.black87,
          //               height: 1.5,
          //             ),
          //             textAlign: TextAlign.center,
          //           ),
          //         ),
          //         const SizedBox(height: 15),
          //         Row(
          //           mainAxisAlignment: MainAxisAlignment.center,
          //           children: [
          //             Container(
          //               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          //               decoration: BoxDecoration(
          //                 color: Colors.amber.withAlpha(20),
          //                 borderRadius: BorderRadius.circular(20),
          //               ),
          //               child: const Row(
          //                 children: [
          //                   Text('🔔', style: TextStyle(fontSize: 14)),
          //                   SizedBox(width: 6),
          //                   Text(
          //                     'Notify Me',
          //                     style: TextStyle(
          //                       fontSize: 12,
          //                       fontWeight: FontWeight.w600,
          //                       color: Colors.amber,
          //                     ),
          //                   ),
          //                 ],
          //               ),
          //             ),
          //           ],
          //         ),
          //       ],
          //     ),
          //     actions: [
          //       TextButton(
          //         onPressed: () => Navigator.pop(dialogContext),
          //         child: const Text(
          //           'Got It! 👍',
          //           style: TextStyle(
          //             fontSize: 14,
          //             fontWeight: FontWeight.w600,
          //             color: Color(0xFFEB6B46),
          //           ),
          //         ),
          //       ),
          //     ],
          //     actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          //   ),
          // );
          //Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen()));
          //              }),
          //_QuickMenuItem(icon: Icons.message_rounded, title: 'Messages', onTap: _goToMessages),
          //  _QuickMenuItem(icon: Icons.help_rounded, title: 'Payment', onTap: (){
          //   Navigator.push(context, MaterialPageRoute(builder: (context)=>PaymentScreen()));
          //  }),
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
              color: const Color(0xFFEB6B46).withAlpha(10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.rocket_launch,
              color: Color(0xFFEB6B46),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Innovator App v:1.0.42',
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

  // Navigation methods - all instant
  // void _goToMessages() => _quickNavigate(() => const OptimizedChatHomePage());
  void _goToProfile() => _quickNavigate(
    () => ProviderScope(
      child: UserProfileScreen(userId: AppData().currentUserId ?? ''),
    ),
  );
  void _goToEliza() => _quickNavigate(() => ElizaChatScreen());
  void _goToEvents() => _quickNavigate(() => EventsHomePage());
  void _goToReports() => _quickNavigate(() => ReportsScreen());
  void _goToPrivacy() =>
      _quickNavigate(() => const ProviderScope(child: PrivacyPolicy()));
  void _goToSettings() => _quickNavigate(() => const SettingsScreen());
  void _goToFAQ() => _quickNavigate(() => const FAQScreen());

  void _quickNavigate(Widget Function() builder) {
    Navigator.of(context).pop(); // Close drawer
    Navigator.push(context, MaterialPageRoute(builder: (_) => builder()));
  }

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
                  Navigator.of(dialogContext).pop(); // Close dialog immediately
                },
                // => _performLogout(
                //   dialogContext,
                // ), // Fixed: Call with dialogContext
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
      developer.log('🚪 Starting optimized logout process...');

      // Close confirmation dialog immediately
      Navigator.of(dialogContext).pop();
      AppData().clearAuthToken();

      // Optionally close drawer to stay on underlying screen (comment out if you want drawer to stay open during loading)
      if (Navigator.of(context).canPop()) {
        Navigator.of(
          context,
        ).pop(); // Pop drawer - now "stays" on the previous screen
      }

      // Show centered CircularProgressIndicator overlay (non-fullscreen, dismissible only by code)
      _showGlobalLoading(true);

      // Execute cleanup in background
      await _executeOptimizedLogout();

      // Brief pause for smooth transition (optional)
      await Future.delayed(const Duration(milliseconds: 500));

      // Close loading overlay
      _showGlobalLoading(false);

      // Direct navigation using GLOBAL KEY (reliable, clears stack)
      developer.log('Direct navigation to login page...');
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
          settings: const RouteSettings(name: '/login'),
        ),
        (route) => false, // Clears entire stack
      );
      developer.log('Direct navigation to login completed');
    } catch (e) {
      developer.log(' Error during logout: $e');

      // Emergency: Close loading and force direct navigation
      _showGlobalLoading(false);

      try {
        // Brief pause in emergency too
        await Future.delayed(const Duration(milliseconds: 300));

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()),
          (route) => false,
        );
        developer.log('Emergency direct navigation to login completed');
      } catch (navError) {
        developer.log(' Emergency navigation failed: $navError');
        // Fallback: If global key fails, try root navigator
        navigatorKey.currentState?.context
            .findRootAncestorStateOfType<NavigatorState>()
            ?.pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
            );
      }
    }
  }

  // Updated: Non-fullscreen, centered CircularProgressIndicator overlay
  void _showGlobalLoading(bool show) {
    if (show) {
      // Use showDialog for lightweight, centered overlay (stays on current screen)
      showDialog(
        context:
            navigatorKey.currentContext ?? context, // Fallback to local context
        barrierDismissible: false, // Can't dismiss by tapping outside
        builder:
            (context) => const Dialog(
              backgroundColor: Colors.transparent, // No background dialog color
              insetPadding: EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 200,
              ), // Compact sizing
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFFEB6B46),
                  ), // Your app's color
                  SizedBox(height: 16),
                  Text(
                    'Logging out...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
      ).then((_) {
        // Auto-dismiss if needed (but we control it manually)
      });
      developer.log('Loading overlay shown');
    } else {
      // Dismiss the loading dialog (pops the top route if it's the loading one)
      if (navigatorKey.currentState?.canPop() ?? false) {
        navigatorKey.currentState?.pop();
        developer.log('Loading overlay dismissed');
      }
    }
  }

  // Optimized logout execution
  Future<void> _executeOptimizedLogout() async {
    developer.log('🧹 Executing optimized logout...');

    // Step 1: Cancel streams immediately to prevent permission errors
    // try {
    //   if (Get.isRegistered<FireChatController>()) {
    //     final chatController = Get.find<FireChatController>();
    //     await chatController.cancelAllStreamSubscriptionsImmediate();
    //     developer.log('Chat streams canceled immediately');
    //   }
    // } catch (e) {
    //   developer.log(' Error canceling chat streams: $e');
    // }

    // Step 2: Update user status to offline (with timeout)
    // try {
    //   final currentUser = AppData().currentUser;
    //   if (currentUser != null && currentUser['_id'] != null) {
    //     await FirebaseService.updateUserStatus(
    //       currentUser['_id'],
    //       false,
    //     ).timeout(const Duration(seconds: 3));
    //     developer.log('User status updated to offline');
    //   }
    // } catch (e) {
    //   developer.log(' Failed to update user status: $e');
    // }

    // Step 3: Sign out from Firebase Auth
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      developer.log('Signed out from Firebase and Google');
    } catch (e) {
      developer.log(' Error signing out from Firebase: $e');
    }

    // Step 4: Clear controllers
    // try {
    //   if (Get.isRegistered<FireChatController>()) {
    //     final chatController = Get.find<FireChatController>();
    //     await chatController.completeLogoutAfterSignout();
    //     Get.delete<FireChatController>(force: true);
    //     developer.log('Chat controller cleared');
    //   }
    // } catch (e) {
    //   developer.log(' Error clearing chat controller: $e');
    // }

    try {
      if (Get.isRegistered<UserController>()) {
        Get.delete<UserController>(force: true);
        developer.log('User controller cleared');
      }
    } catch (e) {
      developer.log(' Error clearing user controller: $e');
    }

    // Step 5: Clear AppData
    try {
      // await AppData().clearAuthToken();
      developer.log('AppData cleared');
    } catch (e) {
      developer.log(' Error clearing AppData: $e');
    }

    // Step 6: Clear all caches
    try {
      await DrawerProfileCache.clearCache();
      await DefaultCacheManager().emptyCache();
      // OptimizedProfileCache.clearCache();
      developer.log('All caches cleared');
    } catch (e) {
      developer.log(' Error clearing caches: $e');
    }

    developer.log('Optimized logout execution finished');
  }
}

// Ultra-lightweight menu item
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
                          : const Color(0xFFEB6B46).withAlpha(10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isLogout ? Colors.red : const Color(0xFFEB6B46),
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

// Public interface
class SmoothDrawerService {
  static void showLeftDrawer(BuildContext context) {
    InstantDrawerService.show(context);
  }
}

// Compatibility classes
class CustomDrawer extends TrueInstantDrawer {
  const CustomDrawer({super.key});
}

class OptimizedCustomDrawer extends TrueInstantDrawer {
  const OptimizedCustomDrawer({super.key});
}

class ZeroLagDrawer extends TrueInstantDrawer {
  const ZeroLagDrawer({super.key});
}
