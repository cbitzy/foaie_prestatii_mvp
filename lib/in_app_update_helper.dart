import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Google Play in-app updates helper (Android only).
///
/// Works only if the app is installed from Google Play (including internal/closed/open testing).
class InAppUpdateHelper {
  static bool _updateFlowActive = false;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<AppUpdateInfo?> checkForUpdateSafe() async {
    if (!isAndroid) return null;
    try {
      return await InAppUpdate.checkForUpdate();
    } catch (err) {
      return null;
    }
  }

  /// Checks for updates and, if available, prompts the user:
  /// - "Update now" starts the update flow.
  /// - Immediate update is preferred when allowed by Google Play.
  /// - If immediate update is not allowed, a visible flexible update flow is used.
  /// - "Later" dismisses the prompt.
  ///
  /// If [showNoUpdateMessage] is true and no update is available, shows a simple info dialog.
  /// If the check fails and [showNoUpdateMessage] is true, shows an error dialog.
  static Future<void> checkAndPrompt({
    required BuildContext context,
    bool immediateIfAllowed = true,
    bool showNoUpdateMessage = false,
    String promptTitle = 'Actualizare disponibilă',
    String promptMessage =
    'Există o versiune nouă disponibilă în Google Play. '
        'Actualizarea va porni acum, iar aplicația se poate reporni automat după instalare. '
        'Vrei să continui?',
    String laterText = 'Mai târziu',
    String updateText = 'Actualizează',
    String noUpdateTitle = 'Actualizare',
    String noUpdateMessage = 'Ai deja ultima versiune.',
    String checkFailedTitle = 'Actualizare',
    String checkFailedMessage = 'Nu s-a putut verifica actualizarea.',
    String okText = 'OK',
  }) async {
    if (!isAndroid) return;
    if (_updateFlowActive) return;

    _updateFlowActive = true;
    try {
      AppUpdateInfo? info;
      try {
        info = await InAppUpdate.checkForUpdate();
      } catch (err) {
        if (showNoUpdateMessage) {
          if (!context.mounted) return;
          await showDialog<void>(
            context: context,
            barrierDismissible: true,
            builder: (dialogCtx) {
              return AlertDialog(
                title: Text(checkFailedTitle),
                content: Text(checkFailedMessage),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: Text(okText),
                  ),
                ],
              );
            },
          );
        }
        return;
      }

      if (info.updateAvailability ==
          UpdateAvailability.developerTriggeredUpdateInProgress) {
        if (immediateIfAllowed) {
          try {
            await InAppUpdate.performImmediateUpdate();
          } catch (err) {
            if (kDebugMode) {
              debugPrint(
                'InAppUpdate.performImmediateUpdate resume failed: $err',
              );
            }
          }
        }
        return;
      }

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        if (showNoUpdateMessage) {
          if (!context.mounted) return;
          await showDialog<void>(
            context: context,
            barrierDismissible: true,
            builder: (dialogCtx) {
              return AlertDialog(
                title: Text(noUpdateTitle),
                content: Text(noUpdateMessage),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: Text(okText),
                  ),
                ],
              );
            },
          );
        }
        return;
      }

      if (!context.mounted) return;

      String? installedVersion;
      try {
        final pkg = await PackageInfo.fromPlatform();
        installedVersion = '${pkg.version}+${pkg.buildNumber}';
      } catch (err) {
        installedVersion = null;
      }

      if (!context.mounted) return;

      final String availableVersion = info.availableVersionCode == null
          ? '-'
          : '${info.availableVersionCode}';

      final String promptMessageWithVersions =
          '$promptMessage\n\nVersiune instalată: ${installedVersion ?? '-'}\nVersiune disponibilă: $availableVersion';

      final wantsUpdate = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogCtx) {
          return AlertDialog(
            title: Text(promptTitle),
            content: Text(promptMessageWithVersions),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: Text(laterText),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: Text(updateText),
              ),
            ],
          );
        },
      );

      if (wantsUpdate != true) return;

      if (immediateIfAllowed && info.immediateUpdateAllowed) {
        try {
          final result = await InAppUpdate.performImmediateUpdate();
          if (result == AppUpdateResult.success ||
              result == AppUpdateResult.userDeniedUpdate) {
            return;
          }
        } catch (err) {
          if (kDebugMode) {
            debugPrint('InAppUpdate.performImmediateUpdate failed: $err');
          }
        }
      }

      if (info.flexibleUpdateAllowed) {
        try {
          final result = await InAppUpdate.startFlexibleUpdate();
          if (result == AppUpdateResult.userDeniedUpdate) {
            return;
          }
          if (result != AppUpdateResult.success) {
            if (!context.mounted) return;
            await showDialog<void>(
              context: context,
              barrierDismissible: true,
              builder: (dialogCtx) {
                return AlertDialog(
                  title: Text(checkFailedTitle),
                  content: const Text(
                    'Actualizarea nu a putut fi pornită acum. Încearcă din nou.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: Text(okText),
                    ),
                  ],
                );
              },
            );
            return;
          }
        } catch (err) {
          if (kDebugMode) {
            debugPrint('InAppUpdate.startFlexibleUpdate failed: $err');
          }
          return;
        }

        if (!context.mounted) return;

        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) {
            return const AlertDialog(
              title: Text('Se descarcă actualizarea'),
              content: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Actualizarea se descarcă acum. '
                          'Când este gata, instalarea pornește automat, '
                          'iar aplicația se va reporni.',
                    ),
                  ),
                ],
              ),
            );
          },
        );

        for (int i = 0; i < 240; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));

          AppUpdateInfo? polled;
          try {
            polled = await InAppUpdate.checkForUpdate();
          } catch (err) {
            polled = null;
          }

          if (polled == null) {
            continue;
          }

          if (polled.installStatus == InstallStatus.downloaded) {
            try {
              await InAppUpdate.completeFlexibleUpdate();
            } catch (err) {
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop();
                await showDialog<void>(
                  context: context,
                  barrierDismissible: true,
                  builder: (dialogCtx) {
                    return AlertDialog(
                      title: Text(checkFailedTitle),
                      content: const Text(
                        'Actualizarea a fost descărcată, dar instalarea nu a putut fi pornită.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          child: Text(okText),
                        ),
                      ],
                    );
                  },
                );
              }
              if (kDebugMode) {
                debugPrint('InAppUpdate.completeFlexibleUpdate failed: $err');
              }
            }
            return;
          }
        }

        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          await showDialog<void>(
            context: context,
            barrierDismissible: true,
            builder: (dialogCtx) {
              return AlertDialog(
                title: Text(checkFailedTitle),
                content: const Text(
                  'Actualizarea nu a putut fi finalizată acum. Încearcă din nou.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: Text(okText),
                  ),
                ],
              );
            },
          );
        }
      }
    } finally {
      _updateFlowActive = false;
    }
  }
}
