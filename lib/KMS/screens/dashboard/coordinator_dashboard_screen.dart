// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:innovator/KMS/core/constants/app_style.dart';
// import 'package:innovator/KMS/model/coordinator_model/coordinator_teacher_response_model.dart';
// import 'package:innovator/KMS/model/coordinator_model/teacher_notes_model.dart';
// import 'package:innovator/KMS/provider/coordinator_provider.dart';
// import 'package:innovator/KMS/screens/constant_screen/custom_scroll.dart';
// import 'package:innovator/KMS/screens/coordinator/coordinator_shared_widget.dart';
// import 'package:innovator/KMS/screens/coordinator/coordinator_teacher_notes_screen.dart';

// final attendanceFilterProvider = StateProvider<String>((ref) => 'ALL');

// class CoordinatorDashboardScreen extends ConsumerWidget {
//   const CoordinatorDashboardScreen({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final attendanceAsync = ref.watch(coordinatorAttendanceProvider);
//     final sessionsAsync = ref.watch(teacherSessionsProvider);
//     final filter = ref.watch(attendanceFilterProvider);

//     return CustomScrolling(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const SizedBox(height: 20),

//           // ── Stats grid ──
//           attendanceAsync.when(
//             loading: () => _StatsGridSkeleton(),
//             error: (_, __) => _buildStatsGrid(null),
//             data: (data) => _buildStatsGrid(data),
//           ),

//           const SizedBox(height: 28),

