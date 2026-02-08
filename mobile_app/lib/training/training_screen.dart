import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_log.dart';
import '../data/data_repo.dart';
import '../data/models.dart';
import '../logs/logs_screen.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  static const String _knownKey = 'training_known_count';
  static const String _unknownKey = 'training_unknown_count';
  static const String _sessionsKey = 'training_total_sessions';

  static const int _sessionSize = 10;
  final DataRepo _dataRepo = DataRepo.instance;
  final Random _random = Random();

  List<WordItem> _items = <WordItem>[];
  int _index = 0;
  bool _loading = true;
  bool _showTranslation = false;
  String? _loadError;
  String? _warningMessage;

  int _knownCount = 0;
  int _unknownCount = 0;
  int _totalSessions = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _knownCount = prefs.getInt(_knownKey) ?? 0;
      _unknownCount = prefs.getInt(_unknownKey) ?? 0;
      _totalSessions = prefs.getInt(_sessionsKey) ?? 0;
      final List<WordItem> loaded = await _dataRepo.getWords();
      final List<WordItem> shuffled = List<WordItem>.from(loaded)
        ..shuffle(_random);
      final List<WordItem> sessionItems =
          shuffled.take(_sessionSize).toList(growable: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = sessionItems;
        _index = 0;
        _showTranslation = false;
        _loading = false;
        _loadError = null;
        _warningMessage = loaded.length < _sessionSize
            ? 'Доступно меньше $_sessionSize слов, используем ${loaded.length}.'
            : null;
        _totalSessions += 1;
      });
      await prefs.setInt(_sessionsKey, _totalSessions);
    } catch (error, stackTrace) {
      await AppLog.instance.add(
        'TrainingScreen: failed to load data',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items = <WordItem>[];
        _loading = false;
        _loadError = 'Данные не загружены. Проверь words.json/examples.json';
        _warningMessage = null;
      });
    }
  }

  Future<void> _saveStats() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_knownKey, _knownCount);
    await prefs.setInt(_unknownKey, _unknownCount);
  }

  Future<void> _markAnswer({required bool known}) async {
    try {
      if (known) {
        _knownCount += 1;
      } else {
        _unknownCount += 1;
      }
      await _saveStats();
      if (!mounted) {
        return;
      }
      setState(() {
        _index = min(_index + 1, _items.length);
        _showTranslation = false;
      });
    } catch (error, stackTrace) {
      await AppLog.instance.add(
        'TrainingScreen: failed to save stats',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тренировка'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _buildEmptyState(_loadError!)
              : _items.isEmpty
                  ? _buildEmptyState(
                      'Данные не загружены. Проверь words.json/examples.json',
                    )
                  : _index >= _items.length
                      ? _buildFinishedState()
                      : _buildTrainingState(),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const LogsScreen(),
                  ),
                );
              },
              child: const Text('Открыть Логи'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Сессия завершена',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text('Знаю: $_knownCount'),
            Text('Не знаю: $_unknownCount'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _load,
              child: const Text('Начать снова'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainingState() {
    final WordItem item = _items[_index];
    final int progressCurrent = _index + 1;
    final int progressTotal = _items.length;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$progressCurrent/$progressTotal',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (_warningMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _warningMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.orangeAccent,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          Text(
            item.ingush.isEmpty ? '—' : item.ingush,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          if (item.transcription != null) ...[
            const SizedBox(height: 8),
            Text(
              item.transcription!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.blueGrey,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          if (_showTranslation)
            Text(
              item.russian.isEmpty ? 'Нет перевода' : item.russian,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            )
          else
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _showTranslation = true;
                });
              },
              child: const Text('Показать перевод'),
            ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _markAnswer(known: false),
                  child: const Text('Не знаю'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: () => _markAnswer(known: true),
                  child: const Text('Знаю'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
