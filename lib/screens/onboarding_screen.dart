// /lib/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foaie_prestatii_mvp/screens/home_screen/index.dart';
import 'setari/actiune_restore_aplicatie.dart';
import 'setari/sarbatori_legale.dart';
import 'setari/norma_lunara.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSavedName();
  }

  Future<void> _loadSavedName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = (prefs.getString('mechanic_name') ?? '').trim();
    if (!mounted) return;
    if (savedName.isNotEmpty && _controller.text.isEmpty) {
      _controller.text = savedName;
    }
  }

  Future<void> _continueInitialSetup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SarbatoriLegaleScreen(),
      ),
    );
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NormaLunaraScreen(),
      ),
    );
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('initial_setup_completed_v1', true);
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _controller.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introdu numele mecanicului')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mechanic_name', name);
      await prefs.setBool('initial_setup_started_v1', true);
      await prefs.setBool('initial_setup_completed_v1', false);

      if (!mounted) return;
      await _continueInitialSetup();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setare nume mecanic'),
        actions: [
          IconButton(
            tooltip: 'Restaurează datele din backup',
            icon: const Icon(Icons.restore_outlined),
            onPressed: () async {
              await showDialogRestore(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nume mecanic (exact ca pe foaie):', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Ex: Popescu Ion'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Continuă')),
          ],
        ),
      ),
    );
  }
}
