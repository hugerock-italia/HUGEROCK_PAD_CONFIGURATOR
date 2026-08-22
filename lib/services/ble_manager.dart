import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/enums.dart';

class BLEManager extends ChangeNotifier {
  static const String SERVICE_UUID = '12345678-1234-1234-1234-123456789012';
  static const String CONFIG_CHAR_UUID = '87654321-4321-4321-4321-210987654321';
  static const String OTA_CHAR_UUID = '87654321-4321-4321-4321-210987654323';

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _configCharacteristic;
  BluetoothCharacteristic? _otaCharacteristic;
  DeviceType? _deviceType;
  bool _isScanning = false;
  int _mtu = 512;
  String? _connectedFirmwareVersion;

  BluetoothDevice? get connectedDevice => _connectedDevice;
  DeviceType? get deviceType => _deviceType;
  bool get isConnected => _connectedDevice != null;
  bool get isScanning => _isScanning;
  int get mtu => _mtu;
  int get otaChunkSize => (_mtu - 3).clamp(20, 512);

  /// Firmware version string read from the connected device (e.g. "3.1.0"),
  /// or null if not yet fetched or no device connected.
  String? get connectedFirmwareVersion => _connectedFirmwareVersion;

  BLEManager() {
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.off) disconnect();
    });
  }

  bool _isTargetDevice(BluetoothDevice device) {
    final name =
        device.localName.isNotEmpty ? device.localName : device.platformName;
    return DeviceType.fromDeviceName(name) != null;
  }

  Future<void> scanAndConnect() async {
    try {
      _isScanning = true;
      notifyListeners();

      final adapterState = await FlutterBluePlus.adapterStateNow;
      if (adapterState != BluetoothAdapterState.on) {
        throw Exception('Bluetooth not enabled');
      }

      final bonded = await FlutterBluePlus.bondedDevices;
      debugPrint(
          '[BLE] Bonded devices: ${bonded.map((d) => d.platformName).toList()}');

      for (final device in bonded) {
        if (_isTargetDevice(device)) {
          debugPrint('[BLE] Found bonded target: ${device.platformName}');
          await FlutterBluePlus.stopScan();
          await _connectToDevice(device);
          return;
        }
      }

      debugPrint('[BLE] No bonded target found, starting scan...');
      await FlutterBluePlus.stopScan();
      await Future.delayed(const Duration(milliseconds: 300));

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      bool found = false;
      await for (var results in FlutterBluePlus.scanResults) {
        for (var r in results) {
          debugPrint(
              '[BLE] Scan found: ${r.device.platformName} / ${r.device.localName}');
          if (_isTargetDevice(r.device)) {
            await FlutterBluePlus.stopScan();
            await _connectToDevice(r.device);
            found = true;
            break;
          }
        }
        if (found) break;
      }

      if (!found) {
        await FlutterBluePlus.stopScan();
        throw Exception('Device not found. Make sure it is on and paired.');
      }
    } catch (e) {
      debugPrint('[BLE] scanAndConnect error: $e');
      _isScanning = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device,
      {int attempt = 1}) async {
    try {
      // Disconnect any stale connection before attempting
      if (device.isConnected) {
        debugPrint('[BLE] Device already connected, disconnecting first...');
        try {
          await device.disconnect();
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 500));
      }

      debugPrint('[BLE] Connecting (attempt $attempt)...');
      await device.connect(timeout: const Duration(seconds: 15));
      debugPrint('[BLE] Connected');

      _connectedDevice = device;

      try {
        _mtu = await device.requestMtu(512);
        debugPrint('[BLE] MTU: $_mtu');
      } catch (_) {
        _mtu = device.mtuNow > 0 ? device.mtuNow : 255;
        debugPrint('[BLE] MTU fallback: $_mtu');
      }

      final name =
          device.localName.isNotEmpty ? device.localName : device.platformName;
      _deviceType = DeviceType.fromDeviceName(name);
      debugPrint('[BLE] DeviceType: $_deviceType');

      final services = await device.discoverServices();
      debugPrint(
          '[BLE] Services found: ${services.map((s) => s.uuid.str).toList()}');

      for (var service in services) {
        if (service.uuid.str.toLowerCase() == SERVICE_UUID.toLowerCase()) {
          for (var char in service.characteristics) {
            final uuid = char.uuid.str.toLowerCase();
            if (uuid == CONFIG_CHAR_UUID.toLowerCase())
              _configCharacteristic = char;
            else if (uuid == OTA_CHAR_UUID.toLowerCase())
              _otaCharacteristic = char;
          }
        }
      }

      if (_configCharacteristic == null) {
        throw Exception('Config characteristic not found');
      }

      await Future.delayed(const Duration(milliseconds: 200));
      await sendConfigModeOn();
      debugPrint('[BLE] CONFIG:MODE:ON sent');
      await _fetchFirmwareVersion();

      _isScanning = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[BLE] _connectToDevice error (attempt $attempt): $e');

      // GATT 133: stale Android BLE cache — retry once after cleanup
      final isGatt133 =
          e.toString().contains('133') || e.toString().contains('GATT');
      if (isGatt133 && attempt == 1) {
        debugPrint('[BLE] GATT 133 detected, retrying after cleanup...');
        try {
          await device.disconnect();
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 2));
        await _connectToDevice(device, attempt: 2);
        return;
      }

      _connectedDevice = null;
      _configCharacteristic = null;
      _otaCharacteristic = null;
      _deviceType = null;
      _connectedFirmwareVersion = null;
      _isScanning = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> sendConfigCommand(int mapId, int keyIndex, int commandId,
      {bool repeat = false}) async {
    if (_configCharacteristic == null) throw Exception('Not connected');
    final cmd =
        'CONFIG:$mapId:$keyIndex:${commandId.toRadixString(16).padLeft(2, '0').toUpperCase()}:${repeat ? 1 : 0}';
    await _configCharacteristic!.write(cmd.codeUnits, withoutResponse: false);
  }

  Future<void> sendConfigModeOn() async {
    if (_configCharacteristic == null) throw Exception('Not connected');
    await _configCharacteristic!
        .write('CONFIG:MODE:ON'.codeUnits, withoutResponse: false);
  }

  /// Requests firmware version from device via CONFIG:GET_VERSION command.
  ///
  /// Writes the command then reads the response from [_configCharacteristic].
  /// Stores the result in [_connectedFirmwareVersion].
  Future<void> _fetchFirmwareVersion() async {
    if (_configCharacteristic == null) return;
    try {
      await _configCharacteristic!
          .write('CONFIG:GET_VERSION'.codeUnits, withoutResponse: false);
      await Future.delayed(const Duration(milliseconds: 300));
      final value = await _configCharacteristic!.read();
      if (value.isNotEmpty) {
        final raw = String.fromCharCodes(value).trim();
        debugPrint('[BLE] Firmware version raw response: $value ("$raw")');
        // The config characteristic is shared by many commands; sanitize the
        // response and extract only a clean version pattern (e.g. 3.2.0).
        // Never trust .trim() alone: stray/non-printable bytes left over
        // from another command must not silently produce a garbage version
        // string that later fails to parse and gets treated as "up to date".
        final match = RegExp(r'\d+(\.\d+){1,2}').firstMatch(raw);
        _connectedFirmwareVersion = match?.group(0);
        if (_connectedFirmwareVersion == null) {
          debugPrint(
              '[BLE] Firmware version response did not match expected pattern: "$raw"');
        } else {
          debugPrint('[BLE] Firmware version: $_connectedFirmwareVersion');
        }
      }
    } catch (e) {
      debugPrint('[BLE] getFirmwareVersion error: $e');
      _connectedFirmwareVersion = null;
    }
  }

  Future<void> sendConfigModeOff() async {
    if (_configCharacteristic == null) throw Exception('Not connected');
    await _configCharacteristic!
        .write('CONFIG:MODE:OFF'.codeUnits, withoutResponse: false);
  }

  Future<void> sendResetCommand() async {
    if (_configCharacteristic == null) throw Exception('Not connected');
    await _configCharacteristic!
        .write('RESET:CONFIG'.codeUnits, withoutResponse: false);
  }

  Future<void> sendWheelEnable(int mapId, bool enabled) async {
    if (_configCharacteristic == null) throw Exception('Not connected');
    await _configCharacteristic!.write(
      'CONFIG:WHEEL:$mapId:${enabled ? 1 : 0}'.codeUnits,
      withoutResponse: false,
    );
  }

  // ==================== MAP COLORS ====================

  /// Sends CONFIG:MAP_COLOR command to set LED color for map index (1-based).
  Future<void> sendMapColor(int mapIndex, int r, int g, int b) async {
    if (_configCharacteristic == null) throw Exception('Not connected');
    final cmd = 'CONFIG:MAP_COLOR:$mapIndex:$r:$g:$b';
    await _configCharacteristic!.write(cmd.codeUnits, withoutResponse: false);
  }

  /// Requests current map colors from device via BLE notification.
  Future<void> sendGetColors() async {
    if (_configCharacteristic == null) throw Exception('Not connected');
    await _configCharacteristic!
        .write('CONFIG:GET_COLORS'.codeUnits, withoutResponse: false);
  }

  /// Notification stream on config characteristic.
  Stream<List<int>>? get configNotifications =>
      _configCharacteristic?.onValueReceived;

  /// Subscribes to config characteristic notifications.
  Future<bool> subscribeConfigNotifications() async {
    if (_configCharacteristic == null) return false;
    try {
      await _configCharacteristic!.setNotifyValue(true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Unsubscribes from config characteristic notifications.
  Future<void> unsubscribeConfigNotifications() async {
    try {
      await _configCharacteristic?.setNotifyValue(false);
    } catch (_) {}
  }

  // ==================== OTA ====================

  Future<void> startOta(int fileSize) async {
    if (_configCharacteristic == null) throw Exception('Not connected');
    await _configCharacteristic!
        .write('CONFIG:OTA:BEGIN:$fileSize'.codeUnits, withoutResponse: false);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> sendOtaChunk(Uint8List chunk) async {
    if (_otaCharacteristic == null)
      throw Exception('OTA characteristic not available');
    await _otaCharacteristic!.write(chunk, withoutResponse: true);
  }

  Future<void> endOta() async {
    if (_configCharacteristic == null) throw Exception('Not connected');
    await _configCharacteristic!
        .write('CONFIG:OTA:END'.codeUnits, withoutResponse: false);
  }

  Stream<List<int>>? get otaNotifications =>
      _otaCharacteristic?.onValueReceived;

  Future<bool> subscribeOtaNotifications() async {
    if (_otaCharacteristic == null) return false;
    try {
      await _otaCharacteristic!.setNotifyValue(true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> unsubscribeOtaNotifications() async {
    try {
      await _otaCharacteristic?.setNotifyValue(false);
    } catch (_) {}
  }

  // ==================== DISCONNECT ====================

  Future<void> disconnect({bool skipConfigOff = false}) async {
    if (_connectedDevice != null) {
      try {
        await unsubscribeOtaNotifications();
      } catch (_) {}
      if (!skipConfigOff) {
        try {
          await sendConfigModeOff();
        } catch (_) {}
      }
      try {
        await _connectedDevice!.disconnect();
      } catch (_) {}
    }
    _connectedDevice = null;
    _configCharacteristic = null;
    _otaCharacteristic = null;
    _deviceType = null;
    _connectedFirmwareVersion = null;
    _mtu = 512;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
