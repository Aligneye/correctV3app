import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import 'package:correctv1/bluetooth/aligneye_device_service.dart';
import 'package:correctv1/bluetooth/bluetooth_service_manager.dart';
import 'package:correctv1/theme/app_theme.dart';

const _kPodPrefix = 'aligneye pod';

// ── Surface card decoration matching the home page ──────────────────────────
BoxDecoration _surfaceDecoration({double radius = 20}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFEEEEF0), width: 0.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    );

class DeviceConnectPage extends StatefulWidget {
  const DeviceConnectPage({super.key});

  @override
  State<DeviceConnectPage> createState() => _DeviceConnectPageState();
}

class _DeviceConnectPageState extends State<DeviceConnectPage>
    with TickerProviderStateMixin {
  final _btManager = BluetoothServiceManager();

  late final AnimationController _pulseCtrl;
  late final Animation<double> _ring1;
  late final Animation<double> _ring2;
  late final Animation<double> _ring3;

  StreamSubscription<List<ScanResult>>? _scanSub;

  List<ScanResult> _found = [];
  bool _scanning = false;
  bool _scanDone = false;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _ring1 = _interval(0.0, 0.60);
    _ring2 = _interval(0.22, 0.82);
    _ring3 = _interval(0.44, 1.00);

    _btManager.deviceService.connectionStatus.addListener(_onStatusChange);
    _startScan();
  }

  Animation<double> _interval(double begin, double end) =>
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _pulseCtrl,
          curve: Interval(begin, end, curve: Curves.easeOut),
        ),
      );

  void _onStatusChange() {
    if (!mounted) return;
    if (_btManager.deviceService.connectionStatus.value ==
        DeviceConnectionStatus.connected) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _startScan() async {
    if (_scanning) return;

    final readiness = await _btManager.deviceService.checkReadiness();
    if (!mounted) return;

    switch (readiness) {
      case BleReadiness.ready:
        break; // proceed to scan
      case BleReadiness.bluetoothOff:
        _showReadinessSnackBar(
          'Bluetooth is off. Please enable Bluetooth and try again.',
        );
        return;
      case BleReadiness.bluetoothUnsupported:
        _showReadinessSnackBar(
          'This device doesn\'t support Bluetooth Low Energy.',
        );
        return;
      case BleReadiness.permissionDenied:
        _showReadinessSnackBar(
          'Bluetooth permission required. Please grant permission and try again.',
        );
        return;
      case BleReadiness.permissionPermanentlyDenied:
        _showPermissionSettingsBar();
        return;
    }

    setState(() {
      _scanning = true;
      _scanDone = false;
      _found = [];
    });
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));
      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        if (!mounted) return;
        final pods = results
            .where((r) =>
                r.device.platformName.toLowerCase().contains(_kPodPrefix))
            .toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));
        setState(() => _found = pods);
      });
      await FlutterBluePlus.isScanning.where((s) => !s).first;
      if (mounted) setState(() { _scanning = false; _scanDone = true; });
    } catch (_) {
      if (mounted) setState(() { _scanning = false; _scanDone = true; });
    }
  }

  void _showReadinessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.destructive,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showPermissionSettingsBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Bluetooth permission permanently denied. Tap to open Settings.',
        ),
        backgroundColor: AppTheme.destructive,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: () => openAppSettings(),
        ),
      ),
    );
  }

  Future<void> _connect() async {
    if (_connecting) return;
    setState(() => _connecting = true);
    await FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    try {
      await _btManager.connect();
    } catch (e) {
      if (!mounted) return;
      setState(() => _connecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e.toString())),
          backgroundColor: AppTheme.destructive,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  String _friendlyError(String raw) {
    if (raw.toLowerCase().contains('permission')) {
      return 'Bluetooth permission required. Go to Settings → Permissions.';
    }
    if (raw.contains('not found')) {
      return 'Pod not found. Make sure it\'s powered on and nearby.';
    }
    if (raw.contains('not enabled')) {
      return 'Please enable Bluetooth and try again.';
    }
    return 'Could not connect. Please try again.';
  }

  int _rssiToBars(int rssi) {
    if (rssi >= -60) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -80) return 2;
    return 1;
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _scanSub?.cancel();
    _btManager.deviceService.connectionStatus.removeListener(_onStatusChange);
    FlutterBluePlus.stopScan().ignore();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                flex: 5,
                child: _buildHeroArea(),
              ),
              _buildStatusLabel(),
              const SizedBox(height: 24),
              Expanded(
                flex: 6,
                child: _buildBottomPanel(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'Connect Your Pod',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ── Hero area with product image + rings ───────────────────────────────────

  Widget _buildHeroArea() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse rings
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Stack(
              alignment: Alignment.center,
              children: [
                _PulseRing(progress: _ring1.value, maxRadius: 140),
                _PulseRing(progress: _ring2.value, maxRadius: 140),
                _PulseRing(progress: _ring3.value, maxRadius: 140),
              ],
            ),
          ),
          // Product image with light card backing
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                  blurRadius: 40,
                  spreadRadius: 4,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Image.asset(
                  'assets/product.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          // Scanning indicator dot
          if (_scanning && !_connecting)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.brandPrimary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Scanning',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Status text ────────────────────────────────────────────────────────────

  Widget _buildStatusLabel() {
    final title = _connecting
        ? 'Connecting to AlignEye Pod'
        : _found.isNotEmpty
            ? '${_found.length} Pod${_found.length > 1 ? 's' : ''} Found Nearby'
            : _scanning
                ? 'Scanning for AlignEye Pods'
                : 'No pods detected';

    final sub = _connecting
        ? 'Establishing a secure connection…'
        : _found.isNotEmpty
            ? 'Tap Connect to pair your AlignEye Pod'
            : _scanning
                ? 'Keep your pod powered on'
                : 'Make sure your pod is powered on and in range';

    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ── Bottom panel ───────────────────────────────────────────────────────────

  Widget _buildBottomPanel() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      decoration: _surfaceDecoration(radius: 24),
      child: _connecting
          ? _buildConnectingBody()
          : _found.isEmpty
              ? _buildEmptyBody()
              : _buildDeviceListBody(),
    );
  }

  Widget _buildDeviceListBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'NEARBY PODS',
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const Spacer(),
            if (_scanning)
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.brandPrimary.withValues(alpha: 0.5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.separated(
            itemCount: _found.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final r = _found[i];
              final name = r.device.platformName.isEmpty
                  ? 'AlignEye Pod'
                  : r.device.platformName;
              return _DeviceCard(
                name: name,
                bars: _rssiToBars(r.rssi),
                onConnect: _connect,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyBody() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.brandPrimary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.bluetooth_searching_rounded,
            size: 28,
            color: AppTheme.brandPrimary.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _scanning ? 'Looking for your pod…' : 'No pods detected',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Power on your AlignEye Pod and\nkeep it within 2 metres',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        if (!_scanning && _scanDone) ...[
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _startScan,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.brandPrimary.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'Scan Again',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConnectingBody() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor:
                AlwaysStoppedAnimation<Color>(AppTheme.brandPrimary),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Connecting',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Pairing with your AlignEye Pod…',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}

// ── Pulse ring ─────────────────────────────────────────────────────────────

class _PulseRing extends StatelessWidget {
  final double progress;
  final double maxRadius;
  const _PulseRing({required this.progress, required this.maxRadius});

  @override
  Widget build(BuildContext context) {
    final r = maxRadius * progress;
    final opacity = ((1.0 - progress) * 0.25).clamp(0.0, 1.0);
    return SizedBox(
      width: r * 2,
      height: r * 2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.brandPrimary.withValues(alpha: opacity),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

// ── Device card ────────────────────────────────────────────────────────────

class _DeviceCard extends StatelessWidget {
  final String name;
  final int bars;
  final VoidCallback onConnect;

  const _DeviceCard({
    required this.name,
    required this.bars,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.brandPrimary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          // Product thumbnail
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset('assets/product.png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 14),
          // Name + signal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ...List.generate(4, (i) {
                      final active = i < bars;
                      return Container(
                        margin: const EdgeInsets.only(right: 3),
                        width: 4,
                        height: 8.0 + i * 3,
                        decoration: BoxDecoration(
                          color: active
                              ? AppTheme.brandPrimary
                              : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      bars >= 3
                          ? 'Strong signal'
                          : bars == 2
                              ? 'Good signal'
                              : 'Weak signal',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Connect button
          GestureDetector(
            onTap: onConnect,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.brandPrimary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Text(
                'Connect',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
