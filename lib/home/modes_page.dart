import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:correctv1/theme/app_theme.dart';

class ModesPage extends StatelessWidget {
  const ModesPage({super.key});

  static const _modes = <_ModeData>[
    _ModeData(
      title: 'Tracking Mode',
      subtitle: 'Monitor your posture in real-time',
      icon: Icons.monitor_heart_outlined,
      gradient: AppTheme.trackingGradient,
    ),
    _ModeData(
      title: 'Training Mode',
      subtitle: 'Basic, Intermediate & Advanced levels',
      icon: Icons.bolt,
      gradient: AppTheme.trainingGradient,
    ),
    _ModeData(
      title: 'Therapy Mode',
      subtitle: 'Acupressure vibration therapy',
      icon: Icons.favorite,
      gradient: AppTheme.therapyGradient,
    ),
    _ModeData(
      title: 'Meditation Mode',
      subtitle: 'Rhythmic breathing guidance',
      icon: Icons.self_improvement,
      gradient: AppTheme.meditationGradient,
    ),
    _ModeData(
      title: 'AlignWalk Mode',
      subtitle: 'Walking posture trainer',
      icon: Icons.directions_walk,
      gradient: AppTheme.alignWalkGradient,
    ),
    _ModeData(
      title: 'Riding Mode',
      subtitle: 'Bike & car posture monitoring',
      icon: Icons.directions_car,
      gradient: AppTheme.ridingGradient,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.pageBackgroundGradientFor(context),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).maybePop();
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Icon(
                    Icons.arrow_back,
                    size: 24,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),

            ShaderMask(
              shaderCallback: (bounds) =>
                  AppTheme.brandGradient.createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: const Text(
                'Mode Selection',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose your training mode',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 28),

            for (int i = 0; i < _modes.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              _ModeCard(
                data: _modes[i],
                onTap: () => _onModeTapped(context, _modes[i]),
              ),
            ],

            const SizedBox(height: 24),

            const _ProTipCard(),
          ],
        ),
      ),
    );
  }

  void _onModeTapped(BuildContext context, _ModeData mode) {
    HapticFeedback.lightImpact();
  }
}

class _ModeData {
  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;

  const _ModeData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });
}

class _ModeCard extends StatelessWidget {
  final _ModeData data;
  final VoidCallback onTap;

  const _ModeCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: data.gradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(data.icon, color: scheme.onPrimary, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProTipCard extends StatelessWidget {
  const _ProTipCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [scheme.primary, scheme.secondary],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pro Tip',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Start with Training Mode to build awareness, then use Therapy Mode for muscle relief.',
                  style: TextStyle(
                    color: scheme.onPrimary.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
