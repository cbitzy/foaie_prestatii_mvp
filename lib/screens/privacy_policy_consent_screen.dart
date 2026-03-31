// /lib/screens/privacy_policy_consent_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:foaie_prestatii_mvp/privacy_policy_text.dart';
import 'package:foaie_prestatii_mvp/screens/home_screen/index.dart';
import 'package:foaie_prestatii_mvp/screens/onboarding_screen.dart';
class PrivacyPolicyConsentScreen extends StatefulWidget {
  final bool initialShowOnboarding;

  const PrivacyPolicyConsentScreen({
    super.key,
    required this.initialShowOnboarding,
  });

  @override
  State<PrivacyPolicyConsentScreen> createState() =>
      _PrivacyPolicyConsentScreenState();
}

class _PrivacyPolicyConsentScreenState extends State<PrivacyPolicyConsentScreen> {
  bool isSaving = false;
  final ScrollController scrollController = ScrollController();
  bool actionsUnlocked = false;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_handleScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScrollUnlock();
    });
  }

  void _handleScroll() {
    if (actionsUnlocked) {
      return;
    }
    _checkScrollUnlock();
  }

  void _checkScrollUnlock() {
    if (!scrollController.hasClients || actionsUnlocked) {
      return;
    }

    final position = scrollController.position;
    final bool reachedBottom =
        position.maxScrollExtent <= 0 ||
            position.pixels >= position.maxScrollExtent - 8;

    if (reachedBottom && mounted) {
      setState(() => actionsUnlocked = true);
    }
  }

  Future<void> acceptPolicy() async {
    if (isSaving) return;
    setState(() => isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(privacyPolicyAcceptedKey, true);
      await prefs.setString(
        privacyPolicyAcceptedVersionKey,
        privacyPolicyVersion,
      );
      await prefs.setString(
        privacyPolicyAcceptedAtKey,
        DateTime.now().toUtc().toIso8601String(),
      );

      if (!mounted) return;

      final Widget next = widget.initialShowOnboarding
          ? const OnboardingScreen()
          : const HomeScreen();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => next),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  void refusePolicy() {
    SystemNavigator.pop();
  }

  @override
  void dispose() {
    scrollController.removeListener(_handleScroll);
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Privacy Policy ($privacyPolicyVersion)'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    privacyPolicyTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Versiune politică: $privacyPolicyVersion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    privacyPolicyEffectiveDate,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text.rich(
                    TextSpan(
                      style: Theme.of(context).textTheme.bodySmall,
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
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: const SelectableText(
                  privacyPolicyText,
                  textAlign: TextAlign.start,
                ),
              ),
            ),
            if (actionsUnlocked) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSaving ? null : refusePolicy,
                        child: const Text('Refuză'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: isSaving ? null : acceptPolicy,
                        child: Text(isSaving ? 'Se salvează...' : 'Acceptă'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
