// import 'dart:async'; 
// import 'package:flutter/material.dart';
// import 'package:innovator/Innovator/App_data/App_data.dart';
// import 'package:innovator/elearning/course_details_screen.dart';
// import 'package:innovator/elearning/services/api_services.dart'; 
// import 'dart:developer' as developer;
// import 'package:lottie/lottie.dart'; 

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;

//   String _greeting = 'Good Morning';
//   String _searchQuery = '';
//   String _selectedFilter = 'All';
//   Timer? _timer;

//   List<Map<String, dynamic>> _courses = [];
//   List<Map<String, dynamic>> _filteredCourses = [];
//   List<Map<String, dynamic>> _enrolledCourses = [];

//   bool _isLoading = true;
//   bool _hasError = false;

//   final ScrollController _scrollController = ScrollController();
//   final List<String> _filterTypes = ['All', 'Free', 'Paid'];

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: const Duration(milliseconds: 800),
//       vsync: this,
//     )..forward();

//     _updateGreeting();
//     _fetchCourses();
//     _timer = Timer.periodic(
//       const Duration(minutes: 1),
//       (_) => _updateGreeting(),
//     );
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     _animationController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }

//   // ── Data ──────────────────────────────────────────────────────────────────

//   Future<void> _fetchCourses() async {
//     try {
//       setState(() {
//         _isLoading = true;
//         _hasError = false;
//       });

//       // Single call — contents are already nested inside each course
//       final courses = await ApiService.getCourses();

//       setState(() {
//         _courses = courses;
//         _filteredCourses = [...courses];
//         _isLoading = false;
//       });

//       developer.log('Loaded ${courses.length} courses');
//       _fetchEnrolledCourses();
//     } catch (e) {
//       developer.log('fetchCourses error: $e');
//       setState(() {
//         _isLoading = false;
//         _hasError = true;
//       });
//     }
//   }

//   Future<void> _fetchEnrolledCourses() async {
//     try {
//       final enrollments = await ApiService.getEnrollments();
//       setState(() => _enrolledCourses = enrollments);
//     } catch (e) {
//       developer.log('fetchEnrollments error: $e');
//     }
//   }

//   void _updateGreeting() {
//     final appData = AppData();
//     final userName = appData.currentUserName?.split(' ').first ?? 'Learner';
//     final hour = DateTime.now().hour;
//     if (!mounted) return;
//     setState(() {
//       _greeting =
//           hour < 12
//               ? 'Good Morning, $userName'
//               : hour < 17
//               ? 'Good Afternoon, $userName'
//               : 'Good Evening, $userName';
//     });
//   }

//   void _filterCourses() {
//     setState(() {
//       _filteredCourses =
//           _courses.where((c) {
//             final title = c['title']?.toString().toLowerCase() ?? '';
//             final desc = c['description']?.toString().toLowerCase() ?? '';
//             final matchSearch =
//                 title.contains(_searchQuery.toLowerCase()) ||
//                 desc.contains(_searchQuery.toLowerCase());

//             final price = double.tryParse(c['price']?.toString() ?? '0') ?? 0;
//             final matchFilter =
//                 _selectedFilter == 'All'
//                     ? true
//                     : _selectedFilter == 'Free'
//                     ? price == 0
//                     : price > 0;

//             return matchSearch && matchFilter;
//           }).toList();
//     });
//   }

