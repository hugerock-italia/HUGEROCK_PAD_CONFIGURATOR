import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/colors.dart';
import '../config/app_theme.dart';
import '../services/ble_manager.dart';
import 'config_screen.dart';
import 'ota_screen.dart';
import 'auto_config_screen.dart';
import '../services/update_checker.dart';
import '../widgets/update_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late BLEManager bleManager;
  BluetoothDevice? connectedDevice;
  bool isConnecting = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    bleManager = BLEManager();
    bleManager.addListener(
        () => setState(() => connectedDevice = bleManager.connectedDevice));
    _loadAppVersion();
    _checkForUpdates();
    _requestBlePermissions();
  }

  @override
  void dispose() {
    bleManager.dispose();
    super.dispose();
  }

  /// Loads the app version from [PackageInfo] and updates [_appVersion].
  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = 'v${info.version}+${info.buildNumber}');
    }
  }

  /// Checks GitHub releases.json for a newer app version.
  /// If an update is available, shows [showUpdateDialog] via a post-frame callback.
  Future<void> _checkForUpdates() async {
    final info = await UpdateChecker.checkForUpdate();
    if (info != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showUpdateDialog(context, info);
      });
    }
  }

  Future<void> _requestBlePermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> _toggleConnection() async {
    if (connectedDevice == null) {
      // Check permissions before connecting
      final scan = await Permission.bluetoothScan.isGranted;
      final connect = await Permission.bluetoothConnect.isGranted;
      final loc = await Permission.location.isGranted;

      if (!scan || !connect || !loc) {
        await _requestBlePermissions();
        final scanOk = await Permission.bluetoothScan.isGranted;
        final connectOk = await Permission.bluetoothConnect.isGranted;
        if (!scanOk || !connectOk) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Bluetooth permissions required. Enable them in Settings.')),
            );
          }
          return;
        }
      }
    }

    setState(() => isConnecting = true);
    try {
      if (connectedDevice != null) {
        await bleManager.disconnect();
      } else {
        await bleManager.scanAndConnect();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), duration: const Duration(seconds: 6)),
        );
      }
    } finally {
      if (mounted) setState(() => isConnecting = false);
    }
  }

  Widget _actionButton(
      {required bool enabled,
      required Color color,
      required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
            backgroundColor: color,
            disabledBackgroundColor: AppColors.surfaceLight),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Text(label, style: AppTheme.buttonStyle)
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = connectedDevice != null;
    final deviceType = bleManager.deviceType;

    return Scaffold(
      appBar: AppBar(title: const Text('HUGEROCK ITALIA'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Image.asset('assets/hugerock_logo.png', height: 80),
              const SizedBox(height: 14),
              Text('PAD CONFIGURATOR',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 6),
              Text(
                connected && deviceType != null
                    ? '${deviceType.displayName} connected'
                    : 'Extreme Â· Discovery',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              Container(
                padding: const EdgeInsets.all(AppTheme.paddingLarge),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  border: Border.all(
                      color: connected
                          ? AppColors.connected
                          : AppColors.disconnected,
                      width: 2),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bluetooth,
                            size: 44,
                            color: connected
                                ? AppColors.connected
                                : AppColors.disconnected),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              connected ? 'CONNECTED' : 'DISCONNECTED',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: connected
                                      ? AppColors.connected
                                      : AppColors.disconnected),
                            ),
                            const SizedBox(height: 4),
                            Text(connectedDevice?.localName ?? 'No device',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isConnecting ? null : _toggleConnection,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: connected
                                ? AppColors.disconnected
                                : AppColors.sandMedium),
                        child: isConnecting
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white)))
                            : Text(connected ? 'DISCONNECT' : 'CONNECT',
                                style: AppTheme.buttonStyle),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              _actionButton(
                  enabled: connected,
                  color: AppColors.sandMedium,
                  icon: Icons.settings,
                  label: 'CONFIGURATION',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ConfigScreen(
                              bleManager: bleManager,
                              deviceType: bleManager.deviceType!)))),

              const SizedBox(height: 10),
              _actionButton(
                  enabled: connected,
                  color: const Color(0xFF4A148C),
                  icon: Icons.auto_fix_high,
                  label: 'AUTO CONFIG',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              AutoConfigScreen(bleManager: bleManager)))),

              const SizedBox(height: 10),
              _actionButton(
                  enabled: connected,
                  color: const Color(0xFF1A237E),
                  icon: Icons.system_update,
                  label: 'UPDATE FIRMWARE',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => OtaScreen(
                              bleManager: bleManager,
                              deviceType: bleManager.deviceType!)))),

              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(AppTheme.padding),
                decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('INFO',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'â€¢ 3 maps: Yellow / Blue / Green\n'
                      'â€¢ Auto config with GPS & roadbook presets\n'
                      'â€¢ Automatic BLE connection\n'
                      'â€¢ Firmware update via BLE\n'
                      'â€¢ Extreme: roadbook lever | Discovery: joystick',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // App version footer
              if (_appVersion.isNotEmpty)
                Text(
                  _appVersion,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.sandGrey,
                      ),
                  textAlign: TextAlign.center,
                ),
              Text(
                'designed by HUGEROCK ITALIA',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.sandGrey,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
