import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/Innovator/widget/Custom_refresh_Indicator.dart';
import 'package:innovator/elearning/model/course_list_model.dart'; 
import 'package:innovator/elearning/provider/course_provider.dart'; 
import 'package:innovator/elearning/screens/course_details_screen.dart';
import 'package:shimmer/shimmer.dart'; 

class CourseListScreen extends ConsumerStatefulWidget {
  const CourseListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends ConsumerState<CourseListScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  String _searchQuery = '';
  String _selectedCategory = 'All';

  // tabs: All | Free | Paid
  static const List<String> _tabs = ['All', 'Free', 'Paid'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── filter helpers ────────────────────────────────────────────────────────

  List<CourseListModel> _filtered(List<CourseListModel> all, int tabIndex) {
    List<CourseListModel> list = all;

    // tab filter
    if (tabIndex == 1) list = list.where((c) => c.isFree).toList();
    if (tabIndex == 2) list = list.where((c) => !c.isFree).toList();

    // category filter
    if (_selectedCategory != 'All') {
      list = list.where((c) => c.categoryName == _selectedCategory).toList();
    }

    // search filter
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((c) => c.title.toLowerCase().contains(_searchQuery))
          .toList();
    }

    return list;
  }

  List<String> _categories(List<CourseListModel> all) {
    final cats = all.map((c) => c.categoryName).toSet().toList()..sort();
    return ['All', ...cats];
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final asyncCourses = ref.watch(courseListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: asyncCourses.when(
        loading: () => _buildSkeleton(),
        error: (e, _) => _buildError(e),
        data: (courses) => _buildContent(courses),
      ),
    );
  }

  // ── skeleton ──────────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(null),
          Expanded(
            child: Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemCount: 6,
                itemBuilder: (_, __) => _SkeletonCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── error ─────────────────────────────────────────────────────────────────

  Widget _buildError(Object e) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text('Failed to load courses',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(e.toString(),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.refresh(courseListProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ── main content ──────────────────────────────────────────────────────────

  Widget _buildContent(List<CourseListModel> courses) {
    final categories = _categories(courses);

    return SafeArea(
      child: CustomRefreshIndicator(
        onRefresh: () async => ref.refresh(courseListProvider),
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(child: _buildHeader(courses)),
            SliverToBoxAdapter(
              child: _buildCategoryChips(categories),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  tabs: _tabs
                      .map((t) => Tab(text: t))
                      .toList(),
                  labelColor: const Color(0xFF2563EB),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFF2563EB),
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: List.generate(_tabs.length, (tabIdx) {
              return AnimatedBuilder(
                animation: _tabController,
                builder: (_, __) {
                  final filtered = _filtered(courses, tabIdx);
                  if (filtered.isEmpty) return _buildEmpty();
                  return _buildGrid(filtered);
                },
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── header (search bar) ───────────────────────────────────────────────────

  Widget _buildHeader(List<CourseListModel>? courses) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('E-Learning',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B))),
              const Spacer(),
              if (courses != null)
                Text('${courses.length} courses',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 12),
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search courses...',
                hintStyle:
                    TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon:
                    Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── category chips ────────────────────────────────────────────────────────

  Widget _buildCategoryChips(List<String> categories) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final cat = categories[i];
            final selected = _selectedCategory == cat;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── grid ──────────────────────────────────────────────────────────────────

  Widget _buildGrid(List<CourseListModel> courses) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: courses.length,
      itemBuilder: (_, i) => _CourseCard(
        course: courses[i],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CourseDetailScreen(course: courses[i]),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No courses found',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─── Course Card ─────────────────────────────────────────────────────────────

class _CourseCard extends StatelessWidget {
  final CourseListModel course;
  final VoidCallback onTap;

  const _CourseCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final thumbnail = course.contents.isNotEmpty
        ? course.contents.first.thumbnail
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: thumbnail != null
                        ? Image.network(
                            thumbnail,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _ThumbnailPlaceholder(),
                          )
                        : _ThumbnailPlaceholder(),
                  ),
                ),
                // Lock icon overlay
                if (!course.isFree)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock,
                          color: Colors.white, size: 12),
                    ),
                  ),
                // Free badge
                if (course.isFree)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('FREE',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.categoryName,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: course.isFree
                              ? const Text('Free',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF10B981)))
                              : Text(
                                  'Rs. ${course.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2563EB)),
                                ),
                        ),
                        Icon(Icons.play_circle_outline,
                            size: 18, color: Colors.grey.shade400),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── helpers ──────────────────────────────────────────────────────────────────

class _ThumbnailPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE2E8F0),
      child: Center(
        child: Icon(Icons.play_lesson_outlined,
            color: Colors.grey.shade400, size: 32),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(14))))),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    height: 12,
                    width: double.infinity,
                    color: Colors.white),
                const SizedBox(height: 6),
                Container(height: 12, width: 80, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  Widget build(_, __, ___) => Container(
        color: Colors.white,
        child: tabBar,
      );

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_) => false;
}