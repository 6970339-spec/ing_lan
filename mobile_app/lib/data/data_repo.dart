import 'dart:convert';

import 'package:flutter/services.dart';

import '../app_log.dart';
import 'models.dart';

class DataRepo {
  const DataRepo();

  Future<List<WordItem>> loadWords() async {
    final List<WordItem> words = await _loadItems(
      path: 'assets/db/words.json',
      mapper: _mapWord,
    );
    await _logLoaded('words', words);
    final List<Object?> items = await _loadItems('assets/db/words.json');
    _logKeysFromFirstItem('words', items);
    if (items.isEmpty) {
      return <WordItem>[];
    }
    final List<WordItem> words =
        items.map(WordItem.fromDynamic).toList(growable: false);
    await AppLog.instance.add('DataRepo: loaded ${words.length} words.');
    return words;
  }

  Future<List<ExampleItem>> loadExamples() async {
    final List<ExampleItem> examples = await _loadItems(
      path: 'assets/db/examples.json',
      mapper: _mapExample,
    );
    await _logLoaded('examples', examples);
    return examples;
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
      await AppLog.instance.add(
        'DataRepo: unexpected JSON payload for $path.',
        error: decoded.runtimeType,
      );
      return <T>[];
    final List<Object?> items = await _loadItems('assets/db/examples.json');
    _logKeysFromFirstItem('examples', items);
    _logExampleLinkCandidates(items);
    if (items.isEmpty) {
      return <ExampleItem>[];
    }
    final List<ExampleItem> examples =
        items.map(ExampleItem.fromDynamic).toList(growable: false);
    await AppLog.instance.add('DataRepo: loaded ${examples.length} examples.');
    return examples;
  }

  Future<List<Object?>> _loadItems(String path) async {
    try {
      final String raw = await rootBundle.loadString(path);
      final Object decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded;
      }
      if (decoded is Map<String, dynamic>) {
        final Object? payload = decoded['items'];
        if (payload is List) {
          return payload;
        }
      }
      await AppLog.instance.add(
        'DataRepo: unexpected JSON shape in $path.',
        error: decoded.runtimeType,
      );
      return <Object?>[];
    } catch (error, stackTrace) {
      await AppLog.instance.add(
        'DataRepo: failed to load $path',
        error: error,
        stackTrace: stackTrace,
      );
      return <T>[];
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
      return <Object?>[];
    }
  }

  void _logKeysFromFirstItem(String label, List<Object?> items) {
    if (items.isEmpty) {
      return;
    }
    final Object? first = items.first;
    if (first is Map<String, dynamic>) {
      final List<String> keys = first.keys.toList()..sort();
      AppLog.instance.add('DataRepo: $label keys = $keys');
    }
  }

  void _logExampleLinkCandidates(List<Object?> items) {
    if (items.isEmpty) {
      return;
    }
    final List<Map<String, dynamic>> maps =
        items.whereType<Map<String, dynamic>>().toList();
    if (maps.isEmpty) {
      return;
    }
    const List<String> candidates = <String>[
      'word_id',
      'wordId',
      'id_word',
      'wordID',
      'wordid',
      'word_ref',
      'word_fk',
    ];
    for (final String candidate in candidates) {
      final List<String> values = maps
          .map((Map<String, dynamic> item) => item[candidate])
          .where((Object? value) => value != null)
          .take(5)
          .map((Object? value) => value.toString())
          .toList();
      if (values.isNotEmpty) {
        AppLog.instance.add(
          'DataRepo: example link values for $candidate: $values',
        );
      }
    }
  }
}