//           // ══════════════════════════════════
//           // SECTION 1 — Teacher Attendance
//           // ══════════════════════════════════
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text(
//                 'Teacher Attendance',
//                 style: TextStyle(
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                   fontFamily: 'Inter',
//                   color: Colors.black87,
//                 ),
//               ),
//               GestureDetector(
//                 onTap: () => ref.refresh(coordinatorAttendanceProvider),
//                 child: Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: AppStyle.primaryColor.withValues(alpha: 0.1),
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: Icon(Icons.refresh_rounded,
//                       size: 18, color: AppStyle.primaryColor),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),

//           // filter chips — only affect attendance section
//           _FilterChips(provider: attendanceFilterProvider),
//           const SizedBox(height: 14),

//           // attendance list — approve/reject via PUT
//           attendanceAsync.when(
//             loading: () => const Center(
//               child: Padding(
//                 padding: EdgeInsets.all(20),
//                 child: CircularProgressIndicator(),
//               ),
//             ),
//             error: (e, _) => _ErrorBox(message: 'Failed to load: $e'),
//             data: (data) {
//               final list = filter == 'ALL'
//                   ? data.attendances
//                   : data.attendances
//                       .where((a) => a.status == filter)
//                       .toList();

//               if (list.isEmpty) {
//                 return _EmptyState(
//                   icon: filter == 'ALL'
//                       ? Icons.check_circle_rounded
//                       : Icons.filter_list_rounded,
//                   message: filter == 'ALL'
//                       ? 'No attendance records'
//                       : 'No ${filter.toLowerCase()} records',
//                 );
//               }

//               return Column(
//                 children:
//                     list.map((item) => _AttendanceTile(item: item)).toList(),
//               );
//             },
//           ),

//           const SizedBox(height: 32),

// Row(
//   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//   children: [
//     const Text(
//       'Teaching Logs',
//       style: TextStyle(
//         fontWeight: FontWeight.bold,
//         fontSize: 16,
//         fontFamily: 'Inter',
//         color: Colors.black87,
//       ),
//     ),
//     GestureDetector(
//       onTap: () => Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => const CoordinatorSessionsScreen(),
//         ),
//       ),
//       child: Container(
//         padding:
//             const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//         decoration: BoxDecoration(
//           color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
//           borderRadius: BorderRadius.circular(20),
//         ),
//         child: const Text(
//           'View All →',
//           style: TextStyle(
//             fontSize: 12,
//             fontFamily: 'Inter',
//             fontWeight: FontWeight.w600,
//             color: Color(0xFF7C3AED),
//           ),
//         ),
//       ),
//     ),
//   ],
// ),
// const SizedBox(height: 14),

// sessionsAsync.when(
//   loading: () => const Center(
//     child: Padding(
//       padding: EdgeInsets.all(20),
//       child: CircularProgressIndicator(),
//     ),
//   ),
//   error: (e, _) => CoordinatorErrorBox(message: 'Failed to load: $e'),
//   data: (data) {
//     if (data.sessions.isEmpty) {
//       return const CoordinatorEmptyState(
//         icon: Icons.menu_book_rounded,
//         message: 'No teaching logs yet',
//       );
//     }
//     // show only first 2 as preview
//     final preview = data.sessions.take(2).toList();
//     return Column(
//       children: [
//         ...preview.map((s) => SessionPreviewTile(session: s)),
//         if (data.totalSessions > 2)
//           GestureDetector(
//             onTap: () => Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => const CoordinatorSessionsScreen(),
//               ),
//             ),
//             child: Container(
//               width: double.infinity,
//               margin: const EdgeInsets.only(top: 4),
//               padding: const EdgeInsets.symmetric(vertical: 12),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(14),
//                 border: Border.all(
//                   color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
//                 ),
//               ),
//               child: Center(
//                 child: Text(
//                   'View all ${data.totalSessions} logs →',
//                   style: const TextStyle(
//                     fontSize: 13,
//                     fontFamily: 'Inter',
//                     fontWeight: FontWeight.w600,
//                     color: Color(0xFF7C3AED),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//       ],
//     );
//   },
// ),
//           const SizedBox(height: 14),

//           // sessions list — approve/reject via POST
//           sessionsAsync.when(
//             loading: () => const Center(
//               child: Padding(
//                 padding: EdgeInsets.all(20),
//                 child: CircularProgressIndicator(),
//               ),
//             ),
//             error: (e, _) =>
//                 _ErrorBox(message: 'Failed to load sessions: $e'),
//             data: (data) {
//               if (data.sessions.isEmpty) {
//                 return const _EmptyState(
//                   icon: Icons.notes_rounded,
//                   message: 'No sessions recorded',
//                 );
//               }
//               return Column(
//                 children: data.sessions
//                     .map((s) => _SessionTile(session: s))
//                     .toList(),
//               );
//             },
//           ),

//           const SizedBox(height: 24),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatsGrid(CoordinatorAttendanceResponse? data) {
//     final total = data?.total ?? 0;
//     final pending = data?.pending ?? 0;
//     final approved = data != null
//         ? data.attendances.where((a) => a.isApproved).length
//         : 0;
//     final rejected = data != null
//         ? data.attendances.where((a) => a.isRejected).length
//         : 0;

//     return GridView(
//       shrinkWrap: true,
//       padding: EdgeInsets.zero,
//       physics: const NeverScrollableScrollPhysics(),
//       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 2,
//         childAspectRatio: 1.6,
//         crossAxisSpacing: 12,
//         mainAxisSpacing: 12,
//       ),
//       children: [
//         _StatCard(
//             label: 'Total',
//             value: '$total',
//             icon: Icons.calendar_today_rounded,
//             color: AppStyle.primaryColor),
//         _StatCard(
//             label: 'Pending',
//             value: '$pending',
//             icon: Icons.pending_actions_rounded,
//             color: const Color(0xFFE85D04),
//             hasBadge: pending > 0),
//         _StatCard(
//             label: 'Approved',
//             value: '$approved',
//             icon: Icons.check_circle_rounded,
//             color: const Color(0xFF059669)),
//         _StatCard(
//             label: 'Rejected',
//             value: '$rejected',
//             icon: Icons.cancel_rounded,
//             color: Colors.red),
//       ],
//     );
//   }
// }

// // ─── Shared filter chips widget (used in both screens) ───────────────────────

// class _FilterChips extends ConsumerWidget {
//   final StateProvider<String> provider;
//   const _FilterChips({required this.provider});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final filter = ref.watch(provider);
//     final options = ['ALL', 'PENDING', 'APPROVED', 'REJECTED'];
//     final colors = {
//       'ALL': AppStyle.primaryColor,
//       'PENDING': const Color(0xFFE85D04),
//       'APPROVED': const Color(0xFF059669),
//       'REJECTED': Colors.red,
//     };

//     return SingleChildScrollView(
//       scrollDirection: Axis.horizontal,
//       child: Row(
//         children: options.map((f) {
//           final isSelected = filter == f;
//           final color = colors[f]!;
//           return Padding(
//             padding: const EdgeInsets.only(right: 8),
//             child: GestureDetector(
//               onTap: () => ref.read(provider.notifier).state = f,
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 200),
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 16, vertical: 8),
//                 decoration: BoxDecoration(
//                   color: isSelected ? color : Colors.white,
//                   borderRadius: BorderRadius.circular(20),
//                   border: Border.all(
//                     color: isSelected ? color : Colors.grey.shade200,
//                     width: 1.5,
//                   ),
//                   boxShadow: isSelected
//                       ? [
//                           BoxShadow(
//                             color: color.withValues(alpha: 0.3),
//                             blurRadius: 8,
//                             offset: const Offset(0, 3),
//                           )
//                         ]
//                       : [],
//                 ),
//                 child: Text(
//                   f,
//                   style: TextStyle(
//                     fontSize: 12,
//                     fontFamily: 'Inter',
//                     fontWeight: FontWeight.w600,
//                     color: isSelected ? Colors.white : Colors.grey.shade600,
//                   ),
//                 ),
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
// }

