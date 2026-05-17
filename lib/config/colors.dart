//==========================================================================
// 🎨 KAT1 CONFIGURATOR - COMPLETE COLOR PALETTE
// Based on TripMaster Rally + Button colors
//==========================================================================

import 'package:flutter/material.dart';

class AppColors {
  // ─────────────────────────────────────────────────────
  // PALETTE SABBIA PRINCIPALE (TripMaster)
  // ─────────────────────────────────────────────────────

  /// Sand Dark - Testi primari, bordi
  static const Color sandDark = Color(0xFF8B6F47);

  /// Sand Medium - Bottoni primari
  static const Color sandMedium = Color(0xFFD4A574);

  /// Sand Light - Sfondo leggero
  static const Color sandLight = Color(0xFFF4E4C1);

  /// Sand Very Light - Background principale
  static const Color sandVeryLight = Color(0xFFFAF7F2);

  /// Sand Grey - Disabled/secondary
  static const Color sandGrey = Color(0xFFB8A69A);

  // ─────────────────────────────────────────────────────
  // COLORI STATUS
  // ─────────────────────────────────────────────────────

  /// Bluetooth Blue
  static const Color bluetoothBlue = Color(0xFF1F97FF);

  /// CAP Blue
  static const Color capBlue = Color(0xFF0D47A1);

  /// Connected/Success Green
  static const Color connected = Color(0xFF4CAF50);

  /// Disconnected/Error Red
  static const Color disconnected = Color(0xFFF44336);

  /// Warning Orange
  static const Color warning = Color(0xFFFFA500);

  // ─────────────────────────────────────────────────────
  // COLORI BOTTONI TASTIERA
  // ─────────────────────────────────────────────────────

  /// Rosso - Button 1/2
  static const Color buttonRed = Color(0xFFE53935);

  /// Blu - Button 3/4
  static const Color buttonBlue = Color(0xFF1976D2);

  /// Nero - Button 5/6
  static const Color buttonBlack = Color(0xFF424242);

  /// Giallo - Button 7/8
  static const Color buttonYellow = Color(0xFFFDD835);

  // ─────────────────────────────────────────────────────
  // COLORI UI GENERALI
  // ─────────────────────────────────────────────────────

  /// Background scuro
  static const Color background = Color(0xFFFAF7F2);

  /// Surface scuro
  static const Color surface = Color(0xFFF4E4C1);

  /// Surface light
  static const Color surfaceLight = Color(0xFFD4A574);

  /// Primary color (sabbia medium)
  static const Color primary = sandMedium;

  /// Secondary color
  static const Color secondary = sandLight;

  // ─────────────────────────────────────────────────────
  // UTILITIES
  // ─────────────────────────────────────────────────────

  static Color sandMediumWithOpacity(double opacity) {
    return sandMedium.withOpacity(opacity);
  }

  static Color sandLightWithOpacity(double opacity) {
    return sandLight.withOpacity(opacity);
  }

  static Color sandDarkWithOpacity(double opacity) {
    return sandDark.withOpacity(opacity);
  }
}
