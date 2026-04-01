// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:innovator/elearning/model/course_list_model.dart';
// import 'package:innovator/elearning/provider/course_provider.dart';
// import 'package:video_player/video_player.dart';
// import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
// import 'package:shimmer/shimmer.dart';

// class CourseDetailScreen extends ConsumerStatefulWidget {
//   final CourseListModel course;
//   const CourseDetailScreen({Key? key, required this.course}) : super(key: key);

//   @override
//   ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
// }

// class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen>
//     with SingleTickerProviderStateMixin {
//   late TabController _tabController;
//   VideoPlayerController? _videoController;

//   bool _videoInitialized = false;
//   bool _videoError = false;
//   bool _isVideoLoading = false;
//   int _selectedIndex = 0;
//   bool _videoStarted = false;

//   static const List<String> _tabs = ['Lessons', 'Docs', 'About'];

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: _tabs.length, vsync: this);
//     WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartVideo());
//   }

//   void _maybeStartVideo() {
//     if (_videoStarted || !mounted) return;
//     final enrolled = ref
//         .read(enrolledCoursesProvider)
//         .contains(widget.course.id);
//     if (enrolled && widget.course.contents.isNotEmpty) {
//       _videoStarted = true;
//       _initVideo(widget.course.contents.first);
//     }
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     _videoController?.dispose();
//     // restore orientation when leaving
//     SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
//     super.dispose();
//   }

//   // ── video init ────────────────────────────────────────────────────────────

//   void _initVideo(CourseContent content) {
//     _videoController?.dispose();
//     setState(() {
//       _videoInitialized = false;
//       _videoError = false;
//       _isVideoLoading = true;
//     });

//     final url =
//         (content.videoUrl != null && content.videoUrl!.isNotEmpty)
//             ? content.videoUrl!
//             : (content.videoFile != null && content.videoFile!.isNotEmpty)
//             ? content.videoFile!
//             : null;

//     if (url == null) {
//       setState(() {
//         _videoError = true;
//         _isVideoLoading = false;
//       });
//       return;
//     }

//     _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
//       ..initialize()
//           .then((_) {
//             if (mounted)
//               setState(() {
//                 _videoInitialized = true;
//                 _isVideoLoading = false;
//               });
//           })
//           .catchError((_) {
//             if (mounted)
//               setState(() {
//                 _videoError = true;
//                 _isVideoLoading = false;
//               });
//           });
//   }

//   // ── enroll ────────────────────────────────────────────────────────────────

//   Future<void> _enroll() async {
//     final courseId = widget.course.id;
//     ref.read(enrollLoadingProvider(courseId).notifier).setLoading(true);
//     try {
//       await ref.read(courseServiceProvider).enrollCourse(courseId);
//       ref.read(enrolledCoursesProvider.notifier).enroll(courseId);
//       ref.read(enrollLoadingProvider(courseId).notifier).setLoading(false);
//       _videoStarted = true;
//       if (widget.course.contents.isNotEmpty) {
//         _initVideo(widget.course.contents.first);
//       }
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               widget.course.isFree
//                   ? 'Enrolled! Start learning now. 🎉'
//                   : 'Request sent. Complete payment to unlock.',
//             ),
//             backgroundColor: Color(0xFF10B981),
//             behavior: SnackBarBehavior.floating,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(10),
//             ),
//           ),
//         );
//       }
//     } catch (e) {
//       ref.read(enrollLoadingProvider(courseId).notifier).setLoading(false);
//     }
//   }

      
//   @override
//   Widget build(BuildContext context) {
//     final enrolledIds = ref.watch(enrolledCoursesProvider);
//     final isEnrolled = enrolledIds.contains(widget.course.id);

