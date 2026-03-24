// import 'dart:developer' as developer;

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:innovator/Innovator/services/Daily_Notifcation.dart';

// class DailyNotificationSettings extends StatefulWidget {
//   const DailyNotificationSettings({Key? key}) : super(key: key);

//   @override
//   State<DailyNotificationSettings> createState() => _DailyNotificationSettingsState();
// }

// class _DailyNotificationSettingsState extends State<DailyNotificationSettings> {
//   bool _isEnabled = false;
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _loadSettings();
//   }

//   Future<void> _loadSettings() async {
//     try {
//       final enabled = await DailyNotificationService.areNotificationsEnabled();
      
//       setState(() {
//         _isEnabled = enabled;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//       });
//       developer.log('Failed to load settings: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return const Scaffold(
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }

//     final schedule = DailyNotificationService.getNotificationSchedule();

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Daily Motivation'),
//         backgroundColor: const Color.fromRGBO(244, 135, 6, 1),
//         foregroundColor: Colors.white,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Daily Innovator Thoughts',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 8),
//             const Text(
//               'Get inspired automatically with engaging thoughts for innovators!',
//               style: TextStyle(fontSize: 16, color: Colors.grey),
//             ),
//             const SizedBox(height: 30),
            
//             SwitchListTile(
//               title: const Text('Daily Notifications'),
//               subtitle: const Text('Automatic inspiring thoughts throughout the day'),
//               value: _isEnabled,
//               onChanged: (bool value) async {
//                 if (value) {
//                   final success = await DailyNotificationService.enableDailyNotifications();
                  
//                   if (success) {
//                     setState(() {
//                       _isEnabled = true;
//                     });
//                     Get.snackbar(
//                       'Enabled',
//                       'Daily notifications activated!',
//                       backgroundColor: Colors.green,
//                       colorText: Colors.white,
//                     );
//                   }
//                 } else {
//                   final success = await DailyNotificationService.disableDailyNotifications();
                  
//                   if (success) {
//                     setState(() {
//                       _isEnabled = false;
//                     });
//                     Get.snackbar(
//                       'Disabled',
//                       'Daily notifications turned off',
//                       backgroundColor: Colors.orange,
//                       colorText: Colors.white,
//                     );
//                   }
//                 }
//               },
//             ),
            
//             if (_isEnabled) ...[
//               const SizedBox(height: 20),
//               const Text(
//                 'Notification Schedule:',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 10),
              
//               Card(
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: schedule.map((time) => Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 4.0),
//                       child: Row(
//                         children: [
//                           const Icon(Icons.schedule, size: 20, color: Colors.orange),
//                           const SizedBox(width: 10),
//                           Text(time, style: const TextStyle(fontSize: 16)),
//                         ],
//                       ),
//                     )).toList(),
//                   ),
//                 ),
//               ),
              
//               const SizedBox(height: 20),
//               const Text(
//                 'You will receive motivational thoughts at these times every day to keep your innovative spirit alive!',
//                 style: TextStyle(fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic),
//               ),
//             ],
            
//             const SizedBox(height: 30),
            
//             // Test button
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton.icon(
//                 onPressed: () async {
//                   await DailyNotificationService.showTestNotification();
//                   Get.snackbar(
//                     'Test Sent',
//                     'Check your notifications for a sample thought!',
//                     backgroundColor: const Color.fromRGBO(244, 135, 6, 1),
//                     colorText: Colors.white,
//                   );
//                 },
//                 icon: const Icon(Icons.notifications_active),
//                 label: const Text('Test Notification'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color.fromRGBO(244, 135, 6, 1),
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.all(16),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
