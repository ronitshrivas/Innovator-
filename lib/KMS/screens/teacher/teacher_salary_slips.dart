// import 'dart:typed_data';
// import 'dart:ui' as ui;
// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:innovator/KMS/core/constants/app_style.dart'; 
// import 'package:innovator/KMS/model/teacher_model/teacher_salary_slips.dart';
// import 'package:innovator/KMS/provider/teacher_provider.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:share_plus/share_plus.dart';

// // ─── Invoice List Screen ─────────────────────────────────────────────────────

// class InvoiceScreen extends ConsumerStatefulWidget {
//   const InvoiceScreen({super.key});

//   @override
//   ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
// }

// class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
//   DateTime? _selectedDate;
//   // how many slips are currently visible (lazy loading)
//   int _visibleCount = 3;

//   void _pickDate() async {
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: _selectedDate ?? DateTime.now(),
//       firstDate: DateTime(2020),
//       lastDate: DateTime.now(),
//       builder: (context, child) => Theme(
//         data: Theme.of(context).copyWith(
//           colorScheme: ColorScheme.light(primary: AppStyle.primaryColor),
//         ),
//         child: child!,
//       ),
//     );
//     if (picked != null) setState(() => _selectedDate = picked);
//   }

//   List<SalarySlipModel> _filtered(List<SalarySlipModel> slips) {
//     final sorted = [...slips]
//       ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

//     if (_selectedDate == null) return sorted;
//     return sorted.where((s) {
//       final d = s.createdAt;
//       return d.year == _selectedDate!.year &&
//           d.month == _selectedDate!.month &&
//           d.day == _selectedDate!.day;
//     }).toList();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final slipsAsync = ref.watch(salarySlipsProvider);

