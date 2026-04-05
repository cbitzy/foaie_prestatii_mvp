// /lib/screens/home_screen/home_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../Adauga_modifica_serviciu/adauga_modifica_serviciu.dart';
import '../afisare_program/afisare_program_screen.dart';
import '../monthly_report_by_train_screen.dart';

import '../setari/dialog_setari.dart';
import 'header_appbar.dart';
import 'sectiune_butoane.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _name = '';
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadName();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = 'Version ${info.version}+${info.buildNumber}';
    });
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _name = prefs.getString('mechanic_name') ?? '';
    });
  }

  Future<void> _openSetari() async {
    await showDialogSetari(
      context,
      appVersion: _appVersion,
      onNameChanged: _loadName, // reîncarcă numele după salvare
    );
  }

  void _openRaportLunar() {
    final now = DateTime.now();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MonthlyReportByTrainScreen(
          year: now.year,
          month: now.month,
        ),
      ),
    );
  }

  void _openAfisareProgram() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AfisareProgramScreen()),
    );
  }

  Future<void> _openAdaugaModifica() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdaugaModificaServiciuScreen()),
    );
  }

  Future<void> _closeApp() async {
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 100,
        title: HomeAppBarTitle(
          name: _name,
          onOpenSettings: _openSetari,
          onOpenRaport: _openRaportLunar,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _closeApp,
        child: const Icon(Icons.power_settings_new),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SectiuneButoane(
              onOpenAfisareProgram: _openAfisareProgram,
              onOpenAdaugaModifica: _openAdaugaModifica,
            ),
          ),
        ),
      ),
    );
  }
}
