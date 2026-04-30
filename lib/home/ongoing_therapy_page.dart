import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:correctv1/bluetooth/aligneye_device_service.dart';
import 'package:correctv1/services/therapy_pattern_names.dart';

class OngoingTherapyPage extends StatefulWidget {
  final AlignEyeDeviceService deviceService;
  final int durationMinutes;
  final int intensity;
  final String targetPointName;

  const OngoingTherapyPage({
    super.key,
    required this.deviceService,
    required this.durationMinutes,
    required this.intensity,
    required this.targetPointName,
  });

  @override
  State<OngoingTherapyPage> createState() => _OngoingTherapyPageState();
}

class _OngoingTherapyPageState extends State<OngoingTherapyPage>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _breathController;
  late final AnimationController _wavesController;

  StreamSubscription<PostureReading>? _readingSub;

  // Live state mirrored from the device. Until the first therapy-mode JSON
  // arrives we show "Starting…" instead of fabricating a countdown.
  int _totalRemainingSeconds = -1;
  int _totalElapsedSeconds = 0;
  int _intensityLevel = 0;
  int _lastPatternStartElapsed = 0;
  String _lastPatternName = '';
  bool _sessionEndedByDevice = false;
  bool _stopping = false;
  int? _lastKnownPatternDurationSeconds;

  // Full therapy plan mirrored from the device. The swipeable card renders
  // one page per entry here, so the user can scroll through every pattern
  // in the session — past, present, and upcoming. Updated on every BLE
  // notification; empty until the device announces the sequence.
  List<int> _patternPlan = const [];
  int _liveIndexInPlan = 0;
  late final PageController _patternPageController;
  int _visiblePatternPage = 0;
  bool _userBrowsingPatterns = false;
  Timer? _browseResetTimer;

  late final int _totalDurationSeconds;

  @override
  void initState() {
    super.initState();
    _totalDurationSeconds = widget.durationMinutes * 60;
    _intensityLevel = widget.intensity;

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _wavesController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _patternPageController = PageController();

    // Prime state from the current reading if available (e.g. if the user
    // reopens this page after a late reconnect while therapy is running).
    _consumeReading(widget.deviceService.currentReading.value);
    _readingSub = widget.deviceService.readings.listen(_handleReading);
  }

  @override
  void dispose() {
    _readingSub?.cancel();
    _browseResetTimer?.cancel();
    _patternPageController.dispose();
    _entryController.dispose();
    _breathController.dispose();
    _wavesController.dispose();
    super.dispose();
  }

  void _handleReading(PostureReading reading) {
    _consumeReading(reading);
  }

  void _consumeReading(PostureReading? reading) {
    if (reading == null || !mounted) return;

    final isTherapy = reading.mode.toUpperCase() == 'THERAPY';
    final elapsed = reading.therapyElapsedSeconds;
    final remaining = reading.therapyRemainingSeconds;
    final patternNameRaw = reading.therapyPattern.trim();
    // Firmware emits `t_patt` like "Wave [S2:7 12s]" — peel off the suffix so
    // the UI shows a clean pattern name.
    final cleanPatternName = _stripSessionMeta(patternNameRaw);

    setState(() {
      if (!isTherapy) {
        // Device is no longer in therapy mode. Either the session finished
        // naturally on-device or we were stopped. Snap the UI to complete.
        if (_totalRemainingSeconds == 0 || _totalElapsedSeconds > 0) {
          _sessionEndedByDevice = true;
          _totalRemainingSeconds = 0;
          _breathController.stop();
          _wavesController.stop();
        }
        return;
      }

      _totalElapsedSeconds = elapsed;
      _totalRemainingSeconds = remaining;
      if (reading.therapyIntensityLevel >= 1 &&
          reading.therapyIntensityLevel <= 3) {
        _intensityLevel = reading.therapyIntensityLevel;
      }

      // Track when the current pattern started so we can show elapsed-in-pattern
      // without asking firmware for it. Pattern boundaries are detected by a
      // change in name.
      final oldLiveIndex = _liveIndexInPlan;
      final wasOnLivePage = _visiblePatternPage == oldLiveIndex;
      if (cleanPatternName != _lastPatternName) {
        if (_lastPatternName.isNotEmpty) {
          // We just crossed a boundary — if we know how long the previous
          // pattern ran, remember it as our best-known pattern duration so the
          // ring keeps showing a reasonable full-scale value for the new
          // pattern until we see it complete.
          final prevDuration = elapsed - _lastPatternStartElapsed;
          if (prevDuration > 0) {
            _lastKnownPatternDurationSeconds = prevDuration;
          }
          HapticFeedback.selectionClick();
        }
        _lastPatternName = cleanPatternName;
        _lastPatternStartElapsed = elapsed;
      }

      // Pull the full plan from the device. Firmware may publish sequence
      // fields a few JSON frames after therapy starts; once we have it we
      // keep it (don't let a momentarily missing frame blank the UI).
      if (reading.therapyPatternSequence.isNotEmpty) {
        _patternPlan = List<int>.unmodifiable(reading.therapyPatternSequence);
      }
      final reportedIndex = reading.therapyCurrentPatternIndex;
      if (reportedIndex >= 0 && reportedIndex < _patternPlan.length) {
        _liveIndexInPlan = reportedIndex;
      }

      // Follow-the-live behaviour: if the user was parked on the live page
      // and firmware advanced the live pattern, animate the pager along.
      if (_liveIndexInPlan != oldLiveIndex &&
          wasOnLivePage &&
          !_userBrowsingPatterns) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_patternPageController.hasClients) {
            _patternPageController.animateToPage(
              _liveIndexInPlan,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }

      if (remaining <= 0 && elapsed > 0) {
        _sessionEndedByDevice = true;
      }
    });
  }

  String _stripSessionMeta(String raw) {
    final bracket = raw.indexOf('[');
    if (bracket <= 0) return raw;
    return raw.substring(0, bracket).trim();
  }

  /// Page index in the swipeable card that represents the currently
  /// playing pattern. Matches firmware's `t_cur`, clamped to the known plan.
  int _liveCardIndex() {
    if (_patternPlan.isEmpty) return 0;
    return _liveIndexInPlan.clamp(0, _patternPlan.length - 1);
  }

  void _onPatternPageChanged(int index) {
    final liveIndex = _liveCardIndex();
    setState(() {
      _visiblePatternPage = index;
      _userBrowsingPatterns = index != liveIndex;
    });
    // If the user drifts away from the live card, remember that so the next
    // firmware pattern advance doesn't snap them back. Auto-reset after a
    // few seconds of stillness so the card resumes following the live pattern.
    _browseResetTimer?.cancel();
    if (_userBrowsingPatterns) {
      _browseResetTimer = Timer(const Duration(seconds: 8), () {
        if (!mounted) return;
        _snapToLivePattern();
      });
    }
  }

  void _snapToLivePattern() {
    final liveIndex = _liveCardIndex();
    if (!_patternPageController.hasClients) return;
    _patternPageController.animateToPage(
      liveIndex,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    setState(() {
      _visiblePatternPage = liveIndex;
      _userBrowsingPatterns = false;
    });
  }

  int get _patternElapsedSeconds {
    if (_totalElapsedSeconds <= 0) return 0;
    return math.max(0, _totalElapsedSeconds - _lastPatternStartElapsed);
  }

  int get _patternDurationSeconds {
    // Best estimate for the current pattern length:
    //   1. last completed pattern's observed duration, else
    //   2. total session / 7 (firmware uses ~1 min per pattern but clamps to
    //      `totalPatterns = minutes` so 10/20/30-min sessions give 10/14/14
    //      patterns — 7 is a safer default-looking visual scale).
    final guess =
        _lastKnownPatternDurationSeconds ?? (_totalDurationSeconds ~/ 7);
    return math.max(20, guess);
  }

  Future<void> _confirmStop() async {
    if (_sessionEndedByDevice) {
      Navigator.of(context).pop();
      return;
    }

    HapticFeedback.selectionClick();
    final shouldStop = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => _StopConfirmDialog(),
    );
    if (shouldStop != true || !mounted) return;

    setState(() => _stopping = true);
    await widget.deviceService.sendTherapyStop();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  String _formatMMSS(int totalSeconds) {
    final safe = math.max(0, totalSeconds);
    final m = (safe ~/ 60).toString().padLeft(2, '0');
    final s = (safe % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final sessionProgress = _totalDurationSeconds == 0
        ? 0.0
        : (_totalElapsedSeconds / _totalDurationSeconds).clamp(0.0, 1.0);
    final remainingForUi = _totalRemainingSeconds >= 0
        ? _totalRemainingSeconds
        : _totalDurationSeconds;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF1F2), Colors.white, Color(0xFFFDF2F8)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
            child: Column(
              children: [
                _StaggeredEntrance(
                  controller: _entryController,
                  delay: 0,
                  dy: -16,
                  child: _OngoingHeader(
                    onClose: _confirmStop,
                    isCompleted: _sessionEndedByDevice,
                    deviceService: widget.deviceService,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: _StaggeredEntrance(
                    controller: _entryController,
                    delay: 0.15,
                    scaleFrom: 0.94,
                    child: Center(
                      child: _RelaxingOrb(
                        breathController: _breathController,
                        wavesController: _wavesController,
                        patternElapsed: _patternElapsedSeconds,
                        patternDuration: _patternDurationSeconds,
                        sessionProgress: sessionProgress,
                        sessionRemainingSeconds: remainingForUi,
                        totalMinutes: widget.durationMinutes,
                        isCompleted: _sessionEndedByDevice,
                        formatTime: _formatMMSS,
                      ),
                    ),
                  ),
                ),
                _StaggeredEntrance(
                  controller: _entryController,
                  delay: 0.30,
                  child: _PatternCardPager(
                    controller: _patternPageController,
                    patternPlan: _patternPlan,
                    liveIndex: _liveCardIndex(),
                    visibleIndex: _visiblePatternPage,
                    targetPoint: widget.targetPointName,
                    intensity:
                        _intensityLevel > 0 ? _intensityLevel : widget.intensity,
                    isCompleted: _sessionEndedByDevice,
                    onPageChanged: _onPatternPageChanged,
                    onReturnToLive: _snapToLivePattern,
                  ),
                ),
                const SizedBox(height: 16),
                _StaggeredEntrance(
                  controller: _entryController,
                  delay: 0.40,
                  scaleFrom: 0.92,
                  child: _ControlRow(
                    isCompleted: _sessionEndedByDevice,
                    isStopping: _stopping,
                    onStop: _confirmStop,
                    onFinish: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OngoingHeader extends StatelessWidget {
  final VoidCallback onClose;
  final bool isCompleted;
  final AlignEyeDeviceService deviceService;

  const _OngoingHeader({
    required this.onClose,
    required this.isCompleted,
    required this.deviceService,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            onClose();
          },
          icon: const Icon(Icons.close_rounded),
          color: const Color(0xFF4B5563),
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 34),
        ),
        const Spacer(),
        ValueListenableBuilder<DeviceConnectionStatus>(
          valueListenable: deviceService.connectionStatus,
          builder: (context, status, _) {
            String label;
            Color color;
            bool animate = false;

            if (isCompleted) {
              label = 'Completed';
              color = const Color(0xFF10B981);
            } else {
              switch (status) {
                case DeviceConnectionStatus.connected:
                  label = 'Live Session';
                  color = const Color(0xFFFF2B62);
                  animate = true;
                  break;
                case DeviceConnectionStatus.connecting:
                  label = 'Reconnecting';
                  color = const Color(0xFFF59E0B);
                  animate = true;
                  break;
                case DeviceConnectionStatus.disconnected:
                  label = 'Disconnected';
                  color = const Color(0xFF6B7280);
                  break;
              }
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color.withValues(alpha: 0.30)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PulsingDot(color: color, animate: animate),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool animate;

  const _PulsingDot({required this.color, required this.animate});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      height: 10,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final ringScale = 1 + t * 1.6;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.animate)
                Opacity(
                  opacity: (1 - t).clamp(0, 1),
                  child: Transform.scale(
                    scale: ringScale,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RelaxingOrb extends StatelessWidget {
  final AnimationController breathController;
  final AnimationController wavesController;
  final int patternElapsed;
  final int patternDuration;
  final double sessionProgress;
  final int sessionRemainingSeconds;
  final int totalMinutes;
  final bool isCompleted;
  final String Function(int) formatTime;

  const _RelaxingOrb({
    required this.breathController,
    required this.wavesController,
    required this.patternElapsed,
    required this.patternDuration,
    required this.sessionProgress,
    required this.sessionRemainingSeconds,
    required this.totalMinutes,
    required this.isCompleted,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSide = math.min(constraints.maxWidth, constraints.maxHeight);
        final orbSize = math.min(maxSide, 340.0);
        final patternProgress = patternDuration == 0
            ? 0.0
            : (patternElapsed / patternDuration).clamp(0.0, 1.0);

        return SizedBox(
          width: orbSize,
          height: orbSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation:
                    Listenable.merge([breathController, wavesController]),
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(orbSize, orbSize),
                    painter: _OrbPainter(
                      breathValue: breathController.value,
                      wavesValue: wavesController.value,
                      isCompleted: isCompleted,
                      patternProgress: patternProgress,
                      sessionProgress: sessionProgress.clamp(0.0, 1.0),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'SESSION LEFT',
                      style: TextStyle(
                        color: Color(0xFFFF2B62),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatTime(sessionRemainingSeconds),
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 54,
                        fontWeight: FontWeight.w300,
                        height: 1.0,
                        letterSpacing: -1.3,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'of ${totalMinutes}m',
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: 40,
                      height: 1,
                      color: const Color(0xFFFCE7F3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      formatTime(patternElapsed),
                      style: const TextStyle(
                        color: Color(0xFFFF2B62),
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                        letterSpacing: 0.2,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'current pattern',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double breathValue;
  final double wavesValue;
  final bool isCompleted;
  final double patternProgress;
  final double sessionProgress;

  _OrbPainter({
    required this.breathValue,
    required this.wavesValue,
    required this.isCompleted,
    required this.patternProgress,
    required this.sessionProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Outer session ring sits near the edge; everything else is laid out
    // inward from it so the two ring thicknesses + the breathing orb + the
    // text column all compose without overlap.
    final outerRadius = size.width * 0.46;
    final innerRadius = outerRadius - 18;
    final baseRadius = innerRadius - 16;

    final breath = Curves.easeInOut.transform(breathValue);

    // Ambient ripple waves behind everything for the "relaxing" feel.
    if (!isCompleted) {
      for (int i = 0; i < 3; i++) {
        final phase = (wavesValue + i / 3) % 1.0;
        final waveRadius = baseRadius * (1.02 + phase * 0.55);
        final opacity = (1 - phase).clamp(0.0, 1.0) * 0.28;
        final wavePaint = Paint()
          ..color = const Color(0xFFFF4F73).withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
        canvas.drawCircle(center, waveRadius, wavePaint);
      }
    }

    final breathRadius = baseRadius * (1.0 + breath * 0.08);

    // Soft halo under the orb.
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF7DA0).withValues(alpha: 0.38),
          const Color(0xFFFFB4C5).withValues(alpha: 0.0),
        ],
        stops: const [0.35, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: breathRadius * 1.6),
      );
    canvas.drawCircle(center, breathRadius * 1.6, haloPaint);

    // Breathing orb body.
    final orbRect = Rect.fromCircle(center: center, radius: breathRadius);
    final orbPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFE4E6),
          Color(0xFFFFD1DC),
          Color(0xFFFCE7F3),
        ],
      ).createShader(orbRect);
    canvas.drawCircle(center, breathRadius, orbPaint);

    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 0.85,
        colors: [
          Colors.white.withValues(alpha: 0.80),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(orbRect);
    canvas.drawCircle(center, breathRadius, highlightPaint);

    final orbBorderPaint = Paint()
      ..color = const Color(0xFFFF2B62).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, breathRadius, orbBorderPaint);

    // Inner ring — current-pattern progress.
    _drawProgressRing(
      canvas,
      center,
      innerRadius,
      patternProgress,
      strokeWidth: 5,
      trackColor: const Color(0xFFFCE7F3),
      gradientColors: const [Color(0xFFFF7DA0), Color(0xFFFF2B62)],
    );

    // Outer ring — total session progress. Slightly thicker so it reads as
    // the "bigger / primary" timer visually.
    _drawProgressRing(
      canvas,
      center,
      outerRadius,
      sessionProgress,
      strokeWidth: 7,
      trackColor: const Color(0xFFFFE4E6),
      gradientColors: const [Color(0xFFFF1F5B), Color(0xFFED2CA6)],
    );
  }

  void _drawProgressRing(
    Canvas canvas,
    Offset center,
    double radius,
    double progress, {
    required double strokeWidth,
    required Color trackColor,
    required List<Color> gradientColors,
  }) {
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final clamped = progress.clamp(0.0, 1.0);
    if (clamped <= 0) return;

    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi,
        colors: gradientColors,
      ).createShader(arcRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      2 * math.pi * clamped,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) {
    return oldDelegate.breathValue != breathValue ||
        oldDelegate.wavesValue != wavesValue ||
        oldDelegate.isCompleted != isCompleted ||
        oldDelegate.patternProgress != patternProgress ||
        oldDelegate.sessionProgress != sessionProgress;
  }
}

/// Swipeable pattern information. One page per pattern in the full session
/// plan — both already-played and upcoming — so the user can swipe through
/// every step of the therapy from start to end. The live pattern is
/// [liveIndex]; everything before it has played, everything after is queued.
class _PatternCardPager extends StatelessWidget {
  final PageController controller;
  final List<int> patternPlan;
  final int liveIndex;
  final int visibleIndex;
  final String targetPoint;
  final int intensity;
  final bool isCompleted;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onReturnToLive;

  const _PatternCardPager({
    required this.controller,
    required this.patternPlan,
    required this.liveIndex,
    required this.visibleIndex,
    required this.targetPoint,
    required this.intensity,
    required this.isCompleted,
    required this.onPageChanged,
    required this.onReturnToLive,
  });

  @override
  Widget build(BuildContext context) {
    final pages = <_PatternCardData>[];
    if (patternPlan.isEmpty) {
      pages.add(_PatternCardData.placeholder(isCompleted: isCompleted));
    } else {
      for (var i = 0; i < patternPlan.length; i++) {
        final patternId = patternPlan[i];
        final hasName = patternId >= 0 && patternId < kTherapyPatternNames.length;
        final name = hasName ? therapyPatternName(patternId) : 'Pattern ${i + 1}';
        final description = hasName
            ? therapyPatternDescription(patternId)
            : 'Pattern details will appear once it plays.';

        final _PatternCardStatus status;
        if (isCompleted) {
          status = _PatternCardStatus.played;
        } else if (i < liveIndex) {
          status = _PatternCardStatus.played;
        } else if (i == liveIndex) {
          status = _PatternCardStatus.live;
        } else {
          status = _PatternCardStatus.upcoming;
        }

        pages.add(_PatternCardData.fromPlan(
          name: name,
          description: description,
          indexInSession: i,
          totalInSession: patternPlan.length,
          status: status,
        ));
      }
    }

    final totalPages = pages.length;
    final effectiveVisible = visibleIndex.clamp(0, totalPages - 1);
    final showReturnToLive =
        !isCompleted && effectiveVisible != liveIndex && patternPlan.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 172,
          child: PageView.builder(
            controller: controller,
            physics: const BouncingScrollPhysics(),
            itemCount: totalPages,
            onPageChanged: (index) {
              HapticFeedback.selectionClick();
              onPageChanged(index);
            },
            itemBuilder: (context, index) {
              final data = pages[index];
              return _PatternInfoCard(
                data: data,
                targetPoint: targetPoint,
                intensity: intensity,
                isCompleted: isCompleted,
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showReturnToLive)
              _BackToLivePill(onTap: onReturnToLive)
            else
              _PageDots(count: totalPages, activeIndex: effectiveVisible, liveIndex: liveIndex),
          ],
        ),
      ],
    );
  }
}

/// Immutable view model for a single pattern card. Populated from either
/// session history, a preview of the upcoming pattern, or a "not started
/// yet" placeholder.
class _PatternCardData {
  final String name;
  final String description;
  final String badge;
  final _PatternCardStatus status;
  final bool isPlaceholder;

  const _PatternCardData({
    required this.name,
    required this.description,
    required this.badge,
    required this.status,
    required this.isPlaceholder,
  });

  bool get isLive => status == _PatternCardStatus.live;
  bool get isUpcoming => status == _PatternCardStatus.upcoming;
  bool get isPlayed => status == _PatternCardStatus.played;

  factory _PatternCardData.fromPlan({
    required String name,
    required String description,
    required int indexInSession,
    required int totalInSession,
    required _PatternCardStatus status,
  }) {
    final badge = switch (status) {
      _PatternCardStatus.live => 'Playing now',
      _PatternCardStatus.upcoming =>
        'Up next · ${indexInSession + 1}/$totalInSession',
      _PatternCardStatus.played => 'Played · ${indexInSession + 1}/$totalInSession',
    };
    return _PatternCardData(
      name: name,
      description: description,
      badge: badge,
      status: status,
      isPlaceholder: false,
    );
  }

  factory _PatternCardData.placeholder({required bool isCompleted}) {
    return _PatternCardData(
      name: isCompleted ? 'Session Complete' : 'Starting…',
      description: isCompleted
          ? 'Your therapy session has finished.'
          : 'Getting your therapy session ready…',
      badge: isCompleted ? 'Finished' : 'Live',
      status: isCompleted ? _PatternCardStatus.played : _PatternCardStatus.live,
      isPlaceholder: true,
    );
  }
}

enum _PatternCardStatus { played, live, upcoming }

class _PatternInfoCard extends StatelessWidget {
  final _PatternCardData data;
  final String targetPoint;
  final int intensity;
  final bool isCompleted;

  const _PatternInfoCard({
    required this.data,
    required this.targetPoint,
    required this.intensity,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final patternName = data.name;
    final patternDescription = data.description;
    final badgeLabel = data.badge;
    final accentGradient = switch (data.status) {
      _PatternCardStatus.live =>
        const [Color(0xFFFF1F5B), Color(0xFFED2CA6)],
      _PatternCardStatus.upcoming =>
        const [Color(0xFFFFB4C5), Color(0xFFFBCFE8)],
      _PatternCardStatus.played =>
        const [Color(0xFFE5E7EB), Color(0xFFD1D5DB)],
    };
    final badgeColor = switch (data.status) {
      _PatternCardStatus.live => const Color(0xFFFF2B62),
      _PatternCardStatus.upcoming => const Color(0xFFA855F7),
      _PatternCardStatus.played => const Color(0xFF9CA3AF),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: data.isLive
              ? const Color(0xFFFF2B62).withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.72),
          width: data.isLive ? 1.2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: accentGradient,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  switch (data.status) {
                    _PatternCardStatus.live => Icons.auto_awesome_rounded,
                    _PatternCardStatus.upcoming => Icons.schedule_rounded,
                    _PatternCardStatus.played => Icons.check_rounded,
                  },
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patternName,
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: badgeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          badgeLabel,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            patternDescription,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF4B5563),
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetaChip(
                icon: Icons.gps_fixed_rounded,
                label: targetPoint,
              ),
              const SizedBox(width: 8),
              _MetaChip(
                icon: Icons.graphic_eq_rounded,
                label: 'Level $intensity/3',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dots below the swipeable card. The live card's dot is drawn as a longer
/// pill so the user can tell at a glance which page the device is on.
class _PageDots extends StatelessWidget {
  final int count;
  final int activeIndex;
  final int liveIndex;

  const _PageDots({
    required this.count,
    required this.activeIndex,
    required this.liveIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox(height: 6);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == activeIndex;
        final isLive = i == liveIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 6,
          width: isActive ? (isLive ? 20 : 16) : 6,
          decoration: BoxDecoration(
            color: isActive
                ? (isLive
                    ? const Color(0xFFFF2B62)
                    : const Color(0xFFED2CA6))
                : const Color(0xFFFBCFE8),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

/// Small "back to live" affordance that appears while the user is browsing
/// the pattern history. Tapping it animates the PageView back to the
/// currently-playing pattern.
class _BackToLivePill extends StatelessWidget {
  final VoidCallback onTap;

  const _BackToLivePill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF1F5B), Color(0xFFED2CA6)],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF43F5E).withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.graphic_eq_rounded,
                color: Colors.white,
                size: 14,
              ),
              SizedBox(width: 6),
              Text(
                'Back to live',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFCE7F3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFFF2B62)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF4B5563),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  final bool isCompleted;
  final bool isStopping;
  final VoidCallback onStop;
  final VoidCallback onFinish;

  const _ControlRow({
    required this.isCompleted,
    required this.isStopping,
    required this.onStop,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompleted) {
      return _PrimaryButton(
        label: 'Finish',
        icon: Icons.check_rounded,
        onTap: onFinish,
      );
    }
    return _PrimaryButton(
      label: isStopping ? 'Stopping…' : 'Stop Therapy',
      icon: Icons.stop_rounded,
      onTap: isStopping ? null : onStop,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: disabled
                  ? const [Color(0xFFFFB4C5), Color(0xFFFBCFE8)]
                  : const [Color(0xFFFF1F5B), Color(0xFFED2CA6)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF43F5E).withValues(alpha: 0.32),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StopConfirmDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.stop_circle_outlined,
                color: Color(0xFFFF2B62),
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'End session?',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your current therapy session will stop on the device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      backgroundColor: const Color(0xFFF3F4F6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Keep going',
                      style: TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ).copyWith(
                      backgroundColor: WidgetStateProperty.all(
                        const Color(0xFFFF2B62),
                      ),
                    ),
                    child: const Text(
                      'End',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

class _StaggeredEntrance extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final double dy;
  final double scaleFrom;
  final Widget child;

  const _StaggeredEntrance({
    required this.controller,
    required this.delay,
    required this.child,
    this.dy = 20,
    this.scaleFrom = 1,
  });

  @override
  Widget build(BuildContext context) {
    final start = delay.clamp(0.0, 0.85);
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final value = animation.value;
        final scale = scaleFrom + (1 - scaleFrom) * value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, dy * (1 - value)),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }
}
