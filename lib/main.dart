import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:innovator/Innovator/constant/app_colors.dart';
import 'package:innovator/Innovator/screens/Splash_Screen/splash_screen.dart';
import 'package:innovator/Innovator/services/fcm_services.dart';
import 'package:innovator/KMS/screens/auth/login_screen.dart';
import 'package:innovator/KMS/screens/dashboard/admin_dashboard_screen.dart';
import 'package:innovator/KMS/screens/dashboard/student_dashboard_screen.dart';
import 'package:innovator/KMS/screens/dashboard/teacher_dashboard_screen.dart';
import 'dart:developer' as developer;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:innovator/ecommerce/screens/Shop/Shop_Page.dart';

late Size mq;
//late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
GlobalKey<NavigatorState> get navigatorKey => Get.key;

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background notification: ${message.notification?.title}');
}

//: Track Firebase initialization state
//bool _isFirebaseInitialized = false;

// void _showImmediateFeedback(RemoteMessage message) {
//   try {
//     final title =
//         message.notification?.title ??
//         message.data['senderName'] ??
//         'New Message';
//     final body =
//         message.notification?.body ?? message.data['message'] ?? 'New message';

//     Get.snackbar(
//       title,
//       body,
//       snackPosition: SnackPosition.TOP,
//       backgroundColor: const Color.fromRGBO(244, 135, 6, 0.95),
//       colorText: AppColors.whitecolor,
//       duration: const Duration(seconds: 3),
//       margin: const EdgeInsets.all(16),
//       borderRadius: 12,
//       isDismissible: true,
//       mainButton: TextButton(
//         onPressed: () {
//           Get.back();
//           _handleNotificationTapFromMessage(message);
//         },
//         child: const Text(
//           'View',
//           style: TextStyle(color: AppColors.whitecolor, fontWeight: FontWeight.bold),
//         ),
//       ),
//     );
//     HapticFeedback.lightImpact();
//   } catch (e) {
//     developer.log('Immediate feedback error: $e');
//   }
// }

// void _handleNotificationTapFromMessage(RemoteMessage message) {
//   try {
//     final data = message.data;
//     final type = data['type']?.toString() ?? '';

//     switch (type) {
//       case 'chat':
//       case 'message':
//         _navigateToChatFromNotification(data);
//         break;
//       default:
//         Get.offAllNamed('/home');
//         break;
//     }
//   } catch (e) {
//     developer.log('Notification tap error: $e');
//   }
// }

// void _navigateToChatFromNotification(Map<String, dynamic> data) {
//   try {
//     final senderId = data['senderId']?.toString() ?? '';
//     final senderName = data['senderName']?.toString() ?? 'Unknown';
//     final chatId = data['chatId']?.toString() ?? '';

//     if (senderId.isNotEmpty) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         Get.toNamed(
//           '/chat',
//           arguments: {
//             'receiverUser': {
//               'id': senderId,
//               'userId': senderId,
//               '_id': senderId,
//               'name': senderName,
//             },
//             'chatId': chatId,
//             'fromNotification': true,
//           },
//         );
//       });
//     }
//   } catch (e) {
//     developer.log('Chat navigation error: $e');
//   }
// }

void main() async {
  // Wrap in error handling zone
  runZonedGuarded(
    () async {
      try {
        developer.log('App starting...');

        // Load environment variables
        //await dotenv.load(fileName: ".env");

        // Ensure Flutter is initialized
        WidgetsFlutterBinding.ensureInitialized();

        // Set system UI
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
        );
        await Firebase.initializeApp();

        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );
        //  Initialize Firebase FIRST before anything else
        //developer.log('Pre-initializing Firebase in main()...');
        // if (Firebase.apps.isEmpty) {
        //   await Firebase.initializeApp(
        //     options: DefaultFirebaseOptions.currentPlatform,
        //   );
        //   _isFirebaseInitialized = true;
        //   developer.log('Firebase pre-initialized');
        // }

        // Set background message handler (must be after Firebase init)
        // FirebaseMessaging.onBackgroundMessage(
        //   _firebaseMessagingBackgroundHandler,
        // );

        // Initialize critical UI components
        //await _initializeCriticalOnly();

        // Start the app
        developer.log(' Starting UI...');
        runApp(ProviderScope(child: InnovatorHomePage()));

        // Initialize non-critical services in background
        //developer.log('Starting background initialization...');
        //_initializeNonCriticalServices();

        developer.log('App started successfully');
      } catch (e, stackTrace) {
        developer.log('Critical error in main: $e\n$stackTrace');
        // Still try to run the app
        runApp(const ProviderScope(child: InnovatorHomePage()));
      }
    },
    (error, stackTrace) {
      developer.log('Uncaught error: $error\n$stackTrace');
    },
  );
}

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

class InnovatorHomePage extends ConsumerStatefulWidget {
  const InnovatorHomePage({super.key});

  @override
  ConsumerState<InnovatorHomePage> createState() => _InnovatorHomePageState();
}

