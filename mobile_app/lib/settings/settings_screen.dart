import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_log.dart';
import '../words/favorites_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FavoritesStore _favoritesStore = FavoritesStore();
  String? _versionLabel;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (!mounted) {
        return;
      }
      setState(() {
        _versionLabel = '${info.version}+${info.buildNumber}';
      });
    } catch (error, stackTrace) {
      await AppLog.instance.e(
        'Settings: failed to load app version.',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _versionLabel = 'unknown';
      });
    }
  }

  Future<void> _clearFavorites() async {
    await _favoritesStore.load();
    await _favoritesStore.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Избранное очищено')),
      );
    }
  }

  Future<void> _clearLogs() async {
    await AppLog.instance.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Логи очищены')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Очистить избранное'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _clearFavorites,
          ),
          const Divider(),
          ListTile(
            title: const Text('Очистить логи'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _clearLogs,
          ),
          const Divider(),
          ListTile(
            title: const Text('О приложении'),
            subtitle: Text('Версия: ${_versionLabel ?? '...'}'),
          ),
        ],
      ),
    );
  }
}