// // ─── Attendance tile ──────────────────────────────────────────────────────────

// class _AttendanceTile extends ConsumerStatefulWidget {
//   final CoordinatorAttendanceModel item;
//   const _AttendanceTile({required this.item});

//   @override
//   ConsumerState<_AttendanceTile> createState() => _AttendanceTileState();
// }

// class _AttendanceTileState extends ConsumerState<_AttendanceTile> {
//   bool _isLoading = false;
//   String? _localStatus;

//   String get _effectiveStatus => _localStatus ?? widget.item.status;

//   Future<void> _act(String action, {String? reason}) async {
//     setState(() => _isLoading = true);
//     try {
//       await ref.read(
//         updateAttendanceProvider({
//           'attendanceId': widget.item.id,
//           'action': action,
//         }).future,
//       );
//       setState(
//           () => _localStatus = action == 'approve' ? 'APPROVED' : 'REJECTED');
//       if (mounted) {
//         ref.refresh(coordinatorAttendanceProvider);
//         _snack(
//           action == 'approve' ? 'Attendance approved!' : 'Attendance rejected.',
//           action == 'approve' ? Colors.green : Colors.red.shade400,
//           action == 'approve'
//               ? Icons.check_circle_rounded
//               : Icons.cancel_rounded,
//         );
//       }
//     } catch (e) {
//       if (mounted) _snack('Failed: $e', Colors.red.shade400, Icons.error);
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   void _snack(String msg, Color color, IconData icon) {
//     ScaffoldMessenger.of(context)
//       ..clearSnackBars()
//       ..showSnackBar(SnackBar(
//         content: Row(children: [
//           Icon(icon, color: Colors.white, size: 18),
//           const SizedBox(width: 8),
//           Text(msg, style: const TextStyle(fontFamily: 'Inter')),
//         ]),
//         backgroundColor: color,
//         behavior: SnackBarBehavior.floating,
//         shape:
//             RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       ));
//   }

//   void _showRejectDialog() {
//     final ctrl = TextEditingController();
//     showAdaptiveDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(20)),
//         backgroundColor: Colors.white,
//         title: const Text('Reason for Rejection',
//             style: TextStyle(
//                 fontFamily: 'Inter',
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16)),
//         content: TextField(
//           controller: ctrl,
//           maxLines: 3,
//           autofocus: true,
//           style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
//           decoration: InputDecoration(
//             hintText: 'Enter reason (optional)...',
//             hintStyle: TextStyle(
//                 color: Colors.grey.shade400,
//                 fontFamily: 'Inter',
//                 fontSize: 13),
//             filled: true,
//             fillColor: const Color(0xFFF5F7FA),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: BorderSide.none,
//             ),
//             contentPadding: const EdgeInsets.all(12),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: Text('Cancel',
//                 style: TextStyle(
//                     color: Colors.grey.shade500, fontFamily: 'Inter')),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.red.shade400,
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10)),
//               elevation: 0,
//             ),
//             onPressed: () {
//               Navigator.pop(ctx);
//               _act('reject', reason: ctrl.text.trim());
//             },
//             child: const Text('Reject',
//                 style: TextStyle(
//                     color: Colors.white,
//                     fontFamily: 'Inter',
//                     fontWeight: FontWeight.w600)),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final status = _effectiveStatus;
//     final isPending = status == 'PENDING';
//     final isApproved = status == 'APPROVED';

