import 'dart:async';

import 'package:correctv1/bluetooth/aligneye_device_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _CalibrationStage {
  intro,
  starting,
  getReady,
  holdStill,
  failed,
  success,
  disconnected,
}

class CalibrationPage extends StatefulWidget {
  const CalibrationPage({
    super.key,
    required this.deviceService,
    this.autoStart = false,
  });

  final AlignEyeDeviceService deviceService;
  final bool autoStart;

  @override
  State<CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends State<CalibrationPage>
    with TickerProviderStateMixin {
  static const Duration _getReadyDuration = Duration(seconds: 3);
  static const Duration _holdStillDuration = Duration(seconds: 5);
  static const Duration _startDetectTimeout = Duration(seconds: 6);
  static const Duration _resultTimeout = Duration(seconds: 14);
  static const Duration _packetPauseThreshold = Duration(milliseconds: 1300);

  late final AnimationController _pulseController;
  late final AnimationController _ringController;
  late final AnimationController _fadeController;
  StreamSubscription<PostureReading>? _readingSubscription;
  Timer? _ticker;
  Timer? _successAutoCloseTimer;

  _CalibrationStage _stage = _CalibrationStage.intro;
  DateTime? _startRequestedAt;
  DateTime? _calibrationStartedAt;
  DateTime? _lastPacketAt;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _lastPacketAt = widget.deviceService.currentReading.value?.timestamp;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _ringController = AnimationController(
      vsync: this,
      duration: _getReadyDuration + _holdStillDuration,
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _readingSubscription = widget.deviceService.readings.listen(_onReading);
    _ticker = Timer.periodic(const Duration(milliseconds: 120), (_) => _onTick());

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_startCalibration());
        }
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _successAutoCloseTimer?.cancel();
    _readingSubscription?.cancel();
    _pulseController.dispose();
    _ringController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  bool get _isConnected =>
      widget.deviceService.connectionStatus.value ==
      DeviceConnectionStatus.connected;

  Future<void> _startCalibration() async {
    if (!_isConnected) {
      setState(() => _stage = _CalibrationStage.disconnected);
      return;
    }

    HapticFeedback.selectionClick();
    final now = DateTime.now();
    setState(() {
      _stage = _CalibrationStage.starting;
      _startRequestedAt = now;
      _calibrationStartedAt = null;
    });

    final sent = await widget.deviceService.sendCalibrationStart();
    if (!mounted) return;
    if (!sent) {
      setState(() => _stage = _CalibrationStage.failed);
    }
  }

