import 'package:flutter/material.dart';
import '../main.dart';


class KeyboardLayoutDisplay extends StatelessWidget {
  final KeyMap selectedMap;
  final Map<int, Map<int, int>> mapConfigs;
  final Map<int, Map<int, bool>> repeatFlags;
  final DeviceType deviceType;
  final Function(int) onTapKey;
  final Function(int)? onToggleRepeat;
  final Map<int, bool> wheelEnabled;
  final Function(bool)? onToggleWheel;

  const KeyboardLayoutDisplay({
    Key? key,
    required this.selectedMap,
    required this.mapConfigs,
    required this.repeatFlags,
    required this.deviceType,
    required this.wheelEnabled,
    required this.onTapKey,
    this.onToggleRepeat,
    this.onToggleWheel,
  }) : super(key: key);

  String _getCommandName(int commandId) {
    try {
      return CommandID.fromId(commandId).display;
    } catch (_) {
      return '?';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final buttonSize = isLandscape ? 45.0 : 65.0;
    final fontSize = isLandscape ? 10.0 : 14.0;
    final spacing = isLandscape ? 2.0 : 4.0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SHORT / LONG header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: spacing * 2),
            child: Row(
              children: [
                Expanded(child: Text('SHORT PRESS', style: TextStyle(fontSize: fontSize - 2, fontWeight: FontWeight.bold, color: AppColors.sandDark))),
                Expanded(child: const SizedBox()),
                Expanded(child: Text('LONG PRESS', textAlign: TextAlign.right, style: TextStyle(fontSize: fontSize - 2, fontWeight: FontWeight.bold, color: AppColors.sandDark))),
                SizedBox(width: buttonSize + spacing * 4),
              ],
            ),
          ),

          _buildButtonRow(context, 0, AppColors.buttonRed, buttonSize, fontSize, spacing),
          _buildButtonRow(context, 2, AppColors.buttonBlue, buttonSize, fontSize, spacing),
          _buildButtonRow(context, 4, AppColors.buttonBlack, buttonSize, fontSize, spacing),
          _buildButtonRow(context, 6, AppColors.buttonYellow, buttonSize, fontSize, spacing),

          SizedBox(height: spacing * 3),

          // SWITCH (Extreme) or JOYSTICK (Discovery)
          if (deviceType == DeviceType.extreme)
            _buildSwitchSection(context, buttonSize, fontSize, spacing)
          else
            _buildJoystickSection(context, buttonSize, fontSize, spacing),
        ],
      ),
    );
  }

  Widget _buildButtonRow(BuildContext context, int startIndex, Color color, double buttonSize, double fontSize, double spacing) {
    return Padding(
      padding: EdgeInsets.only(bottom: spacing),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildColoredKey(context, startIndex, color, buttonSize, fontSize),
          SizedBox(width: spacing * 2),
          _buildColoredKey(context, startIndex + 1, color, buttonSize, fontSize),
          SizedBox(width: spacing * 2),
          _buildRepeatSquare(startIndex, color, buttonSize),
        ],
      ),
    );
  }

  Widget _buildSwitchSection(BuildContext context, double buttonSize, double fontSize, double spacing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ROADBOOK LEVER', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: AppColors.sandDark)),
        SizedBox(height: spacing * 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildControlButton(context, 8, '▲', 'SU', buttonSize, fontSize),
            SizedBox(width: spacing * 6),
            _buildControlButton(context, 9, '▼', 'GIÙ', buttonSize, fontSize),
          ],
        ),
        SizedBox(height: spacing * 3),
        _buildExtAndWheelRow(context, buttonSize, fontSize, spacing),
      ],
    );
  }

  Widget _buildJoystickSection(BuildContext context, double buttonSize, double fontSize, double spacing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('JOYSTICK', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: AppColors.sandDark)),
        SizedBox(height: spacing * 2),
        Center(child: _buildControlButton(context, 8, '↑', '', buttonSize * 0.7, fontSize)),
        SizedBox(height: spacing * 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildControlButton(context, 10, '←', '', buttonSize * 0.7, fontSize),
            SizedBox(width: spacing * 3),
            _buildControlButton(context, 12, '⊙', '', buttonSize * 0.7, fontSize),
            SizedBox(width: spacing * 3),
            _buildControlButton(context, 11, '→', '', buttonSize * 0.7, fontSize),
          ],
        ),
        SizedBox(height: spacing * 2),
        Center(child: _buildControlButton(context, 9, '↓', '', buttonSize * 0.7, fontSize)),
        SizedBox(height: spacing * 3),
        _buildExtAndWheelRow(context, buttonSize, fontSize, spacing),
      ],
    );
  }

  Widget _buildExtAndWheelRow(BuildContext context, double buttonSize, double fontSize, double spacing) {
    final isWheelOn = wheelEnabled[selectedMap.id] ?? true;
    return Row(
      children: [
        _buildControlButton(context, 13, 'EXT', '', buttonSize * 0.75, fontSize - 2),
        SizedBox(width: spacing * 3),
        Expanded(
          child: GestureDetector(
            onTap: () => onToggleWheel?.call(!isWheelOn),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: buttonSize * 0.75,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isWheelOn ? Colors.grey[700] : Colors.grey[900],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isWheelOn ? Colors.greenAccent : Colors.grey, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WHEEL', style: TextStyle(fontSize: fontSize - 3, fontWeight: FontWeight.bold, color: Colors.white70)),
                      Text('SENSOR', style: TextStyle(fontSize: fontSize - 4, color: Colors.white54)),
                    ],
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: isWheelOn,
                      onChanged: (val) => onToggleWheel?.call(val),
                      activeColor: Colors.greenAccent,
                      activeTrackColor: Colors.green[800],
                      inactiveThumbColor: Colors.grey[400],
                      inactiveTrackColor: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColoredKey(BuildContext context, int keyIndex, Color color, double buttonSize, double fontSize) {
    final config = mapConfigs[selectedMap.id]?[keyIndex] ?? 0x00;
    return GestureDetector(
      onTap: () => onTapKey(keyIndex),
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
        child: Center(
          child: Text(
            _getCommandName(config),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildRepeatSquare(int keyIndex, Color color, double buttonSize) {
    final isRepeat = repeatFlags[selectedMap.id]?[keyIndex] ?? false;
    return GestureDetector(
      onTap: () => onToggleRepeat?.call(keyIndex),
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: isRepeat ? color : Colors.transparent,
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Center(
          child: Text(
            isRepeat ? '🔄' : '—',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isRepeat ? Colors.white : color),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(BuildContext context, int keyIndex, String icon, String label, double buttonSize, double fontSize) {
    final config = mapConfigs[selectedMap.id]?[keyIndex] ?? 0x00;
    final commandName = _getCommandName(config);
    return GestureDetector(
      onTap: () => onTapKey(keyIndex),
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(6)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: TextStyle(fontSize: fontSize + 2, fontWeight: FontWeight.bold, color: Colors.black)),
            if (label.isNotEmpty) Text(label, style: TextStyle(fontSize: fontSize - 3, color: Colors.black54)),
            const SizedBox(height: 2),
            Text(commandName, textAlign: TextAlign.center, style: TextStyle(fontSize: fontSize - 2, fontWeight: FontWeight.bold, color: Colors.black)),
          ],
        ),
      ),
    );
  }
}