//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18),
//         border: !isPending
//             ? Border.all(
//                 color: isApproved
//                     ? Colors.green.shade300
//                     : Colors.red.shade300,
//                 width: 1.5,
//               )
//             : null,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.06),
//             blurRadius: 10,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 CircleAvatar(
//                   radius: 22,
//                   backgroundColor:
//                       AppStyle.primaryColor.withValues(alpha: 0.12),
//                   child: Text(
//                     widget.item.teacherName[0],
//                     style: TextStyle(
//                         color: AppStyle.primaryColor,
//                         fontWeight: FontWeight.bold,
//                         fontFamily: 'Inter'),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(widget.item.teacherName,
//                           style: const TextStyle(
//                               fontWeight: FontWeight.w700,
//                               fontSize: 14,
//                               fontFamily: 'Inter',
//                               color: Colors.black87)),
//                       Text(widget.item.schoolName,
//                           style: TextStyle(
//                               fontSize: 12,
//                               color: Colors.grey.shade500,
//                               fontFamily: 'Inter')),
//                     ],
//                   ),
//                 ),
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 8, vertical: 3),
//                   decoration: BoxDecoration(
//                     color: Colors.blue.withValues(alpha: 0.1),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Text(
//                     '${widget.item.date.day}/${widget.item.date.month}',
//                     style: const TextStyle(
//                         fontSize: 11,
//                         color: Colors.blue,
//                         fontFamily: 'Inter',
//                         fontWeight: FontWeight.w600),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),
//             if (_isLoading)
//               const SizedBox(
//                 height: 40,
//                 child: Center(
//                     child: CircularProgressIndicator(strokeWidth: 2)),
//               )
//             else if (!isPending)
//               Container(
//                 height: 40,
//                 decoration: BoxDecoration(
//                   color: isApproved
//                       ? Colors.green.withValues(alpha: 0.1)
//                       : Colors.red.withValues(alpha: 0.1),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Center(
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(
//                         isApproved
//                             ? Icons.check_circle_rounded
//                             : Icons.cancel_rounded,
//                         color: isApproved ? Colors.green : Colors.red,
//                         size: 18,
//                       ),
//                       const SizedBox(width: 6),
//                       Text(
//                         isApproved ? 'Approved' : 'Rejected',
//                         style: TextStyle(
//                           color: isApproved
//                               ? Colors.green.shade700
//                               : Colors.red.shade600,
//                           fontWeight: FontWeight.w700,
//                           fontFamily: 'Inter',
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               )
//             else
//               Row(
//                 children: [
//                   Expanded(
//                     child: GestureDetector(
//                       onTap: _showRejectDialog,
//                       child: Container(
//                         height: 40,
//                         decoration: BoxDecoration(
//                           color: Colors.red.shade50,
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: Colors.red.shade200),
//                         ),
//                         child: Center(
//                           child: Text('Reject',
//                               style: TextStyle(
//                                   color: Colors.red.shade600,
//                                   fontWeight: FontWeight.w700,
//                                   fontFamily: 'Inter',
//                                   fontSize: 13)),
//                         ),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: GestureDetector(
//                       onTap: () => _act('approve'),
//                       child: Container(
//                         height: 40,
//                         decoration: BoxDecoration(
//                           color: Colors.green.shade50,
//                           borderRadius: BorderRadius.circular(12),
//                           border:
//                               Border.all(color: Colors.green.shade300),
//                         ),
//                         child: Center(
//                           child: Text('Approve',
//                               style: TextStyle(
//                                   color: Colors.green.shade700,
//                                   fontWeight: FontWeight.w700,
//                                   fontFamily: 'Inter',
//                                   fontSize: 13)),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ─── Session tile ─────────────────────────────────────────────────────────────

// class _SessionTile extends ConsumerStatefulWidget {
//   final TeacherSessionModel session;
//   const _SessionTile({required this.session});

//   @override
//   ConsumerState<_SessionTile> createState() => _SessionTileState();
// }

// class _SessionTileState extends ConsumerState<_SessionTile> {
//   bool _isLoading = false;
//   bool _acted = false;
//   bool _approved = false;

//   void _snack(String msg, Color color, IconData icon) {
//     ScaffoldMessenger.of(context)
//       ..clearSnackBars()
//       ..showSnackBar(SnackBar(
//         content: Row(children: [
//           Icon(icon, color: Colors.white, size: 18),
//           const SizedBox(width: 8),
//           Text(msg, style: const TextStyle(fontFamily: 'Inter')),
//         ]),
//         backgroundColor: color,
//         behavior: SnackBarBehavior.floating,
//         shape:
//             RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       ));
//   }

