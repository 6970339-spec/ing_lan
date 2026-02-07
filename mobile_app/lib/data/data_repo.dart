import 'dart:convert';

import 'package:flutter/services.dart';

import '../app_log.dart';
import 'models.dart';

class DataRepo {
  const DataRepo();

  Future<List<WordItem>> loadWords() async {
    final List<Object?> items = await _loadItems('assets/db/words.json');
    if (items.isEmpty) {
      return <WordItem>[];
    }
    final List<WordItem> words =
        items.map(WordItem.fromDynamic).toList(growable: false);
    await AppLog.instance.add('DataRepo: loaded ${words.length} words.');
    return words;
  }

  Future<List<ExampleItem>> loadExamples() async {
    final List<Object?> items = await _loadItems('assets/db/examples.json');
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
      return <Object?>[];
    }
  }
}
