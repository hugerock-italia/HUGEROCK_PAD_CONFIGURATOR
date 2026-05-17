import 'package:flutter/material.dart';

enum DeviceType {
  extreme('EXTREME-PAD', 'Extreme'),
  discovery('DISCOVERY-PAD', 'Discovery');

  final String bleName;
  final String displayName;
  const DeviceType(this.bleName, this.displayName);

  static DeviceType? fromDeviceName(String name) {
    for (final t in DeviceType.values) {
      if (name.contains(t.bleName)) return t;
    }
    return null;
  }
}

enum CommandID {
  cmdA(0x04, 'A'),
  cmdB(0x05, 'B'),
  cmdC(0x06, 'C'),
  cmdD(0x07, 'D'),
  cmdE(0x08, 'E'),
  cmdF(0x09, 'F'),
  cmdG(0x0A, 'G'),
  cmdH(0x0B, 'H'),
  cmdI(0x0C, 'I'),
  cmdJ(0x0D, 'J'),
  cmdK(0x0E, 'K'),
  cmdL(0x0F, 'L'),
  cmdM(0x10, 'M'),
  cmdN(0x11, 'N'),
  cmdO(0x12, 'O'),
  cmdP(0x13, 'P'),
  cmdQ(0x14, 'Q'),
  cmdR(0x15, 'R'),
  cmdS(0x16, 'S'),
  cmdT(0x17, 'T'),
  cmdU(0x18, 'U'),
  cmdV(0x19, 'V'),
  cmdW(0x1A, 'W'),
  cmdX(0x1B, 'X'),
  cmdY(0x1C, 'Y'),
  cmdZ(0x1D, 'Z'),
  cmd1(0x1E, '1'),
  cmd2(0x1F, '2'),
  cmd3(0x20, '3'),
  cmd4(0x21, '4'),
  cmd5(0x22, '5'),
  cmd6(0x23, '6'),
  cmdVolumeDown(0x24, 'VOL-'),
  cmdVolumeUp(0x25, 'VOL+'),
  cmdNextTrack(0x26, 'NEXT'),
  cmdPrevTrack(0x27, 'PREV'),
  cmdEnter(0x28, 'ENTER'),
  cmdEsc(0x29, 'ESC'),
  cmdBackspace(0x2A, 'BACK'),
  cmdTab(0x2B, 'TAB'),
  cmdAltTab(0x2C, 'ALT+TAB'),
  cmd7(0x31, '7'),
  cmd8(0x33, '8'),
  cmd9(0x34, '9'),
  cmd0(0x35, '0'),
  cmdComma(0x36, ','),
  cmdDot(0x37, '.'),
  cmdPlayPause(0x2D, 'PLAY'),
  cmdMute(0x2E, 'MUTE'),
  cmdPlus(0x38, '+'),
  cmdMinus(0x39, '-'),
  cmdPageUp(0x4B, 'PG UP'),
  cmdPageDown(0x4E, 'PG DN'),
  cmdRightArrow(0x4F, 'RIGHT'),
  cmdLeftArrow(0x50, 'LEFT'),
  cmdDownArrow(0x51, 'DOWN'),
  cmdUpArrow(0x52, 'UP');

  final int id;
  final String display;
  const CommandID(this.id, this.display);

  static CommandID fromId(int id) {
    try {
      return CommandID.values.firstWhere((c) => c.id == id);
    } catch (_) {
      return CommandID.cmdA;
    }
  }
}

enum KeyboardKey {
  button1Short(0, 'Button 1 Short'),
  button1Long(1, 'Button 1 Long'),
  button2Short(2, 'Button 2 Short'),
  button2Long(3, 'Button 2 Long'),
  button3Short(4, 'Button 3 Short'),
  button3Long(5, 'Button 3 Long'),
  button4Short(6, 'Button 4 Short'),
  button4Long(7, 'Button 4 Long'),
  joystickUp(8, 'Up / Switch Up'),
  joystickDown(9, 'Down / Switch Down'),
  joystickLeft(10, 'Joystick Left'),
  joystickRight(11, 'Joystick Right'),
  joystickClick(12, 'Joystick Click'),
  externalButton(13, 'External Button');

  final int keyId;
  final String displayName;
  const KeyboardKey(this.keyId, this.displayName);

  String getDisplayName() => displayName;

  static KeyboardKey fromIndex(int keyId) {
    try {
      return KeyboardKey.values.firstWhere((k) => k.keyId == keyId);
    } catch (_) {
      return KeyboardKey.button1Short;
    }
  }
}

// id 0-based: corrisponde all'indice array firmware
enum KeyMap {
  map1(0, 'Yellow', Color(0xFFF9A825)),
  map2(1, 'Blue', Color(0xFF1565C0)),
  map3(2, 'Green', Color(0xFF2E7D32));

  final int id;
  final String displayName;
  final Color color;
  const KeyMap(this.id, this.displayName, this.color);

  static KeyMap fromId(int id) {
    try {
      return KeyMap.values.firstWhere((m) => m.id == id);
    } catch (_) {
      return KeyMap.map1;
    }
  }
}
