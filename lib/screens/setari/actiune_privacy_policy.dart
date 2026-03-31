// /lib/screens/setari/actiune_privacy_policy.dart

import 'package:flutter/material.dart';

import 'package:foaie_prestatii_mvp/privacy_policy_text.dart';

Future<void> showDialogPrivacyPolicy(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final screenSize = MediaQuery.of(ctx).size;

      return AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: screenSize.width * 0.04,
          vertical: screenSize.height * 0.015,
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        title: Text(
          'Privacy Policy ($privacyPolicyVersion)',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(ctx).textTheme.titleSmall,
        ),
        content: SizedBox(
          width: screenSize.width * 0.92,
          height: screenSize.height * 0.84,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                privacyPolicyTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Versiune politică: $privacyPolicyVersion',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              Text(
                privacyPolicyEffectiveDate,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              Text.rich(
                TextSpan(
                  style: Theme.of(ctx).textTheme.bodySmall,
                  children: const [
                    TextSpan(text: 'Creator/Dezvoltator: '),
                    TextSpan(
                      text: 'bitzy',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: ' - (în măsura aplicabilă)'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                privacyPolicyContact,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: SelectableText(
                      privacyPolicyText,
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Închide'),
          ),
        ],
      );
    },
  );
}
