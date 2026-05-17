import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Holds metadata for an available app update.
class UpdateInfo {
  /// The version string from releases.json (e.g. "1.3.0").
  final String version;

  /// Direct download / release page URL for the APK.
  final String apkUrl;

  /// Human-readable release notes shown in the update dialog.
  final String releaseNotes;

  /// Release date string (e.g. "2026-05-10").
  final String date;

  const UpdateInfo({
    required this.version,
    required this.apkUrl,
    required this.releaseNotes,
    required this.date,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String,
      apkUrl: json['apkUrl'] as String,
      releaseNotes: json['releaseNotes'] as String,
      date: json['date'] as String,
    );
  }
}

/// Checks GitHub for a newer app version by reading releases.json.
class UpdateChecker {
  static const _releasesUrl =
      'https://raw.githubusercontent.com/hugerock-italia/HUGEROCK_PAD_CONFIGURATOR/main/releases.json';

  /// Compares two semver strings (MAJOR.MINOR.PATCH).
  ///
  /// Returns true if [remote] is strictly greater than [current].
  static bool _isNewer(String remote, String current) {
    try {
      final r = remote.split('.').map(int.parse).toList();
      final c = current.split('.').map(int.parse).toList();
      // Pad shorter list with zeros
      while (r.length < 3) {
        r.add(0);
      }
      while (c.length < 3) {
        c.add(0);
      }
      for (int i = 0; i < 3; i++) {
        if (r[i] > c[i]) return true;
        if (r[i] < c[i]) return false;
      }
      return false; // equal
    } catch (_) {
      return false;
    }
  }

  /// Fetches releases.json and returns [UpdateInfo] if a newer version exists,
  /// or null if already up-to-date or on any error (network, parsing, etc.).
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "1.2.0"

      final response = await http
          .get(Uri.parse(_releasesUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        debugPrint('UpdateChecker: unexpected status ${response.statusCode}');
        return null;
      }

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      final info = UpdateInfo.fromJson(json);

      if (_isNewer(info.version, currentVersion)) {
        return info;
      }
      return null;
    } catch (e) {
      debugPrint('UpdateChecker: check failed – $e');
      return null;
    }
  }
}
