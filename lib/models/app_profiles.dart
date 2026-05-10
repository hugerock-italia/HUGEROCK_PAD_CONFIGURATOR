import 'package:flutter/material.dart';

// ignore: unused_import
import 'enums.dart';

// KeyMap ids: Green=0, Blue=1, Yellow=2

class AppProfile {
  final String id;
  final String name;
  final String category;
  final String description;
  final IconData icon;
  final int recommendedMapId; // 0=Green, 1=Blue, 2=Yellow
  // 14 slots: 0-1 btn1, 2-3 btn2, 4-5 btn3, 6-7 btn4,
  //           8 up/swUp, 9 down/swDown, 10 left, 11 right,
  //           12 ext, 13 wheel
  final List<int> assignments;
  final List<bool> repeatFlags;

  const AppProfile({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.icon,
    required this.recommendedMapId,
    required this.assignments,
    required this.repeatFlags,
  });
}

// ==================== GPS ====================

const osmandProfile = AppProfile(
  id: 'osmand',
  name: 'OsmAnd',
  category: 'GPS',
  description: 'Zoom VOL+/VOL-, center map, orientation',
  icon: Icons.map,
  recommendedMapId: 0,
  assignments: [0x25,0x25,0x24,0x24,0x06,0x07,0x09,0x2C,0x52,0x51,0x50,0x4F,0x06,0x00],
  repeatFlags: [true,true,true,true,false,false,false,false,false,false,false,false,false,false],
);

const whipProfile = AppProfile(
  id: 'whip',
  name: 'WHIP',
  category: 'GPS',
  description: 'Zoom +/-, center map, orientation',
  icon: Icons.navigation,
  recommendedMapId: 0,
  assignments: [0x38,0x38,0x39,0x39,0x06,0x07,0x09,0x2C,0x52,0x51,0x50,0x4F,0x06,0x00],
  repeatFlags: [true,true,true,true,false,false,false,false,false,false,false,false,false,false],
);

const locusMapProfile = AppProfile(
  id: 'locus_map',
  name: 'Locus Map',
  category: 'GPS',
  description: 'Zoom +/-, center, pan with joystick',
  icon: Icons.explore,
  recommendedMapId: 0,
  assignments: [0x38,0x38,0x39,0x39,0x06,0x07,0x09,0x2C,0x52,0x51,0x50,0x4F,0x06,0x00],
  repeatFlags: [true,true,true,true,false,false,false,false,false,false,false,false,false,false],
);

// ==================== ROADBOOK ====================

const terraPirataProfile = AppProfile(
  id: 'terrapirata',
  name: 'TerraPirata',
  category: 'ROADBOOK',
  description: 'Roadbook scroll, volume controls',
  icon: Icons.menu_book,
  recommendedMapId: 1,
  assignments: [
    0x4F,  // btn1: →
    0x4F,  // btn1L: →
    0x50,  // btn2: ←
    0x50,  // btn2L: ←
    0x1D,  // btn3: Z
    0x15,  // btn3L: R
    0x51,  // btn4: ↓
    0x2C,  // btn4L: ALT+TAB
    0x52,  // up: ↑
    0x51,  // down: ↓
    0x26,  // left: NEXT
    0x27,  // right: PREV
    0x10,  // ext: M
    0x0A  // wheel: G
  ],
  repeatFlags: [true,false,true,false,false,false,false,false,false,false,false,false,false,false],
);

const mrbProfile = AppProfile(
  id: 'mrb',
  name: 'MRB',
  category: 'ROADBOOK',
  description: 'Scroll with arrows and page keys',
  icon: Icons.book,
  recommendedMapId: 2,
  assignments: [
    0x52,  // btn1: ↑
    0x52,  // btn1L: ↑
    0x51,  // btn2: ↓
    0x51,  // btn2L: ↓
    0x52,  // btn3: ↑
    0x07,  // btn3L: D
    0x51,  // btn4: ↓
    0x1D,  // btn4L: Z
    0x24,  // up: VOL-
    0x25,  // down: VOL+
    0x25,  // left: VOL+
    0x24,  // right: VOL-
    0x17,  // ext: T
    0x17  // wheel: T
  ],
  repeatFlags: [true,true,true,true,false,false,false,false,false,false,false,false,false,false],
);

const roadbookReaderProfile = AppProfile(
  id: 'roadbook_reader',
  name: 'Rally Roadbook Reader',
  category: 'ROADBOOK',
  description: 'Digital scroll, trip +/-',
  icon: Icons.article,
  recommendedMapId: 0,
  assignments: [0x4B,0x4B,0x4E,0x4E,0x25,0x25,0x24,0x24,0x4B,0x4E,0x50,0x4F,0x28,0x00],
  repeatFlags: [true,true,false,false,true,true,false,false,false,false,false,false,false,false],
);

// ==================== MULTIMEDIA ====================

const youtubeProfile = AppProfile(
  id: 'youtube',
  name: 'YouTube / Media',
  category: 'MULTIMEDIA',
  description: 'Vol +/-, play/pause, mute, track forward/back',
  icon: Icons.play_circle_fill,
  recommendedMapId: 1,
  assignments: [0x25,0x25,0x24,0x24,0x2D,0x2D,0x2E,0x2E,0x26,0x27,0x26,0x27,0x2D,0x00],
  repeatFlags: [true,true,true,true,false,false,false,false,false,false,false,false,false,false],
);

// ==================== REGISTRY ====================

const List<AppProfile> allProfiles = [
  osmandProfile,
  whipProfile,
  locusMapProfile,
  terraPirataProfile,
  mrbProfile,
  roadbookReaderProfile,
  youtubeProfile,
];

List<AppProfile> getProfilesByCategory(String category) =>
    allProfiles.where((p) => p.category == category).toList();

const List<String> profileCategories = ['GPS', 'ROADBOOK', 'MULTIMEDIA'];