//   void _showRejectDialog() {
//     final ctrl = TextEditingController();
//     showAdaptiveDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(20)),
//         backgroundColor: Colors.white,
//         title: const Text('Reason for Rejection',
//             style: TextStyle(
//                 fontFamily: 'Inter',
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16)),
//         content: TextField(
//           controller: ctrl,
//           maxLines: 3,
//           autofocus: true,
//           style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
//           decoration: InputDecoration(
//             hintText: 'Enter reason (optional)...',
//             hintStyle: TextStyle(
//                 color: Colors.grey.shade400,
//                 fontFamily: 'Inter',
//                 fontSize: 13),
//             filled: true,
//             fillColor: const Color(0xFFF5F7FA),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: BorderSide.none,
//             ),
//             contentPadding: const EdgeInsets.all(12),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: Text('Cancel',
//                 style: TextStyle(
//                     color: Colors.grey.shade500, fontFamily: 'Inter')),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.red.shade400,
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10)),
//               elevation: 0,
//             ),
//             onPressed: () {
//               Navigator.pop(ctx);
//               _verify('reject', coordinatorNotes: ctrl.text.trim());
//             },
//             child: const Text('Reject',
//                 style: TextStyle(
//                     color: Colors.white,
//                     fontFamily: 'Inter',
//                     fontWeight: FontWeight.w600)),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _verify(String action, {String? coordinatorNotes}) async {
//     setState(() => _isLoading = true);
//     try {
//       await ref.read(
//         verifySessionProvider({
//           'teacherId': widget.session.teacherId,
//           'classroomId': widget.session.classroomId,
//           'date': widget.session.date,
//           'notes': widget.session.notes,
//           'action': action,
//           'coordinatorNotes': coordinatorNotes,
//         }).future,
//       );
//       setState(() {
//         _acted = true;
//         _approved = action == 'approve';
//       });
//       if (mounted) {
//         ref.refresh(teacherSessionsProvider);
//         _snack(
//           action == 'approve' ? 'Session approved!' : 'Session rejected.',
//           action == 'approve' ? Colors.green : Colors.red.shade400,
//           action == 'approve'
//               ? Icons.check_circle_rounded
//               : Icons.cancel_rounded,
//         );
//       }
//     } catch (e) {
//       if (mounted) _snack('Failed: $e', Colors.red.shade400, Icons.error);
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18),
//         border: _acted
//             ? Border.all(
//                 color: _approved
//                     ? Colors.green.shade300
//                     : Colors.red.shade300,
//                 width: 1.5,
//               )
//             : null,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.06),
//             blurRadius: 10,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 CircleAvatar(
//                   radius: 22,
//                   backgroundColor:
//                       const Color(0xFF7C3AED).withValues(alpha: 0.12),
//                   child: Text(
//                     widget.session.teacherName[0],
//                     style: const TextStyle(
//                         color: Color(0xFF7C3AED),
//                         fontWeight: FontWeight.bold,
//                         fontFamily: 'Inter'),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(widget.session.teacherName,
//                           style: const TextStyle(
//                               fontWeight: FontWeight.w700,
//                               fontSize: 14,
//                               fontFamily: 'Inter',
//                               color: Colors.black87)),
//                       Text(widget.session.classroomName,
//                           style: TextStyle(
//                               fontSize: 12,
//                               color: Colors.grey.shade500,
//                               fontFamily: 'Inter')),
//                     ],
//                   ),
//                 ),
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 8, vertical: 3),
//                   decoration: BoxDecoration(
//                     color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Text(
//                     widget.session.date,
//                     style: const TextStyle(
//                         fontSize: 11,
//                         color: Color(0xFF7C3AED),
//                         fontFamily: 'Inter',
//                         fontWeight: FontWeight.w600),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: const Color(0xFFF5F7FA),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(children: [
//                     Icon(Icons.notes_rounded,
//                         size: 14, color: Colors.grey.shade500),
//                     const SizedBox(width: 6),
//                     Text('Teacher Notes',
//                         style: TextStyle(
//                             fontSize: 11,
//                             fontFamily: 'Inter',
//                             color: Colors.grey.shade500,
//                             fontWeight: FontWeight.w600)),
//                   ]),
//                   const SizedBox(height: 6),
//                   Text(widget.session.notes,
//                       style: const TextStyle(
//                           fontSize: 13,
//                           fontFamily: 'Inter',
//                           color: Colors.black87)),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 8),
//             Row(children: [
//               Icon(Icons.people_rounded,
//                   size: 14, color: Colors.grey.shade400),
//               const SizedBox(width: 5),
//               Text('${widget.session.studentCount} students',
//                   style: TextStyle(
//                       fontSize: 12,
//                       fontFamily: 'Inter',
//                       color: Colors.grey.shade500)),
//             ]),
//             const SizedBox(height: 12),
//             if (_isLoading)
//               const SizedBox(
//                 height: 40,
//                 child: Center(
//                     child: CircularProgressIndicator(strokeWidth: 2)),
//               )
//             else if (_acted)
//               Container(
//                 height: 40,
//                 decoration: BoxDecoration(
//                   color: _approved
//                       ? Colors.green.withValues(alpha: 0.1)
//                       : Colors.red.withValues(alpha: 0.1),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Center(
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(
//                         _approved
//                             ? Icons.check_circle_rounded
//                             : Icons.cancel_rounded,
//                         color: _approved ? Colors.green : Colors.red,
//                         size: 18,
//                       ),
//                       const SizedBox(width: 6),
//                       Text(
//                         _approved ? 'Approved' : 'Rejected',
//                         style: TextStyle(
//                           color: _approved
//                               ? Colors.green.shade700
//                               : Colors.red.shade600,
//                           fontWeight: FontWeight.w700,
//                           fontFamily: 'Inter',
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               )
//             else
//               Row(
//                 children: [
//                   Expanded(
//                     child: GestureDetector(
//                       onTap: _showRejectDialog,
//                       child: Container(
//                         height: 40,
//                         decoration: BoxDecoration(
//                           color: Colors.red.shade50,
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: Colors.red.shade200),
//                         ),
//                         child: Center(
//                           child: Text('Reject',
//                               style: TextStyle(
//                                   color: Colors.red.shade600,
//                                   fontWeight: FontWeight.w700,
//                                   fontFamily: 'Inter',
//                                   fontSize: 13)),
//                         ),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: GestureDetector(
//                       onTap: () => _verify('approve'),
//                       child: Container(
//                         height: 40,
//                         decoration: BoxDecoration(
//                           color: Colors.green.shade50,
//                           borderRadius: BorderRadius.circular(12),
//                           border:
//                               Border.all(color: Colors.green.shade300),
//                         ),
//                         child: Center(
//                           child: Text('Approve',
//                               style: TextStyle(
//                                   color: Colors.green.shade700,
//                                   fontWeight: FontWeight.w700,
//                                   fontFamily: 'Inter',
//                                   fontSize: 13)),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ─── Shared helpers ───────────────────────────────────────────────────────────