//   // ── Build ──────────────────────────────────────────────────────────────────

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       body: SafeArea(
//         child: Column(
//           children: [
//             _buildHeader(),
//             _buildSearchBar(),
//             _buildFilterChips(),
//             Expanded(
//               child:
//                   _isLoading
//                       ? _buildLoader()
//                       : _hasError
//                       ? _buildError()
//                       : RefreshIndicator(
//                         onRefresh: _fetchCourses,
//                         color: const Color.fromRGBO(244, 135, 6, 1),
//                         child: CustomScrollView(
//                           controller: _scrollController,
//                           slivers: [
//                             if (_enrolledCourses.isNotEmpty)
//                               _buildEnrolledSection(),
//                             _buildCoursesGrid(),
//                           ],
//                         ),
//                       ),
//             ),
//           ],
//         ),
//       ),
//       //floatingActionButton: const FloatingMenuWidget(),
//     );
//   }

//   // ── Header ─────────────────────────────────────────────────────────────────

//   Widget _buildHeader() {
//     return Padding(
//       padding: const EdgeInsets.all(16),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Welcome back!',
//                 style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 _greeting,
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black87,
//                 ),
//               ),
//             ],
//           ),
//           _buildAvatar(),
//         ],
//       ),
//     );
//   }

//   Widget _buildAvatar() {
//     final photoUrl =
//         AppData().currentUser?['photo_url']?.toString() ??
//         AppData().currentUser?['photoURL']?.toString();

//     if (photoUrl != null && photoUrl.isNotEmpty) {
//       return CircleAvatar(
//         radius: 22,
//         backgroundColor: const Color.fromRGBO(244, 135, 6, 0.1),
//         backgroundImage: NetworkImage(photoUrl),
//         onBackgroundImageError: (_, __) {},
//       );
//     }
//     return Container(
//       width: 44,
//       height: 44,
//       decoration: BoxDecoration(
//         color: const Color.fromRGBO(244, 135, 6, 0.1),
//         shape: BoxShape.circle,
//         border: Border.all(
//           color: const Color.fromRGBO(244, 135, 6, 0.3),
//           width: 2.8,
//         ),
//       ),
//       child: const Icon(
//         Icons.person,
//         color: Color.fromRGBO(244, 135, 6, 1),
//         size: 24,
//       ),
//     );
//   }

//   // ── Search ─────────────────────────────────────────────────────────────────

//   Widget _buildSearchBar() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       child: Container(
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withAlpha(5),
//               blurRadius: 10,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         padding: const EdgeInsets.symmetric(horizontal: 16),
//         child: Row(
//           children: [
//             const Icon(Icons.search, color: Color.fromRGBO(244, 135, 6, 1)),
//             const SizedBox(width: 10),
//             Expanded(
//               child: TextField(
//                 decoration: InputDecoration(
//                   hintText: 'Search courses...',
//                   border: InputBorder.none,
//                   hintStyle: TextStyle(color: Colors.grey[500]),
//                 ),
//                 onChanged: (v) {
//                   setState(() => _searchQuery = v);
//                   _filterCourses();
//                 },
//               ),
//             ),
//             if (_searchQuery.isNotEmpty)
//               IconButton(
//                 icon: const Icon(Icons.clear, color: Colors.grey),
//                 onPressed: () {
//                   setState(() => _searchQuery = '');
//                   _filterCourses();
//                 },
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ── Filter chips ───────────────────────────────────────────────────────────

//   Widget _buildFilterChips() {
//     return SizedBox(
//       height: 50,
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         padding: const EdgeInsets.only(left: 16),
//         itemCount: _filterTypes.length,
//         itemBuilder: (_, i) {
//           final type = _filterTypes[i];
//           final selected = _selectedFilter == type;
//           return Padding(
//             padding: const EdgeInsets.only(right: 8),
//             child: FilterChip(
//               label: Text(type),
//               selected: selected,
//               onSelected: (v) {
//                 setState(() => _selectedFilter = v ? type : 'All');
//                 _filterCourses();
//               },
//               backgroundColor: Colors.white,
//               selectedColor: const Color.fromRGBO(244, 135, 6, 0.2),
//               labelStyle: TextStyle(
//                 color:
//                     selected
//                         ? const Color.fromRGBO(244, 135, 6, 1)
//                         : Colors.grey[700],
//                 fontWeight: selected ? FontWeight.bold : FontWeight.normal,
//               ),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//                 side: BorderSide(
//                   color:
//                       selected
//                           ? const Color.fromRGBO(244, 135, 6, 1)
//                           : Colors.grey[300]!,
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   // ── Enrolled section ───────────────────────────────────────────────────────

//   Widget _buildEnrolledSection() {
//     return SliverToBoxAdapter(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Padding(
//             padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
//             child: Text(
//               'Continue Learning',
//               style: TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black87,
//               ),
//             ),
//           ),
//           SizedBox(
//             height: 185,
//             child: ListView.builder(
//               scrollDirection: Axis.horizontal,
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               itemCount: _enrolledCourses.length,
//               itemBuilder: (_, i) => _buildEnrolledCard(_enrolledCourses[i]),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildEnrolledCard(Map<String, dynamic> enrollment) {
//     final title = enrollment['course_title']?.toString() ?? 'Course';
//     final courseId = enrollment['course']?.toString();

//     return GestureDetector(
//       onTap: () {
//         if (courseId == null) return;
//         // Find full course data from loaded list
//         final course = _courses.firstWhere(
//           (c) => c['id'] == courseId,
//           orElse: () => {'id': courseId},
//         );
//         Navigator.push(
//           context,
//           MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
//         );
//       },
//       child: Container(
//         width: 260,
//         margin: const EdgeInsets.only(right: 16, bottom: 8),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(16),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withAlpha(8),
//               blurRadius: 12,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               height: 95,
//               decoration: const BoxDecoration(
//                 borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//                 gradient: LinearGradient(
//                   colors: [
//                     Color.fromRGBO(244, 135, 6, 0.8),
//                     Color.fromRGBO(244, 135, 6, 0.4),
//                   ],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//               ),
//               child: const Center(
//                 child: Icon(
//                   Icons.play_circle_filled,
//                   color: Colors.white,
//                   size: 44,
//                 ),
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.all(12),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     title,
//                     style: const TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.bold,
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     'Continue from where you left',
//                     style: TextStyle(fontSize: 11, color: Colors.grey[600]),
//                   ),
//                   const SizedBox(height: 8),
//                   LinearProgressIndicator(
//                     value: 0.3,
//                     backgroundColor: Colors.grey[200],
//                     valueColor: const AlwaysStoppedAnimation(
//                       Color.fromRGBO(244, 135, 6, 1),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ── Courses grid ───────────────────────────────────────────────────────────

//   Widget _buildCoursesGrid() {
//     if (_filteredCourses.isEmpty) {
//       return SliverToBoxAdapter(
//         child: Center(
//           child: Padding(
//             padding: const EdgeInsets.all(40),
//             child: Column(
//               children: [
//                 Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
//                 const SizedBox(height: 16),
//                 Text(
//                   'No courses found',
//                   style: TextStyle(fontSize: 16, color: Colors.grey[500]),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     }

//     return SliverPadding(
//       padding: const EdgeInsets.all(16),
//       sliver: SliverGrid(
//         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: 2,
//           childAspectRatio: 0.75,
//           crossAxisSpacing: 12,
//           mainAxisSpacing: 12,
//         ),
//         delegate: SliverChildBuilderDelegate(
//           (_, i) => _buildCourseCard(_filteredCourses[i]),
//           childCount: _filteredCourses.length,
//         ),
//       ),
//     );
//   }

//   Widget _buildCourseCard(Map<String, dynamic> course) {
//     final price = double.tryParse(course['price']?.toString() ?? '0') ?? 0;
//     final isFree = price == 0;
//     final title = course['title']?.toString() ?? '';
//     final vendorName = course['vendor_name']?.toString() ?? '';
//     final categoryName = course['category_name']?.toString() ?? '';
//     final isPublished = course['is_published'] == true;

//     // Check if first content has a YouTube thumbnail
//     final contents =
//         (course['contents'] as List?)?.cast<Map<String, dynamic>>() ?? [];
//     String? thumbUrl;
//     if (contents.isNotEmpty) {
//       final videoUrl = contents.first['video_url']?.toString() ?? '';
//       final ytId = ApiService.extractYouTubeId(videoUrl);
//       if (ytId != null) {
//         thumbUrl = 'https://img.youtube.com/vi/$ytId/mqdefault.jpg';
//       }
//     }

//     return GestureDetector(
//       onTap:
//           () => Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (_) => CourseDetailScreen(course: course),
//             ),
//           ),
//       child: Container(
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(16),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withAlpha(8),
//               blurRadius: 10,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Thumbnail
//             ClipRRect(
//               borderRadius: const BorderRadius.vertical(
//                 top: Radius.circular(16),
//               ),
//               child: Stack(
//                 children: [
//                   SizedBox(
//                     height: 120,
//                     width: double.infinity,
//                     child:
//                         thumbUrl != null
//                             ? Image.network(
//                               thumbUrl,
//                               fit: BoxFit.cover,
//                               errorBuilder:
//                                   (_, __, ___) => _gradientPlaceholder(title),
//                             )
//                             : _gradientPlaceholder(title),
//                   ),
//                   // Price badge
//                   Positioned(
//                     bottom: 6,
//                     right: 8,
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 8,
//                         vertical: 3,
//                       ),
//                       decoration: BoxDecoration(
//                         color:
//                             isFree
//                                 ? Colors.green
//                                 : const Color.fromRGBO(244, 135, 6, 1),
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: Text(
//                         isFree ? 'FREE' : 'Rs. ${price.toStringAsFixed(0)}',
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 11,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ),
//                   if (!isPublished)
//                     Positioned(
//                       top: 6,
//                       left: 8,
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 6,
//                           vertical: 2,
//                         ),
//                         decoration: BoxDecoration(
//                           color: Colors.grey,
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: const Text(
//                           'Draft',
//                           style: TextStyle(color: Colors.white, fontSize: 10),
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//             // Info
//             Expanded(
//               child: Padding(
//                 padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       title,
//                       style: const TextStyle(
//                         fontWeight: FontWeight.bold,
//                         color: Colors.black87,
//                         fontSize: 13,
//                       ),
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     if (vendorName.isNotEmpty) ...[
//                       const SizedBox(height: 3),
//                       Text(
//                         vendorName,
//                         style: TextStyle(fontSize: 11, color: Colors.grey[600]),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ],
//                     //const Spacer(),
//                     if (categoryName.isNotEmpty)
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 7,
//                           vertical: 2,
//                         ),
//                         decoration: BoxDecoration(
//                           color: const Color.fromRGBO(244, 135, 6, 0.1),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Text(
//                           categoryName,
//                           style: const TextStyle(
//                             fontSize: 9,
//                             fontWeight: FontWeight.bold,
//                             color: Color.fromRGBO(244, 135, 6, 1),
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _gradientPlaceholder(String title) {
//     return Container(
//       height: 120,
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [
//             Color(
//               (0xFF000000 + (title.hashCode * 0x10101) % 0x1000000) |
//                   0xFF000000,
//             ),
//             Color(
//               (0xFF000000 + (title.hashCode * 0x10101) % 0x1000000) |
//                   0xFF000000,
//             ).withAlpha(60),
//           ],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//       ),
//       child: const Center(
//         child: Icon(Icons.play_lesson, size: 36, color: Colors.white54),
//       ),
//     );
//   }

//   // ── States ─────────────────────────────────────────────────────────────────

//   Widget _buildLoader() => const Center(
//     child: Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         CircularProgressIndicator(
//           valueColor: AlwaysStoppedAnimation(Color.fromRGBO(244, 135, 6, 1)),
//         ),
//         SizedBox(height: 20),
//         Text(
//           'Loading courses...',
//           style: TextStyle(
//             fontSize: 16,
//             color: Colors.grey,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//       ],
//     ),
//   );

//   Widget _buildError() => Center(
//     child: Padding(
//       padding: const EdgeInsets.all(20),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Lottie.asset('animation/No_Internet.json', fit: BoxFit.contain),
//           const SizedBox(height: 20),
//           const Text(
//             'Oops! Something went wrong',
//             style: TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//               color: Colors.black87,
//             ),
//           ),
//           const SizedBox(height: 20),
//           ElevatedButton(
//             onPressed: _fetchCourses,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: const Color.fromRGBO(244, 135, 6, 1),
//               foregroundColor: Colors.white,
//               padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(25),
//               ),
//             ),
//             child: const Text(
//               'Try Again',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//           ),
//         ],
//       ),
//     ),
//   );
// }
