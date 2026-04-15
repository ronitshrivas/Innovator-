// ─── reels_camera_screen.dart ────────────────────────────────────────────────
// Place at: lib/Innovator/screens/CreatePost/reels_camera_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:innovator/Innovator/provider/reels_provider.dart';

import 'reels_music_screen.dart';
import 'reels_preview_screen.dart'; // ← FIX: was missing; ReelsPreviewScreen lives here

const _kPrimary = Color.fromRGBO(244, 135, 6, 1);

class ReelsCameraScreen extends ConsumerStatefulWidget {
  const ReelsCameraScreen({super.key});

  @override
  ConsumerState<ReelsCameraScreen> createState() => _ReelsCameraScreenState();
}

class _ReelsCameraScreenState extends ConsumerState<ReelsCameraScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  List<CameraDescription> _cameras = [];
  CameraController? _ctrl;
  bool _ready = false;
  bool _recording = false;
  bool _isFront = false;
  FlashMode _flash = FlashMode.off;
  int _elapsed = 0;
  Timer? _recTimer;
  int _countdown = 0;
  Timer? _cdTimer;
  int _timerSec = 0; // 0 = off, 3, 10
  bool _showFilters = false;
  bool _showSpeed = false;
  bool _showTimer = false;
  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 1.0, end: 1.10).animate(_pulse);
    _initCams();
  }

  Future<void> _initCams() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) await _initCtrl(_cameras[0]);
    } catch (e) {
      debugPrint('cam init: $e');
    }
  }

  Future<void> _initCtrl(CameraDescription d) async {
    final old = _ctrl;
    _ctrl = CameraController(d, ResolutionPreset.high, enableAudio: true);
    try {
      await _ctrl!.initialize();
      await old?.dispose();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      debugPrint('ctrl init: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (_ctrl == null || !_ctrl!.value.isInitialized) return;
    if (s == AppLifecycleState.inactive) {
      _ctrl!.dispose();
    } else if (s == AppLifecycleState.resumed) {
      _initCtrl(_ctrl!.description);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recTimer?.cancel();
    _cdTimer?.cancel();
    _ctrl?.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _flip() async {
    if (_cameras.length < 2 || _recording) return;
    setState(() {
      _ready = false;
      _isFront = !_isFront;
    });
    ref.read(reelsProvider.notifier).toggleCamera();
    await _initCtrl(_cameras[_isFront ? 1 : 0]);
  }

  Future<void> _toggleFlash() async {
    final next = _flash == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await _ctrl?.setFlashMode(next);
    setState(() => _flash = next);
  }

  Future<void> _pickGallery() async {
    final v = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (v != null && mounted) {
      // FIX: was `const ReelsEditScreen()` — navigate with the picked path
      ref.read(reelsProvider.notifier).setVideo(v.path, fromGallery: true);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReelsPreviewScreen(videoPath: v.path),
        ),
      );
    }
  }

  void _handleRecordTap() {
    if (_recording) {
      _stopRec();
      return;
    }
    if (_timerSec > 0) {
      _startCountdown();
    } else {
      _startRec();
    }
  }

  void _startCountdown() {
    setState(() => _countdown = _timerSec);
    _cdTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _startRec();
      }
    });
  }

  Future<void> _startRec() async {
    if (_ctrl == null || !_ready) return;
    try {
      await _ctrl!.startVideoRecording();
      setState(() {
        _recording = true;
        _elapsed = 0;
        _showFilters = false;
        _showSpeed = false;
      });
      final maxSec = ref.read(reelsProvider).maxDurationSeconds;
      _recTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _elapsed++);
        if (_elapsed >= maxSec) _stopRec();
      });
    } catch (e) {
      debugPrint('startRec: $e');
    }
  }

  Future<void> _stopRec() async {
    _recTimer?.cancel();
    if (_ctrl == null || !_recording) return;
    try {
      final f = await _ctrl!.stopVideoRecording();
      setState(() => _recording = false);
      ref.read(reelsProvider.notifier).setVideo(f.path);
      if (mounted) {
        // FIX: was `const ReelsEditScreen()` — navigate with recorded path
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReelsPreviewScreen(videoPath: f.path),
          ),
        );
      }
    } catch (e) {
      debugPrint('stopRec: $e');
      setState(() => _recording = false);
    }
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(reelsProvider);
    // FIX: use [kReelFilters] which is now an alias for [reelsFilters]
    final matrix = kReelFilters[rs.selectedFilterIndex].matrix;
    final maxSec = rs.maxDurationSeconds;
    final progress = _recording ? (_elapsed / maxSec).clamp(0.0, 1.0) : 0.0;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBot = MediaQuery.of(context).padding.bottom;
    final h = MediaQuery.of(context).size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Camera preview with selected filter ──────────────────────────
            if (_ready && _ctrl != null)
              Positioned.fill(
                child: ColorFiltered(
                  colorFilter: ColorFilter.matrix(matrix),
                  child: CameraPreview(_ctrl!),
                ),
              )
            else
              const Center(child: CircularProgressIndicator(color: _kPrimary)),

            // ── Recording progress bar ────────────────────────────────────────
            if (_recording)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 3,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(_kPrimary),
                ),
              ),

            // ── TOP BAR ──────────────────────────────────────────────────────
            Positioned(
              top: safeTop + 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _circBtn(Icons.close, () {
                    ref.read(reelsProvider.notifier).reset();
                    Navigator.pop(context);
                  }),
                  const Spacer(),
                  // Music pill
                  GestureDetector(
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReelsMusicScreen(),
                          ),
                        ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color:
                              rs.selectedMusic != null
                                  ? _kPrimary
                                  : Colors.white38,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.music_note_rounded,
                            color:
                                rs.selectedMusic != null
                                    ? _kPrimary
                                    : Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(
                              rs.selectedMusic?.title ?? 'Add Sound',
                              style: TextStyle(
                                color:
                                    rs.selectedMusic != null
                                        ? _kPrimary
                                        : Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  _circBtn(
                    _flash == FlashMode.off
                        ? Icons.flash_off_rounded
                        : Icons.flash_on_rounded,
                    _toggleFlash,
                  ),
                ],
              ),
            ),

            // ── RIGHT SIDEBAR ─────────────────────────────────────────────────
            Positioned(
              right: 12,
              top: h * 0.22,
              child: Column(
                children: [
                  _sideItem(Icons.flip_camera_android_rounded, 'Flip', _flip),
                  const SizedBox(height: 22),
                  GestureDetector(
                    onTap: () => setState(() => _showSpeed = !_showSpeed),
                    child: _sideLabel(
                      Icons.speed_rounded,
                      rs.recordingSpeed == 1.0 ? '1×' : '${rs.recordingSpeed}×',
                      highlight: rs.recordingSpeed != 1.0,
                    ),
                  ),
                  const SizedBox(height: 22),
                  GestureDetector(
                    onTap: () => setState(() => _showTimer = !_showTimer),
                    child: _sideLabel(
                      Icons.timer_rounded,
                      _timerSec == 0 ? 'Timer' : '${_timerSec}s',
                      highlight: _timerSec != 0,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _sideItem(Icons.auto_fix_high_rounded, 'Effects', () {}),
                  const SizedBox(height: 22),
                  _sideItem(
                    Icons.lens_blur_rounded,
                    'Filters',
                    () => setState(() {
                      _showFilters = !_showFilters;
                      _showSpeed = false;
                      _showTimer = false;
                    }),
                  ),
                ],
              ),
            ),

            // ── BOTTOM CONTROLS ───────────────────────────────────────────────
            Positioned(
              bottom: safeBot + 16,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Duration chips
                  if (!_recording)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children:
                            [15, 30, 60, 180].map((d) {
                              final sel = rs.maxDurationSeconds == d;
                              return GestureDetector(
                                onTap:
                                    () => ref
                                        .read(reelsProvider.notifier)
                                        .setMaxDuration(d),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sel ? Colors.white : Colors.black45,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color:
                                          sel ? Colors.white : Colors.white38,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Text(
                                    d < 60 ? '${d}s' : '${d ~/ 60}m',
                                    style: TextStyle(
                                      color: sel ? Colors.black : Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Gallery
                      GestureDetector(
                        onTap: _recording ? null : _pickGallery,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white54),
                          ),
                          child: const Icon(
                            Icons.photo_library_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),

                      // Record button
                      GestureDetector(
                        onTap: _handleRecordTap,
                        child:
                            _recording
                                ? _StopBtn(elapsed: _elapsed, max: maxSec)
                                : ScaleTransition(
                                  scale: _pulseAnim,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 4,
                                      ),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 64,
                                        height: 64,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                      ),

                      const SizedBox(width: 52),
                    ],
                  ),
                ],
              ),
            ),

            // ── FILTER PANEL ──────────────────────────────────────────────────
            if (_showFilters)
              Positioned(
                bottom: safeBot + 160,
                left: 0,
                right: 0,
                height: 110,
                child: Container(
                  color: Colors.black54,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    itemCount: kReelFilters.length,
                    itemBuilder: (_, i) {
                      final f = kReelFilters[i];
                      final sel = rs.selectedFilterIndex == i;
                      return GestureDetector(
                        onTap: () {
                          ref.read(reelsProvider.notifier).setFilter(i);
                          setState(() => _showFilters = false);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Color(f.previewColor),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: sel ? _kPrimary : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                f.name,
                                style: TextStyle(
                                  color: sel ? _kPrimary : Colors.white,
                                  fontSize: 10,
                                  fontWeight:
                                      sel ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // ── SPEED PANEL ───────────────────────────────────────────────────
            if (_showSpeed)
              Positioned(
                right: 64,
                top: h * 0.28,
                child: _OptionPanel(
                  items: const ['0.3×', '0.5×', '1×', '2×', '3×'],
                  values: const [0.3, 0.5, 1.0, 2.0, 3.0],
                  selectedValue: rs.recordingSpeed,
                  onSelect: (v) {
                    ref.read(reelsProvider.notifier).setSpeed(v);
                    setState(() => _showSpeed = false);
                  },
                ),
              ),

            // ── TIMER PANEL ───────────────────────────────────────────────────
            if (_showTimer)
              Positioned(
                right: 64,
                top: h * 0.40,
                child: _OptionPanel(
                  items: const ['Off', '3s', '10s'],
                  values: const [0.0, 3.0, 10.0],
                  selectedValue: _timerSec.toDouble(),
                  onSelect:
                      (v) => setState(() {
                        _timerSec = v.toInt();
                        _showTimer = false;
                      }),
                ),
              ),

            // ── COUNTDOWN OVERLAY ─────────────────────────────────────────────
            if (_countdown > 0)
              Center(
                child: Text(
                  '$_countdown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(blurRadius: 30, color: Colors.black87)],
                  ),
                ),
              ),

            // ── REC BADGE ─────────────────────────────────────────────────────
            if (_recording)
              Positioned(
                top: safeTop + 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, color: Colors.white, size: 8),
                        const SizedBox(width: 6),
                        Text(
                          _fmt(_elapsed),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _circBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    ),
  );

  Widget _sideItem(IconData icon, String label, VoidCallback onTap) =>
      GestureDetector(onTap: onTap, child: _sideLabel(icon, label));

  Widget _sideLabel(IconData icon, String label, {bool highlight = false}) =>
      Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
              border: highlight ? Border.all(color: _kPrimary, width: 2) : null,
            ),
            child: Icon(
              icon,
              color: highlight ? _kPrimary : Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: highlight ? _kPrimary : Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}

// ─── Stop button ──────────────────────────────────────────────────────────────
class _StopBtn extends StatelessWidget {
  final int elapsed, max;
  const _StopBtn({required this.elapsed, required this.max});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 80,
    height: 80,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            value: (elapsed / max).clamp(0, 1),
            strokeWidth: 4,
            backgroundColor: Colors.white30,
            valueColor: const AlwaysStoppedAnimation<Color>(_kPrimary),
          ),
        ),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    ),
  );
}

// ─── Option panel (speed / timer) ─────────────────────────────────────────────
class _OptionPanel extends StatelessWidget {
  final List<String> items;
  final List<double> values;
  final double selectedValue;
  final ValueChanged<double> onSelect;

  const _OptionPanel({
    required this.items,
    required this.values,
    required this.selectedValue,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    decoration: BoxDecoration(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(items.length, (i) {
        final sel = values[i] == selectedValue;
        return GestureDetector(
          onTap: () => onSelect(values[i]),
          child: Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? _kPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              items[i],
              textAlign: TextAlign.center,
              style: TextStyle(
                color: sel ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        );
      }),
    ),
  );
}
