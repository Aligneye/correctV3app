import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TherapyPage extends StatefulWidget {
  const TherapyPage({super.key});

  @override
  State<TherapyPage> createState() => _TherapyPageState();
}

class _TherapyPageState extends State<TherapyPage>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _pulseController;

  double _intensity = 2;
  int _durationMinutes = 10;
  bool _isRunning = false;
  String _selectedPointId = 'GV14';

  static const _points = <_TherapyPoint>[
    _TherapyPoint(
      id: 'GV14',
      name: 'GV14 (Dazhui)',
      description: 'Upper back, between shoulder blades',
      x: 0.50,
      y: 0.35,
    ),
    _TherapyPoint(
      id: 'GV13',
      name: 'GV13 (Taodao)',
      description: 'Mid-upper back',
      x: 0.50,
      y: 0.45,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _selectPoint(String id) {
    HapticFeedback.selectionClick();
    setState(() => _selectedPointId = id);
  }

  void _toggleTherapy() {
    HapticFeedback.mediumImpact();
    setState(() => _isRunning = !_isRunning);
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
            colors: [Color(0xFFFFF1F2), Colors.white, Color(0xFFFDF2F8)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(23, 20, 22, 22),
            children: [
              _StaggeredEntrance(
                controller: _entryController,
                delay: 0,
                dy: -20,
                child: _TherapyHeader(
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(height: 29),
              _StaggeredEntrance(
                controller: _entryController,
                delay: 0.10,
                child: _GlassPanel(
                  padding: const EdgeInsets.fromLTRB(22, 25, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Target Acupressure Points',
                        style: TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _BodyMap(
                        points: _points,
                        selectedPointId: _selectedPointId,
                        pulseController: _pulseController,
                        onPointSelected: _selectPoint,
                      ),
                      const SizedBox(height: 16),
                      for (final point in _points) ...[
                        _PointButton(
                          point: point,
                          isSelected: _selectedPointId == point.id,
                          onTap: () => _selectPoint(point.id),
                        ),
                        if (point != _points.last) const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 23),
              _StaggeredEntrance(
                controller: _entryController,
                delay: 0.20,
                child: _GlassPanel(
                  padding: const EdgeInsets.fromLTRB(22, 23, 22, 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Vibration Intensity',
                            style: TextStyle(
                              color: Color(0xFF374151),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${_intensity.round()}/3',
                            style: const TextStyle(
                              color: Color(0xFFFF0055),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFFE1E4E8),
                          inactiveTrackColor: const Color(0xFFE1E4E8),
                          thumbColor: const Color(0xFFFF2B62),
                          overlayColor: Colors.transparent,
                          trackHeight: 6,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: SliderComponentShape.noOverlay,
                        ),
                        child: Slider(
                          min: 1,
                          max: 3,
                          divisions: 2,
                          value: _intensity,
                          onChanged: (value) {
                            HapticFeedback.selectionClick();
                            setState(() => _intensity = value);
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Gentle',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Intense',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 23),
              _StaggeredEntrance(
                controller: _entryController,
                delay: 0.30,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Session Duration',
                      style: TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [10, 20, 30]
                          .map(
                            (minutes) => Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: minutes == 30 ? 0 : 12,
                                ),
                                child: _DurationButton(
                                  minutes: minutes,
                                  isSelected: _durationMinutes == minutes,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _durationMinutes = minutes);
                                  },
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _StaggeredEntrance(
                controller: _entryController,
                delay: 0.40,
                child: _BenefitsCard(pulseController: _pulseController),
              ),
              const SizedBox(height: 21),
              _StaggeredEntrance(
                controller: _entryController,
                delay: 0.50,
                scaleFrom: 0.90,
                child: _StartButton(
                  isRunning: _isRunning,
                  onTap: _toggleTherapy,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _isRunning
                    ? Padding(
                        key: const ValueKey('running-session'),
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              color: Color(0xFF4B5563),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Session in progress: $_durationMinutes:00',
                              style: const TextStyle(
                                color: Color(0xFF4B5563),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TherapyHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _TherapyHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
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
        const Text(
          'Therapy Mode',
          style: TextStyle(
            color: Color(0xFFFF0055),
            fontSize: 26,
            height: 1.15,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Acupressure vibration therapy',
          style: TextStyle(
            color: Color(0xFF667085),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _BodyMap extends StatelessWidget {
  final List<_TherapyPoint> points;
  final String selectedPointId;
  final AnimationController pulseController;
  final ValueChanged<String> onPointSelected;

  const _BodyMap({
    required this.points,
    required this.selectedPointId,
    required this.pulseController,
    required this.onPointSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 229,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF1F2), Color(0xFFFDF2F8)],
          ),
          borderRadius: BorderRadius.circular(11),
        ),
        child: AnimatedBuilder(
          animation: pulseController,
          builder: (context, _) {
            final pulse = Curves.easeInOut.transform(
              math.sin(pulseController.value * math.pi),
            );
            return CustomPaint(
              painter: _BodyMapPainter(
                points: points,
                selectedPointId: selectedPointId,
                pulse: pulse,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: points.map((point) {
                      final left = point.x * constraints.maxWidth;
                      final top = point.y * constraints.maxHeight;
                      return Positioned(
                        left: left - 28,
                        top: top - 28,
                        width: 56,
                        height: 56,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () => onPointSelected(point.id),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BodyMapPainter extends CustomPainter {
  final List<_TherapyPoint> points;
  final String selectedPointId;
  final double pulse;

  const _BodyMapPainter({
    required this.points,
    required this.selectedPointId,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.fill;
    final centerX = size.width * 0.5;

    canvas.drawCircle(Offset(centerX, size.height * 0.15), 18, bodyPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, size.height * 0.27),
          width: 10,
          height: 18,
        ),
        const Radius.circular(16),
      ),
      bodyPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, size.height * 0.57),
        width: 84,
        height: 132,
      ),
      bodyPaint,
    );

    for (final point in points) {
      final offset = Offset(point.x * size.width, point.y * size.height);
      final isSelected = selectedPointId == point.id;
      final ringPaint = Paint()
        ..color = const Color(0xFFFF4F73).withValues(alpha: 0.90 - pulse * 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      final dotPaint = Paint()
        ..color = isSelected ? const Color(0xFFFF2B62) : const Color(0xFFFF6E88)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(offset, 16 + pulse * 1.5, ringPaint);
      canvas.drawCircle(offset, 10, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BodyMapPainter oldDelegate) {
    return oldDelegate.pulse != pulse ||
        oldDelegate.selectedPointId != selectedPointId;
  }
}

class _PointButton extends StatelessWidget {
  final _TherapyPoint point;
  final bool isSelected;
  final VoidCallback onTap;

  const _PointButton({
    required this.point,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isSelected ? 54 : 52,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFFF1F5B), Color(0xFFED2CA6)],
                    )
                  : null,
              color: isSelected ? null : const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(10),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.27),
                        blurRadius: 13,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF374151),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  point.description,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFFFFE4E6)
                        : const Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
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

class _DurationButton extends StatelessWidget {
  final int minutes;
  final bool isSelected;
  final VoidCallback onTap;

  const _DurationButton({
    required this.minutes,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF43F5E), Color(0xFFEC4899)],
                    )
                  : null,
              color: isSelected ? null : Colors.white.withValues(alpha: 0.60),
              borderRadius: BorderRadius.circular(11),
              border: isSelected
                  ? null
                  : Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              '$minutes min',
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF4B5563),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitsCard extends StatelessWidget {
  final AnimationController pulseController;

  const _BenefitsCard({required this.pulseController});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AnimatedBuilder(
        animation: pulseController,
        builder: (context, child) {
          final pulse = Curves.easeInOut.transform(
            math.sin(pulseController.value * math.pi),
          );
          return Stack(
            children: [
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 126),
                padding: const EdgeInsets.fromLTRB(20, 21, 20, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFE4E6), Color(0xFFFCE7F3)],
                  ),
                ),
                child: child,
              ),
              Positioned(
                right: -21,
                top: -42,
                child: Transform.scale(
                  scale: 1 + pulse * 0.2,
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFFDA4AF,
                      ).withValues(alpha: 0.20 - pulse * 0.10),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.favorite_border_rounded,
                  color: Color(0xFFE11D48),
                  size: 20,
                ),
                SizedBox(width: 13),
                Text(
                  'Therapy Benefits',
                  style: TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              'Relieves muscle tension, improves circulation, and promotes relaxation through targeted vibration therapy.',
              style: TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
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
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isRunning
                  ? [const Color(0xFF6B7280), const Color(0xFF4B5563)]
                  : [const Color(0xFFFF1F5B), const Color(0xFFED2CA6)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color:
                    (isRunning
                            ? const Color(0xFF4B5563)
                            : const Color(0xFFF43F5E))
                        .withValues(alpha: 0.28),
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
                size: 25,
              ),
              const SizedBox(width: 12),
              Text(
                isRunning ? 'Stop Therapy' : 'Start Therapy Session',
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

class _TherapyPoint {
  final String id;
  final String name;
  final String description;
  final double x;
  final double y;

  const _TherapyPoint({
    required this.id,
    required this.name,
    required this.description,
    required this.x,
    required this.y,
  });
}