  Future<void> _cancelCalibration() async {
    await widget.deviceService.sendCalibrationCancel();
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  void _markCalibrationStarted() {
    if (_stage == _CalibrationStage.getReady || _stage == _CalibrationStage.holdStill) {
      return;
    }

    final now = DateTime.now();
    setState(() {
      _calibrationStartedAt = now;
      _stage = _CalibrationStage.getReady;
    });
    _ringController
      ..value = 0
      ..forward();
  }

  void _onReading(PostureReading reading) {
    _lastPacketAt = DateTime.now();

    if (!_isConnected &&
        _stage != _CalibrationStage.success &&
        _stage != _CalibrationStage.intro) {
      setState(() => _stage = _CalibrationStage.disconnected);
      return;
    }

    if ((_stage == _CalibrationStage.starting || _stage == _CalibrationStage.intro) &&
        reading.isCalibrating) {
      _markCalibrationStarted();
      return;
    }

    if (_stage == _CalibrationStage.getReady || _stage == _CalibrationStage.holdStill) {
      if (!reading.isCalibrating) {
        _completeFromReading(reading);
      }
    }
  }

  void _completeFromReading(PostureReading reading) {
    final mode = reading.mode.trim().toUpperCase();
    final success = mode == 'TRAINING' || mode == 'POSTURE';

    setState(() {
      _stage = success ? _CalibrationStage.success : _CalibrationStage.failed;
    });

    if (success) {
      HapticFeedback.lightImpact();
      _successAutoCloseTimer?.cancel();
      _successAutoCloseTimer = Timer(const Duration(milliseconds: 1500), () {
        if (!mounted || _closing) return;
        _closing = true;
        Navigator.of(context).pop(true);
      });
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _onTick() {
    if (!mounted) return;

    if (!_isConnected &&
        _stage != _CalibrationStage.intro &&
        _stage != _CalibrationStage.success) {
      setState(() => _stage = _CalibrationStage.disconnected);
      return;
    }

    if (_stage == _CalibrationStage.starting) {
      final now = DateTime.now();
      final requestStart = _startRequestedAt ?? now;
      final elapsed = now.difference(requestStart);
      final packetAge = _lastPacketAt == null
          ? Duration.zero
          : now.difference(_lastPacketAt!);

      if (packetAge >= _packetPauseThreshold) {
        _markCalibrationStarted();
        return;
      }

      if (elapsed >= _startDetectTimeout) {
        setState(() => _stage = _CalibrationStage.failed);
      }
    }

    if (_stage == _CalibrationStage.getReady || _stage == _CalibrationStage.holdStill) {
      final startedAt = _calibrationStartedAt;
      if (startedAt == null) return;
      final elapsed = DateTime.now().difference(startedAt);

      // Rebuild continuously so countdown text and progress ring animate live.
      setState(() {});

      if (_stage == _CalibrationStage.getReady && elapsed >= _getReadyDuration) {
        setState(() => _stage = _CalibrationStage.holdStill);
      }

      if (elapsed >= _resultTimeout) {
        setState(() => _stage = _CalibrationStage.failed);
      }
    }
  }

  double _phaseProgress() {
    if (_calibrationStartedAt == null) return 0;
    final elapsed = DateTime.now().difference(_calibrationStartedAt!);
    if (_stage == _CalibrationStage.getReady) {
      return (elapsed.inMilliseconds / _getReadyDuration.inMilliseconds).clamp(
        0.0,
        1.0,
      );
    }
    if (_stage == _CalibrationStage.holdStill) {
      final holdElapsed = elapsed - _getReadyDuration;
      return (holdElapsed.inMilliseconds / _holdStillDuration.inMilliseconds).clamp(
        0.0,
        1.0,
      );
    }
    return 0;
  }

  int _remainingSeconds() {
    if (_calibrationStartedAt == null) return 0;
    final elapsed = DateTime.now().difference(_calibrationStartedAt!);

    if (_stage == _CalibrationStage.getReady) {
      final remainingMs = _getReadyDuration.inMilliseconds - elapsed.inMilliseconds;
      if (remainingMs <= 0) return 0;
      return (remainingMs / 1000).ceil();
    }

    if (_stage == _CalibrationStage.holdStill) {
      final holdElapsed = elapsed - _getReadyDuration;
      final remainingMs = _holdStillDuration.inMilliseconds - holdElapsed.inMilliseconds;
      if (remainingMs <= 0) return 0;
      return (remainingMs / 1000).ceil();
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAFF),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _buildStage(context),
          ),
        ),
      ),
    );
  }

  Widget _buildStage(BuildContext context) {
    switch (_stage) {
      case _CalibrationStage.intro:
        return _IntroScreen(
          key: const ValueKey('intro'),
          onStart: () => unawaited(_startCalibration()),
          onCancel: () => Navigator.of(context).pop(false),
        );
      case _CalibrationStage.starting:
        return _StatusScreen(
          key: const ValueKey('starting'),
          iconColor: const Color(0xFF0EA5A4),
          ringColor: const Color(0xFF0EA5A4),
          title: 'Starting Calibration',
          message:
              'Preparing your device. Sit comfortably and keep a natural upright posture.',
          progress: null,
          icon: Icons.bluetooth_searching_rounded,
        );
      case _CalibrationStage.getReady:
        return _StatusScreen(
          key: const ValueKey('get_ready'),
          iconColor: const Color(0xFFF59E0B),
          ringColor: const Color(0xFFF59E0B),
          title: 'Get Ready...',
          message:
              'Sit comfortably and relax your shoulders.\nCalibration will begin shortly.',
          progress: _phaseProgress(),
          icon: Icons.circle_rounded,
          pulse: _pulseController,
          showCalibratingText: false,
          timerText: '${_remainingSeconds()}s',
        );
      case _CalibrationStage.holdStill:
        return _StatusScreen(
          key: const ValueKey('hold_still'),
          iconColor: const Color(0xFF16A34A),
          ringColor: const Color(0xFF16A34A),
          title: 'Hold Still',
          message: 'Keep your posture steady\nTry not to move',
          progress: _phaseProgress(),
          icon: Icons.check_circle_outline_rounded,
          pulse: _pulseController,
          showCalibratingText: true,
          timerText: '${_remainingSeconds()}s',
        );
      case _CalibrationStage.failed:
        return _ResultScreen(
          key: const ValueKey('failed'),
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFDC2626),
          title: 'Calibration Failed',
          message:
              'We detected movement during calibration.\nPlease sit still and try again.',
          primaryLabel: 'Try Again',
          secondaryLabel: 'Cancel',
          onPrimary: () => unawaited(_startCalibration()),
          onSecondary: _cancelCalibration,
        );
      case _CalibrationStage.success:
        return const _ResultScreen(
          key: ValueKey('success'),
          icon: Icons.check_circle_rounded,
          iconColor: Color(0xFF16A34A),
          title: 'Calibration Complete',
          message: 'Your neutral posture has been saved successfully.',
          subText: 'Training mode is now active.',
        );
      case _CalibrationStage.disconnected:
        return _ResultScreen(
          key: const ValueKey('disconnected'),
          icon: Icons.bluetooth_disabled_rounded,
          iconColor: const Color(0xFFDC2626),
          title: 'Device Disconnected',
          message: 'Reconnect your device to continue calibration.',
          primaryLabel: 'Back',
          onPrimary: () => Navigator.of(context).pop(false),
        );
    }
  }
}

