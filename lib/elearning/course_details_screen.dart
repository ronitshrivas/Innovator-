// course_details_screen.dart
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:innovator/elearning/services/api_services.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'dart:developer' as developer;

class CourseDetailScreen extends StatefulWidget {
  final Map<String, dynamic> course;
  const CourseDetailScreen({Key? key, required this.course}) : super(key: key);

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late List<Map<String, dynamic>> _contents;

  // Enrollment
  bool _isEnrolled = false;
  String? _enrollmentId;
  bool _isEnrolling = false;
  bool _isLoading = true;

  // Video state
  _PlayerType _playerType = _PlayerType.none;

  // YouTube
  YoutubePlayerController? _ytController;

  // Direct video (chewie)
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  int? _selectedIdx;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final raw = widget.course['contents'];
    _contents = raw is List ? raw.cast<Map<String, dynamic>>() : [];
    _init();
  }

  Future<void> _init() async {
    await _checkEnrollment();
    setState(() => _isLoading = false);
    if (_isEnrolled && _contents.isNotEmpty) {
      _loadVideo(_contents.first['video_url']?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _disposeVideo();
    super.dispose();
  }

  void _disposeVideo() {
    _ytController?.close();
    _ytController = null;
    _chewieController?.dispose();
    _chewieController = null;
    _videoController?.dispose();
    _videoController = null;
    _playerType = _PlayerType.none;
  }

  // ── Enrollment ────────────────────────────────────────────────────────────

  Future<void> _checkEnrollment() async {
    try {
      final list = await ApiService.getEnrollments();
      final m = list.firstWhere(
        (e) => e['course'] == widget.course['id'],
        orElse: () => {},
      );
      if (m.isNotEmpty) {
        _isEnrolled = true;
        _enrollmentId = m['id']?.toString();
      }
    } catch (e) {
      developer.log('checkEnrollment: $e');
    }
  }

  Future<void> _handleEnroll() async {
    setState(() => _isEnrolling = true);
    try {
      final r = await ApiService.enroll(widget.course['id'].toString());
      setState(() {
        _isEnrolled = true;
        _enrollmentId = r['id']?.toString();
        _isEnrolling = false;
      });
      _snack('Successfully enrolled!');
      if (_contents.isNotEmpty) {
        _loadVideo(_contents.first['video_url']?.toString() ?? '');
      }
    } catch (e) {
      setState(() => _isEnrolling = false);
      _snack(e.toString().replaceAll('Exception: ', ''), err: true);
    }
  }

  Future<void> _handleUnenroll() async {
    if (_enrollmentId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Unenroll'),
            content: const Text('Remove yourself from this course?'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Unenroll',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (ok != true) return;

    setState(() => _isEnrolling = true);
    try {
      await ApiService.deleteEnrollment(_enrollmentId!);
      _disposeVideo();
      setState(() {
        _isEnrolled = false;
        _enrollmentId = null;
        _isEnrolling = false;
      });
      _snack('Unenrolled successfully');
    } catch (e) {
      setState(() => _isEnrolling = false);
      _snack(e.toString().replaceAll('Exception: ', ''), err: true);
    }
  }

  void _snack(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            err ? Colors.red : const Color.fromRGBO(244, 135, 6, 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Video loading ─────────────────────────────────────────────────────────

  void _loadVideo(String url) {
    if (url.isEmpty) return;
    _disposeVideo();

    if (ApiService.isYouTubeUrl(url)) {
      _loadYouTube(url);
    } else {
      _loadDirect(url);
    }
  }

  void _loadYouTube(String url) {
    final id = ApiService.extractYouTubeId(url);
    if (id == null) return;

    _ytController = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
        loop: false,
        enableCaption: false,
      ),
    );
    _ytController!.loadVideoById(videoId: id);

    setState(() => _playerType = _PlayerType.youtube);
    developer.log('YouTube loaded: $id');
  }

  Future<void> _loadDirect(String url) async {
    final fullUrl = ApiService.getFullMediaUrl(url);
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(fullUrl));
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        aspectRatio: 16 / 9,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color.fromRGBO(244, 135, 6, 1),
          handleColor: const Color.fromRGBO(244, 135, 6, 1),
          bufferedColor: const Color.fromRGBO(244, 135, 6, 0.3),
          backgroundColor: Colors.white24,
        ),
        placeholder: Container(color: Colors.black),
        autoInitialize: true,
      );

      if (mounted) setState(() => _playerType = _PlayerType.direct);
      developer.log('Direct video loaded: $fullUrl');
    } catch (e) {
      developer.log('Direct video error: $e');
      _disposeVideo();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading ? _buildLoader() : _buildBody(),
    );
  }

  Widget _buildBody() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: _playerType == _PlayerType.none ? 220 : 0,
          pinned: true,
          backgroundColor: const Color.fromRGBO(244, 135, 6, 1),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title:
              _playerType != _PlayerType.none
                  ? Text(
                    widget.course['title']?.toString() ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                  : null,
          flexibleSpace:
              _playerType == _PlayerType.none
                  ? FlexibleSpaceBar(background: _buildThumb())
                  : null,
        ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              // ── Active player ──
              if (_playerType == _PlayerType.youtube && _ytController != null)
                YoutubePlayerScaffold(
                  controller: _ytController!,
                  aspectRatio: 16 / 9,
                  builder: (context, player) => player,
                ),

              if (_playerType == _PlayerType.direct &&
                  _chewieController != null)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Chewie(controller: _chewieController!),
                ),

              _buildInfo(),
              _buildEnrollBanner(),
              _buildTabs(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Thumbnail placeholder ─────────────────────────────────────────────────

  Widget _buildThumb() {
    String? ytId;
    if (_contents.isNotEmpty) {
      ytId = ApiService.extractYouTubeId(
        _contents.first['video_url']?.toString() ?? '',
      );
    }
    final thumb =
        ytId != null ? 'https://img.youtube.com/vi/$ytId/hqdefault.jpg' : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        thumb != null
            ? Image.network(
              thumb,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _gradBg(),
            )
            : _gradBg(),
        Container(color: Colors.black.withAlpha(45)),

        if (_isEnrolled && _contents.isNotEmpty)
          Center(
            child: GestureDetector(
              onTap:
                  () => _loadVideo(
                    _contents.first['video_url']?.toString() ?? '',
                  ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(244, 135, 6, 1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(50),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          )
        else
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 40, color: Colors.white60),
                SizedBox(height: 6),
                Text(
                  'Enroll to watch',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _gradBg() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color.fromRGBO(244, 135, 6, 0.9),
          Color.fromRGBO(244, 60, 6, 0.7),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  );

  // ── Course info ───────────────────────────────────────────────────────────

  Widget _buildInfo() {
    final price =
        double.tryParse(widget.course['price']?.toString() ?? '0') ?? 0;
    final isFree = price == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.course['title']?.toString() ?? '',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.course['description']?.toString() ?? '',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if ((widget.course['category_name']?.toString() ?? '').isNotEmpty)
                _chip(
                  Icons.category,
                  widget.course['category_name'].toString(),
                  Colors.blue,
                ),
              if ((widget.course['vendor_name']?.toString() ?? '').isNotEmpty)
                _chip(
                  Icons.person,
                  widget.course['vendor_name'].toString(),
                  Colors.green,
                ),
              _chip(
                Icons.attach_money,
                isFree ? 'Free' : 'Rs. ${price.toStringAsFixed(0)}',
                isFree ? Colors.green : const Color.fromRGBO(244, 135, 6, 1),
              ),
              _chip(
                Icons.video_library,
                '${_contents.length} lesson${_contents.length == 1 ? '' : 's'}',
                Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );

  // ── Enroll banner ─────────────────────────────────────────────────────────

  Widget _buildEnrollBanner() {
    if (_isEnrolled) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'You are enrolled in this course',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: _isEnrolling ? null : _handleUnenroll,
              child:
                  _isEnrolling
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red,
                        ),
                      )
                      : const Icon(Icons.close, color: Colors.red, size: 20),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Enroll to access all videos and documents',
                    style: TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isEnrolling ? null : _handleEnroll,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(244, 135, 6, 1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              icon:
                  _isEnrolling
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.school, size: 20),
              label: Text(
                _isEnrolling ? 'Enrolling...' : 'Enroll Now',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tabs ──────────────────────────────────────────────────────────────────

  Widget _buildTabs() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabAlignment: TabAlignment.fill,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          unselectedLabelColor: const Color.fromRGBO(244, 135, 6, 1),
          labelColor: Colors.white,
          padding: const EdgeInsets.only(top: 9, bottom: 9, left: 9),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          labelPadding: EdgeInsets.zero,
          unselectedLabelStyle: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color.fromRGBO(244, 135, 6, 1),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(20),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_lesson, size: 15),
                  const SizedBox(width: 4),
                  Text('Lessons (${_contents.length})'),
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.picture_as_pdf, size: 15),
                  SizedBox(width: 4),
                  Text('Docs'),
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 15),
                  SizedBox(width: 4),
                  Text('About'),
                ],
              ),
            ),
          ],
        ),
        SizedBox(
          height: 400,
          child: TabBarView(
            controller: _tabController,
            children: [_buildLessonsTab(), _buildDocsTab(), _buildAboutTab()],
          ),
        ),
      ],
    );
  }

  // ── Lessons tab ───────────────────────────────────────────────────────────

  Widget _buildLessonsTab() {
    if (!_isEnrolled) return _locked();
    if (_contents.isEmpty) {
      return Center(
        child: Text(
          'No lessons yet',
          style: TextStyle(color: Colors.grey[500], fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _contents.length,
      itemBuilder: (_, i) {
        final item = _contents[i];
        final sel = _selectedIdx == i;
        final hasVid = (item['video_url']?.toString() ?? '').isNotEmpty;
        final hasDoc = (item['document_url']?.toString() ?? '').isNotEmpty;
        final ytId =
            hasVid
                ? ApiService.extractYouTubeId(item['video_url'].toString())
                : null;
        final thumb =
            ytId != null
                ? 'https://img.youtube.com/vi/$ytId/default.jpg'
                : null;

        return GestureDetector(
          onTap: () {
            setState(() => _selectedIdx = sel ? null : i);
            if (hasVid) _loadVideo(item['video_url'].toString());
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color:
                  sel
                      ? const Color.fromRGBO(244, 135, 6, 0.08)
                      : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    sel
                        ? const Color.fromRGBO(244, 135, 6, 1)
                        : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                  child:
                      thumb != null
                          ? Image.network(
                            thumb,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) =>
                                    _badge(item['order'] ?? i + 1, sel),
                          )
                          : _badge(item['order'] ?? i + 1, sel),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title']?.toString() ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((item['course_level']?.toString() ?? '')
                            .isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            item['course_level'].toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (hasVid) ...[
                              const Icon(
                                Icons.play_circle_outline,
                                size: 13,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Video',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (hasVid && hasDoc) const SizedBox(width: 8),
                            if (hasDoc) ...[
                              const Icon(
                                Icons.picture_as_pdf,
                                size: 13,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'PDF',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (sel)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.play_circle_filled,
                      color: Color.fromRGBO(244, 135, 6, 1),
                      size: 26,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _badge(dynamic order, bool sel) => Container(
    width: 72,
    height: 72,
    color: sel ? const Color.fromRGBO(244, 135, 6, 1) : Colors.grey[300],
    child: Center(
      child: Text(
        '$order',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: sel ? Colors.white : Colors.grey[700],
        ),
      ),
    ),
  );

  // ── Docs tab ──────────────────────────────────────────────────────────────

  Widget _buildDocsTab() {
    if (!_isEnrolled) return _locked();
    final docs =
        _contents
            .where((c) => (c['document_url']?.toString() ?? '').isNotEmpty)
            .toList();

    if (docs.isEmpty) {
      return Center(
        child: Text(
          'No documents',
          style: TextStyle(color: Colors.grey[500], fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final item = docs[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(244, 135, 6, 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.picture_as_pdf,
                  color: Color.fromRGBO(244, 135, 6, 1),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title']?.toString() ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if ((item['course_level']?.toString() ?? '')
                        .isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item['course_level'].toString(),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        );
      },
    );
  }

  // ── About tab ─────────────────────────────────────────────────────────────

  Widget _buildAboutTab() {
    final price =
        double.tryParse(widget.course['price']?.toString() ?? '0') ?? 0;
    final isFree = price == 0;
    final pub = widget.course['is_published'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(244, 135, 6, 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color.fromRGBO(244, 135, 6, 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color.fromRGBO(244, 135, 6, 1),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Course Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _row(
                  Icons.attach_money,
                  isFree ? 'Free Course' : 'Rs. ${price.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 8),
                _row(
                  pub ? Icons.check_circle : Icons.pending,
                  pub ? 'Published' : 'Draft',
                  c: pub ? Colors.green : Colors.orange,
                ),
                if ((widget.course['vendor_name']?.toString() ?? '')
                    .isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _row(Icons.business, widget.course['vendor_name'].toString()),
                ],
                if ((widget.course['category_name']?.toString() ?? '')
                    .isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _row(
                    Icons.category,
                    widget.course['category_name'].toString(),
                  ),
                ],
                if (widget.course['created_at'] != null) ...[
                  const SizedBox(height: 8),
                  _row(
                    Icons.calendar_today,
                    _date(widget.course['created_at'].toString()),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Description',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.course['description']?.toString() ??
                'No description available.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    IconData icon,
    String label, {
    Color c = const Color.fromRGBO(244, 135, 6, 1),
  }) => Row(
    children: [
      Icon(icon, size: 17, color: c),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
    ],
  );

  String _date(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  // ── Locked state ──────────────────────────────────────────────────────────

  Widget _locked() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color.fromRGBO(244, 135, 6, 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline,
              size: 44,
              color: Color.fromRGBO(244, 135, 6, 1),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Content Locked',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Enroll to access all videos and documents.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isEnrolling ? null : _handleEnroll,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(244, 135, 6, 1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon:
                _isEnrolling
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.school),
            label: Text(
              _isEnrolling ? 'Enrolling...' : 'Enroll Now',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );

  // ── Loader ────────────────────────────────────────────────────────────────

  Widget _buildLoader() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color.fromRGBO(244, 135, 6, 1)),
        ),
        SizedBox(height: 20),
        Text(
          'Loading...',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

// Internal enum to track which player is active
enum _PlayerType { none, youtube, direct }
