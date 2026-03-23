import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:innovator/Innovator/screens/Feed/Inner_Homepage.dart';
import 'package:innovator/Innovator/screens/Feed/Video_Feed.dart';
import 'package:innovator/Innovator/services/notifcation_polling_services.dart';
import 'package:innovator/Innovator/utils/Drawer/custom_drawer.dart';
import 'package:innovator/Innovator/widget/FloatingMenuwidget.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<Homepage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // final NotificationPollingService _pollingService =
  //     NotificationPollingService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Check for app updates
    _checkForUpdate();

    // Start notification polling
    _startNotificationPolling();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FloatingMenuOverlay.show(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Note: We don't stop polling here as it should continue app-wide
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        log('App resumed - starting notification polling');
        // _pollingService.startPolling();
        // _pollingService.forceCheck();
        break;
      case AppLifecycleState.paused:
        log('App paused - stopping notification polling');
        // _pollingService.stopPolling();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _startNotificationPolling() {
    //_pollingService.startPolling();
    log('Notification polling started');
    Future.delayed(const Duration(seconds: 2), () {
      // _pollingService.forceCheck();
    });
  }

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
        pageBuilder:
            (context, animation, secondaryAnimation) => VideoFeedPage(),
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
      //    FloatingMenuOverlay handles it globally above all screens.
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