//     return Scaffold(
//       backgroundColor: AppStyle.primaryColor,
//       appBar: AppBar(
//         backgroundColor: AppStyle.primaryColor,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: const Text(
//           'Salary Slips',
//           style: TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//             fontFamily: 'Inter',
//             fontSize: 18,
//           ),
//         ),
//         actions: [
//           // Date filter button
//           Padding(
//             padding: const EdgeInsets.only(right: 12),
//             child: GestureDetector(
//               onTap: _pickDate,
//               child: Container(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
//                 decoration: BoxDecoration(
//                   color: _selectedDate != null
//                       ? Colors.white
//                       : Colors.white.withValues(alpha: 0.2),
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(
//                       Icons.calendar_today_rounded,
//                       size: 13,
//                       color: _selectedDate != null
//                           ? AppStyle.primaryColor
//                           : Colors.white,
//                     ),
//                     const SizedBox(width: 6),
//                     Text(
//                       _selectedDate != null
//                           ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
//                           : 'Filter',
//                       style: TextStyle(
//                         fontSize: 12,
//                         fontFamily: 'Inter',
//                         fontWeight: FontWeight.w600,
//                         color: _selectedDate != null
//                             ? AppStyle.primaryColor
//                             : Colors.white,
//                       ),
//                     ),
//                     if (_selectedDate != null) ...[
//                       const SizedBox(width: 6),
//                       GestureDetector(
//                         onTap: () => setState(() => _selectedDate = null),
//                         child: Icon(Icons.close_rounded,
//                             size: 13, color: AppStyle.primaryColor),
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
//             child: Text(
//               _selectedDate != null
//                   ? 'Showing results for ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
//                   : 'Your payroll records',
//               style: TextStyle(
//                 color: Colors.white.withValues(alpha: 0.8),
//                 fontSize: 13,
//                 fontFamily: 'Inter',
//               ),
//             ),
//           ),
//           Expanded(
//             child: Container(
//               decoration: const BoxDecoration(
//                 color: Color(0xFFF5F7FA),
//                 borderRadius: BorderRadius.only(
//                   topLeft: Radius.circular(28),
//                   topRight: Radius.circular(28),
//                 ),
//               ),
//               child: slipsAsync.when(
//                 loading: () => _buildSkeletonList(),
//                 error: (e, _) => Center(
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(Icons.error_outline_rounded,
//                           size: 48, color: Colors.grey.shade300),
//                       const SizedBox(height: 12),
//                       Text(
//                         'Failed to load salary slips',
//                         style: TextStyle(
//                             fontFamily: 'Inter',
//                             color: Colors.grey.shade500),
//                       ),
//                     ],
//                   ),
//                 ),
//                 data: (response) {
//                   final slips = _filtered(response.slips);
//                   if (slips.isEmpty) {
//                     return Center(
//                       child: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(Icons.receipt_long_rounded,
//                               size: 52, color: Colors.grey.shade300),
//                           const SizedBox(height: 12),
//                           Text(
//                             _selectedDate != null
//                                 ? 'No slips for this date'
//                                 : 'No salary slips yet',
//                             style: TextStyle(
//                               fontFamily: 'Inter',
//                               color: Colors.grey.shade400,
//                               fontSize: 15,
//                             ),
//                           ),
//                         ],
//                       ),
//                     );
//                   }

//                   final visible = slips.take(_visibleCount).toList();
//                   final hasMore = _visibleCount < slips.length;

//                   return ListView.builder(
//                     padding: const EdgeInsets.all(20),
//                     // +1 for load more button if needed
//                     itemCount: visible.length + (hasMore ? 1 : 0),
//                     itemBuilder: (context, i) {
//                       if (i == visible.length) {
//                         // load more button
//                         return Padding(
//                           padding: const EdgeInsets.only(bottom: 20),
//                           child: GestureDetector(
//                             onTap: () => setState(
//                                 () => _visibleCount += 3),
//                             child: Container(
//                               height: 48,
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(14),
//                                 border: Border.all(
//                                   color: AppStyle.primaryColor
//                                       .withValues(alpha: 0.3),
//                                 ),
//                               ),
//                               child: Center(
//                                 child: Text(
//                                   'Load more  (${slips.length - _visibleCount} remaining)',
//                                   style: TextStyle(
//                                     fontSize: 13,
//                                     fontFamily: 'Inter',
//                                     fontWeight: FontWeight.w600,
//                                     color: AppStyle.primaryColor,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         );
//                       }
//                       return _SlipCard(slip: visible[i]);
//                     },
//                   );
//                 },
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSkeletonList() {
//     return ListView.builder(
//       padding: const EdgeInsets.all(20),
//       itemCount: 4,
//       itemBuilder: (_, i) => _SkeletonSlipCard(index: i),
//     );
//   }
// }

// // ─── Skeleton Card ───────────────────────────────────────────────────────────

// class _SkeletonSlipCard extends StatefulWidget {
//   final int index;
//   const _SkeletonSlipCard({required this.index});

//   @override
//   State<_SkeletonSlipCard> createState() => _SkeletonSlipCardState();
// }

// class _SkeletonSlipCardState extends State<_SkeletonSlipCard>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _ctrl;

//   @override
//   void initState() {
//     super.initState();
//     _ctrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 900),
//     )..repeat(reverse: true);
//   }

//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: _ctrl,
//       builder: (_, __) {
//         final opacity = 0.3 + 0.4 * _ctrl.value;
//         return Opacity(
//           opacity: opacity,
//           child: Container(
//             margin: const EdgeInsets.only(bottom: 14),
//             padding: const EdgeInsets.all(18),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(20),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         _box(120, 14),
//                         const SizedBox(height: 6),
//                         _box(80, 10),
//                       ],
//                     ),
//                     _box(60, 28, radius: 14),
//                   ],
//                 ),
//                 const SizedBox(height: 16),
//                 const Divider(height: 1),
//                 const SizedBox(height: 14),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     _box(70, 32),
//                     _box(70, 32),
//                     _box(50, 32),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _box(double w, double h, {double radius = 8}) => Container(
//         width: w,
//         height: h,
//         decoration: BoxDecoration(
//           color: Colors.grey.shade300,
//           borderRadius: BorderRadius.circular(radius),
//         ),
//       );
// }

// // ─── Slip Summary Card ───────────────────────────────────────────────────────

// class _SlipCard extends StatelessWidget {
//   final SalarySlipModel slip;
//   const _SlipCard({required this.slip});

//   String _fmt(double v) => v.toStringAsFixed(2).replaceAllMapped(
//       RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},');

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: () => Navigator.push(
//         context,
//         MaterialPageRoute(
//             builder: (_) => InvoiceDetailScreen(slip: slip)),
//       ),
//       child: Container(
//         margin: const EdgeInsets.only(bottom: 14),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(20),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withValues(alpha: 0.07),
//               blurRadius: 14,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(18),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         '${slip.monthName} ${slip.year}',
//                         style: const TextStyle(
//                           fontWeight: FontWeight.w700,
//                           fontSize: 16,
//                           fontFamily: 'Inter',
//                           color: Colors.black87,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         slip.schoolName,
//                         style: TextStyle(
//                           fontSize: 12,
//                           fontFamily: 'Inter',
//                           color: Colors.grey.shade500,
//                         ),
//                       ),
//                     ],
//                   ),
//                   _StatusBadge(status: slip.status),
//                 ],
//               ),
//               const SizedBox(height: 16),
//               const Divider(height: 1),
//               const SizedBox(height: 14),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   _SlipStat(
//                     label: 'Base Salary',
//                     value: 'Rs. ${_fmt(slip.baseSalary)}',
//                     color: Colors.black87,
//                   ),
//                   _SlipStat(
//                     label: 'Net Salary',
//                     value: 'Rs. ${_fmt(slip.netSalary)}',
//                     color: AppStyle.primaryColor,
//                     isBold: true,
//                   ),
//                   _SlipStat(
//                     label: 'Classes',
//                     value: '${slip.totalClasses}',
//                     color: Colors.black87,
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 14),
//               Row(
//                 children: [
//                   Text(
//                     'Created: ${slip.createdAt.day}/${slip.createdAt.month}/${slip.createdAt.year}',
//                     style: TextStyle(
//                       fontSize: 11,
//                       fontFamily: 'Inter',
//                       color: Colors.grey.shade400,
//                     ),
//                   ),
//                   const Spacer(),
//                   Icon(Icons.arrow_forward_rounded,
//                       size: 14, color: Colors.grey.shade400),
//                   const SizedBox(width: 4),
//                   Text(
//                     'View invoice',
//                     style: TextStyle(
//                       fontSize: 12,
//                       fontFamily: 'Inter',
//                       color: Colors.grey.shade400,
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _SlipStat extends StatelessWidget {
//   final String label;
//   final String value;
//   final Color color;
//   final bool isBold;

//   const _SlipStat({
//     required this.label,
//     required this.value,
//     required this.color,
//     this.isBold = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(label,
//             style: TextStyle(
//                 fontSize: 11,
//                 color: Colors.grey.shade400,
//                 fontFamily: 'Inter')),
//         const SizedBox(height: 3),
//         Text(value,
//             style: TextStyle(
//               fontSize: 14,
//               color: color,
//               fontFamily: 'Inter',
//               fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
//             )),
//       ],
//     );
//   }
// }

// class _StatusBadge extends StatelessWidget {
//   final String status;
//   const _StatusBadge({required this.status});

//   @override
//   Widget build(BuildContext context) {
//     final isPaid = status == 'PAID';
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
//       decoration: BoxDecoration(
//         color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(
//           color: isPaid
//               ? Colors.green.withValues(alpha: 0.3)
//               : Colors.orange.withValues(alpha: 0.3),
//         ),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 7,
//             height: 7,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: isPaid ? Colors.green : Colors.orange,
//             ),
//           ),
//           const SizedBox(width: 6),
//           Text(
//             status,
//             style: TextStyle(
//               fontSize: 12,
//               fontFamily: 'Inter',
//               fontWeight: FontWeight.w700,
//               color: isPaid ? Colors.green.shade700 : Colors.orange.shade700,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ─── Invoice Detail Screen ───────────────────────────────────────────────────

// class InvoiceDetailScreen extends StatefulWidget {
//   final SalarySlipModel slip;
//   const InvoiceDetailScreen({super.key, required this.slip});

//   @override
//   State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
// }

// class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
//   final GlobalKey _invoiceKey = GlobalKey();
//   bool _isDownloading = false;

//   // Image picked for the invoice header
//   File? _headerImage;

//   String _fmt(double v) => v.toStringAsFixed(2).replaceAllMapped(
//       RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},');

//   Future<void> _downloadInvoice() async {
//     setState(() => _isDownloading = true);
//     try {
//       await Future.delayed(const Duration(milliseconds: 300));
//       final boundary = _invoiceKey.currentContext!.findRenderObject()
//           as RenderRepaintBoundary;
//       final image = await boundary.toImage(pixelRatio: 3.0);
//       final byteData =
//           await image.toByteData(format: ui.ImageByteFormat.png);
//       final Uint8List pngBytes = byteData!.buffer.asUint8List();

//       final dir = await getTemporaryDirectory();
//       final file = File(
//           '${dir.path}/invoice_${widget.slip.monthName}_${widget.slip.year}_${widget.slip.id.substring(0, 6)}.png');
//       await file.writeAsBytes(pngBytes);

//       await Share.shareXFiles(
//         [XFile(file.path)],
//         text:
//             'Salary Slip — ${widget.slip.monthName} ${widget.slip.year}\nNet Salary: Rs. ${_fmt(widget.slip.netSalary)}',
//       );
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Download failed: $e'),
//             backgroundColor: Colors.red.shade400,
//             behavior: SnackBarBehavior.floating,
//             shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12)),
//           ),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _isDownloading = false);
//     }
//   }

//   // Use image_picker if available, else just show a placeholder tap action
//   void _pickImage() async {
//     // If you have image_picker: uncomment and use it
//     // final picker = ImagePicker();
//     // final picked = await picker.pickImage(source: ImageSource.gallery);
//     // if (picked != null) setState(() => _headerImage = File(picked.path));

//     // For now show a snack guiding the user
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: const Text(
//             'Add image_picker to pubspec.yaml to enable image upload'),
//         backgroundColor: AppStyle.primaryColor,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12)),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final slip = widget.slip;

//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F7FA),
//       appBar: AppBar(
//         backgroundColor: const Color(0xFFF5F7FA),
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_rounded,
//               color: Colors.black87),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: const Text(
//           'Invoice',
//           style: TextStyle(
//             color: Colors.black87,
//             fontWeight: FontWeight.bold,
//             fontFamily: 'Inter',
//             fontSize: 18,
//           ),
//         ),
//         actions: [
//           Padding(
//             padding: const EdgeInsets.only(right: 16),
//             child: GestureDetector(
//               onTap: _isDownloading ? null : _downloadInvoice,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 14, vertical: 8),
//                 decoration: BoxDecoration(
//                   color: AppStyle.primaryColor,
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: _isDownloading
//                     ? const SizedBox(
//                         width: 16,
//                         height: 16,
//                         child: CircularProgressIndicator(
//                             color: Colors.white, strokeWidth: 2),
//                       )
//                     : const Row(
//                         children: [
//                           Icon(Icons.download_rounded,
//                               color: Colors.white, size: 16),
//                           SizedBox(width: 6),
//                           Text(
//                             'Download',
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontFamily: 'Inter',
//                               fontWeight: FontWeight.w600,
//                               fontSize: 13,
//                             ),
//                           ),
//                         ],
//                       ),
//               ),
//             ),
//           ),
//         ],
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(20),
//         child: RepaintBoundary(
//           key: _invoiceKey,
//           child: Container(
//             color: const Color(0xFFF5F7FA),
//             child: Container(
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(24),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withValues(alpha: 0.08),
//                     blurRadius: 20,
//                     offset: const Offset(0, 6),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 children: [
//                   // ── Image placeholder / header image ──
//                   GestureDetector(
//                     onTap: _pickImage,
//                     child: ClipRRect(
//                       borderRadius: const BorderRadius.only(
//                         topLeft: Radius.circular(24),
//                         topRight: Radius.circular(24),
//                       ),
//                       child: _headerImage != null
//                           ? Image.file(
//                               _headerImage!,
//                               width: double.infinity,
//                               height: 160,
//                               fit: BoxFit.cover,
//                             )
//                           : Container(
//                               width: double.infinity,
//                               height: 160,
//                               decoration: BoxDecoration(
//                                 color: AppStyle.primaryColor
//                                     .withValues(alpha: 0.07),
//                               ),
//                               child: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Container(
//                                     width: 52,
//                                     height: 52,
//                                     decoration: BoxDecoration(
//                                       color: AppStyle.primaryColor
//                                           .withValues(alpha: 0.12),
//                                       shape: BoxShape.circle,
//                                     ),
//                                     child: Icon(
//                                       Icons.add_photo_alternate_rounded,
//                                       color: AppStyle.primaryColor,
//                                       size: 26,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 10),
//                                   Text(
//                                     'Tap to add company logo or banner',
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       fontFamily: 'Inter',
//                                       color: AppStyle.primaryColor
//                                           .withValues(alpha: 0.7),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                     ),
//                   ),

//                   // ── Gradient header ──
//                   Container(
//                     width: double.infinity,
//                     decoration: BoxDecoration(
//                       gradient: LinearGradient(
//                         colors: [
//                           AppStyle.primaryColor,
//                           AppStyle.primaryColor.withValues(alpha: 0.82),
//                         ],
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                       ),
//                     ),
//                     padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           mainAxisAlignment:
//                               MainAxisAlignment.spaceBetween,
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 const Text(
//                                   'SALARY SLIP',
//                                   style: TextStyle(
//                                     color: Colors.white70,
//                                     fontSize: 11,
//                                     fontFamily: 'Inter',
//                                     letterSpacing: 2,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 6),
//                                 Text(
//                                   '${slip.monthName} ${slip.year}',
//                                   style: const TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 26,
//                                     fontFamily: 'Inter',
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 14, vertical: 7),
//                               decoration: BoxDecoration(
//                                 color: slip.isPaid
//                                     ? Colors.green.shade400
//                                     : Colors.orange.shade400,
//                                 borderRadius: BorderRadius.circular(20),
//                               ),
//                               child: Text(
//                                 slip.status,
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontFamily: 'Inter',
//                                   fontWeight: FontWeight.w700,
//                                   fontSize: 13,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 16),
//                         Row(children: [
//                           const Icon(Icons.person_rounded,
//                               color: Colors.white54, size: 15),
//                           const SizedBox(width: 8),
//                           Text(slip.teacherName,
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontFamily: 'Inter',
//                                 fontWeight: FontWeight.w600,
//                                 fontSize: 14,
//                               )),
//                         ]),
//                         const SizedBox(height: 6),
//                         Row(children: [
//                           const Icon(Icons.school_rounded,
//                               color: Colors.white54, size: 15),
//                           const SizedBox(width: 8),
//                           Text(slip.schoolName,
//                               style: const TextStyle(
//                                 color: Colors.white70,
//                                 fontFamily: 'Inter',
//                                 fontSize: 13,
//                               )),
//                         ]),
//                       ],
//                     ),
//                   ),

//                   // ── Net Salary Hero ──
//                   Container(
//                     width: double.infinity,
//                     margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 24, vertical: 20),
//                     decoration: BoxDecoration(
//                       color:
//                           AppStyle.primaryColor.withValues(alpha: 0.06),
//                       borderRadius: BorderRadius.circular(18),
//                       border: Border.all(
//                         color: AppStyle.primaryColor
//                             .withValues(alpha: 0.15),
//                       ),
//                     ),
//                     child: Column(children: [
//                       Text(
//                         'Net Salary',
//                         style: TextStyle(
//                           fontSize: 13,
//                           fontFamily: 'Inter',
//                           color: Colors.grey.shade500,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       Text(
//                         'Rs. ${_fmt(slip.netSalary)}',
//                         style: TextStyle(
//                           fontSize: 32,
//                           fontFamily: 'Inter',
//                           fontWeight: FontWeight.bold,
//                           color: AppStyle.primaryColor,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         'For ${slip.monthName} ${slip.year}',
//                         style: TextStyle(
//                           fontSize: 12,
//                           fontFamily: 'Inter',
//                           color: Colors.grey.shade400,
//                         ),
//                       ),
//                     ]),
//                   ),

//                   // ── Salary Breakdown ──
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Salary Breakdown',
//                           style: TextStyle(
//                             fontSize: 14,
//                             fontFamily: 'Inter',
//                             fontWeight: FontWeight.w700,
//                             color: Colors.black87,
//                           ),
//                         ),
//                         const SizedBox(height: 14),
//                         _InvoiceRow(
//                           label: 'Base Salary',
//                           value: 'Rs. ${_fmt(slip.baseSalary)}',
//                           icon: Icons.account_balance_wallet_rounded,
//                           iconColor: AppStyle.primaryColor,
//                         ),
//                         _InvoiceRow(
//                           label: 'Commission',
//                           value: 'Rs. ${_fmt(slip.commission)}',
//                           icon: Icons.trending_up_rounded,
//                           iconColor: Colors.green,
//                         ),
//                         _InvoiceRow(
//                           label: 'Adjustments',
//                           value: 'Rs. ${_fmt(slip.adjustments)}',
//                           icon: Icons.tune_rounded,
//                           iconColor: const Color(0xffF8BD00),
//                         ),
//                         const Padding(
//                           padding: EdgeInsets.symmetric(vertical: 12),
//                           child: Divider(height: 1),
//                         ),
//                         Row(
//                           mainAxisAlignment:
//                               MainAxisAlignment.spaceBetween,
//                           children: [
//                             const Text(
//                               'Net Salary',
//                               style: TextStyle(
//                                 fontSize: 15,
//                                 fontFamily: 'Inter',
//                                 fontWeight: FontWeight.w700,
//                                 color: Colors.black87,
//                               ),
//                             ),
//                             Text(
//                               'Rs. ${_fmt(slip.netSalary)}',
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontFamily: 'Inter',
//                                 fontWeight: FontWeight.bold,
//                                 color: AppStyle.primaryColor,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),

//                   // ── Work Summary ──
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Work Summary',
//                           style: TextStyle(
//                             fontSize: 14,
//                             fontFamily: 'Inter',
//                             fontWeight: FontWeight.w700,
//                             color: Colors.black87,
//                           ),
//                         ),
//                         const SizedBox(height: 14),
//                         Row(children: [
//                           Expanded(
//                             child: _WorkStatCard(
//                               label: 'Total Classes',
//                               value: '${slip.totalClasses}',
//                               icon: Icons.class_rounded,
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: _WorkStatCard(
//                               label: 'Total Hours',
//                               value:
//                                   '${slip.totalHours.toStringAsFixed(1)}h',
//                               icon: Icons.access_time_rounded,
//                             ),
//                           ),
//                         ]),
//                       ],
//                     ),
//                   ),

//                   // ── Admin Override Note ──
//                   if (slip.adminOverride && slip.overrideNotes != null)
//                     Container(
//                       margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
//                       padding: const EdgeInsets.all(16),
//                       decoration: BoxDecoration(
//                         color: const Color(0xFFFFF8E1),
//                         borderRadius: BorderRadius.circular(14),
//                         border: Border.all(
//                           color: const Color(0xffF8BD00)
//                               .withValues(alpha: 0.4),
//                         ),
//                       ),
//                       child: Row(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Icon(Icons.info_outline_rounded,
//                               color: Color(0xffF8BD00), size: 18),
//                           const SizedBox(width: 10),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment:
//                                   CrossAxisAlignment.start,
//                               children: [
//                                 const Text(
//                                   'Admin Note',
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     fontFamily: 'Inter',
//                                     fontWeight: FontWeight.w700,
//                                     color: Color(0xffB8860B),
//                                   ),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 Text(
//                                   slip.overrideNotes!,
//                                   style: const TextStyle(
//                                     fontSize: 13,
//                                     fontFamily: 'Inter',
//                                     color: Color(0xff7A6200),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),

//                   // ── Footer ──
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
//                     child: Column(children: [
//                       const Divider(height: 1),
//                       const SizedBox(height: 16),
//                       Row(
//                         mainAxisAlignment:
//                             MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'Issued: ${slip.createdAt.day}/${slip.createdAt.month}/${slip.createdAt.year}',
//                             style: TextStyle(
//                               fontSize: 11,
//                               fontFamily: 'Inter',
//                               color: Colors.grey.shade400,
//                             ),
//                           ),
//                           Text(
//                             'ID: ${slip.id.substring(0, 8).toUpperCase()}',
//                             style: TextStyle(
//                               fontSize: 11,
//                               fontFamily: 'Inter',
//                               color: Colors.grey.shade400,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ]),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ─── Reusable Widgets ────────────────────────────────────────────────────────

// class _InvoiceRow extends StatelessWidget {
//   final String label;
//   final String value;
//   final IconData icon;
//   final Color iconColor;

//   const _InvoiceRow({
//     required this.label,
//     required this.value,
//     required this.icon,
//     required this.iconColor,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 12),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Row(children: [
//             Container(
//               width: 32,
//               height: 32,
//               decoration: BoxDecoration(
//                 color: iconColor.withValues(alpha: 0.1),
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Icon(icon, size: 16, color: iconColor),
//             ),
//             const SizedBox(width: 12),
//             Text(label,
//                 style: const TextStyle(
//                     fontSize: 14,
//                     fontFamily: 'Inter',
//                     color: Colors.black54)),
//           ]),
//           Text(value,
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontFamily: 'Inter',
//                 fontWeight: FontWeight.w600,
//                 color: Colors.black87,
//               )),
//         ],
//       ),
//     );
//   }
// }

// class _WorkStatCard extends StatelessWidget {
//   final String label;
//   final String value;
//   final IconData icon;

//   const _WorkStatCard({
//     required this.label,
//     required this.value,
//     required this.icon,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF5F7FA),
//         borderRadius: BorderRadius.circular(14),
//       ),
//       child: Row(children: [
//         Icon(icon, color: AppStyle.primaryColor, size: 22),
//         const SizedBox(width: 10),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(value,
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontFamily: 'Inter',
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black87,
//                 )),
//             Text(label,
//                 style: TextStyle(
//                   fontSize: 11,
//                   fontFamily: 'Inter',
//                   color: Colors.grey.shade500,
//                 )),
//           ],
//         ),
//       ]),
//     );
//   }
// }



import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:innovator/KMS/core/constants/app_style.dart';
import 'package:innovator/KMS/model/teacher_model/teacher_salary_slips.dart';
import 'package:innovator/KMS/provider/teacher_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// ─── Invoice List Screen ─────────────────────────────────────────────────────

class InvoiceScreen extends ConsumerStatefulWidget {
  const InvoiceScreen({super.key});

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  DateTime? _selectedDate;
  int _visibleCount = 3;

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppStyle.primaryColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  List<SalarySlipModel> _filtered(List<SalarySlipModel> slips) {
    final sorted = [...slips]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (_selectedDate == null) return sorted;
    return sorted.where((s) {
      final d = s.createdAt;
      return d.year == _selectedDate!.year &&
          d.month == _selectedDate!.month &&
          d.day == _selectedDate!.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final slipsAsync = ref.watch(salarySlipsProvider);

    return Scaffold(
      backgroundColor: AppStyle.primaryColor,
      appBar: AppBar(
        backgroundColor: AppStyle.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Salary Slips',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _selectedDate != null
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: _selectedDate != null
                          ? AppStyle.primaryColor
                          : Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _selectedDate != null
                          ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Filter',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        color: _selectedDate != null
                            ? AppStyle.primaryColor
                            : Colors.white,
                      ),
                    ),
                    if (_selectedDate != null) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() => _selectedDate = null),
                        child: Icon(Icons.close_rounded,
                            size: 13, color: AppStyle.primaryColor),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _selectedDate != null
                    ? 'Results for ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                    : 'Your payroll records',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7FA),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: slipsAsync.when(
                loading: () => _buildSkeletonList(),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load salary slips',
                        style: TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                data: (response) {
                  final slips = _filtered(response.slips);
                  if (slips.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_rounded,
                              size: 52, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            _selectedDate != null
                                ? 'No slips for this date'
                                : 'No salary slips yet',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.grey.shade400,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final visible = slips.take(_visibleCount).toList();
                  final hasMore = _visibleCount < slips.length;
                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: visible.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == visible.length) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _visibleCount += 3),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppStyle.primaryColor
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Load more  (${slips.length - _visibleCount} remaining)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                    color: AppStyle.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      return _SlipCard(slip: visible[i]);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      itemBuilder: (_, i) => _SkeletonSlipCard(index: i),
    );
  }
}

// ─── Skeleton ────────────────────────────────────────────────────────────────

class _SkeletonSlipCard extends StatefulWidget {
  final int index;
  const _SkeletonSlipCard({required this.index});

  @override
  State<_SkeletonSlipCard> createState() => _SkeletonSlipCardState();
}

class _SkeletonSlipCardState extends State<_SkeletonSlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: 0.3 + 0.4 * _ctrl.value,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(120, 14),
                      const SizedBox(height: 6),
                      _box(80, 10),
                    ],
                  ),
                  _box(60, 28, radius: 14),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _box(70, 32),
                  _box(70, 32),
                  _box(50, 32),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box(double w, double h, {double radius = 8}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

// ─── Slip Card ───────────────────────────────────────────────────────────────

class _SlipCard extends StatelessWidget {
  final SalarySlipModel slip;
  const _SlipCard({required this.slip});

  String _fmt(double v) => v.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => InvoiceDetailScreen(slip: slip)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${slip.monthName} ${slip.year}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          fontFamily: 'Inter',
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        slip.schoolName,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Inter',
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  _StatusBadge(status: slip.status),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SlipStat(
                    label: 'Base Salary',
                    value: 'Rs. ${_fmt(slip.baseSalary)}',
                    color: Colors.black87,
                  ),
                  _SlipStat(
                    label: 'Net Salary',
                    value: 'Rs. ${_fmt(slip.netSalary)}',
                    color: AppStyle.primaryColor,
                    isBold: true,
                  ),
                  _SlipStat(
                    label: 'Classes',
                    value: '${slip.totalClasses}',
                    color: Colors.black87,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Created: ${slip.createdAt.day}/${slip.createdAt.month}/${slip.createdAt.year}',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Inter',
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded,
                      size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    'View invoice',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Inter',
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlipStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isBold;

  const _SlipStat({
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade400,
                fontFamily: 'Inter')),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontFamily: 'Inter',
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            )),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPaid = status == 'PAID';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPaid
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPaid ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              color: isPaid ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

 
class InvoiceDetailScreen extends StatefulWidget {
  final SalarySlipModel slip;
  const InvoiceDetailScreen({super.key, required this.slip});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final GlobalKey _invoiceKey = GlobalKey();
  bool _isDownloading = false;
  bool _isSharing = false;

  static const _darkNavy = Color(0xFF1B2A4A);

  String _fmt(double v) => v.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},');

  Future<Uint8List?> _capture() async {
    try {
      // wait for asset image to fully render
      await Future.delayed(const Duration(milliseconds: 600));
      final context = _invoiceKey.currentContext;
      if (context == null) return null;
      final boundary =
          context.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _download() async {
    setState(() => _isDownloading = true);
    try {
      final bytes = await _capture();
      if (bytes == null) throw Exception('Failed to capture invoice');

      final fileName =
          'invoice_${widget.slip.monthName}_${widget.slip.year}_${widget.slip.id.substring(0, 6)}.png';

      // Save directly to Android Downloads folder — no package needed
      final downloadsDir = Directory('/storage/emulated/0/Download');
      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Saved to Downloads/$fileName',
                  style: const TextStyle(fontFamily: 'Inter'),
                ),
              ),
            ]),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e',
                style: const TextStyle(fontFamily: 'Inter')),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _share() async {
    setState(() => _isSharing = true);
    try {
      final bytes = await _capture();
      if (bytes == null) throw Exception('Failed to capture invoice');

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/invoice_${widget.slip.monthName}_${widget.slip.year}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Salary Slip — ${widget.slip.monthName} ${widget.slip.year}'
            '\nNet Salary: Rs. ${_fmt(widget.slip.netSalary)}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: $e',
                style: const TextStyle(fontFamily: 'Inter')),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slip = widget.slip;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F2F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Invoice',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
            fontSize: 18,
          ),
        ),
        actions: [
          // Share button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _isSharing ? null : _share,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: _isSharing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: AppStyle.primaryColor, strokeWidth: 2),
                      )
                    : Row(children: [
                        Icon(Icons.share_rounded,
                            color: AppStyle.primaryColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Share',
                          style: TextStyle(
                            color: AppStyle.primaryColor,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ]),
              ),
            ),
          ),
          // Download button
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: _isDownloading ? null : _download,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppStyle.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isDownloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Row(children: [
                        Icon(Icons.download_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Download',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ]),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RepaintBoundary(
          key: _invoiceKey,
          child: Container(
            color: const Color(0xFFF0F2F5),
            padding: const EdgeInsets.all(4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Dark navy header ──
                  Container(
                    width: double.infinity,
                    color: _darkNavy,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/kms/nepatronix.png',
                          width: 72,
                          height: 72,
                          fit: BoxFit.contain,
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'SALARY SLIP',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _headerMeta('Slip No',
                                '#${slip.id.substring(0, 8).toUpperCase()}'),
                            const SizedBox(height: 4),
                            _headerMeta(
                              'Invoice Date',
                              '${slip.createdAt.day} ${slip.monthName} ${slip.createdAt.year}',
                            ),
                            const SizedBox(height: 4),
                            _headerMeta(
                                'Period', '${slip.monthName} ${slip.year}'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Info row ──
                  Container(
                    color: const Color(0xFFF5F7FA),
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _infoLabel('Teacher'),
                              const SizedBox(height: 6),
                              _infoValue(slip.teacherName),
                              const SizedBox(height: 3),
                              _infoValue('Status: ${slip.status}',
                                  color: slip.isPaid
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _infoLabel('School'),
                              const SizedBox(height: 6),
                              _infoValue(slip.schoolName),
                              const SizedBox(height: 3),
                              _infoValue('Classes: ${slip.totalClasses}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Table ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Container(
                          color: _darkNavy,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          child: Row(children: [
                            _tableHead('No.', flex: 1),
                            _tableHead('Description', flex: 4),
                            _tableHead('Details',
                                flex: 3, align: TextAlign.center),
                            _tableHead('Amount',
                                flex: 3, align: TextAlign.right),
                          ]),
                        ),
                        _tableRow(
                          no: '1',
                          desc: 'Base Salary',
                          detail: '${slip.totalClasses} classes',
                          amount: 'Rs. ${_fmt(slip.baseSalary)}',
                          isEven: false,
                        ),
                        _tableRow(
                          no: '2',
                          desc: 'Commission',
                          detail:
                              '${slip.totalHours.toStringAsFixed(1)} hrs',
                          amount: 'Rs. ${_fmt(slip.commission)}',
                          isEven: true,
                        ),
                        _tableRow(
                          no: '3',
                          desc: 'Adjustments',
                          detail: slip.adminOverride ? 'Admin override' : '—',
                          amount: 'Rs. ${_fmt(slip.adjustments)}',
                          isEven: false,
                        ),
                        const SizedBox(height: 4),
                        _totalRow('Subtotal',
                            'Rs. ${_fmt(slip.baseSalary + slip.commission)}'),
                        _totalRow(
                            'Adjustments', 'Rs. ${_fmt(slip.adjustments)}'),
                        _totalRow('Net Salary', 'Rs. ${_fmt(slip.netSalary)}',
                            highlight: true),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Dashed divider ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: List.generate(
                        48,
                        (i) => Expanded(
                          child: Container(
                            height: 1,
                            color: i.isEven
                                ? Colors.grey.shade400
                                : Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Notes ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Notes :',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: Colors.black87)),
                        const SizedBox(height: 8),
                        _note('Payment is processed at the end of each month.'),
                        _note(
                            'Contact HR for any discrepancies in this slip.'),
                        if (slip.adminOverride &&
                            slip.overrideNotes != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xffF8BD00)
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    color: Color(0xffF8BD00), size: 15),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Admin Note: ${slip.overrideNotes}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'Inter',
                                        color: Color(0xff7A6200)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Footer ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: const Text(
                      'Thank You for Your Business',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'Inter',
                        color: Colors.black54,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerMeta(String label, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label  :  ',
              style: const TextStyle(
                  color: Colors.white60, fontSize: 12, fontFamily: 'Inter')),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600)),
        ],
      );

  Widget _infoLabel(String text) => Text(text,
      style: TextStyle(
          fontSize: 11,
          fontFamily: 'Inter',
          color: Colors.grey.shade500,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5));

  Widget _infoValue(String text, {Color? color}) => Text(text,
      style: TextStyle(
          fontSize: 13,
          fontFamily: 'Inter',
          color: color ?? Colors.black87,
          fontWeight: FontWeight.w500));

  Widget _tableHead(String text,
          {int flex = 1, TextAlign align = TextAlign.left}) =>
      Expanded(
        flex: flex,
        child: Text(text,
            textAlign: align,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
                fontSize: 12)),
      );

  Widget _tableRow({
    required String no,
    required String desc,
    required String detail,
    required String amount,
    required bool isEven,
  }) =>
      Container(
        color: isEven ? Colors.grey.shade50 : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Expanded(
              flex: 1,
              child: Text(no,
                  style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Inter',
                      color: Colors.grey.shade500))),
          Expanded(
              flex: 4,
              child: Text(desc,
                  style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      color: Colors.black87))),
          Expanded(
              flex: 3,
              child: Text(detail,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Inter',
                      color: Colors.grey.shade500))),
          Expanded(
              flex: 3,
              child: Text(amount,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      color: Colors.black87))),
        ]),
      );

  Widget _totalRow(String label, String value, {bool highlight = false}) =>
      Container(
        color: highlight ? _darkNavy : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(children: [
          const Spacer(),
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Inter',
                    fontWeight:
                        highlight ? FontWeight.bold : FontWeight.normal,
                    color: highlight ? Colors.white : Colors.black87)),
          ),
          SizedBox(
            width: 110,
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Inter',
                    fontWeight:
                        highlight ? FontWeight.bold : FontWeight.w600,
                    color: highlight ? Colors.white : Colors.black87)),
          ),
        ]),
      );

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• ',
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13)),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Inter',
                      color: Colors.grey.shade600)),
            ),
          ],
        ),
      );
}