class _IntroScreen extends StatelessWidget {
  const _IntroScreen({
    super.key,
    required this.onStart,
    required this.onCancel,
  });

  final VoidCallback onStart;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: key,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEAF5FF), Color(0xFFF8FEFF), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        children: [
          const Spacer(),
          const Text(
            'Posture Calibration',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'This helps AlignEye understand your natural upright posture.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF475569),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 30),
          const _SittingIllustration(),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Start Calibration',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onCancel,
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusScreen extends StatelessWidget {
  const _StatusScreen({
    super.key,
    required this.iconColor,
    required this.ringColor,
    required this.title,
    required this.message,
    required this.progress,
    required this.icon,
    this.pulse,
    this.showCalibratingText = false,
    this.timerText,
  });

  final Color iconColor;
  final Color ringColor;
  final String title;
  final String message;
  final double? progress;
  final IconData icon;
  final Animation<double>? pulse;
  final bool showCalibratingText;
  final String? timerText;

  @override
  Widget build(BuildContext context) {
    final progressValue = progress;
    final ringScale =
        pulse == null ? 1.0 : (0.96 + ((pulse!.value) * 0.08)).clamp(0.9, 1.1);

    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEAF6FF), Color(0xFFF8FEFF), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withOpacity(0.12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 31,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF475569),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 26),
          if (timerText != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: ringColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: ringColor.withOpacity(0.25)),
              ),
              child: Text(
                timerText!,
                style: TextStyle(
                  color: ringColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Transform.scale(
            scale: ringScale,
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progressValue,
                    strokeWidth: 11,
                    color: ringColor,
                    backgroundColor: const Color(0xFFDCEFFE),
                  ),
                  if (showCalibratingText)
                    const Text(
                      'Calibrating...',
                      style: TextStyle(
                        color: Color(0xFF166534),
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(height: 54),
        ],
      ),
    );
  }
}

class _ResultScreen extends StatelessWidget {
  const _ResultScreen({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.subText,
    this.primaryLabel,
    this.secondaryLabel,
    this.onPrimary,
    this.onSecondary,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? subText;
  final String? primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEAF6FF), Color(0xFFF8FEFF), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withOpacity(0.12),
            ),
            child: Icon(icon, color: iconColor, size: 42),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF475569),
              height: 1.35,
            ),
          ),
          if (subText != null) ...[
            const SizedBox(height: 10),
            Text(
              subText!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ],
          const Spacer(),
          if (primaryLabel != null && onPrimary != null)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: onPrimary,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  primaryLabel!,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSecondary,
              child: Text(
                secondaryLabel!,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SittingIllustration extends StatelessWidget {
  const _SittingIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8EAFE)),
      ),
      child: CustomPaint(
        painter: _SittingIllustrationPainter(),
      ),
    );
  }
}

class _SittingIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 5
      ..color = const Color(0xFF0EA5A4);

    final support = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0xFF60A5FA);

    final chairPath = Path()
      ..moveTo(size.width * 0.33, size.height * 0.72)
      ..lineTo(size.width * 0.65, size.height * 0.72)
      ..moveTo(size.width * 0.33, size.height * 0.72)
      ..lineTo(size.width * 0.33, size.height * 0.35);
    canvas.drawPath(chairPath, support);

    final headCenter = Offset(size.width * 0.54, size.height * 0.24);
    canvas.drawCircle(headCenter, 16, line);

    final bodyPath = Path()
      ..moveTo(size.width * 0.54, size.height * 0.40)
      ..lineTo(size.width * 0.54, size.height * 0.58)
      ..lineTo(size.width * 0.44, size.height * 0.65)
      ..lineTo(size.width * 0.37, size.height * 0.72)
      ..moveTo(size.width * 0.54, size.height * 0.56)
      ..lineTo(size.width * 0.63, size.height * 0.62)
      ..lineTo(size.width * 0.69, size.height * 0.72)
      ..moveTo(size.width * 0.54, size.height * 0.46)
      ..lineTo(size.width * 0.44, size.height * 0.50);
    canvas.drawPath(bodyPath, line);

    final uprightPath = Path()
      ..moveTo(size.width * 0.73, size.height * 0.15)
      ..lineTo(size.width * 0.73, size.height * 0.64);
    canvas.drawPath(
      uprightPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF93C5FD),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
