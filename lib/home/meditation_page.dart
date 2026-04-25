import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MeditationPage extends StatefulWidget {
  const MeditationPage({super.key});

  @override
  State<MeditationPage> createState() => _MeditationPageState();
}

enum _BreathPhase { inhale, hold, exhale }

class _MeditationPageState extends State<MeditationPage>
    with TickerProviderStateMixin {
  static const _inhaleSeconds = 4;
  static const _holdSeconds = 2;
  static const _exhaleSeconds = 6;
  static const _cycleSeconds =
      _inhaleSeconds + _holdSeconds + _exhaleSeconds; // 12s

  late final AnimationController _entryController;
  late final AnimationController _breathController;

  bool _isRunning = false;
  bool _hapticSync = false;
  _BreathPhase _phase = _BreathPhase.inhale;
  Timer? _phaseTimer;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _cycleSeconds),
    );
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _entryController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  void _toggleSession() {
    HapticFeedback.mediumImpact();
    if (_isRunning) {
      _stopSession();
    } else {
      _startSession();
    }
  }

  void _startSession() {
    setState(() {
      _isRunning = true;
      _phase = _BreathPhase.inhale;
    });
    _breathController
      ..reset()
      ..repeat();
    _scheduleNextPhase(Duration.zero);
  }

  void _stopSession() {
    _phaseTimer?.cancel();
    _breathController.stop();
    _breathController.reset();
    setState(() {
      _isRunning = false;
      _phase = _BreathPhase.inhale;
    });
  }

  void _scheduleNextPhase(Duration delay) {
    _phaseTimer?.cancel();
    _phaseTimer = Timer(delay, () {
      if (!mounted || !_isRunning) return;
      _advancePhase();
    });
  }

  void _advancePhase() {
    final next = switch (_phase) {
      _BreathPhase.inhale => _BreathPhase.hold,
      _BreathPhase.hold => _BreathPhase.exhale,
      _BreathPhase.exhale => _BreathPhase.inhale,
    };
    setState(() => _phase = next);
    if (_hapticSync) {
      HapticFeedback.lightImpact();
    }
    _scheduleNextPhase(_phaseDuration(next));
  }

  Duration _phaseDuration(_BreathPhase phase) {
    return switch (phase) {
      _BreathPhase.inhale => const Duration(seconds: _inhaleSeconds),
      _BreathPhase.hold => const Duration(seconds: _holdSeconds),
      _BreathPhase.exhale => const Duration(seconds: _exhaleSeconds),
    };
  }

  void _toggleHaptic() {
    HapticFeedback.selectionClick();
    setState(() => _hapticSync = !_hapticSync);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEFF6FF), Colors.white, Color(0xFFFAF5FF)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(23, 20, 22, 28),
            children: [
              _StaggeredEntrance(
                controller: _entryController,
                delay: 0,
                dy: -20,
                child: _MeditationHeader(
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(height: 28),
              _StaggeredEntrance(
                controller: _entryController,
                delay: 0.10,
                child: _BreathingCircle(
                  isRunning: _isRunning,
                  phase: _phase,
                  controller: _breathController,
                ),
              ),
              const SizedBox(height: 28),
              _StaggeredEntrance(
                controller: _entryController,
                delay: 0.20,
                child: _HapticSyncCard(
                  active: _hapticSync,
                  onToggle: _toggleHaptic,
                ),
              ),
              const SizedBox(height: 18),
              _StaggeredEntrance(
                controller: _entryController,
                delay: 0.30,
                child: const _BreathingPatternCard(
                  inhaleSeconds: _inhaleSeconds,
                  holdSeconds: _holdSeconds,
                  exhaleSeconds: _exhaleSeconds,
                ),
              ),
              const SizedBox(height: 22),
              _StaggeredEntrance(
                controller: _entryController,
                delay: 0.40,
                scaleFrom: 0.92,
                child: _StartButton(
                  isRunning: _isRunning,
                  onTap: _toggleSession,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeditationHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _MeditationHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            onBack();
          },
          icon: const Icon(Icons.arrow_back_rounded),
          color: const Color(0xFF4B5563),
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 34),
        ),
        const SizedBox(height: 12),
        ShaderMask(
          shaderCallback: (bounds) => gradient.createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: const Text(
            'Breating Mode',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Rhythmic breathing guidance',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _BreathingCircle extends StatelessWidget {
  final bool isRunning;
  final _BreathPhase phase;
  final AnimationController controller;

  const _BreathingCircle({
    required this.isRunning,
    required this.phase,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Center(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final scale = isRunning ? _scaleForCycle(controller.value) : 1.0;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF818CF8), Color(0xFF3B82F6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.32),
                      blurRadius: 40,
                      spreadRadius: 4,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    child: Text(
                      _phaseLabel(phase),
                      key: ValueKey(phase),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static const _inhaleEnd = 4 / 12;
  static const _holdEnd = 6 / 12;

  double _scaleForCycle(double t) {
    const minScale = 0.78;
    const maxScale = 1.05;
    if (t < _inhaleEnd) {
      final f = t / _inhaleEnd;
      return _lerp(minScale, maxScale, Curves.easeInOut.transform(f));
    }
    if (t < _holdEnd) {
      return maxScale;
    }
    final f = (t - _holdEnd) / (1 - _holdEnd);
    return _lerp(maxScale, minScale, Curves.easeInOut.transform(f));
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  String _phaseLabel(_BreathPhase phase) {
    return switch (phase) {
      _BreathPhase.inhale => 'Inhale',
      _BreathPhase.hold => 'Hold',
      _BreathPhase.exhale => 'Exhale',
    };
  }
}

class _HapticSyncCard extends StatelessWidget {
  final bool active;
  final VoidCallback onToggle;

  const _HapticSyncCard({required this.active, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Haptic Sync',
                  style: TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StatusPill(active: active, onTap: onToggle),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Device vibrates gently in sync with breathing rhythm to guide your meditation.',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _StatusPill({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
                  )
                : null,
            color: active ? null : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            active ? 'Active' : 'Inactive',
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _BreathingPatternCard extends StatelessWidget {
  final int inhaleSeconds;
  final int holdSeconds;
  final int exhaleSeconds;

  const _BreathingPatternCard({
    required this.inhaleSeconds,
    required this.holdSeconds,
    required this.exhaleSeconds,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEEF2FF), Color(0xFFDBEAFE)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC7D2FE).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$inhaleSeconds-$holdSeconds-$exhaleSeconds Breathing Pattern',
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _PatternRow(
            seconds: inhaleSeconds,
            title: 'Inhale deeply',
            subtitle: 'Fill your lungs completely',
            gradient: const [Color(0xFF818CF8), Color(0xFF6366F1)],
          ),
          const SizedBox(height: 12),
          _PatternRow(
            seconds: holdSeconds,
            title: 'Hold breath',
            subtitle: 'Pause naturally',
            gradient: const [Color(0xFFC084FC), Color(0xFFA855F7)],
          ),
          const SizedBox(height: 12),
          _PatternRow(
            seconds: exhaleSeconds,
            title: 'Exhale slowly',
            subtitle: 'Release tension completely',
            gradient: const [Color(0xFF60A5FA), Color(0xFF3B82F6)],
          ),
        ],
      ),
    );
  }
}

class _PatternRow extends StatelessWidget {
  final int seconds;
  final String title;
  final String subtitle;
  final List<Color> gradient;

  const _PatternRow({
    required this.seconds,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${seconds}s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StartButton extends StatelessWidget {
  final bool isRunning;
  final VoidCallback onTap;

  const _StartButton({required this.isRunning, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isRunning
                  ? const [Color(0xFF6B7280), Color(0xFF4B5563)]
                  : const [Color(0xFF6366F1), Color(0xFF3B82F6)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color:
                    (isRunning
                            ? const Color(0xFF4B5563)
                            : const Color(0xFF4F46E5))
                        .withValues(alpha: 0.30),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isRunning
                    ? Icons.pause_circle_outline_rounded
                    : Icons.play_circle_outline_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                isRunning ? 'Stop Meditation' : 'Begin Meditation',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassPanel({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
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
      child: child,
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
