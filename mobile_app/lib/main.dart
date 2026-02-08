import 'dart:async';

import 'package:flutter/material.dart';

import 'app_log.dart';
import 'logs/logs_screen.dart';
import 'settings/settings_screen.dart';
import 'training/training_screen.dart';
import 'words/words_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLog.initialize();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLog.instance.add(
      'FlutterError: ${details.exceptionAsString()}',
      stackTrace: details.stack,
    );
    AppLog.instance.markCrash();
  };

  runZonedGuarded(
    () {
      runApp(const IngTrainerApp());
    },
    (Object error, StackTrace stackTrace) {
      AppLog.instance.add(
        'Unhandled error: $error',
        stackTrace: stackTrace,
      );
      AppLog.instance.markCrash();
    },
  );
}

class IngTrainerApp extends StatelessWidget {
  const IngTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IngTrainer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IngTrainer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('IngTrainer'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const LogsScreen(),
                  ),
                );
              },
              child: const Text('Логи'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const WordsScreen(),
                  ),
                );
              },
              child: const Text('Слова'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        const TrainingScreen(),
                  ),
                );
              },
              child: const Text('Тренировка'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const WordsScreen(
                      initialFavoritesOnly: true,
                    ),
                  ),
                );
              },
              child: const Text('Избранное'),
            ),
          ],
        ),
      ),
    );
  }
}
