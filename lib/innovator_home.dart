// ─────────────────────────────────────────────────────────────────────────────
// lib/Innovator/screens/Feed/homepage.dart  (or wherever your Homepage lives)
//
// CHANGES FROM YOUR ORIGINAL:
//   1. StatefulWidget → ConsumerStatefulWidget  (needed for ref)
//   2. State → ConsumerState                    (needed for ref)
//   3. didChangeAppLifecycleState wired to setAppActive()
//      resumed → 8-second polling (fast, user is looking at the app)
//      paused  → 30-second polling (slow, saves battery)
//   4. Everything else is IDENTICAL to your original
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ← NEW
import 'package:in_app_update/in_app_update.dart';
import 'package:innovator/Innovator/provider/notification_provider.dart';
import 'package:innovator/Innovator/screens/Feed/Inner_Homepage.dart';
import 'package:innovator/Innovator/screens/Feed/Video_Feed.dart';
import 'package:innovator/Innovator/widget/FloatingMenuwidget.dart';

// ── CHANGE 1: StatefulWidget → ConsumerStatefulWidget ──────────────────────
class Homepage extends ConsumerStatefulWidget {
  const Homepage({super.key});

  @override
  ConsumerState<Homepage> createState() => _HomepageState();
}

// ── CHANGE 2: State<Homepage> → ConsumerState<Homepage> ────────────────────
class _HomepageState extends ConsumerState<Homepage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _checkForUpdate();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FloatingMenuOverlay.show(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── CHANGE 3: Wire lifecycle to polling speed ───────────────────────────
  // @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   super.didChangeAppLifecycleState(state);
  //   switch (state) {
  //     case AppLifecycleState.resumed:
  //       // User opened the app → switch to fast polling (every 8 seconds)
  //       // Also triggers an immediate poll so the user sees fresh notifications
  //       // the moment they return to the app.
  //       log('App resumed → fast polling');
  //       ref.read(notificationProvider.notifier).setAppActive(true);
  //       break;

  //     case AppLifecycleState.paused:
  //       // App went to background → switch to slow polling (every 30 seconds)
  //       // This is battery-friendly. FCM handles background system tray
  //       // notifications independently — this polling is only for the
  //       // in-app banner when the app is open.
  //       log('App paused → slow polling');
  //       ref.read(notificationProvider.notifier).setAppActive(false);
  //       break;

  //     case AppLifecycleState.inactive:
  //     case AppLifecycleState.detached:
  //     case AppLifecycleState.hidden:
  //       // No polling changes needed for these states
  //       break;
  //   }
  // }

  // ── Everything below is IDENTICAL to your original ─────────────────────

  Future<void> _checkForUpdate() async {
    try {
      log('Checking for Update!');
      final AppUpdateInfo info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        log('Update available!');
        if (info.immediateUpdateAllowed) {
          _performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          _performFlexibleUpdate();
        }
      } else {
        log('No update available');
      }
    } catch (error) {
      log('Error checking for update: $error');
    }
  }

  Future<void> _performImmediateUpdate() async {
    try {
      log('Starting immediate update');
      await InAppUpdate.performImmediateUpdate();
    } catch (error) {
      log('Immediate update failed: $error');
    }
  }

  Future<void> _performFlexibleUpdate() async {
    try {
      log('Starting flexible update');
      await InAppUpdate.startFlexibleUpdate();
      InAppUpdate.completeFlexibleUpdate()
          .then((_) {
            log('Flexible update completed');
            _showUpdateCompletedSnackbar();
          })
          .catchError((error) {
            log('Error completing flexible update: $error');
          });
    } catch (error) {
      log('Flexible update failed: $error');
    }
  }

  void _showUpdateCompletedSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Update downloaded. Restart app to apply changes.'),
        action: SnackBarAction(
          label: 'RESTART',
          onPressed: () {
            InAppUpdate.completeFlexibleUpdate();
          },
        ),
        duration: const Duration(seconds: 10),
      ),
    );
  }

  void _navigateToVideoFeed() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ReelsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: GestureDetector(
        onHorizontalDragEnd: (DragEndDetails details) {
          if (details.primaryVelocity! < -200) {
            _navigateToVideoFeed();
          }
        },
        child: Inner_HomePage(),
      ),
    );
  }
}
