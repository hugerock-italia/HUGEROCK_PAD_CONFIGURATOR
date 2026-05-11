import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_checker.dart';

/// Shows a non-blocking dialog informing the user about an available update.
///
/// Tapping "Aggiorna ora" opens [UpdateInfo.apkUrl] in the external browser.
/// Tapping "Più tardi" dismisses the dialog without any action.
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext ctx) {
      return AlertDialog(
        title: const Text('Aggiornamento disponibile'),
        content: Text(
          'Versione ${info.version} disponibile.\n\n${info.releaseNotes}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Più tardi'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final uri = Uri.parse(info.apkUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Aggiorna ora'),
          ),
        ],
      );
    },
  );
}
