import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/ble_manager.dart';
import '../models/enums.dart';

const String _githubOwner = 'hugerock-italia';
const String _githubRepo = 'kat1-firmware';
// ignore: unused_element
const int _chunkSize = 512;
const int _chunkDelay = 30;

class OtaScreen extends StatefulWidget {
  final BLEManager bleManager;
  final DeviceType deviceType;

  const OtaScreen(
      {Key? key, required this.bleManager, required this.deviceType})
      : super(key: key);

  @override
  State<OtaScreen> createState() => _OtaScreenState();
}

class _OtaScreenState extends State<OtaScreen> {
  String? _latestVersion;
  String? _assetUrl;
  String _status = 'Verifico aggiornamenti...';
  bool _loading = true;
  bool _updating = false;
  double _progress = 0.0;
  int _totalBytes = 0;
  int _sentBytes = 0;

  @override
  void initState() {
    super.initState();
    _checkLatestRelease();
  }

  Future<void> _checkLatestRelease() async {
    setState(() {
      _loading = true;
      _status = 'Connecting to GitHub...';
    });
    try {
      final url =
          'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest';
      final response = await http.get(Uri.parse(url),
          headers: {'Accept': 'application/vnd.github.v3+json'});
      if (response.statusCode != 200)
        throw Exception('GitHub API error: ${response.statusCode}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final version = data['tag_name'] as String;
      final assets = data['assets'] as List<dynamic>;
      final assetName = '${widget.deviceType.bleName}.bin';

      String? foundUrl;
      for (final asset in assets) {
        if ((asset['name'] as String).toLowerCase() ==
            assetName.toLowerCase()) {
          foundUrl = asset['browser_download_url'] as String;
          break;
        }
      }
      if (foundUrl == null)
        throw Exception('File $assetName non trovato nella release');

      setState(() {
        _latestVersion = version;
        _assetUrl = foundUrl;
        _status = 'Versione disponibile: $version';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _startUpdate() async {
    if (_assetUrl == null) return;
    setState(() {
      _updating = true;
      _progress = 0;
      _sentBytes = 0;
      _status = 'Downloading firmware...';
    });

    try {
      final response = await http.get(Uri.parse(_assetUrl!));
      if (response.statusCode != 200)
        throw Exception('Download fallito: ${response.statusCode}');

      final Uint8List firmware = response.bodyBytes;
      _totalBytes = firmware.length;

      setState(() =>
          _status = 'Starting OTA on ${widget.deviceType.displayName}...');
      final hasNotify = await widget.bleManager.subscribeOtaNotifications();

      bool otaError = false;
      if (hasNotify) {
        widget.bleManager.otaNotifications?.listen((value) {
          if (String.fromCharCodes(value).startsWith('ERR')) otaError = true;
        });
      }

      await widget.bleManager.startOta(_totalBytes);
      setState(() => _status =
          'Sending firmware... (chunk: \${widget.bleManager.otaChunkSize}B)');

      final chunkSize = widget.bleManager.otaChunkSize;
      int offset = 0;
      while (offset < firmware.length) {
        if (otaError) throw Exception('OTA error reported by device');
        final end = (offset + chunkSize < firmware.length)
            ? offset + chunkSize
            : firmware.length;
        await widget.bleManager.sendOtaChunk(firmware.sublist(offset, end));
        offset = end;
        _sentBytes = offset;
        setState(() => _progress = _sentBytes / _totalBytes);
        await Future.delayed(const Duration(milliseconds: _chunkDelay));
      }

      setState(() => _status = 'Finalizing...');
      try {
        await widget.bleManager.endOta();
      } catch (_) {}
      await widget.bleManager.unsubscribeOtaNotifications();

      setState(() {
        _status = '✓ Update complete! Device is restarting.';
        _updating = false;
        _progress = 1.0;
      });
      await Future.delayed(const Duration(seconds: 4));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      try {
        await widget.bleManager.unsubscribeOtaNotifications();
      } catch (_) {}
      setState(() {
        _status = 'Error: $e';
        _updating = false;
        _progress = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('FIRMWARE · ${widget.deviceType.displayName}'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.system_update,
                  size: 64, color: Color(0xFF1A237E)),
              const SizedBox(height: 24),
              Text('Firmware Update',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(widget.deviceType.displayName,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 32),

              // STATUS BOX
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    if (_loading) const CircularProgressIndicator(),
                    if (!_loading && _latestVersion != null) ...[
                      Text('Repository: $_githubOwner/$_githubRepo',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(_latestVersion!,
                          style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                    ],
                    const SizedBox(height: 8),
                    Text(_status,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // PROGRESS BAR
              if (_updating || _progress > 0) ...[
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey[800],
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_progress * 100).toStringAsFixed(1)}%  ·  '
                  '${(_sentBytes / 1024).toStringAsFixed(1)} / ${(_totalBytes / 1024).toStringAsFixed(1)} KB',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 24),
              ],

              // BUTTONS
              if (!_updating) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _latestVersion != null && !_loading
                        ? _startUpdate
                        : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E)),
                    child: const Text('SCARICA E INSTALLA',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _checkLatestRelease,
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white30)),
                    child: const Text('CHECK FOR UPDATES'),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800]),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('UPDATING...',
                            style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],

              const Spacer(),
              const Text(
                '⚠ Do not disconnect the device during update.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
