import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/ble_manager.dart';
import '../models/app_profiles.dart';
import '../models/enums.dart';

class AutoConfigScreen extends StatefulWidget {
  final BLEManager bleManager;
  const AutoConfigScreen({Key? key, required this.bleManager})
      : super(key: key);

  @override
  State<AutoConfigScreen> createState() => _AutoConfigScreenState();
}

class _AutoConfigScreenState extends State<AutoConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AppProfile? _selectedProfile;
  late KeyMap _selectedMap;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _selectedMap = KeyMap.map1;
    _tabController =
        TabController(length: profileCategories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _selectProfile(AppProfile profile) {
    setState(() {
      _selectedProfile = profile;
      // Pre-seleziona la mappa raccomandata
      _selectedMap = KeyMap.values.firstWhere(
        (m) => m.id == profile.recommendedMapId,
        orElse: () => KeyMap.map1,
      );
    });
  }

  Future<void> _applyProfile() async {
    if (_selectedProfile == null) return;
    setState(() => _applying = true);

    try {
      final mapId = _selectedMap.id; // 0-based, come si aspetta il firmware

      // Invia via BLE
      for (int keyIndex = 0; keyIndex < 14; keyIndex++) {
        await widget.bleManager.sendConfigCommand(
          mapId,
          keyIndex,
          _selectedProfile!.assignments[keyIndex],
          repeat: _selectedProfile!.repeatFlags[keyIndex],
        );
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Salva su SharedPreferences per aggiornare config_screen
      final prefs = await SharedPreferences.getInstance();
      for (int keyIndex = 0; keyIndex < 14; keyIndex++) {
        await prefs.setInt('map_${mapId}_key_$keyIndex',
            _selectedProfile!.assignments[keyIndex]);
        await prefs.setBool('map_${mapId}_key_${keyIndex}_repeat',
            _selectedProfile!.repeatFlags[keyIndex]);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✓ ${_selectedProfile!.name} applicato a ${_selectedMap.displayName}'),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AUTO CONFIG'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.sandMedium,
          labelColor: AppColors.sandMedium,
          unselectedLabelColor: Colors.white54,
          tabs: profileCategories.map((cat) => Tab(text: cat)).toList(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children:
                    profileCategories.map((cat) => _buildAppList(cat)).toList(),
              ),
            ),
            if (_selectedProfile != null) _buildApplyBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppList(String category) {
    final profiles = getProfilesByCategory(category);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: profiles.length,
      itemBuilder: (context, index) {
        final profile = profiles[index];
        final isSelected = _selectedProfile?.id == profile.id;
        final recommendedMap = KeyMap.values.firstWhere(
          (m) => m.id == profile.recommendedMapId,
          orElse: () => KeyMap.map1,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => _selectProfile(profile),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.sandMedium.withOpacity(0.15)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                border: Border.all(
                  color: isSelected
                      ? AppColors.sandMedium
                      : AppColors.surfaceLight,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.sandMedium
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(profile.icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const SizedBox(height: 3),
                        Text(profile.description,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('Recommended map: ',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 11)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: recommendedMap.color.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: recommendedMap.color, width: 1),
                              ),
                              child: Text(recommendedMap.displayName,
                                  style: TextStyle(
                                      color: recommendedMap.color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: AppColors.sandMedium),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildApplyBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border:
            Border(top: BorderSide(color: AppColors.surfaceLight, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(_selectedProfile!.icon,
                  color: AppColors.sandMedium, size: 16),
              const SizedBox(width: 8),
              Text(_selectedProfile!.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const Spacer(),
              const Text('Apply to:',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: KeyMap.values
                .map((map) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedMap = map),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedMap == map
                                  ? map.color
                                  : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              map.displayName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _applying ? null : _applyProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedMap.color,
                disabledBackgroundColor: AppColors.surfaceLight,
              ),
              child: _applying
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white)))
                  : const Text('APPLY',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
}
