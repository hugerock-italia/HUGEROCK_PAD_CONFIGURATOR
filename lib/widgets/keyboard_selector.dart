import 'package:flutter/material.dart';
import '../main.dart';

class KeyboardSelector extends StatefulWidget {
  final int keyIndex;

  const KeyboardSelector({
    Key? key,
    required this.keyIndex,
  }) : super(key: key);

  @override
  State<KeyboardSelector> createState() => _KeyboardSelectorState();
}

class _KeyboardSelectorState extends State<KeyboardSelector>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedCommandId = 0x00;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _selectCommand(int commandId) {
    setState(() {
      _selectedCommandId = commandId;
    });
    Navigator.pop(context, commandId);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppTheme.padding),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SELEZIONA COMANDO',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'per ${KeyboardKey.values[widget.keyIndex].getDisplayName()}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: 'TASTIERA'),
              Tab(text: 'SPECIALI'),
            ],
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: TASTIERA PRINCIPALE
                _buildMainKeyboard(),
                // TAB 2: SPECIALI + MEDIA
                _buildSpecialKeys(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TASTIERA PRINCIPALE ====================

  Widget _buildMainKeyboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // QWERTY - Keycodes HID standard corretti
          const SizedBox(height: 8),
          _buildKeyRow(
            ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
            [0x14, 0x1A, 0x08, 0x15, 0x17, 0x1C, 0x18, 0x0C, 0x12, 0x13],
          ),
          const SizedBox(height: 8),

          // ASDFGH - Keycodes HID standard corretti
          _buildKeyRow(
            ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
            [0x04, 0x16, 0x07, 0x09, 0x0A, 0x0B, 0x0D, 0x0E, 0x0F],
          ),
          const SizedBox(height: 8),

          // ZXCVBN - Keycodes HID standard corretti
          _buildKeyRow(
            ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
            [0x1D, 0x1B, 0x06, 0x19, 0x05, 0x11, 0x10],
          ),
          const SizedBox(height: 8),

          // NUMERI - Keycodes HID (1-6=0x1E-0x23, 7=0x31, 8=0x33, 9=0x34, 0=0x35)
          _buildKeyRow(
            ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
            [0x35, 0x1E, 0x1F, 0x20, 0x21, 0x22, 0x23, 0x31, 0x33, 0x34],
          ),
          const SizedBox(height: 8),

          // SIMBOLI - Keycodes custom per ., ,, +, -
          _buildKeyRow(
            ['.', ',', '+', '-'],
            [0x37, 0x36, 0x38, 0x39],
          ),
          const SizedBox(height: 8),

          // FRECCE
          Text(
            'FRECCE',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildKeyRow(['↑', '↓', '←', '→'], [0x52, 0x51, 0x50, 0x4F]),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ==================== TASTI SPECIALI E MEDIA ====================

  Widget _buildSpecialKeys() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // MEDIA KEYS
          Text(
            'MEDIA KEYS',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildKeyRow(['VOL+', 'VOL-', 'PREV', 'NEXT', 'PLAY', 'MUTE'],
              [0x25, 0x24, 0x27, 0x26, 0x2D, 0x2E]),
          const SizedBox(height: 16),

          // TASTI SPECIALI
          Text(
            'TASTI SPECIALI',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildKeyRow(
              ['ENTER', 'TAB', 'ESC', 'SPACE'], [0x28, 0x2B, 0x29, 0x2C]),
          const SizedBox(height: 8),
          _buildKeyRow(['BACK', 'DEL'], [0x2A, 0x4E]),
          const SizedBox(height: 16),

          // COMBINAZIONI
          Text(
            'COMBINAZIONI',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildKeyRow(['ALT+TAB'], [0x2C]),
          const SizedBox(height: 16),

          // PAGE UP/DOWN
          Text(
            'NAVIGAZIONE',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildKeyRow(['PAGE UP', 'PAGE DOWN'], [0x4B, 0x4E]),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ==================== HELPER: BUILD ROW ====================

  Widget _buildKeyRow(List<String> labels, List<int> commandIds) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(
        labels.length,
        (index) => _buildKeyButton(labels[index], commandIds[index]),
      ),
    );
  }

  // ==================== HELPER: BUILD BUTTON ====================

  Widget _buildKeyButton(String label, int commandId) {
    bool isSelected = _selectedCommandId == commandId;

    return GestureDetector(
      onTap: () => _selectCommand(commandId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.sandMedium : Colors.grey[400],
          border: Border.all(
            color: isSelected ? AppColors.sandMedium : Colors.grey[400]!,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
