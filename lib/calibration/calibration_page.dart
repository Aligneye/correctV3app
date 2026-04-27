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
  static const int _getReadyMs = 3000;
  static const int _holdStillMs = 5000;
  static const Duration _startDetectTimeout = Duration(seconds: 6);

  late final AnimationController _pulseController;
  late final AnimationController _scaleController;
  late final AnimationController _successBarController;
  late final AnimationController _failedBarController;
  StreamSubscription<PostureReading>? _readingSubscription;
  Timer? _ticker;
  Timer? _successAutoCloseTimer;

  _CalibrationStage _stage = _CalibrationStage.intro;
  DateTime? _startRequestedAt;
  bool _closing = false;
  bool _completionHandled = false;

  // Device-driven progress (from BLE)
  int _deviceElapsedMs = 0;
  String _devicePhase = 'IDLE';

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _successBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _failedBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _readingSubscription = widget.deviceService.readings.listen(_onReading);
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _onTick());

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_startCalibration());
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _successAutoCloseTimer?.cancel();
    _readingSubscription?.cancel();
    _pulseController.dispose();
    _scaleController.dispose();
    _successBarController.dispose();
    _failedBarController.dispose();
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
    setState(() {
      _stage = _CalibrationStage.starting;
      _startRequestedAt = DateTime.now();
      _completionHandled = false;
      _deviceElapsedMs = 0;
      _devicePhase = 'IDLE';
    });

    final sent = await widget.deviceService.sendCalibrationStart();
    if (!mounted) return;
    if (!sent) {
      setState(() => _stage = _CalibrationStage.failed);
      _failedBarController.forward();
    }
  }

  void _onReading(PostureReading reading) {
    if (_stage == _CalibrationStage.success || _completionHandled) return;

    if (!_isConnected && _stage != _CalibrationStage.intro) {
      setState(() => _stage = _CalibrationStage.disconnected);
      return;
    }

    // Device-driven: calibration_result is authoritative
    // But ignore stale results when just starting (they're from previous calibration)
    if (reading.calibrationResult.isNotEmpty &&
        _stage != _CalibrationStage.starting &&
        _stage != _CalibrationStage.intro) {
      _handleCalibrationResult(reading.calibrationResult == 'complete');
      return;
    }

    // Sync progress from device
    _deviceElapsedMs = reading.calibrationElapsedMs;
    _devicePhase = reading.calibrationPhase;

    // Transition to getReady when device starts calibrating
    if ((_stage == _CalibrationStage.starting || _stage == _CalibrationStage.intro) &&
        reading.isCalibrating) {
      setState(() => _stage = _CalibrationStage.getReady);
      return;
    }

    // Phase transitions from device
    if (_stage == _CalibrationStage.getReady &&
        _devicePhase == 'HOLD_STILL') {
      setState(() => _stage = _CalibrationStage.holdStill);
    }

    // Calibration cancelled from device (e.g. button press) - no result sent
    if ((_stage == _CalibrationStage.getReady ||
            _stage == _CalibrationStage.holdStill) &&
        !reading.isCalibrating &&
        reading.calibrationResult.isEmpty) {
      if (mounted) Navigator.of(context).pop(false);
    }
  }

  void _handleCalibrationResult(bool success) {
    if (_completionHandled) return;
    _completionHandled = true;

    setState(() {
      _stage = success ? _CalibrationStage.success : _CalibrationStage.failed;
    });

    if (success) {
      HapticFeedback.lightImpact();
      _successBarController.forward();

      Future<void> syncMode() async {
        if (mounted && _isConnected) {
          try {
            await widget.deviceService.sendModeControl(
              mode: 'TRAINING',
              postureTiming: 'INSTANT',
              therapyDurationMinutes: 10,
              difficultyDegrees: 25,
            );
          } catch (_) {}
        }
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted && _isConnected) {
          try {
            await widget.deviceService.sendModeControl(
              mode: 'TRAINING',
              postureTiming: 'INSTANT',
              therapyDurationMinutes: 10,
              difficultyDegrees: 25,
            );
          } catch (_) {}
        }
      }
      unawaited(syncMode());

      _successAutoCloseTimer?.cancel();
      _successAutoCloseTimer = Timer(const Duration(milliseconds: 2200), () {
        if (!mounted || _closing) return;
        _closing = true;
        Navigator.of(context).pop(true);
      });
    } else {
      HapticFeedback.heavyImpact();
      _failedBarController.reset();
      _failedBarController.forward();
    }
  }

  void _onTick() {
    if (!mounted) return;
    if (_stage == _CalibrationStage.success || _completionHandled) return;

    if (!_isConnected && _stage != _CalibrationStage.intro) {
      setState(() => _stage = _CalibrationStage.disconnected);
      return;
    }

    if (_stage == _CalibrationStage.starting) {
      final elapsed = DateTime.now().difference(_startRequestedAt ?? DateTime.now());
      if (elapsed >= _startDetectTimeout) {
        setState(() => _stage = _CalibrationStage.failed);
        _failedBarController.forward();
      }
    }

    // Rebuild for progress updates
    if (_stage == _CalibrationStage.getReady ||
        _stage == _CalibrationStage.holdStill) {
      setState(() {});
    }
  }

  int _getReadyRemainingSeconds() {
    if (_devicePhase != 'GET_READY') return 0;
    final remainingMs = _getReadyMs - _deviceElapsedMs;
    if (remainingMs <= 0) return 0;
    return (remainingMs / 1000).ceil();
  }

  double _getHoldStillProgress() {
    if (_devicePhase != 'HOLD_STILL') return 0;
    final holdElapsed = _deviceElapsedMs - _getReadyMs;
    return (holdElapsed / _holdStillMs).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1A1D),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _buildStage(context),
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
          title: 'Starting',
          message: 'Preparing your device...',
          icon: Icons.bluetooth_searching_rounded,
          color: const Color(0xFF008090),
        );
      case _CalibrationStage.getReady:
        return _GetReadyScreen(
          key: const ValueKey('get_ready'),
          countdown: _getReadyRemainingSeconds(),
          progress: (_deviceElapsedMs / _getReadyMs).clamp(0.0, 1.0),
          pulse: _pulseController,
        );
      case _CalibrationStage.holdStill:
        return _HoldStillScreen(
          key: const ValueKey('hold_still'),
          progress: _getHoldStillProgress(),
          pulse: _pulseController,
        );
      case _CalibrationStage.failed:
        return _ResultScreen(
          key: const ValueKey('failed'),
          icon: Icons.error_outline_rounded,
          color: const Color(0xFFEF4444),
          title: 'Calibration Failed',
          message: 'Movement detected.\nPlease try again.',
          showFailedBar: true,
          barProgress: _failedBarController,
          primaryLabel: 'Retry Calibration',
          onPrimary: () {
            _failedBarController.reset();
            unawaited(_startCalibration());
          },
        );
      case _CalibrationStage.success:
        return _ResultScreen(
          key: const ValueKey('success'),
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF14B8A6),
          title: 'Calibration Complete',
          message: 'Your ideal posture has been saved.\nPosture tracking started.',
          subText: 'Auto return → Training Screen',
          showSuccessBar: true,
          barProgress: _successBarController,
        );
      case _CalibrationStage.disconnected:
        return _ResultScreen(
          key: const ValueKey('disconnected'),
          icon: Icons.bluetooth_disabled_rounded,
          color: const Color(0xFFEF4444),
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
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 36),
      child: Column(
        children: [
          const Spacer(),
          Text(
            'Calibrate Posture',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Set your ideal sitting posture for accurate tracking.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.65),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                Icon(Icons.airline_seat_recline_normal_rounded,
                    size: 48, color: const Color(0xFF008090).withOpacity(0.9)),
                const SizedBox(height: 16),
                Text(
                  'Sit comfortably in your natural upright posture.\nKeep your back straight and shoulders relaxed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: onStart,
                  borderRadius: BorderRadius.circular(16),
                  child: const Center(
                    child: Text(
                      'Start Calibration',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onCancel,
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withOpacity(0.6),
                fontWeight: FontWeight.w500,
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
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: key,
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.7),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _GetReadyScreen extends StatelessWidget {
  const _GetReadyScreen({
    super.key,
    required this.countdown,
    required this.progress,
    required this.pulse,
  });

  final int countdown;
  final double progress;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final scale = 0.97 + (pulse.value * 0.06);
    return Container(
      key: key,
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Get Ready',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Adjust your posture.\nCalibration will begin shortly.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF59E0B).withOpacity(0.15),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withOpacity(0.4),
                  width: 3,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      color: const Color(0xFFF59E0B),
                      backgroundColor: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  Text(
                    countdown > 0 ? '$countdown' : '',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            countdown == 3 ? '(3…2…1)' : countdown == 2 ? '(2…1)' : countdown == 1 ? '(1)' : '',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoldStillScreen extends StatelessWidget {
  const _HoldStillScreen({
    super.key,
    required this.progress,
    required this.pulse,
  });

  final double progress;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final scale = 0.98 + (pulse.value * 0.04);
    return Container(
      key: key,
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Hold Still',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Keep your neck steady.\nDo not move during calibration.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 150),
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      color: const Color(0xFF22C55E),
                      backgroundColor: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.accessibility_new_rounded,
                        size: 56,
                        color: const Color(0xFF22C55E).withOpacity(0.9),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Calibrating...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultScreen extends StatelessWidget {
  const _ResultScreen({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.subText,
    this.showSuccessBar = false,
    this.showFailedBar = false,
    this.barProgress,
    this.primaryLabel,
    this.onPrimary,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String? subText;
  final bool showSuccessBar;
  final bool showFailedBar;
  final AnimationController? barProgress;
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: key,
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showSuccessBar || showFailedBar) ...[
            AnimatedBuilder(
              animation: barProgress!,
              builder: (context, child) {
                final t = Curves.easeOutCubic.transform(barProgress!.value);
                return Container(
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: constraints.maxWidth * t,
                            child: Container(
                              decoration: BoxDecoration(
                                color: showSuccessBar
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ],
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
            ),
            child: Icon(icon, color: color, size: 44),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.75),
              height: 1.5,
            ),
          ),
          if (subText != null) ...[
            const SizedBox(height: 10),
            Text(
              subText!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
          const Spacer(),
          if (primaryLabel != null && onPrimary != null)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: onPrimary,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF008090),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  primaryLabel!,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
