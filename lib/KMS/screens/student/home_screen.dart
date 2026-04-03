import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/KMS/core/constants/app_style.dart';
import 'package:innovator/KMS/model/student_model/homework_model.dart';
import 'package:innovator/KMS/provider/student_provider/student_provider.dart';

// Filter enum
enum _DateFilter { all, thisWeek, thisMonth, lastMonth }

extension _DateFilterLabel on _DateFilter {
  String get label {
    switch (this) {
      case _DateFilter.all:
        return 'All';
      case _DateFilter.thisWeek:
        return 'This Week';
      case _DateFilter.thisMonth:
        return 'This Month';
      case _DateFilter.lastMonth:
        return 'Last Month';
    }
  }
}

// Screen
class HomeworkScreen extends ConsumerStatefulWidget {
  const HomeworkScreen({super.key});

  @override
  ConsumerState<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends ConsumerState<HomeworkScreen> {
  _DateFilter _selectedFilter = _DateFilter.all;
  bool _isRefreshing = false;
  List<HomeworkModel> _applyFilter(List<HomeworkModel> list) {
    if (_selectedFilter == _DateFilter.all) return list;
    final now = DateTime.now();
    return list.where((hw) {
      final date = DateTime.tryParse(hw.date);
      if (date == null) return false;
      switch (_selectedFilter) {
        case _DateFilter.thisWeek:
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final start = DateTime(
            startOfWeek.year,
            startOfWeek.month,
            startOfWeek.day,
          );
          return !date.isBefore(start);
        case _DateFilter.thisMonth:
          return date.year == now.year && date.month == now.month;
        case _DateFilter.lastMonth:
          final lastMonth = DateTime(now.year, now.month - 1);
          return date.year == lastMonth.year && date.month == lastMonth.month;
        case _DateFilter.all:
          return true;
      }
    }).toList();
  }

  List<_MonthGroup> _groupByMonth(List<HomeworkModel> list) {
    final map = <String, List<HomeworkModel>>{};
    for (final hw in list) {
      final key = _monthKey(hw.date);
      map.putIfAbsent(key, () => []).add(hw);
    }
    return map.entries
        .map((e) => _MonthGroup(month: e.key, items: e.value))
        .toList();
  }

  String _monthKey(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return 'Unknown';
    }
  }

  Future<void> _handleRefresh() async {
    // Show skeleton immediately when pull-to-refresh starts
    setState(() => _isRefreshing = true);
    ref.invalidate(homeworkProvider);
    try {
      await ref.read(homeworkProvider.future);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeworkAsync = ref.watch(homeworkProvider);

    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      appBar: AppBar(
        backgroundColor: AppStyle.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Homework',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: homeworkAsync.when(
        // Initial load — show skeleton
        loading: () => const _SkeletonLoader(),

        // Error — show retry button
        error:
            (err, _) => _ErrorView(
              message: 'Failed to load homework.',
              onRetry: () => ref.invalidate(homeworkProvider),
            ),

        data: (list) {
          // Pull-to-refresh in progress — show skeleton instead of stale list
          if (_isRefreshing) return const _SkeletonLoader();

          final filtered = _applyFilter(list);
          final grouped = _groupByMonth(filtered);

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: CustomScrollView(
              slivers: [
                // Filter chips
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filter by date',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children:
                              _DateFilter.values.map((f) {
                                final isSelected = _selectedFilter == f;
                                return GestureDetector(
                                  onTap:
                                      () => setState(() => _selectedFilter = f),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? AppStyle.primaryColor
                                              : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color:
                                            isSelected
                                                ? AppStyle.primaryColor
                                                : Colors.grey.shade300,
                                      ),
                                      boxShadow:
                                          isSelected
                                              ? [
                                                BoxShadow(
                                                  color: AppStyle.primaryColor
                                                      .withValues(alpha: 0.25),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                              : [],
                                    ),
                                    child: Text(
                                      f.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            isSelected
                                                ? Colors.white
                                                : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${filtered.length} assignment${filtered.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Empty state
                if (list.isEmpty || filtered.isEmpty)
                  SliverFillRemaining(
                    child: _EmptyView(
                      message:
                          list.isEmpty
                              ? 'No homework assigned yet.'
                              : 'No homework for this period.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _MonthSection(
                          month: grouped[index].month,
                          items: grouped[index].items,
                        ),
                        childCount: grouped.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Month group model
class _MonthGroup {
  final String month;
  final List<HomeworkModel> items;
  _MonthGroup({required this.month, required this.items});
}

// Month section
class _MonthSection extends StatelessWidget {
  final String month;
  final List<HomeworkModel> items;

  const _MonthSection({required this.month, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppStyle.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                month,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        ...items.map((hw) => _HomeworkCard(homework: hw)),
        const SizedBox(height: 4),
      ],
    );
  }
}

// Homework card
class _HomeworkCard extends StatelessWidget {
  final HomeworkModel homework;

  const _HomeworkCard({required this.homework});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(homework.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colored top accent bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date row + status badge inline
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(homework.date),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            homework.classroomName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status badge — inline, no widget
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(homework.status),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey.shade100),
                const SizedBox(height: 12),

                // Assignment label
                Row(
                  children: [
                    Icon(
                      Icons.book_outlined,
                      size: 13,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'ASSIGNMENT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade400,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Assignment text
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    homework.homework,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Teacher
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 13,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Assigned by ${homework.teacherName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present_with_homework':
        return Colors.blue;
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'present_with_homework':
        return 'With HW';
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      default:
        return status;
    }
  }
}

// Skeleton loader — shown on both initial load and pull-to-refresh
class _SkeletonLoader extends StatefulWidget {
  const _SkeletonLoader();

  @override
  State<_SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<_SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.25,
      end: 0.6,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final shimmerColor = Colors.grey.withValues(alpha: _animation.value);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          itemCount: 4,
          itemBuilder: (_, __) => _SkeletonCard(shimmerColor: shimmerColor),
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final Color shimmerColor;

  const _SkeletonCard({required this.shimmerColor});

  Widget _box({double? width, double height = 12, double radius = 8}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: shimmerColor,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _box(width: 110),
                          const SizedBox(height: 6),
                          _box(width: 70, height: 10),
                        ],
                      ),
                    ),
                    _box(width: 58, height: 24, radius: 20),
                  ],
                ),
                const SizedBox(height: 14),
                _box(width: 90, height: 10),
                const SizedBox(height: 8),
                _box(height: 52, radius: 10),
                const SizedBox(height: 10),
                _box(width: 150, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Error view
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.grey, fontSize: 15),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyle.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// Empty view
class _EmptyView extends StatelessWidget {
  final String message;

  const _EmptyView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.assignment_late_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