//     if (isEnrolled && !_videoStarted) {
//       _videoStarted = true;
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (mounted && widget.course.contents.isNotEmpty) {
//           _initVideo(widget.course.contents.first);
//         }
//       });
//     }

//     return Scaffold(
//       backgroundColor: Color(0xFFF5F7FA),
//       body: Column(
//         children: [
//           _buildVideoSection(isEnrolled),
//           _buildTitleBar(),
//           Expanded(
//             child: TabBarView(
//               controller: _tabController,
//               children: [
//                 _buildLessonsTab(isEnrolled),
//                 _buildDocsTab(isEnrolled),
//                 _buildAboutTab(isEnrolled),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ── title bar ─────────────────────────────────────────────────────────────

//   Widget _buildTitleBar() {
//     return Container(
//       color: Colors.white,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Padding(
//             padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
//             child: Row(
//               children: [
//                 GestureDetector(
//                   onTap: () => Navigator.pop(context),
//                   child: Container(
//                     padding: const EdgeInsets.all(6),
//                     decoration: BoxDecoration(
//                       color: Color(0xFFF5F7FA),
//                       borderRadius: BorderRadius.circular(8),
//                       border: Border.all(color: Color(0xFFE2E8F0)),
//                     ),
//                     child: const Icon(
//                       Icons.arrow_back_ios_new,
//                       size: 14,
//                       color: Color(0xFF1E293B),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: Text(
//                     widget.course.title,
//                     style: const TextStyle(
//                       fontSize: 15,
//                       fontWeight: FontWeight.bold,
//                       color: Color(0xFF1E293B),
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 _CourseBadge(isFree: widget.course.isFree),
//               ],
//             ),
//           ),
//           TabBar(
//             controller: _tabController,
//             tabs: _tabs.map((t) => Tab(text: t)).toList(),
//             labelColor: Color(0xFF2563EB),
//             unselectedLabelColor: Color(0xFF94A3B8),
//             indicatorColor: Color(0xFF2563EB),
//             indicatorWeight: 2.5,
//             labelStyle: const TextStyle(
//               fontWeight: FontWeight.w600,
//               fontSize: 14,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildVideoSection(bool isEnrolled) {
//     final isLoading = ref.watch(enrollLoadingProvider(widget.course.id));
//     return Container(
//       color: Colors.black,
//       width: double.infinity,
//       child: SafeArea(
//         bottom: false,
//         child: AspectRatio(
//           aspectRatio: 16 / 9,
//           child: Stack(
//             alignment: Alignment.center,
//             children: [
//               if (!isEnrolled)
//                 _LockedOverlay(course: widget.course)
//               else if (_isVideoLoading)
//                 _videoShimmer()
//               else if (_videoError)
//                 _videoErrorWidget()
//               else if (_videoInitialized)
//                 // ✅ Full-featured video player with all controls
//                 _VideoPlayerWithControls(
//                   controller: _videoController!,
//                   onFullscreen: _openFullscreen,
//                 )
//               else
//                 _videoShimmer(),

//               // back button
//               Positioned(
//                 top: 10,
//                 left: 10,
//                 child: GestureDetector(
//                   onTap: () => Navigator.pop(context),
//                   child: Container(
//                     padding: const EdgeInsets.all(7),
//                     decoration: BoxDecoration(
//                       color: Colors.black.withAlpha(115),
//                       shape: BoxShape.circle,
//                     ),
//                     child: const Icon(
//                       Icons.arrow_back,
//                       color: Colors.white,
//                       size: 18,
//                     ),
//                   ),
//                 ),
//               ),

//               // enroll button
//               if (!isEnrolled)
//                 Positioned(
//                   bottom: 14,
//                   child: _EnrollButton(
//                     isFree: widget.course.isFree,
//                     isLoading: isLoading,
//                     onTap: _enroll,
//                   ),
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   void _openFullscreen() {
//     if (!_videoInitialized || _videoController == null) return;
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => _FullscreenVideoScreen(controller: _videoController!),
//       ),
//     );
//   }

//   Widget _videoShimmer() => Shimmer.fromColors(
//     baseColor: Colors.grey.shade800,
//     highlightColor: Colors.grey.shade700,
//     child: Container(color: Colors.grey.shade800),
//   );

//   Widget _videoErrorWidget() => Container(
//     color: Colors.grey.shade900,
//     child: const Center(
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(Icons.videocam_off, color: Colors.white54, size: 36),
//           SizedBox(height: 8),
//           Text(
//             'Video unavailable',
//             style: TextStyle(color: Colors.white54, fontSize: 13),
//           ),
//         ],
//       ),
//     ),
//   );

//   // ── Lessons tab ───────────────────────────────────────────────────────────

//   Widget _buildLessonsTab(bool isEnrolled) {
//     final contents = widget.course.contents;
//     if (contents.isEmpty) return _emptyTab('No lessons available');

//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       itemCount: contents.length,
//       itemBuilder: (_, i) {
//         final c = contents[i];
//         final active = _selectedIndex == i;
//         return GestureDetector(
//           onTap:
//               isEnrolled
//                   ? () {
//                     setState(() {
//                       _selectedIndex = i;
//                     });
//                     _initVideo(c);
//                     _tabController.animateTo(0);
//                   }
//                   : null,
//           child: AnimatedContainer(
//             duration: const Duration(milliseconds: 200),
//             margin: const EdgeInsets.only(bottom: 10),
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: active ? const Color(0xFFEFF6FF) : Colors.white,
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(
//                 color: active ? Color(0xFF2563EB) : Colors.transparent,
//                 width: 1.5,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withAlpha(8),
//                   blurRadius: 6,
//                   offset: const Offset(0, 1),
//                 ),
//               ],
//             ),
//             child: Row(
//               children: [
//                 ClipRRect(
//                   borderRadius: BorderRadius.circular(8),
//                   child: SizedBox(
//                     width: 62,
//                     height: 46,
//                     child:
//                         c.thumbnail != null
//                             ? Image.network(
//                               c.thumbnail!,
//                               fit: BoxFit.cover,
//                               errorBuilder:
//                                   (_, __, ___) => _thumbPlaceholder(c.order),
//                             )
//                             : _thumbPlaceholder(c.order),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         c.title,
//                         style: const TextStyle(
//                           fontSize: 13,
//                           fontWeight: FontWeight.w600,
//                           color: Color(0xFF1E293B),
//                         ),
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                       const SizedBox(height: 5),
//                       Row(
//                         children: [
//                           const Icon(
//                             Icons.timer_outlined,
//                             size: 11,
//                             color: Color(0xFF94A3B8),
//                           ),
//                           const SizedBox(width: 3),
//                           Text(
//                             '${c.duration.toStringAsFixed(0)} min',
//                             style: const TextStyle(
//                               fontSize: 11,
//                               color: Color(0xFF94A3B8),
//                             ),
//                           ),
//                           const SizedBox(width: 8),
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 6,
//                               vertical: 2,
//                             ),
//                             decoration: BoxDecoration(
//                               color: Color(0xFFF5F7FA),
//                               borderRadius: BorderRadius.circular(4),
//                             ),
//                             child: Text(
//                               c.courseLevel.toUpperCase(),
//                               style: const TextStyle(
//                                 fontSize: 9,
//                                 fontWeight: FontWeight.w600,
//                                 color: Color(0xFF64748B),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 isEnrolled
//                     ? Icon(
//                       active
//                           ? Icons.pause_circle_filled
//                           : Icons.play_circle_outline,
//                       color: active ? Color(0xFF2563EB) : Color(0xFF94A3B8),
//                       size: 22,
//                     )
//                     : const Icon(
//                       Icons.lock_outline,
//                       size: 16,
//                       color: Color(0xFF94A3B8),
//                     ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _thumbPlaceholder(int order) => Container(
//     color: const Color(0xFFEFF6FF),
//     child: Center(
//       child: Text(
//         '$order',
//         style: const TextStyle(
//           fontWeight: FontWeight.bold,
//           color: Color(0xFF93C5FD),
//           fontSize: 16,
//         ),
//       ),
//     ),
//   );

//   // ── Docs tab ──────────────────────────────────────────────────────────────

//   Widget _buildDocsTab(bool isEnrolled) {
//     final docs =
//         widget.course.contents
//             .where(
//               (c) =>
//                   (c.documentUrl != null && c.documentUrl!.isNotEmpty) ||
//                   (c.documentFile != null && c.documentFile!.isNotEmpty),
//             )
//             .toList();
//     if (docs.isEmpty) return _emptyTab('No documents available');
//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       itemCount: docs.length,
//       itemBuilder: (_, i) => _DocItem(content: docs[i], isEnrolled: isEnrolled),
//     );
//   }

//   // ── About tab ─────────────────────────────────────────────────────────────

//   Widget _buildAboutTab(bool isEnrolled) {
//     final course = widget.course;
//     final instructor =
//         course.contents.isNotEmpty
//             ? course.contents.first.instructorName
//             : course.vendorName;
//     final isLoading = ref.watch(enrollLoadingProvider(course.id));

//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _AboutCard(
//             icon: Icons.person_outline,
//             label: 'Instructor',
//             value: instructor,
//             iconColor: const Color(0xFF8B5CF6),
//           ),
//           const SizedBox(height: 10),
//           _AboutCard(
//             icon: Icons.category_outlined,
//             label: 'Category',
//             value: course.categoryName,
//             iconColor: const Color(0xFFF59E0B),
//           ),
//           const SizedBox(height: 10),
//           _AboutCard(
//             icon: Icons.library_books_outlined,
//             label: 'Total Lessons',
//             value: '${course.contents.length} lessons',
//             iconColor: Color(0xFF10B981),
//           ),
//           if (!course.isFree) ...[
//             const SizedBox(height: 10),
//             _AboutCard(
//               icon: Icons.sell_outlined,
//               label: 'Price',
//               value: 'Rs. ${course.price.toStringAsFixed(0)}',
//               iconColor: Color(0xFF2563EB),
//             ),
//           ],
//           const SizedBox(height: 16),
//           const Text(
//             'About this Course',
//             style: TextStyle(
//               fontSize: 15,
//               fontWeight: FontWeight.bold,
//               color: Color(0xFF1E293B),
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             course.description,
//             style: TextStyle(
//               fontSize: 14,
//               color: Colors.grey.shade700,
//               height: 1.65,
//             ),
//           ),
//           const SizedBox(height: 24),
//           if (!isEnrolled)
//             _EnrollButton(
//               isFree: course.isFree,
//               isLoading: isLoading,
//               onTap: _enroll,
//               fullWidth: true,
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _emptyTab(String msg) => Center(
//     child: Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
//         const SizedBox(height: 8),
//         Text(
//           msg,
//           style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
//         ),
//       ],
//     ),
//   );
// }

// // ─── Video Player With Full Controls ──────────────────────────────────────────

// class _VideoPlayerWithControls extends StatefulWidget {
//   final VideoPlayerController controller;
//   final VoidCallback onFullscreen;

//   const _VideoPlayerWithControls({
//     required this.controller,
//     required this.onFullscreen,
//   });

//   @override
//   State<_VideoPlayerWithControls> createState() =>
//       _VideoPlayerWithControlsState();
// }

// class _VideoPlayerWithControlsState extends State<_VideoPlayerWithControls> {
//   bool _showControls = true;
//   bool _isDragging = false;

//   // Available playback speeds
//   static const List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
//   double _currentSpeed = 1.0;

//   // Auto-hide timer
//   DateTime _lastTap = DateTime.now();

   
//   @override
//   void initState() {
//     super.initState();
//     widget.controller.addListener(_onControllerUpdate);
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (mounted) setState(() {});
//     });
//     _scheduleHide();
//   }

// @override
// void didUpdateWidget(_VideoPlayerWithControls oldWidget) {
//   super.didUpdateWidget(oldWidget);
//   if (oldWidget.controller != widget.controller) {
//     oldWidget.controller.removeListener(_onControllerUpdate);
//     widget.controller.addListener(_onControllerUpdate);
//     _currentSpeed = 1.0;  
//     setState(() {});
//   }
// }


//   void _onControllerUpdate() {
//     if (mounted) setState(() {});
//   }

//   void _scheduleHide() {
//     Future.delayed(const Duration(seconds: 3), () {
//       if (!mounted) return;
//       final elapsed = DateTime.now().difference(_lastTap).inSeconds;
//       if (elapsed >= 3 && !_isDragging) {
//         setState(() => _showControls = false);
//       }
//     });
//   }

//   void _toggleControls() {
//     setState(() {
//       _showControls = !_showControls;
//       _lastTap = DateTime.now();
//     });
//     if (_showControls) _scheduleHide();
//   }

//   // void _skip(int seconds) {
//   //   final current = widget.controller.value.position;
//   //   final total = widget.controller.value.duration;
//   //   final target = current + Duration(seconds: seconds);
//   //   final clamped =
//   //       target < Duration.zero
//   //           ? Duration.zero
//   //           : (target > total ? total : target);
//   //   widget.controller.seekTo(clamped);
//   // }
//   void _skip(int seconds) {
//     final total = widget.controller.value.duration;
//     if (total == Duration.zero) return;
//     final current = widget.controller.value.position;
//     final target = current + Duration(seconds: seconds);
//     final clamped =
//         target < Duration.zero
//             ? Duration.zero
//             : (target > total ? total : target);
//     widget.controller.seekTo(clamped);
//   }

//   String _formatDuration(Duration d) {
//     final h = d.inHours;
//     final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
//     final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
//     return h > 0 ? '$h:$m:$s' : '$m:$s';
//   }

//   void _setSpeed(double speed) {
//     setState(() => _currentSpeed = speed);
//     widget.controller.setPlaybackSpeed(speed);
//   }

//   void _showSpeedPicker() {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: const Color(0xFF1E293B),
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder:
//           (_) => Padding(
//             padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'Playback Speed',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 ..._speeds.map((s) {
//                   final selected = s == _currentSpeed;
//                   return GestureDetector(
//                     onTap: () {
//                       _setSpeed(s);
//                       Navigator.pop(context);
//                     },
//                     child: Container(
//                       margin: const EdgeInsets.only(bottom: 8),
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 16,
//                         vertical: 12,
//                       ),
//                       decoration: BoxDecoration(
//                         color:
//                             selected
//                                 ? const Color(0xFF2563EB)
//                                 : Colors.white.withAlpha(20),
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: Row(
//                         children: [
//                           Text(
//                             s == 1.0 ? 'Normal (1x)' : '${s}x',
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontWeight:
//                                   selected
//                                       ? FontWeight.bold
//                                       : FontWeight.normal,
//                             ),
//                           ),
//                           const Spacer(),
//                           if (selected)
//                             const Icon(
//                               Icons.check,
//                               color: Colors.white,
//                               size: 18,
//                             ),
//                         ],
//                       ),
//                     ),
//                   );
//                 }),
//               ],
//             ),
//           ),
//     );
//   }

//   @override
//   void dispose() {
//     widget.controller.removeListener(_onControllerUpdate);
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final ctrl = widget.controller;
//     final value = ctrl.value;
//     final isPlaying = value.isPlaying;
//     final position = value.position;
//     final duration = value.duration;
//     final progress =
//         duration.inMilliseconds > 0
//             ? position.inMilliseconds / duration.inMilliseconds
//             : 0.0;

//     return GestureDetector(
//       onTap: _toggleControls,
//       child: Stack(
//         fit: StackFit.expand,
//         children: [
//           // ── Video ─────────────────────────────────────────────────────────
//           FittedBox(
//             fit: BoxFit.cover,
//             child: SizedBox(
//               width: value.size.width,
//               height: value.size.height,
//               child: VideoPlayer(ctrl),
//             ),
//           ),

//           // ── Controls overlay ──────────────────────────────────────────────
//           AnimatedOpacity(
//             opacity: _showControls ? 1.0 : 0.0,
//             duration: const Duration(milliseconds: 250),
//             child: IgnorePointer(
//               ignoring: !_showControls,
//               child: Container(
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                     colors: [
//                       Colors.black.withAlpha(160),
//                       Colors.transparent,
//                       Colors.transparent,
//                       Colors.black.withAlpha(200),
//                     ],
//                     stops: const [0.0, 0.3, 0.6, 1.0],
//                   ),
//                 ),
//                 child: Stack(
//                   children: [
//                     // ── Top row: speed + fullscreen ───────────────────────────
//                     Positioned(
//                       top: 8,
//                       right: 8,
//                       child: Row(
//                         children: [
//                           // Speed button
//                           GestureDetector(
//                             behavior: HitTestBehavior.opaque,
//                             onTap: () {
//                               _lastTap = DateTime.now();
//                               _showSpeedPicker();
//                             },
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 10,
//                                 vertical: 5,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: Colors.black.withAlpha(130),
//                                 borderRadius: BorderRadius.circular(6),
//                                 border: Border.all(
//                                   color: Colors.white.withAlpha(60),
//                                 ),
//                               ),
//                               child: Text(
//                                 _currentSpeed == 1.0 ? '1x' : '${_currentSpeed}x',
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 8),
//                           // Fullscreen button
//                           GestureDetector(
//                             onTap: () {
//                               _lastTap = DateTime.now();
//                               widget.onFullscreen();
//                             },
//                             child: Container(
//                               padding: const EdgeInsets.all(6),
//                               decoration: BoxDecoration(
//                                 color: Colors.black.withAlpha(130),
//                                 borderRadius: BorderRadius.circular(6),
//                                 border: Border.all(
//                                   color: Colors.white.withAlpha(60),
//                                 ),
//                               ),
//                               child: const Icon(
//                                 Icons.fullscreen,
//                                 color: Colors.white,
//                                 size: 18,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
              
//                     // ── Centre row: skip back | play/pause | skip forward ─────
//                     Center(
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           // Skip back 10s
//                           GestureDetector(
//                             onTap: () {
//                               _lastTap = DateTime.now();
//                               _skip(-10);
//                             },
//                             child: Container(
//                               padding: const EdgeInsets.all(10),
//                               decoration: BoxDecoration(
//                                 color: Colors.black.withAlpha(100),
//                                 shape: BoxShape.circle,
//                               ),
//                               child: const Icon(
//                                 Icons.replay_10,
//                                 color: Colors.white,
//                                 size: 28,
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 24),
              
//                           // Play / Pause
//                           GestureDetector(
//                             onTap: () {
//                               _lastTap = DateTime.now();
//                               setState(
//                                 () => isPlaying ? ctrl.pause() : ctrl.play(),
//                               );
//                             },
//                             child: Container(
//                               padding: const EdgeInsets.all(14),
//                               decoration: BoxDecoration(
//                                 color: Colors.black.withAlpha(140),
//                                 shape: BoxShape.circle,
//                                 border: Border.all(
//                                   color: Colors.white.withAlpha(80),
//                                   width: 2,
//                                 ),
//                               ),
//                               child: Icon(
//                                 isPlaying
//                                     ? Icons.pause_rounded
//                                     : Icons.play_arrow_rounded,
//                                 color: Colors.white,
//                                 size: 36,
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 24),
              
//                           // Skip forward 10s
//                           GestureDetector(
//                             onTap: () {
//                               _lastTap = DateTime.now();
//                               _skip(10);
//                             },
//                             child: Container(
//                               padding: const EdgeInsets.all(10),
//                               decoration: BoxDecoration(
//                                 color: Colors.black.withAlpha(100),
//                                 shape: BoxShape.circle,
//                               ),
//                               child: const Icon(
//                                 Icons.forward_10,
//                                 color: Colors.white,
//                                 size: 28,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
              
//                     // ── Bottom: time + seek bar ───────────────────────────────
//                     Positioned(
//                       bottom: 0,
//                       left: 0,
//                       right: 0,
//                       child: Padding(
//                         padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
//                         child: Column(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             // Time labels
//                             Row(
//                               children: [
//                                 Text(
//                                   _formatDuration(position),
//                                   style: const TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 11,
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                                 const Spacer(),
//                                 Text(
//                                   _formatDuration(duration),
//                                   style: TextStyle(
//                                     color: Colors.white.withAlpha(180),
//                                     fontSize: 11,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 4),
              
//                             // Seek slider
//                             SliderTheme(
//                               data: SliderTheme.of(context).copyWith(
//                                 trackHeight: 3,
//                                 thumbShape: const RoundSliderThumbShape(
//                                   enabledThumbRadius: 7,
//                                 ),
//                                 overlayShape: const RoundSliderOverlayShape(
//                                   overlayRadius: 14,
//                                 ),
//                                 activeTrackColor: const Color(0xFF2563EB),
//                                 inactiveTrackColor: Colors.white.withAlpha(60),
//                                 thumbColor: Colors.white,
//                                 overlayColor: Colors.white.withAlpha(40),
//                               ),
//                               child: Slider(
//                                 value: progress.clamp(0.0, 1.0),
//                                 onChangeStart: (_) {
//                                   setState(() => _isDragging = true);
//                                   _lastTap = DateTime.now();
//                                 },
//                                 // onChanged: (v) {
//                                 //   final target = Duration(
//                                 //     milliseconds:
//                                 //         (v * duration.inMilliseconds).toInt(),
//                                 //   );
//                                 //   ctrl.seekTo(target);
//                                 //   setState(() {});
//                                 // },
//                                 onChanged: (v) {
//                 final dur = widget.controller.value.duration;
//                 if (dur == Duration.zero) return; // <-- add this guard
//                 final target = Duration(
//                   milliseconds: (v * dur.inMilliseconds).toInt(),
//                 );
//                 widget.controller.seekTo(target);
//                 setState(() {});
//               },
//                                 onChangeEnd: (_) {
//                                   setState(() => _isDragging = false);
//                                   _scheduleHide();
//                                 },
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ─── Fullscreen Video Screen ──────────────────────────────────────────────────

// class _FullscreenVideoScreen extends StatefulWidget {
//   final VideoPlayerController controller;
//   const _FullscreenVideoScreen({required this.controller});

//   @override
//   State<_FullscreenVideoScreen> createState() => _FullscreenVideoScreenState();
// }

// class _FullscreenVideoScreenState extends State<_FullscreenVideoScreen> {
//   @override
//   void initState() {
//     super.initState();
//     // Force landscape on entering fullscreen
//     SystemChrome.setPreferredOrientations([
//       DeviceOrientation.landscapeLeft,
//       DeviceOrientation.landscapeRight,
//     ]);
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
//   }

//   @override
//   void dispose() {
//     // Restore portrait on exit
//     SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: SafeArea(
//         child: _VideoPlayerWithControls(
//           controller: widget.controller,
//           onFullscreen: () => Navigator.pop(context), // exit fullscreen
//         ),
//       ),
//     );
//   }
// }

// // ─── Locked Overlay ───────────────────────────────────────────────────────────

// class _LockedOverlay extends StatelessWidget {
//   final CourseListModel course;
//   const _LockedOverlay({required this.course});

//   @override
//   Widget build(BuildContext context) {
//     final thumb =
//         course.contents.isNotEmpty ? course.contents.first.thumbnail : null;
//     return Stack(
//       fit: StackFit.expand,
//       children: [
//         if (thumb != null)
//           Image.network(
//             thumb,
//             fit: BoxFit.cover,
//             errorBuilder:
//                 (_, __, ___) => Container(color: Colors.grey.shade900),
//           )
//         else
//           Container(color: Colors.grey.shade900),
//         Container(color: Colors.black.withAlpha(140)),
//         Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(14),
//               decoration: BoxDecoration(
//                 color: Colors.white.withAlpha(38),
//                 shape: BoxShape.circle,
//               ),
//               child: const Icon(
//                 Icons.lock_outline,
//                 color: Colors.white,
//                 size: 34,
//               ),
//             ),
//             const SizedBox(height: 10),
//             Text(
//               course.isFree
//                   ? 'Enroll for free to watch'
//                   : 'Pay to enroll and unlock',
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 13,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }
// }

// // ─── Enroll Button ────────────────────────────────────────────────────────────

// class _EnrollButton extends StatelessWidget {
//   final bool isFree;
//   final bool isLoading;
//   final VoidCallback onTap;
//   final bool fullWidth;

//   const _EnrollButton({
//     required this.isFree,
//     required this.isLoading,
//     required this.onTap,
//     this.fullWidth = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final color = isFree ? Color(0xFF10B981) : Color(0xFF2563EB);
//     final label = isFree ? 'Enroll for Free' : 'Pay to Enroll';
//     final icon = isFree ? Icons.school_rounded : Icons.payment_rounded;

//     return GestureDetector(
//       onTap: isLoading ? null : onTap,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 200),
//         width: fullWidth ? double.infinity : null,
//         padding: EdgeInsets.symmetric(
//           horizontal: fullWidth ? 0 : 26,
//           vertical: 13,
//         ),
//         decoration: BoxDecoration(
//           color: color,
//           borderRadius: BorderRadius.circular(fullWidth ? 12 : 30),
//           boxShadow: [
//             BoxShadow(
//               color: color.withAlpha(90),
//               blurRadius: 12,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child:
//             isLoading
//                 ? const Center(
//                   child: SizedBox(
//                     height: 20,
//                     width: 20,
//                     child: CircularProgressIndicator(
//                       color: Colors.white,
//                       strokeWidth: 2,
//                     ),
//                   ),
//                 )
//                 : Row(
//                   mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(icon, color: Colors.white, size: 18),
//                     const SizedBox(width: 8),
//                     Text(
//                       label,
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 14,
//                       ),
//                     ),
//                   ],
//                 ),
//       ),
//     );
//   }
// }

// // ─── Course Badge ─────────────────────────────────────────────────────────────

// class _CourseBadge extends StatelessWidget {
//   final bool isFree;
//   const _CourseBadge({required this.isFree});

//   @override
//   Widget build(BuildContext context) => Container(
//     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//     decoration: BoxDecoration(
//       color: isFree ? const Color(0xFFD1FAE5) : const Color(0xFFDBEAFE),
//       borderRadius: BorderRadius.circular(20),
//     ),
//     child: Text(
//       isFree ? 'Free' : 'Paid',
//       style: TextStyle(
//         fontSize: 12,
//         fontWeight: FontWeight.w600,
//         color: isFree ? const Color(0xFF059669) : Color(0xFF2563EB),
//       ),
//     ),
//   );
// }

// // ─── Doc Item ─────────────────────────────────────────────────────────────────

// class _DocItem extends StatelessWidget {
//   final CourseContent content;
//   final bool isEnrolled;
//   const _DocItem({required this.content, required this.isEnrolled});

//   String? get _url => content.documentUrl ?? content.documentFile;

//   @override
//   Widget build(BuildContext context) => Container(
//     margin: const EdgeInsets.only(bottom: 10),
//     padding: const EdgeInsets.all(14),
//     decoration: BoxDecoration(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(12),
//       boxShadow: [
//         BoxShadow(
//           color: Colors.black.withAlpha(8),
//           blurRadius: 6,
//           offset: const Offset(0, 1),
//         ),
//       ],
//     ),
//     child: Row(
//       children: [
//         Container(
//           padding: const EdgeInsets.all(10),
//           decoration: BoxDecoration(
//             color: const Color(0xFFFEF3C7),
//             borderRadius: BorderRadius.circular(10),
//           ),
//           child: const Icon(
//             Icons.picture_as_pdf,
//             color: Color(0xFFF59E0B),
//             size: 22,
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 content.title,
//                 style: const TextStyle(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w600,
//                   color: Color(0xFF1E293B),
//                 ),
//                 maxLines: 2,
//                 overflow: TextOverflow.ellipsis,
//               ),
//               const SizedBox(height: 3),
//               Text(
//                 'Lesson ${content.order} · Document',
//                 style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(width: 8),
//         isEnrolled
//             ? GestureDetector(
//               onTap:
//                   _url != null
//                       ? () => Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder:
//                               (_) => _PdfViewScreen(
//                                 url: _url!,
//                                 title: content.title,
//                               ),
//                         ),
//                       )
//                       : null,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 12,
//                   vertical: 6,
//                 ),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFEFF6FF),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: const Text(
//                   'View',
//                   style: TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.w600,
//                     color: Color(0xFF2563EB),
//                   ),
//                 ),
//               ),
//             )
//             : const Icon(
//               Icons.lock_outline,
//               size: 16,
//               color: Color(0xFF94A3B8),
//             ),
//       ],
//     ),
//   );
// }

// // ─── PDF Viewer ───────────────────────────────────────────────────────────────

// class _PdfViewScreen extends StatelessWidget {
//   final String url;
//   final String title;
//   const _PdfViewScreen({required this.url, required this.title});

//   @override
//   Widget build(BuildContext context) => Scaffold(
//     appBar: AppBar(
//       title: Text(
//         title,
//         style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
//       ),
//       backgroundColor: Colors.white,
//       foregroundColor: Color(0xFF1E293B),
//       elevation: 0,
//       bottom: PreferredSize(
//         preferredSize: const Size.fromHeight(1),
//         child: Container(height: 1, color: Color(0xFFE2E8F0)),
//       ),
//     ),
//     body: SfPdfViewer.network(url),
//   );
// }

// // ─── About Card ───────────────────────────────────────────────────────────────

// class _AboutCard extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final String value;
//   final Color iconColor;
//   const _AboutCard({
//     required this.icon,
//     required this.label,
//     required this.value,
//     required this.iconColor,
//   });

//   @override
//   Widget build(BuildContext context) => Container(
//     padding: const EdgeInsets.all(14),
//     decoration: BoxDecoration(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(12),
//       boxShadow: [
//         BoxShadow(
//           color: Colors.black.withAlpha(8),
//           blurRadius: 6,
//           offset: const Offset(0, 1),
//         ),
//       ],
//     ),
//     child: Row(
//       children: [
//         Container(
//           padding: const EdgeInsets.all(9),
//           decoration: BoxDecoration(
//             color: iconColor.withAlpha(25),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Icon(icon, color: iconColor, size: 20),
//         ),
//         const SizedBox(width: 12),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               label,
//               style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
//             ),
//             const SizedBox(height: 3),
//             Text(
//               value,
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w600,
//                 color: Color(0xFF1E293B),
//               ),
//             ),
//           ],
//         ),
//       ],
//     ),
//   );
// }



import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/elearning/model/course_list_model.dart';
import 'package:innovator/elearning/provider/course_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:shimmer/shimmer.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final CourseListModel course;
  const CourseDetailScreen({Key? key, required this.course}) : super(key: key);

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  VideoPlayerController? _videoController;

  bool _videoInitialized = false;
  bool _videoError = false;
  bool _isVideoLoading = false;
  int _selectedIndex = 0;
  bool _videoStarted = false;

  static const List<String> _tabs = ['Lessons', 'Docs', 'About'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartVideo());
  }

  void _maybeStartVideo() {
    if (_videoStarted || !mounted) return;
    final enrolled = ref.read(enrolledCoursesProvider).contains(widget.course.id);
    if (enrolled && widget.course.contents.isNotEmpty) {
      _videoStarted = true;
      _initVideo(widget.course.contents.first);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _videoController?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // ── video init ────────────────────────────────────────────────────────────
  //
  // KEY FIX: save old controller reference, clear state first, THEN dispose
  // old controller so the widget tree has already detached from it before
  // dispose() is called. This prevents a disposed-controller listener from
  // accidentally firing and resetting position/duration.
  void _initVideo(CourseContent content) {
    final oldController = _videoController;

    setState(() {
      _videoController = null;
      _videoInitialized = false;
      _videoError = false;
      _isVideoLoading = true;
    });

    oldController?.dispose();

    final url =
        (content.videoUrl != null && content.videoUrl!.isNotEmpty)
            ? content.videoUrl!
            : (content.videoFile != null && content.videoFile!.isNotEmpty)
            ? content.videoFile!
            : null;

    if (url == null) {
      setState(() {
        _videoError = true;
        _isVideoLoading = false;
      });
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    controller.initialize().then((_) {
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _videoController = controller;
        _videoInitialized = true;
        _isVideoLoading = false;
      });
    }).catchError((_) {
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _videoError = true;
        _isVideoLoading = false;
      });
    });
  }

  // ── enroll ────────────────────────────────────────────────────────────────

  Future<void> _enroll() async {
    final courseId = widget.course.id;
    ref.read(enrollLoadingProvider(courseId).notifier).setLoading(true);
    try {
      await ref.read(courseServiceProvider).enrollCourse(courseId);
      ref.read(enrolledCoursesProvider.notifier).enroll(courseId);
      ref.read(enrollLoadingProvider(courseId).notifier).setLoading(false);
      _videoStarted = true;
      if (widget.course.contents.isNotEmpty) {
        _initVideo(widget.course.contents.first);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.course.isFree
                  ? 'Enrolled! Start learning now. 🎉'
                  : 'Request sent. Complete payment to unlock.',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      ref.read(enrollLoadingProvider(courseId).notifier).setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enrolledIds = ref.watch(enrolledCoursesProvider);
    final isEnrolled = enrolledIds.contains(widget.course.id);

    if (isEnrolled && !_videoStarted) {
      _videoStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.course.contents.isNotEmpty) {
          _initVideo(widget.course.contents.first);
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildVideoSection(isEnrolled),
          _buildTitleBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLessonsTab(isEnrolled),
                _buildDocsTab(isEnrolled),
                _buildAboutTab(isEnrolled),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── title bar ─────────────────────────────────────────────────────────────

  Widget _buildTitleBar() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.course.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _CourseBadge(isFree: widget.course.isFree),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
            labelColor: const Color(0xFF2563EB),
            unselectedLabelColor: const Color(0xFF94A3B8),
            indicatorColor: const Color(0xFF2563EB),
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ── video section ─────────────────────────────────────────────────────────

  Widget _buildVideoSection(bool isEnrolled) {
    final isLoading = ref.watch(enrollLoadingProvider(widget.course.id));
    return Container(
      color: Colors.black,
      width: double.infinity,
      child: SafeArea(
        bottom: false,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!isEnrolled)
                _LockedOverlay(course: widget.course)
              else if (_isVideoLoading)
                _videoShimmer()
              else if (_videoError)
                _videoErrorWidget()
              else if (_videoInitialized && _videoController != null)
                // ValueKey ensures a brand-new widget (and initState) per controller
                _VideoPlayerWithControls(
                  key: ValueKey(_videoController),
                  controller: _videoController!,
                  onFullscreen: _openFullscreen,
                )
              else
                _videoShimmer(),

              // back button
              Positioned(
                top: 10,
                left: 10,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(115),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),

              if (!isEnrolled)
                Positioned(
                  bottom: 14,
                  child: _EnrollButton(
                    isFree: widget.course.isFree,
                    isLoading: isLoading,
                    onTap: _enroll,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFullscreen() {
    if (!_videoInitialized || _videoController == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenVideoScreen(controller: _videoController!),
      ),
    );
  }

  Widget _videoShimmer() => Shimmer.fromColors(
    baseColor: Colors.grey.shade800,
    highlightColor: Colors.grey.shade700,
    child: Container(color: Colors.grey.shade800),
  );

  Widget _videoErrorWidget() => Container(
    color: Colors.grey.shade900,
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off, color: Colors.white54, size: 36),
          SizedBox(height: 8),
          Text(
            'Video unavailable',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    ),
  );

  // ── Lessons tab ───────────────────────────────────────────────────────────

  Widget _buildLessonsTab(bool isEnrolled) {
    final contents = widget.course.contents;
    if (contents.isEmpty) return _emptyTab('No lessons available');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: contents.length,
      itemBuilder: (_, i) {
        final c = contents[i];
        final active = _selectedIndex == i;
        return GestureDetector(
          onTap:
              isEnrolled
                  ? () {
                    setState(() => _selectedIndex = i);
                    _initVideo(c);
                    _tabController.animateTo(0);
                  }
                  : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFEFF6FF) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? const Color(0xFF2563EB) : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 62,
                    height: 46,
                    child:
                        c.thumbnail != null
                            ? Image.network(
                              c.thumbnail!,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => _thumbPlaceholder(c.order),
                            )
                            : _thumbPlaceholder(c.order),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 11,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${c.duration.toStringAsFixed(0)} min',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              c.courseLevel.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                isEnrolled
                    ? Icon(
                      active
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_outline,
                      color:
                          active
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF94A3B8),
                      size: 22,
                    )
                    : const Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _thumbPlaceholder(int order) => Container(
    color: const Color(0xFFEFF6FF),
    child: Center(
      child: Text(
        '$order',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF93C5FD),
          fontSize: 16,
        ),
      ),
    ),
  );

  // ── Docs tab ──────────────────────────────────────────────────────────────

  Widget _buildDocsTab(bool isEnrolled) {
    final docs =
        widget.course.contents
            .where(
              (c) =>
                  (c.documentUrl != null && c.documentUrl!.isNotEmpty) ||
                  (c.documentFile != null && c.documentFile!.isNotEmpty),
            )
            .toList();
    if (docs.isEmpty) return _emptyTab('No documents available');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (_, i) =>
          _DocItem(content: docs[i], isEnrolled: isEnrolled),
    );
  }

  // ── About tab ─────────────────────────────────────────────────────────────

  Widget _buildAboutTab(bool isEnrolled) {
    final course = widget.course;
    final instructor =
        course.contents.isNotEmpty
            ? course.contents.first.instructorName
            : course.vendorName;
    final isLoading = ref.watch(enrollLoadingProvider(course.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AboutCard(
            icon: Icons.person_outline,
            label: 'Instructor',
            value: instructor,
            iconColor: const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 10),
          _AboutCard(
            icon: Icons.category_outlined,
            label: 'Category',
            value: course.categoryName,
            iconColor: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 10),
          _AboutCard(
            icon: Icons.library_books_outlined,
            label: 'Total Lessons',
            value: '${course.contents.length} lessons',
            iconColor: const Color(0xFF10B981),
          ),
          if (!course.isFree) ...[
            const SizedBox(height: 10),
            _AboutCard(
              icon: Icons.sell_outlined,
              label: 'Price',
              value: 'Rs. ${course.price.toStringAsFixed(0)}',
              iconColor: const Color(0xFF2563EB),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'About this Course',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            course.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 24),
          if (!isEnrolled)
            _EnrollButton(
              isFree: course.isFree,
              isLoading: isLoading,
              onTap: _enroll,
              fullWidth: true,
            ),
        ],
      ),
    );
  }

  Widget _emptyTab(String msg) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 8),
        Text(
          msg,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
      ],
    ),
  );
}

