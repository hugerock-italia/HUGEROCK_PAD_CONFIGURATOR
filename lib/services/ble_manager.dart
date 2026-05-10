import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/enums.dart';

class BLEManager extends ChangeNotifier {
  static const String SERVICE_UUID     = '12345678-1234-1234-1234-123456789012';
  static const String CONFIG_CHAR_UUID = '87654321-4321-4321-4321-210987654321';
  static const String OTA_CHAR_UUID    = '87654321-4321-4321-4321-210987654323';

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _configCharacteristic;
  BluetoothCharacteristic? _otaCharacteristic;
  DeviceType? _deviceType;
  bool _isScanning = false;
  int _mtu = 512;

  BluetoothDevice? get connectedDevice => _connectedDevice;
  DeviceType?      get deviceType      => _deviceType;
  bool             get isConnected     => _connectedDevice != null;
  bool             get isScanning      => _isScanning;
  int              get mtu             => _mtu;
  int              get otaChunkSize    => (_mtu - 3).clamp(20, 512);

  BLEManager() {
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.off) disconnect();
    });
  }

  bool _isTargetDevice(BluetoothDevice device) {
    final name = device.localName.isNotEmpty ? device.localName : device.platformName;
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
      debugPrint('[BLE] Bonded devices: ${bonded.map((d) => d.platformName).toList()}');

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
          debugPrint('[BLE] Scan found: ${r.device.platformName} / ${r.device.localName}');
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

  Future<void> _connectToDevice(BluetoothDevice device, {int attempt = 1}) async {
    try {
      // Disconnect any stale connection before attempting
      if (device.isConnected) {
        debugPrint('[BLE] Device already connected, disconnecting first...');
        try { await device.disconnect(); } catch (_) {}
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

      final name = device.localName.isNotEmpty ? device.localName : device.platformName;
      _deviceType = DeviceType.fromDeviceName(name);
      debugPrint('[BLE] DeviceType: $_deviceType');

      final services = await device.discoverServices();
      debugPrint('[BLE] Services found: ${services.map((s) => s.uuid.str).toList()}');

      for (var service in services) {
        if (service.uuid.str.toLowerCase() == SERVICE_UUID.toLowerCase()) {
          for (var char in service.characteristics) {
            final uuid = char.uuid.str.toLowerCase();
            if (uuid == CONFIG_CHAR_UUID.toLowerCase()) _configCharacteristic = char;
            else if (uuid == OTA_CHAR_UUID.toLowerCase()) _otaCharacteristic = char;
          }
        }
      }

      if (_configCharacteristic == null) {
        throw Exception('Config characteristic not found');
      }

      await Future.delayed(const Duration(milliseconds: 200));
      await sendConfigModeOn();
      debugPrint('[BLE] CONFIG:MODE:ON sent');

      _isScanning = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[BLE] _connectToDevice error (attempt $attempt): $e');

      // GATT 133: stale Android BLE cache — retry once after cleanup
      final isGatt133 = e.toString().contains('133') || e.toString().contains('GATT');
      if (isGatt133 && attempt == 1) {
        debugPrint('[BLE] GATT 133 detected, retrying after cleanup...');
        try { await device.disconnect(); } catch (_) {}
        await Future.delayed(const Duration(seconds: 2));
        await _connectToDevice(device, attempt: 2);
        return;
      }

      _connectedDevice = null;
      _configCharacteristic = null;
      _otaCharacteristic = null;
      _deviceType = null;
      _isScanning = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> sendConfigCommand(int mapId, int keyIndex, int commandId, {bool repeat = false}) async {
    if (_configCharacteristic == null) throw Exception('Not connected');
    final cmd = 'CONFIG:$mapId:$keyIndex:${commandId.toRadixString(16).padLeft(2, '0').toUpperCase()}:${repeat ? 1 : 0}';
    await _configCharacteristic!.write(cmd.codeUnits, withoutResponse: false);
  }

  Future<void> sendConfigModeOn() async {
    if (_configCharacteristic == null) throw Exception('Not connected');
    await _configCharacteristic!.write('CONFIG:MODE:ON'.codeUnits, withoutResponse: false);
  }

  Future<void> sendConfigModeOff() async {
    if (_configCharacteristic == null) throw Exception('Not connected');
    await _configCharacteristic!.write('CONFIG:MODE:OFF'.codeUnits, withoutResponse: false);
  }

  Future<void> sendResetCommand() async {
    if (_configCharacteristic == null) throw Exception('Not connected');
    await _configCharacteristic!.write('RESET:CONFIG'.codeUnits, withoutResponse: false);
  }

  Future<void> sendWheelEnable(int mapId, bool enabled) async {
    if (_configCharacteristic == null) throw Exception('Not connected');
    await _configCharacteristic!.write(
      'CONFIG:WHEEL:$mapId:${enabled ? 1 : 0}'.codeUnits,
      withoutResponse: false,
    );
  }

  // ==================== OTA ====================

  Future<void> startOta(int fileSize) async {
    if (_configCharacteristic == null) throw Exception('Not connected');
    await _configCharacteristic!.write('CONFIG:OTA:BEGIN:$fileSize'.codeUnits, withoutResponse: false);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> sendOtaChunk(Uint8List chunk) async {
    if (_otaCharacteristic == null) throw Exception('OTA characteristic not available');
    await _otaCharacteristic!.write(chunk, withoutResponse: true);
  }

  Future<void> endOta() async {
    if (_configCharacteristic == null) throw Exception('Not connected');
    await _configCharacteristic!.write('CONFIG:OTA:END'.codeUnits, withoutResponse: false);
  }

  Stream<List<int>>? get otaNotifications => _otaCharacteristic?.onValueReceived;

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
    try { await _otaCharacteristic?.setNotifyValue(false); } catch (_) {}
  }

  // ==================== DISCONNECT ====================

  Future<void> disconnect({bool skipConfigOff = false}) async {
    if (_connectedDevice != null) {
      try { await unsubscribeOtaNotifications(); } catch (_) {}
      if (!skipConfigOff) {
        try { await sendConfigModeOff(); } catch (_) {}
      }
      try { await _connectedDevice!.disconnect(); } catch (_) {}
    }
    _connectedDevice = null;
    _configCharacteristic = null;
    _otaCharacteristic = null;
    _deviceType = null;
    _mtu = 512;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}