import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/ble_manager.dart';

import '../widgets/keyboard_selector.dart';
import '../widgets/keyboard_button_display.dart';

class ConfigScreen extends StatefulWidget {
  final BLEManager bleManager;
  final DeviceType deviceType;

  const ConfigScreen({
    Key? key,
    required this.bleManager,
    required this.deviceType,
  }) : super(key: key);

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  late KeyMap selectedMap;
  Map<int, Map<int, int>> mapConfigs = {};
  Map<int, Map<int, bool>> repeatFlags = {};
  Map<int, bool> wheelEnabled = {};

  @override
  void initState() {
    super.initState();
    selectedMap = KeyMap.map1;
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (int map = 0; map < 3; map++) {
        mapConfigs[map] = {};
        repeatFlags[map] = {};
        for (int key = 0; key < 14; key++) {
          mapConfigs[map]![key] = prefs.getInt('map_${map}_key_$key') ?? _getDefaultCommand(map, key);
          repeatFlags[map]![key] = prefs.getBool('map_${map}_key_${key}_repeat') ?? _getDefaultRepeat(map, key);
        }
        wheelEnabled[map] = prefs.getBool('map_${map}_wheel_enabled') ?? true;
      }
    });
  }

  int _getDefaultCommand(int map, int key) {
    const maps = [
      [0x25,0x25,0x24,0x24,0x06,0x07,0x09,0x2C,0x52,0x51,0x50,0x4F,0x06,0x06], // Map1
      [0x4F,0x4F,0x50,0x50,0x1D,0x15,0x51,0x2C,0x52,0x51,0x26,0x27,0x10,0x0A], // Map2
      [0x52,0x52,0x51,0x51,0x52,0x07,0x51,0x1D,0x24,0x25,0x25,0x24,0x17,0x17], // Map3
    ];
    if (map < 0 || map > 2 || key < 0 || key > 13) return 0x00;
    return maps[map][key];
  }

  bool _getDefaultRepeat(int map, int key) {
    // Map1: keys 0-3 repeat | Map2: keys 0,2 repeat | Map3: keys 0-3 repeat
    if (map == 1) return [0, 2].contains(key);
    return [0, 1, 2, 3].contains(key);
  }

  Future<void> _setCommand(int keyIndex, int commandId) async {
    setState(() => mapConfigs[selectedMap.id]![keyIndex] = commandId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('map_${selectedMap.id}_key_$keyIndex', commandId);
    final repeat = repeatFlags[selectedMap.id]![keyIndex] ?? false;
    await widget.bleManager.sendConfigCommand(selectedMap.id, keyIndex, commandId, repeat: repeat);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Configurazione salvata'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _toggleRepeat(int keyIndex) async {
    final newRepeat = !(repeatFlags[selectedMap.id]![keyIndex] ?? false);
    setState(() => repeatFlags[selectedMap.id]![keyIndex] = newRepeat);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('map_${selectedMap.id}_key_${keyIndex}_repeat', newRepeat);
    final commandId = mapConfigs[selectedMap.id]![keyIndex] ?? 0x00;
    await widget.bleManager.sendConfigCommand(selectedMap.id, keyIndex, commandId, repeat: newRepeat);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newRepeat ? '🔄 Ripetizione attivata' : '🔄 Ripetizione disattivata'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _resetMapToDefault() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final mapId = selectedMap.id;
    final mapName = selectedMap.displayName;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset defaults'),
        content: Text('Reset $mapName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final prefs = await SharedPreferences.getInstance();
              for (int key = 0; key < 14; key++) {
                final cmd = _getDefaultCommand(mapId, key);
                final rep = _getDefaultRepeat(mapId, key);
                if (mounted) setState(() {
                  mapConfigs[mapId]![key] = cmd;
                  repeatFlags[mapId]![key] = rep;
                });
                await prefs.setInt('map_${mapId}_key_$key', cmd);
                await prefs.setBool('map_${mapId}_key_${key}_repeat', rep);
                await widget.bleManager.sendConfigCommand(mapId, key, cmd, repeat: rep);
              }
              scaffoldMessenger.showSnackBar(
                SnackBar(content: Text('✓ $mapName reset'), duration: const Duration(seconds: 2)),
              );
            },
            child: const Text('RESET', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMapToDevice() async {
    setState(() {});
    try {
      for (int key = 0; key < 14; key++) {
        final cmd = mapConfigs[selectedMap.id]![key] ?? _getDefaultCommand(selectedMap.id, key);
        final rep = repeatFlags[selectedMap.id]![key] ?? _getDefaultRepeat(selectedMap.id, key);
        await widget.bleManager.sendConfigCommand(selectedMap.id, key, cmd, repeat: rep);
        await Future.delayed(const Duration(milliseconds: 25));
      }
      final wheelOn = wheelEnabled[selectedMap.id] ?? true;
      await widget.bleManager.sendWheelEnable(selectedMap.id, wheelOn);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✓ ${selectedMap.displayName} saved to device'),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[700]),
        );
      }
    }
  }

  Future<void> _toggleWheel(int mapId, bool enabled) async {
    setState(() => wheelEnabled[mapId] = enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('map_\${mapId}_wheel_enabled', enabled);
    await widget.bleManager.sendWheelEnable(mapId, enabled);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(enabled ? '✓ Wheel sensor enabled' : '✓ Wheel sensor disabled'),
        duration: const Duration(seconds: 1),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: Text('CONFIG · ${widget.deviceType.displayName}'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isLandscape ? 6.0 : 12.0),
          child: Column(
            children: [
              // MAP SELECTOR
              Row(
                children: KeyMap.values.map((map) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ElevatedButton(
                      onPressed: () => setState(() => selectedMap = map),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedMap == map ? map.color : AppColors.surfaceLight,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: isLandscape ? 4 : 8),
                      ),
                      child: Text(
                        map.displayName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: isLandscape ? 9 : 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                )).toList(),
              ),
              SizedBox(height: isLandscape ? 6 : 12),

              Container(
                padding: EdgeInsets.all(isLandscape ? 4 : 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KEYBOARD',
                      style: TextStyle(fontSize: isLandscape ? 11 : 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(height: isLandscape ? 4 : 8),
                    KeyboardLayoutDisplay(
                      selectedMap: selectedMap,
                      mapConfigs: mapConfigs,
                      repeatFlags: repeatFlags,
                      deviceType: widget.deviceType,
                      wheelEnabled: wheelEnabled,
                      onToggleWheel: (enabled) => _toggleWheel(selectedMap.id, enabled),
                      onTapKey: (keyIndex) async {
                        final result = await showDialog<int>(
                          context: context,
                          builder: (_) => KeyboardSelector(keyIndex: keyIndex),
                        );
                        if (result != null) await _setCommand(keyIndex, result);
                      },
                      onToggleRepeat: _toggleRepeat,
                    ),
                  ],
                ),
              ),
              SizedBox(height: isLandscape ? 6 : 12),

              // SAVE TO DEVICE
              SizedBox(
                width: double.infinity,
                height: isLandscape ? 36 : 48,
                child: ElevatedButton(
                  onPressed: _saveMapToDevice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedMap.color,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.save_alt, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'SAVE TO DEVICE',
                        style: TextStyle(fontSize: isLandscape ? 10 : 13, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: isLandscape ? 4 : 8),

              SizedBox(
                width: double.infinity,
                height: isLandscape ? 32 : 40,
                child: OutlinedButton(
                  onPressed: _resetMapToDefault,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning, width: 2),
                  ),
                  child: Text(
                    'RESET DEFAULTS',
                    style: TextStyle(fontSize: isLandscape ? 10 : 12, fontWeight: FontWeight.bold),
                  ),
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