// class _StatCard extends StatelessWidget {
//   final String label;
//   final String value;
//   final IconData icon;
//   final Color color;
//   final bool hasBadge;

//   const _StatCard({
//     required this.label,
//     required this.value,
//     required this.icon,
//     required this.color,
//     this.hasBadge = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//               color: Colors.black.withValues(alpha: 0.06),
//               blurRadius: 12,
//               offset: const Offset(0, 4)),
//         ],
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(10),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: color.withValues(alpha: 0.12),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Icon(icon, color: color, size: 22),
//                 ),
//                 if (hasBadge)
//                   Container(
//                     width: 10,
//                     height: 10,
//                     decoration: const BoxDecoration(
//                         color: Colors.red, shape: BoxShape.circle),
//                   ),
//               ],
//             ),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(value,
//                     style: const TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 20,
//                         fontFamily: 'Inter',
//                         color: Colors.black87)),
//                 Text(label,
//                     style: TextStyle(
//                         fontSize: 11,
//                         color: Colors.grey.shade500,
//                         fontFamily: 'Inter')),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _StatsGridSkeleton extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return GridView(
//       shrinkWrap: true,
//       padding: EdgeInsets.zero,
//       physics: const NeverScrollableScrollPhysics(),
//       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 2,
//         childAspectRatio: 1.6,
//         crossAxisSpacing: 12,
//         mainAxisSpacing: 12,
//       ),
//       children: List.generate(
//         4,
//         (_) => Container(
//           decoration: BoxDecoration(
//               color: Colors.grey.shade200,
//               borderRadius: BorderRadius.circular(20)),
//         ),
//       ),
//     );
//   }
// }

