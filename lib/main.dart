import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'config/colors.dart';
import 'config/app_theme.dart';

export 'config/colors.dart';
export 'config/app_theme.dart';
export 'services/ble_manager.dart';
export 'models/enums.dart';

void main() {
  runApp(const HugeRockApp());
}

class HugeRockApp extends StatelessWidget {
  const HugeRockApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HugeRock KAT1 Configurator',
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}