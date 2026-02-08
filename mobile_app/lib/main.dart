import 'dart:async';

import 'package:flutter/material.dart';

import 'app_log.dart';
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

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLog.instance,
      builder: (BuildContext context, Widget? child) {
        final List<String> lines = AppLog.instance.lines;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Логи'),
          ),
          body: Column(
            children: [
              if (AppLog.instance.previousCrash)
                MaterialBanner(
                  content: const Text(
                    'Предыдущее завершение было некорректным',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                      },
                      child: const Text('Ок'),
                    ),
                  ],
                ),
              Expanded(
                child: lines.isEmpty
                    ? const Center(child: Text('Лог пуст'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: lines.length,
                        itemBuilder: (BuildContext context, int index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(lines[index]),
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await AppLog.instance.copyToClipboard();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Логи скопированы'),
                                ),
                              );
                            }
                          },
                          child: const Text('Копировать'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await AppLog.instance.clear();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Логи очищены'),
                                ),
                              );
                            }
                          },
                          child: const Text('Очистить'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