// class _EmptyState extends StatelessWidget {
//   final IconData icon;
//   final String message;
//   const _EmptyState({required this.icon, required this.message});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 28),
//       child: Column(
//         children: [
//           Icon(icon, size: 48, color: Colors.grey.shade300),
//           const SizedBox(height: 10),
//           Text(message,
//               style: TextStyle(
//                   color: Colors.grey.shade500,
//                   fontSize: 14,
//                   fontFamily: 'Inter')),
//         ],
//       ),
//     );
//   }
// }

// class _ErrorBox extends StatelessWidget {
//   final String message;
//   const _ErrorBox({required this.message});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//           color: Colors.red.shade50,
//           borderRadius: BorderRadius.circular(12)),
//       child: Text(message,
//           style: TextStyle(
//               fontFamily: 'Inter',
//               color: Colors.red.shade400,
//               fontSize: 13)),
//     );
//   }
// }

// class SessionPreviewTile extends StatelessWidget {
//   final TeacherSessionModel session;
//   const SessionPreviewTile({required this.session});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 10),
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.05),
//             blurRadius: 8,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 40,
//             height: 40,
//             decoration: BoxDecoration(
//               color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: const Icon(Icons.menu_book_rounded,
//                 color: Color(0xFF7C3AED), size: 20),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(session.teacherName,
//                     style: const TextStyle(
//                         fontWeight: FontWeight.w700,
//                         fontSize: 13,
//                         fontFamily: 'Inter',
//                         color: Colors.black87)),
//                 Text(
//                   session.notes,
//                   style: TextStyle(
//                       fontSize: 12,
//                       color: Colors.grey.shade500,
//                       fontFamily: 'Inter'),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(width: 8),
//           Text(
//             session.date,
//             style: TextStyle(
//                 fontSize: 11,
//                 color: Colors.grey.shade400,
//                 fontFamily: 'Inter'),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/KMS/core/constants/app_style.dart';
import 'package:innovator/KMS/model/coordinator_model/coordinator_teacher_response_model.dart';
import 'package:innovator/KMS/model/coordinator_model/teacher_notes_model.dart';
import 'package:innovator/KMS/provider/coordinator_provider.dart';
import 'package:innovator/KMS/screens/constant_screen/custom_scroll.dart';
import 'package:innovator/KMS/screens/coordinator/coordinator_attendance_approval_screen.dart';
import 'package:innovator/KMS/screens/coordinator/coordinator_shared_widget.dart';
import 'package:innovator/KMS/screens/coordinator/coordinator_teacher_notes_screen.dart';

final attendanceFilterProvider = StateProvider<String>((ref) => 'ALL');

class CoordinatorDashboardScreen extends ConsumerWidget {
  const CoordinatorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(coordinatorAttendanceProvider);
    final sessionsAsync = ref.watch(teacherSessionsProvider);