// ─── Video Player With Full Controls ──────────────────────────────────────────

class _VideoPlayerWithControls extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onFullscreen;

  const _VideoPlayerWithControls({
    Key? key,
    required this.controller,
    required this.onFullscreen,
  }) : super(key: key);

  @override
  State<_VideoPlayerWithControls> createState() =>
      _VideoPlayerWithControlsState();
}

class _VideoPlayerWithControlsState extends State<_VideoPlayerWithControls> {
  bool _showControls = true;
  bool _isDragging = false;

  static const List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  double _currentSpeed = 1.0;
  DateTime _lastTap = DateTime.now();

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  // No manual addListener needed — ValueListenableBuilder handles all
  // position/duration/isPlaying updates automatically and re-subscribes
  // whenever widget.controller changes.

  void _scheduleHide() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(_lastTap).inSeconds;
      if (elapsed >= 3 && !_isDragging) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      _lastTap = DateTime.now();
    });
    if (_showControls) _scheduleHide();
  }

  void _skip(int seconds) {
    final ctrl = widget.controller;
    final duration = ctrl.value.duration;
    if (duration == Duration.zero) return;
    final current = ctrl.value.position;
    final target = current + Duration(seconds: seconds);
    final clamped =
        target < Duration.zero
            ? Duration.zero
            : (target > duration ? duration : target);
    ctrl.seekTo(clamped);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _setSpeed(double speed) {
    setState(() => _currentSpeed = speed);
    widget.controller.setPlaybackSpeed(speed);
  }

  void _showSpeedPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (_) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Playback Speed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ..._speeds.map((s) {
                  final selected = s == _currentSpeed;
                  return GestureDetector(
                    onTap: () {
                      _setSpeed(s);
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            selected
                                ? const Color(0xFF2563EB)
                                : Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Text(
                            s == 1.0 ? 'Normal (1x)' : '${s}x',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight:
                                  selected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                          const Spacer(),
                          if (selected)
                            const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Video ─────────────────────────────────────────────────────────
          // ValueListenableBuilder picks up size changes (e.g. first frame)
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: widget.controller,
            builder: (_, value, __) {
              final w = value.size.width > 0 ? value.size.width : 16.0;
              final h = value.size.height > 0 ? value.size.height : 9.0;
              return FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: w,
                  height: h,
                  child: VideoPlayer(widget.controller),
                ),
              );
            },
          ),

          // ── Controls overlay ──────────────────────────────────────────────
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_showControls,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(160),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withAlpha(200),
                    ],
                    stops: const [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
                // ValueListenableBuilder reads position/duration/isPlaying
                // directly from the controller on every controller event —
                // no manual setState listener needed, no stale values.
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: widget.controller,
                  builder: (_, value, __) {
                    final isPlaying = value.isPlaying;
                    final position = value.position;
                    final duration = value.duration;
                    final progress =
                        duration.inMilliseconds > 0
                            ? (position.inMilliseconds /
                                    duration.inMilliseconds)
                                .clamp(0.0, 1.0)
                            : 0.0;

                    return Stack(
                      children: [
                        // ── Top: speed + fullscreen ──────────────────────────
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {}, // absorb — stop bubble to _toggleControls
                            child: Row(
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    _lastTap = DateTime.now();
                                    _showSpeedPicker();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(130),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.white.withAlpha(60),
                                      ),
                                    ),
                                    child: Text(
                                      _currentSpeed == 1.0
                                          ? '1x'
                                          : '${_currentSpeed}x',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    _lastTap = DateTime.now();
                                    widget.onFullscreen();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(130),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.white.withAlpha(60),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.fullscreen,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── Centre: skip back | play/pause | skip forward ────
                        Center(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {}, // absorb
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    _lastTap = DateTime.now();
                                    _skip(-10);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(100),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.replay_10,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 24),

                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    _lastTap = DateTime.now();
                                    isPlaying
                                        ? widget.controller.pause()
                                        : widget.controller.play();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(140),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withAlpha(80),
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 36,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 24),

                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    _lastTap = DateTime.now();
                                    _skip(10);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(100),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.forward_10,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── Bottom: time + seek bar ──────────────────────────
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {}, // absorb
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _formatDuration(position),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _formatDuration(duration),
                                        style: TextStyle(
                                          color: Colors.white.withAlpha(180),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 3,
                                      thumbShape:
                                          const RoundSliderThumbShape(
                                            enabledThumbRadius: 7,
                                          ),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                            overlayRadius: 14,
                                          ),
                                      activeTrackColor:
                                          const Color(0xFF2563EB),
                                      inactiveTrackColor:
                                          Colors.white.withAlpha(60),
                                      thumbColor: Colors.white,
                                      overlayColor:
                                          Colors.white.withAlpha(40),
                                    ),
                                    child: Slider(
                                      value: progress,
                                      onChangeStart: (_) {
                                        _isDragging = true;
                                        _lastTap = DateTime.now();
                                      },
                                      onChanged: (v) {
                                        if (duration == Duration.zero) return;
                                        widget.controller.seekTo(
                                          Duration(
                                            milliseconds: (v *
                                                    duration.inMilliseconds)
                                                .toInt(),
                                          ),
                                        );
                                      },
                                      onChangeEnd: (_) {
                                        _isDragging = false;
                                        _scheduleHide();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Fullscreen Video Screen ──────────────────────────────────────────────────

class _FullscreenVideoScreen extends StatefulWidget {
  final VideoPlayerController controller;
  const _FullscreenVideoScreen({required this.controller});

  @override
  State<_FullscreenVideoScreen> createState() => _FullscreenVideoScreenState();
}

class _FullscreenVideoScreenState extends State<_FullscreenVideoScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _VideoPlayerWithControls(
          key: ValueKey(widget.controller),
          controller: widget.controller,
          onFullscreen: () => Navigator.pop(context),
        ),
      ),
    );
  }
}

// ─── Locked Overlay ───────────────────────────────────────────────────────────

class _LockedOverlay extends StatelessWidget {
  final CourseListModel course;
  const _LockedOverlay({required this.course});

  @override
  Widget build(BuildContext context) {
    final thumb =
        course.contents.isNotEmpty ? course.contents.first.thumbnail : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumb != null)
          Image.network(
            thumb,
            fit: BoxFit.cover,
            errorBuilder:
                (_, __, ___) => Container(color: Colors.grey.shade900),
          )
        else
          Container(color: Colors.grey.shade900),
        Container(color: Colors.black.withAlpha(140)),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(38),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              course.isFree
                  ? 'Enroll for free to watch'
                  : 'Pay to enroll and unlock',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Enroll Button ────────────────────────────────────────────────────────────

class _EnrollButton extends StatelessWidget {
  final bool isFree;
  final bool isLoading;
  final VoidCallback onTap;
  final bool fullWidth;

  const _EnrollButton({
    required this.isFree,
    required this.isLoading,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isFree ? const Color(0xFF10B981) : const Color(0xFF2563EB);
    final label = isFree ? 'Enroll for Free' : 'Pay to Enroll';
    final icon = isFree ? Icons.school_rounded : Icons.payment_rounded;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: fullWidth ? 0 : 26,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(fullWidth ? 12 : 30),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(90),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child:
            isLoading
                ? const Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
                : Row(
                  mainAxisSize:
                      fullWidth ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

// ─── Course Badge ─────────────────────────────────────────────────────────────

class _CourseBadge extends StatelessWidget {
  final bool isFree;
  const _CourseBadge({required this.isFree});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: isFree ? const Color(0xFFD1FAE5) : const Color(0xFFDBEAFE),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      isFree ? 'Free' : 'Paid',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isFree ? const Color(0xFF059669) : const Color(0xFF2563EB),
      ),
    ),
  );
}

// ─── Doc Item ─────────────────────────────────────────────────────────────────

class _DocItem extends StatelessWidget {
  final CourseContent content;
  final bool isEnrolled;
  const _DocItem({required this.content, required this.isEnrolled});

  String? get _url => content.documentUrl ?? content.documentFile;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(8),
          blurRadius: 6,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.picture_as_pdf,
            color: Color(0xFFF59E0B),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                'Lesson ${content.order} · Document',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        isEnrolled
            ? GestureDetector(
              onTap:
                  _url != null
                      ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => _PdfViewScreen(
                                url: _url!,
                                title: content.title,
                              ),
                        ),
                      )
                      : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'View',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            )
            : const Icon(
              Icons.lock_outline,
              size: 16,
              color: Color(0xFF94A3B8),
            ),
      ],
    ),
  );
}

// ─── PDF Viewer ───────────────────────────────────────────────────────────────

class _PdfViewScreen extends StatelessWidget {
  final String url;
  final String title;
  const _PdfViewScreen({required this.url, required this.title});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1E293B),
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFE2E8F0)),
      ),
    ),
    body: SfPdfViewer.network(url),
  );
}

// ─── About Card ───────────────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  const _AboutCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(8),
          blurRadius: 6,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}