import 'dart:convert';

import 'package:flutter/services.dart';

import '../app_log.dart';
import 'models.dart';

class DataRepo {
  DataRepo._();

  static final DataRepo instance = DataRepo._();

  List<WordItem>? _wordsCache;
  Map<int, List<ExampleItem>>? _examplesByWordId;

  Future<List<WordItem>> getWords() async {
    if (_wordsCache != null) {
      return _wordsCache!;
    }
    try {
      final List<WordItem> words = await _loadItems(
        path: 'assets/db/words.json',
        mapper: _mapWord,
      );
      await _logLoaded('words', words);
      _wordsCache = words;
      return words;
    } catch (error, stackTrace) {
      await AppLog.instance.e(
        'DataRepo: failed to load words.',
        error: error,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to load words dataset.');
    }
  }

  Future<List<ExampleItem>> getExamplesForWord(int wordId) async {
    if (_examplesByWordId == null) {
      await _loadExamplesIndex();
    }
    return _examplesByWordId![wordId] ?? <ExampleItem>[];
  }

  Future<List<T>> _loadItems<T>({
    required String path,
    required T Function(Map<String, dynamic> json) mapper,
  }) async {
    try {
      final String raw = await rootBundle.loadString(path);
      final Object decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final Object? items = decoded['items'];
        if (items is List) {
          return items
              .whereType<Map<String, dynamic>>()
              .map(mapper)
              .toList(growable: false);
        }
      }
      await AppLog.instance.e(
        'DataRepo: unexpected JSON payload for $path.',
        error: decoded.runtimeType,
      );
      throw Exception('Unexpected JSON payload for $path.');
    } catch (error, stackTrace) {
      await AppLog.instance.e(
        'DataRepo: failed to load $path',
        error: error,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to load dataset from $path.');
    }
  }

  Future<void> _loadExamplesIndex() async {
    try {
      final List<ExampleItem> examples = await _loadItems(
        path: 'assets/db/examples.json',
        mapper: _mapExample,
      );
      await _logLoaded('examples', examples);
      final Map<int, List<ExampleItem>> index = <int, List<ExampleItem>>{};
      for (final ExampleItem example in examples) {
        index.putIfAbsent(example.wordId, () => <ExampleItem>[]).add(example);
      }
      _examplesByWordId = index;
    } catch (error, stackTrace) {
      await AppLog.instance.e(
        'DataRepo: failed to load examples.',
        error: error,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to load examples dataset.');
    }
  }

  Future<void> _logLoaded<T>(String label, List<T> items) async {
    if (items.isEmpty) {
      await AppLog.instance.add('DataRepo: loaded 0 $label.');
      return;
    }
    final String first = items.isNotEmpty ? items.first.toString() : 'n/a';
    final String? second = items.length > 1 ? items[1].toString() : null;
    await AppLog.instance.add(
      'DataRepo: loaded ${items.length} $label. first=$first'
      '${second == null ? '' : ', second=$second'}',
    );
  }

  WordItem _mapWord(Map<String, dynamic> json) {
    return WordItem(
      id: _readInt(json['id']),
      seq: _readNullableInt(json['seq']),
      ingush: _readString(json['ingush']),
      russian: _readString(json['russian']),
      transcription: _readNullableString(json['transcription']),
    );
  }

  ExampleItem _mapExample(Map<String, dynamic> json) {
    return ExampleItem(
      id: _readInt(json['id']),
      wordId: _readInt(json['word_id']),
      ing: _readString(json['ing']),
      rus: _readString(json['rus']),
    );
  }

  int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  int? _readNullableInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  String _readString(Object? value) {
    if (value == null) {
      return '';
    }
    return value.toString();
  }

  String? _readNullableString(Object? value) {
    if (value == null) {
      return null;
    }
    final String resolved = value.toString();
    return resolved.isEmpty ? null : resolved;
  }
}