    return CustomScrolling(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // ── Stats grid ──
          attendanceAsync.when(
            loading: () => _StatsGridSkeleton(),
            error: (_, __) => _buildStatsGrid(null),
            data: (data) => _buildStatsGrid(data),
          ),

          const SizedBox(height: 28),

          // ══════════════════════════════
          // SECTION 1 — Teacher Attendance
          // ══════════════════════════════
          _SectionHeader(
            title: 'Teacher Attendance',
            onViewAll:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CoordinatorAttendanceApprovalScreen(),
                  ),
                ),
            onRefresh: () => ref.refresh(coordinatorAttendanceProvider),
            color: AppStyle.primaryColor,
          ),
          const SizedBox(height: 14),

          attendanceAsync.when(
            loading:
                () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
            error: (e, _) => CoordinatorErrorBox(message: 'Failed to load: $e'),
            data: (data) {
              if (data.attendances.isEmpty) {
                return const CoordinatorEmptyState(
                  icon: Icons.how_to_reg_rounded,
                  message: 'No attendance records',
                );
              }
              final preview = data.attendances.take(3).toList();
              return Column(
                children: [
                  ...preview.map(
                    (item) => _AttendancePreviewTile(
                      item: item,
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => CoordinatorAttendanceDetailScreen(
                                    item: item,
                                  ),
                            ),
                          ),
                    ),
                  ),
                  if (data.total > 3)
                    _ViewMoreButton(
                      label: 'View all ${data.total} records',
                      color: AppStyle.primaryColor,
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) =>
                                      const CoordinatorAttendanceApprovalScreen(),
                            ),
                          ),
                    ),
                ],
              );
            },
          ),

          const SizedBox(height: 32),

          // ══════════════════════════════
          // SECTION 2 — Teaching Logs
          // ══════════════════════════════
          _SectionHeader(
            title: 'Teaching Logs',
            onViewAll:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CoordinatorSessionsScreen(),
                  ),
                ),
            onRefresh: () => ref.refresh(teacherSessionsProvider),
            color: AppStyle.primaryColor,
          ),
          const SizedBox(height: 14),

          sessionsAsync.when(
            loading:
                () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
            error: (e, _) => CoordinatorErrorBox(message: 'Failed to load: $e'),
            data: (data) {
              if (data.sessions.isEmpty) {
                return const CoordinatorEmptyState(
                  icon: Icons.menu_book_rounded,
                  message: 'No teaching logs yet',
                );
              }
              final preview = data.sessions.take(3).toList();
              return Column(
                children: [
                  ...preview.map(
                    (s) => _SessionPreviewTile(
                      session: s,
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => CoordinatorSessionDetailScreen(
                                    session: s,
                                  ),
                            ),
                          ),
                    ),
                  ),
                  if (data.totalSessions > 3)
                    _ViewMoreButton(
                      label: 'View all ${data.totalSessions} logs',
                      color: const Color(0xFF7C3AED),
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CoordinatorSessionsScreen(),
                            ),
                          ),
                    ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(CoordinatorAttendanceResponse? data) {
    final total = data?.total ?? 0;
    final pending = data?.pending ?? 0;
    final approved =
        data != null ? data.attendances.where((a) => a.isApproved).length : 0;
    final rejected =
        data != null ? data.attendances.where((a) => a.isRejected).length : 0;

    return GridView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      children: [
        _StatCard(
          label: 'Total',
          value: '$total',
          icon: Icons.calendar_today_rounded,
          color: AppStyle.primaryColor,
        ),
        _StatCard(
          label: 'Pending',
          value: '$pending',
          icon: Icons.pending_actions_rounded,
          color: const Color(0xFFE85D04),
          hasBadge: pending > 0,
        ),
        _StatCard(
          label: 'Approved',
          value: '$approved',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF059669),
        ),
        _StatCard(
          label: 'Rejected',
          value: '$rejected',
          icon: Icons.cancel_rounded,
          color: Colors.red,
        ),
      ],
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll;
  final VoidCallback onRefresh;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.onViewAll,
    required this.onRefresh,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            fontFamily: 'Inter',
            color: Colors.black87,
          ),
        ),
        Row(
          children: [
            GestureDetector(
              onTap: onViewAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'View All →',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRefresh,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.refresh_rounded, size: 16, color: color),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Attendance preview tile (no buttons) ────────────────────────────────────

class _AttendancePreviewTile extends StatelessWidget {
  final CoordinatorAttendanceModel item;
  final VoidCallback onTap;

  const _AttendancePreviewTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPending = item.status == 'PENDING';
    final isApproved = item.status == 'APPROVED';

    final statusColor =
        isPending
            ? const Color(0xFFE85D04)
            : isApproved
            ? const Color(0xFF059669)
            : Colors.red;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppStyle.primaryColor.withValues(alpha: 0.1),
              child: Text(
                item.teacherName[0],
                style: TextStyle(
                  color: AppStyle.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.teacherName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      fontFamily: 'Inter',
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    item.schoolName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.date.day}/${item.date.month}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.status,
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Colors.grey.shade300,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Session preview tile (no buttons) ───────────────────────────────────────

class _SessionPreviewTile extends StatelessWidget {
  final TeacherSessionModel session;
  final VoidCallback onTap;

  const _SessionPreviewTile({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: AppStyle.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.teacherName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      fontFamily: 'Inter',
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    session.notes,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontFamily: 'Inter',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  session.date,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.grey.shade300,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── View more button ─────────────────────────────────────────────────────────

class _ViewMoreButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ViewMoreButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared stat card & skeleton ─────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool hasBadge;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.hasBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (hasBadge)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    fontFamily: 'Inter',
                    color: Colors.black87,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGridSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      children: List.generate(
        4,
        (_) => Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
