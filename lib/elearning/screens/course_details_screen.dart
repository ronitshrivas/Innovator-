import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/elearning/model/course_list_model.dart';
 import 'package:innovator/elearning/provider/course_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:shimmer/shimmer.dart';
 

class _EnrollState {
  final bool isEnrolled;
  final bool isLoading;
  final String? error;
  const _EnrollState(
      {this.isEnrolled = false, this.isLoading = false, this.error});
  _EnrollState copyWith(
          {bool? isEnrolled, bool? isLoading, String? error}) =>
      _EnrollState(
        isEnrolled: isEnrolled ?? this.isEnrolled,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

final _enrollStateProvider =
    StateProvider.family<_EnrollState, String>((ref, courseId) {
  return const _EnrollState();
});
 

class CourseDetailScreen extends ConsumerStatefulWidget {
  final CourseListModel course;
  const CourseDetailScreen({Key? key, required this.course}) : super(key: key);

  @override
  ConsumerState<CourseDetailScreen> createState() =>
      _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _videoError = false;
  int _selectedContentIndex = 0;

  static const List<String> _detailTabs = ['Lessons', 'Docs', 'About'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _detailTabs.length, vsync: this);
    if (widget.course.contents.isNotEmpty) {
      _initVideo(widget.course.contents.first);
    }
  }

  void _initVideo(CourseContent content) {
    _videoController?.dispose();
    setState(() {
      _videoInitialized = false;
      _videoError = false;
    });

    final url = content.videoUrl ?? content.videoFile;
    if (url == null || url.isEmpty) {
      setState(() => _videoError = true);
      return;
    }

    _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (mounted) setState(() => _videoInitialized = true);
      }).catchError((_) {
        if (mounted) setState(() => _videoError = true);
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // ── enroll ────────────────────────────────────────────────────────────────

  Future<void> _enroll() async {
    final courseId = widget.course.id;
    ref
        .read(_enrollStateProvider(courseId).notifier)
        .update((s) => s.copyWith(isLoading: true, error: null));

    try {
      await ref.read(courseServiceProvider).enrollCourse(courseId);
      if (mounted) {
        ref
            .read(_enrollStateProvider(courseId).notifier)
            .update((s) => s.copyWith(isEnrolled: true, isLoading: false));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.course.isFree
                ? '🎉 Enrolled! Start learning now.'
                : '✅ Enrollment request sent. Complete payment to unlock.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ref
            .read(_enrollStateProvider(courseId).notifier)
            .update((s) => s.copyWith(isLoading: false, error: e.toString()));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enrollment failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final enrollState =
        ref.watch(_enrollStateProvider(widget.course.id));
    final isEnrolled = enrollState.isEnrolled;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Video Player
          _buildVideoSection(isEnrolled),

          // Course title bar + tabs
          Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      // back button (when full screen nav)
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          margin: EdgeInsets.only(
                              top: MediaQuery.of(context).padding.top > 0
                                  ? 0
                                  : 0),
                          child: const Icon(Icons.arrow_back_ios_new,
                              size: 18, color: Color(0xFF1E293B)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.course.title,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildCourseBadge(),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TabBar(
                  controller: _tabController,
                  tabs: _detailTabs.map((t) => Tab(text: t)).toList(),
                  labelColor: const Color(0xFF2563EB),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFF2563EB),
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ),

          // Tab content
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

  // ── video section ─────────────────────────────────────────────────────────

  Widget _buildVideoSection(bool isEnrolled) {
    final enrollState = ref.watch(_enrollStateProvider(widget.course.id));

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
              // Video or placeholder
              if (!isEnrolled)
                _buildLockedOverlay()
              else if (_videoError)
                _buildVideoErrorWidget()
              else if (!_videoInitialized)
                _buildVideoLoading()
              else
                _buildVideoPlayer(),

              // Back button overlay
              Positioned(
                top: 8,
                left: 8,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),

              // Enroll button overlay (when not enrolled)
              if (!isEnrolled)
                Positioned(
                  bottom: 12,
                  child: _buildEnrollButton(enrollState),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockedOverlay() {
    final thumbnail = widget.course.contents.isNotEmpty
        ? widget.course.contents.first.thumbnail
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumbnail != null)
          Image.network(thumbnail, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade900))
        else
          Container(color: Colors.grey.shade900),
        Container(color: Colors.black.withOpacity(0.55)),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 10),
            Text(
              widget.course.isFree
                  ? 'Enroll for free to watch'
                  : 'Enroll to access this course',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVideoLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade800,
      highlightColor: Colors.grey.shade600,
      child: Container(color: Colors.grey.shade800),
    );
  }

  Widget _buildVideoErrorWidget() {
    return Container(
      color: Colors.grey.shade900,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, color: Colors.white54, size: 40),
            SizedBox(height: 8),
            Text('Video unavailable',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Stack(
      alignment: Alignment.center,
      children: [
        VideoPlayer(_videoController!),
        // Play/pause overlay
        GestureDetector(
          onTap: () {
            setState(() {
              _videoController!.value.isPlaying
                  ? _videoController!.pause()
                  : _videoController!.play();
            });
          },
          child: AnimatedOpacity(
            opacity:
                _videoController!.value.isPlaying ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow,
                  color: Colors.white, size: 36),
            ),
          ),
        ),
        // Progress bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: VideoProgressIndicator(
            _videoController!,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: const Color(0xFF2563EB),
              bufferedColor: Colors.white38,
              backgroundColor: Colors.white12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnrollButton(_EnrollState enrollState) {
    return GestureDetector(
      onTap: enrollState.isLoading ? null : _enroll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: widget.course.isFree
              ? const Color(0xFF10B981)
              : const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: enrollState.isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.course.isFree
                        ? Icons.school
                        : Icons.payment,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.course.isFree
                        ? 'Enroll for Free'
                        : 'Pay to Enroll',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCourseBadge() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: widget.course.isFree
            ? const Color(0xFFD1FAE5)
            : const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        widget.course.isFree ? 'Free' : 'Paid',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: widget.course.isFree
              ? const Color(0xFF059669)
              : const Color(0xFF2563EB),
        ),
      ),
    );
  }

  // ── Lessons tab ───────────────────────────────────────────────────────────

  Widget _buildLessonsTab(bool isEnrolled) {
    final contents = widget.course.contents;
    if (contents.isEmpty) {
      return _buildEmptyTab('No lessons available');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: contents.length,
      itemBuilder: (_, i) {
        final content = contents[i];
        final isSelected = _selectedContentIndex == i;
        return GestureDetector(
          onTap: isEnrolled
              ? () {
                  setState(() {
                    _selectedContentIndex = i;
                    _initVideo(content);
                  });
                  // scroll the video into view by switching focus
                  _tabController.animateTo(0);
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFEFF6FF)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : Colors.transparent,
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
                // Thumbnail / order number
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,
                    height: 44,
                    child: content.thumbnail != null
                        ? Image.network(content.thumbnail!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _lessonPlaceholder(content.order))
                        : _lessonPlaceholder(content.order),
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
                            color: Color(0xFF1E293B)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            '${content.duration.toStringAsFixed(0)} min',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              content.courseLevel.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!isEnrolled)
                  const Icon(Icons.lock_outline,
                      size: 16, color: Color(0xFF94A3B8))
                else
                  Icon(
                    isSelected
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_outline,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : Colors.grey.shade400,
                    size: 22,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _lessonPlaceholder(int order) {
    return Container(
      color: const Color(0xFFE2E8F0),
      child: Center(
        child: Text(
          '$order',
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF94A3B8),
              fontSize: 16),
        ),
      ),
    );
  }

  // ── Docs tab ──────────────────────────────────────────────────────────────

  Widget _buildDocsTab(bool isEnrolled) {
    final docsContents = widget.course.contents
        .where((c) =>
            (c.documentUrl != null && c.documentUrl!.isNotEmpty) ||
            (c.documentFile != null && c.documentFile!.isNotEmpty))
        .toList();

    if (docsContents.isEmpty) {
      return _buildEmptyTab('No documents available');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docsContents.length,
      itemBuilder: (_, i) {
        final content = docsContents[i];
        return _DocItem(
          content: content,
          isEnrolled: isEnrolled,
        );
      },
    );
  }

  // ── About tab ─────────────────────────────────────────────────────────────

  Widget _buildAboutTab(bool isEnrolled) {
    final course = widget.course;
    final instructor = course.contents.isNotEmpty
        ? course.contents.first.instructorName
        : course.vendorName;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instructor card
          _AboutCard(
            icon: Icons.person_outline,
            label: 'Instructor',
            value: instructor,
            iconColor: const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 12),
          _AboutCard(
            icon: Icons.category_outlined,
            label: 'Category',
            value: course.categoryName,
            iconColor: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 12),
          _AboutCard(
            icon: Icons.library_books_outlined,
            label: 'Total Lessons',
            value: '${course.contents.length} lessons',
            iconColor: const Color(0xFF10B981),
          ),
          const SizedBox(height: 16),
          // Description
          const Text('About this Course',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          Text(
            course.description,
            style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.6),
          ),
          const SizedBox(height: 24),
          // Enroll button (if not enrolled)
          if (!isEnrolled) _buildAboutEnrollButton(),
        ],
      ),
    );
  }

  Widget _buildAboutEnrollButton() {
    final enrollState =
        ref.watch(_enrollStateProvider(widget.course.id));
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: enrollState.isLoading ? null : _enroll,
        icon: enrollState.isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Icon(widget.course.isFree ? Icons.school : Icons.payment,
                size: 18),
        label: Text(
          widget.course.isFree ? 'Enroll for Free' : 'Pay to Enroll',
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.course.isFree
              ? const Color(0xFF10B981)
              : const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildEmptyTab(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(msg,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        ],
      ),
    );
  }
}

// ─── Doc Item widget ──────────────────────────────────────────────────────────

class _DocItem extends StatelessWidget {
  final CourseContent content;
  final bool isEnrolled;
  const _DocItem({required this.content, required this.isEnrolled});

  String? get _docUrl => content.documentUrl ?? content.documentFile;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 6,
              offset: const Offset(0, 1)),
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
            child: const Icon(Icons.picture_as_pdf,
                color: Color(0xFFF59E0B), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(content.title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  'Lesson ${content.order} · Document',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isEnrolled)
            const Icon(Icons.lock_outline,
                size: 16, color: Color(0xFF94A3B8))
          else
            GestureDetector(
              onTap: _docUrl != null
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              _PdfViewScreen(url: _docUrl!, title: content.title),
                        ),
                      )
                  : null,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('View',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB))),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── PDF Viewer Screen ────────────────────────────────────────────────────────

class _PdfViewScreen extends StatelessWidget {
  final String url;
  final String title;
  const _PdfViewScreen({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0.5,
      ),
      body: SfPdfViewer.network(url),
    );
  }
}

// ─── About Card ───────────────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  const _AboutCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 6,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B))),
            ],
          ),
        ],
      ),
    );
  }
}