import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:correctv1/bluetooth/bluetooth_service_manager.dart';
import 'package:correctv1/theme/app_theme.dart';

const _kPagePadding = EdgeInsets.fromLTRB(24, 24, 24, 100);
const _kSectionSpacing = SizedBox(height: 24);
const _kInnerSpacing = SizedBox(height: 16);
const _kPrimaryBlue = AppTheme.brandPrimary;
const _kMutedText = AppTheme.textSecondary;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _btManager = BluetoothServiceManager();
  bool _autoReconnect = true;
  bool _lowPowerMode = false;
  bool _vibrationAlerts = true;

  @override
  void initState() {
    super.initState();
    _autoReconnect = _btManager.autoReconnectEnabled.value;
    _btManager.autoReconnectEnabled.addListener(_onAutoReconnectChanged);
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _controller.forward();
  }

  void _onAutoReconnectChanged() {
    if (mounted) {
      setState(() => _autoReconnect = _btManager.autoReconnectEnabled.value);
    }
  }

  @override
  void dispose() {
    _btManager.autoReconnectEnabled.removeListener(_onAutoReconnectChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.pageBackgroundGradientFor(context),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: _kPagePadding,
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────
                _StaggeredFadeSlide(
                  controller: _controller,
                  delayMs: 0,
                  child: const _SettingsHeader(),
                ),
                _kSectionSpacing,

                // ── Device Info Card ────────────────────────────────
                _StaggeredFadeSlide(
                  controller: _controller,
                  delayMs: 100,
                  child: const _DeviceInfoCard(),
                ),
                _kSectionSpacing,

                // ── Firmware Update Card ────────────────────────────
                _StaggeredFadeSlide(
                  controller: _controller,
                  delayMs: 200,
                  child: const _FirmwareUpdateCard(),
                ),
                _kSectionSpacing,

                // ── Alignment Calibration Card ──────────────────────
                _StaggeredFadeSlide(
                  controller: _controller,
                  delayMs: 300,
                  child: const _AlignmentCalibrationCard(),
                ),
                _kSectionSpacing,

                // ── Battery & Temperature Row ───────────────────────
                _StaggeredFadeSlide(
                  controller: _controller,
                  delayMs: 400,
                  child: const _BatteryTemperatureRow(),
                ),
                _kSectionSpacing,

                // ── Connection Settings Card ────────────────────────
                _StaggeredFadeSlide(
                  controller: _controller,
                  delayMs: 500,
                  child: _ConnectionSettingsCard(
                    autoReconnect: _autoReconnect,
                    lowPowerMode: _lowPowerMode,
                    vibrationAlerts: _vibrationAlerts,
                    onAutoReconnectChanged: (v) =>
                        _btManager.setAutoReconnect(v),
                    onLowPowerModeChanged: (v) =>
                        setState(() => _lowPowerMode = v),
                    onVibrationAlertsChanged: (v) {
                      if (v) HapticFeedback.lightImpact();
                      setState(() => _vibrationAlerts = v);
                    },
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

// ── Surface Card (identical to home_page) ───────────────────────────────────

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _SurfaceCard({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.glassBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Staggered Animation (identical to home_page) ────────────────────────────

class _StaggeredFadeSlide extends StatelessWidget {
  final Animation<double> controller;
  final int delayMs;
  final Widget child;

  const _StaggeredFadeSlide({
    required this.controller,
    required this.delayMs,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final start = delayMs / 1000.0;
        final value = Curves.easeOut.transform(
          ((controller.value - start) / 0.6).clamp(0.0, 1.0),
        );

        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';
    final initials = _extractInitials(email);
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;

    return Row(
      children: [
        // Profile avatar
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: avatarUrl == null ? AppTheme.brandGradient : null,
            border: Border.all(
              color: scheme.outline,
              width: 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: avatarUrl != null
              ? Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
        const Spacer(),
        Text(
          'Settings',
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        // Help icon
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: scheme.outline,
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.help_outline_rounded,
            color: scheme.onSurface,
            size: 20,
          ),
        ),
      ],
    );
  }

  static String _extractInitials(String email) {
    final name = email.split('@').first;
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'[._\-]'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}

// ── Device Info Card ────────────────────────────────────────────────────────

class _DeviceInfoCard extends StatelessWidget {
  const _DeviceInfoCard();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Device row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.connectedBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.bluetooth_rounded,
                  color: _kPrimaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AlignEye Pro',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'AE-2024-X01',
                      style: TextStyle(
                        color: _kMutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.successBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppTheme.successText,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Connected',
                      style: TextStyle(
                        color: AppTheme.successText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, thickness: 1, color: AppTheme.border),
          const SizedBox(height: 14),
          _InfoRow(label: 'Firmware Version', value: 'v2.4.1'),
          const SizedBox(height: 14),
          _InfoRow(label: 'Hardware Revision', value: 'Rev B'),
          const SizedBox(height: 14),
          _InfoRow(label: 'Serial Number', value: 'AE2024120301'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _kMutedText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Firmware Update Card ────────────────────────────────────────────────────

class _FirmwareUpdateCard extends StatelessWidget {
  const _FirmwareUpdateCard();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(
                  Icons.download_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Firmware Update',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Check for latest updates',
                      style: TextStyle(
                        color: _kMutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _kInnerSpacing,
          _GradientButton(
            label: 'Check for Updates',
            gradient: AppTheme.trackingGradient,
            onTap: () {},
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: AppTheme.successText,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "You're running the latest firmware version",
                  style: TextStyle(
                    color: AppTheme.successText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Alignment Calibration Card ──────────────────────────────────────────────

class _AlignmentCalibrationCard extends StatelessWidget {
  const _AlignmentCalibrationCard();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppTheme.goodPostureGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(
                  Icons.wifi_tethering_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alignment Calibration',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reset posture baseline',
                      style: TextStyle(
                        color: _kMutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _kInnerSpacing,
          // Info tip box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.connectedBg.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                color: AppTheme.brandPrimary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: _kPrimaryBlue,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sit in your ideal posture position before calibrating. '
                    'This will set your baseline reference angle.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _kInnerSpacing,
          _GradientButton(
            label: 'Start Calibration',
            gradient: AppTheme.trainingGradient,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

// ── Battery & Temperature Row ───────────────────────────────────────────────

class _BatteryTemperatureRow extends StatelessWidget {
  const _BatteryTemperatureRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Battery card
        Expanded(
          child: _SurfaceCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.successBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.battery_std_rounded,
                    color: AppTheme.successText,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '85%',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Battery Health',
                  style: TextStyle(
                    color: _kMutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.85,
                    minHeight: 6,
                    backgroundColor:
                        AppTheme.brandPrimary.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.brandPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '~12 hours remaining',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Temperature card
        Expanded(
          child: _SurfaceCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.connectedBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.thermostat_rounded,
                    color: _kPrimaryBlue,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '23°C',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Temperature',
                  style: TextStyle(
                    color: _kMutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppTheme.successText,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Normal range',
                      style: TextStyle(
                        color: AppTheme.successText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Connection Settings Card ────────────────────────────────────────────────

class _ConnectionSettingsCard extends StatelessWidget {
  final bool autoReconnect;
  final bool lowPowerMode;
  final bool vibrationAlerts;
  final ValueChanged<bool> onAutoReconnectChanged;
  final ValueChanged<bool> onLowPowerModeChanged;
  final ValueChanged<bool> onVibrationAlertsChanged;

  const _ConnectionSettingsCard({
    required this.autoReconnect,
    required this.lowPowerMode,
    required this.vibrationAlerts,
    required this.onAutoReconnectChanged,
    required this.onLowPowerModeChanged,
    required this.onVibrationAlertsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connection Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          _ToggleRow(
            label: 'Auto-Reconnect',
            value: autoReconnect,
            onChanged: onAutoReconnectChanged,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.border,
            ),
          ),
          _ToggleRow(
            label: 'Low Power Mode',
            value: lowPowerMode,
            onChanged: onLowPowerModeChanged,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.border,
            ),
          ),
          _ToggleRow(
            label: 'Vibration Alerts',
            value: vibrationAlerts,
            onChanged: onVibrationAlertsChanged,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gradient Button ─────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