class _InnovatorHomePageState extends ConsumerState<InnovatorHomePage>
    with WidgetsBindingObserver {
  // Declare at class level — NOT inside the function
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _localNotificationsInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    developer.log('InnovatorHomePage initialized');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupFCM();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _setupFCM() async {
    try {
      // ── 1. Initialize Local Notifications FIRST ──────────────────────────
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          developer.log('Local notification tapped: ${details.payload}');
          if (details.payload != null) {
            try {
              final data = jsonDecode(details.payload!) as Map<String, dynamic>;
              _handleNotificationData(data);
            } catch (e) {
              developer.log('Payload parse error: $e');
            }
          }
        },
      );

      // ── 2. Create Android Notification Channel ───────────────────────────
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications',
        importance: Importance.max, // ← MAX not HIGH
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      _localNotificationsInitialized = true;
      developer.log('Local notifications initialized ');

      // ── 3. Request Permission ────────────────────────────────────────────
      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);

      developer.log('FCM permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        developer.log('User denied notification permission');
        return;
      }

      // ── 4. iOS foreground options ────────────────────────────────────────
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      // ── 5. Register FCM Token ────────────────────────────────────────────
      await FCMService().registerToken();

      // ── 6. Token Refresh ─────────────────────────────────────────────────
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        developer.log('FCM Token refreshed: $newToken');
        await FCMService().registerToken();
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showForegroundNotification(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        developer.log('Notification tapped from background');
        _handleNotificationTap(message);
      });

      RemoteMessage? initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        developer.log('App opened from killed state via notification');
        await Future.delayed(const Duration(milliseconds: 500));
        _handleNotificationTap(initialMessage);
      }

      developer.log('FCM setup completed ');
    } catch (e) {
      developer.log('FCM setup error: $e');
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    try {
      if (!_localNotificationsInitialized) {
        developer.log(' Local notifications not initialized yet');
        return;
      }

      // Works for BOTH notification messages AND data-only messages
      final title =
          message.notification?.title ??
          message.data['title']?.toString() ??
          message.data['senderName']?.toString() ??
          'New Notification';

      final body =
          message.notification?.body ??
          message.data['body']?.toString() ??
          message.data['message']?.toString() ??
          '';

      developer.log('Showing local notification — title: $title, body: $body');

      final androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications',
        importance: Importance.max, // ← MAX
        priority: Priority.max, // ← MAX
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        icon: '@mipmap/ic_launcher',
        // This forces heads-up popup on Android
        fullScreenIntent: false,
        ticker: title,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, // unique ID
        title,
        body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: jsonEncode(message.data),
      );

      developer.log('Local notification shown ');
    } catch (e) {
      developer.log('Show foreground notification error: $e');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    _handleNotificationData(message.data);
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    try {
      final type = data['type']?.toString() ?? '';
      developer.log('Handling notification type: $type');

      switch (type) {
        case 'follow':
          break;
        case 'reaction':
        case 'comment':
          break;
        case 'chat':
        case 'message':
          break;
        default:
          break;
      }
    } catch (e) {
      developer.log('Handle notification data error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    mq = MediaQuery.of(context).size;

    return GetMaterialApp(
      //  FIX: Use the global navigator key for InAppNotificationService
      navigatorKey: navigatorKey,
      home: SplashScreen(),

      routes: {
        '/kms/login': (_) => KmsLoginScreen(),
        '/kms/adminDasboard': (_) => AdminDashboardScreen(),
        '/kms/partnerDashboard': (_) => TeacherDashboardScreen(),
        '/kms/studentDashboard': (_) => StudentDashboardScreen(),
        // '/kms/partnerAssignedSchool': (_) => PartnerAssignedSchoolScreen(),
        // '/kms/partnerAssignmentMgmt':
        //     (_) => PartnerAssignmentManagementScreen(),
        // '/kms/partnerAttendanceSpecificGrade':
        //     (_) => PartnerAttendanceSpecificGradeScreen(),
      },
      title: 'Innovator',
      theme: _buildAppTheme(),
      debugShowCheckedModeBanner: false,

      // home: const SplashScreen(),
      // home: LoginScreen(),
      // use this authwrapper when in the production when the token things is solved
      // home:   AuthWrapper(),
      getPages: [
        GetPage(
          name: '/shop',
          page: () => const ShopPage(),
          // binding: BindingsBuilder(() {
          //   Get.lazyPut<CartStateManager>(() => CartStateManager());
          // }),
        ),
      ],

      // GetPage(
      //   name: '/chat',
      //   page: () {
      //     final args = Get.arguments as Map<String, dynamic>? ?? {};
      //     return OptimizedChatScreen(
      //       receiverUser: args['receiverUser'] ?? {},
      //       currentUser: args['currentUser'],
      //     );
      //   },
      //   binding: BindingsBuilder(() {
      //     Get.lazyPut<FireChatController>(() => FireChatController());
      //   }),
      // ),
    );
  }

  ThemeData _buildAppTheme() {
    return ThemeData(
      fontFamily: 'InterThin',
      primarySwatch: Colors.orange,
      primaryColor: const Color.fromRGBO(244, 135, 6, 1),
      appBarTheme: const AppBarTheme(
        elevation: 1,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.whitecolor,
          fontWeight: FontWeight.bold,
          fontSize: 19,
        ),
        backgroundColor: Color.fromRGBO(244, 135, 6, 1),
        iconTheme: IconThemeData(color: AppColors.whitecolor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromRGBO(244, 135, 6, 1),
          foregroundColor: AppColors.whitecolor,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color.fromRGBO(244, 135, 6, 1),
        foregroundColor: AppColors.whitecolor,
      ),
    );
  }
}
