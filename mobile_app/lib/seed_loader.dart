import 'dart:convert';

import 'package:flutter/services.dart';

import 'app_log.dart';

class WordItem {
  const WordItem({
    required this.id,
    required this.word,
    required this.translation,
    this.transcription,
    this.example,
  });

  final int id;
  final String word;
  final String translation;
  final String? transcription;
  final String? example;

  factory WordItem.fromDynamic(Object item) {
    if (item is Map<String, dynamic>) {
      return WordItem.fromJson(item);
    }

    return WordItem(
      id: 0,
      word: jsonEncode(item),
      translation: '',
    );
  }

  factory WordItem.fromJson(Map<String, dynamic> json) {
    final Object? idValue = json['id'];
    final int parsedId;
    if (idValue is int) {
      parsedId = idValue;
    } else if (idValue is String) {
      parsedId = int.tryParse(idValue) ?? 0;
    } else {
      parsedId = 0;
    }

    String readString(String key) {
      final Object? value = json[key];
      if (value == null) {
        return '';
      }
      return value.toString();
    }

    String? readNullable(String key) {
      final Object? value = json[key];
      if (value == null) {
        return null;
      }
      final String asString = value.toString();
      return asString.isEmpty ? null : asString;
    }

    final String wordValue = readString('word');
    final String translationValue = readString('translation');
    if (wordValue.isEmpty || translationValue.isEmpty) {
      return WordItem(
        id: parsedId,
        word: jsonEncode(json),
        translation: '',
        transcription: readNullable('transcription'),
        example: readNullable('example'),
      );
    }

    return WordItem(
      id: parsedId,
      word: wordValue,
      translation: translationValue,
      transcription: readNullable('transcription'),
      example: readNullable('example'),
    );
  }
}

class ExampleItem {
  const ExampleItem({
    required this.id,
    required this.text,
    this.translation,
    this.wordId,
    this.wordValue,
    this.linkField,
  });

  final int id;
  final String text;
  final String? translation;
  final int? wordId;
  final String? wordValue;
  final String? linkField;

  factory ExampleItem.fromDynamic(Object item) {
    if (item is Map<String, dynamic>) {
      return ExampleItem.fromJson(item);
    }

    return ExampleItem(
      id: 0,
      text: jsonEncode(item),
    );
  }

  factory ExampleItem.fromJson(Map<String, dynamic> json) {
    int readInt(String key) {
      final Object? value = json[key];
      if (value is int) {
        return value;
      }
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }

    int? readNullableInt(String key) {
      final Object? value = json[key];
      if (value is int) {
        return value;
      }
      if (value is String) {
        return int.tryParse(value);
      }
      return null;
    }

    String? readNullableString(String key) {
      final Object? value = json[key];
      if (value == null) {
        return null;
      }
      final String stringValue = value.toString();
      return stringValue.isEmpty ? null : stringValue;
    }

    final List<String> linkCandidates = <String>[
      'word_id',
      'wordId',
      'wordID',
      'wordid',
      'word_ref',
      'word_fk',
    ];
    String? linkField;
    int? linkedId;
    for (final String candidate in linkCandidates) {
      final int? candidateId = readNullableInt(candidate);
      if (candidateId != null) {
        linkField = candidate;
        linkedId = candidateId;
        break;
      }
    }

    final String? ing = readNullableString('ing');
    final String? example = readNullableString('example');
    final String? text = readNullableString('text');
    final String? sentence = readNullableString('sentence');
    final String? rus = readNullableString('rus');

    final String resolvedText =
        ing ?? example ?? text ?? sentence ?? jsonEncode(json);
    final String? resolvedTranslation = rus ?? readNullableString('translation');

    return ExampleItem(
      id: readInt('id'),
      text: resolvedText,
      translation: resolvedTranslation,
      wordId: linkedId,
      wordValue: readNullableString('word'),
      linkField: linkField,
    );
  }
}

class SeedData {
  const SeedData({
    required this.words,
    required this.examples,
  });

  final List<WordItem> words;
  final List<ExampleItem> examples;
}

class SeedLoader {
  const SeedLoader();

  Future<SeedData> loadData() async {
    try {
      final List<Object?> wordsPayload =
          await _loadItemsFromAsset('assets/db/words.json');
      final List<Object?> examplesPayload =
          await _loadItemsFromAsset('assets/db/examples.json');

      List<Object?> seedPayload = <Object?>[];
      String? seedSourceTable;
      if (wordsPayload.isEmpty && examplesPayload.isEmpty) {
        final SeedPayload seedData =
            await _loadSeedPayload('assets/db/seed.json');
        seedPayload = seedData.items;
        seedSourceTable = seedData.sourceTable;
      }

      final List<Object?> resolvedWords = wordsPayload.isNotEmpty
          ? wordsPayload
          : (seedSourceTable == null || seedSourceTable == 'words')
              ? seedPayload
              : <Object?>[];
      final List<Object?> resolvedExamples = examplesPayload.isNotEmpty
          ? examplesPayload
          : seedSourceTable == 'examples'
              ? seedPayload
              : <Object?>[];

      if (resolvedWords.isEmpty && resolvedExamples.isEmpty) {
        await AppLog.instance.add(
          'SeedLoader: no words/examples items found.',
        );
        return const SeedData(words: <WordItem>[], examples: <ExampleItem>[]);
      }

      final List<WordItem> words = resolvedWords
          .whereType<Object>()
          .map(WordItem.fromDynamic)
          .toList(growable: false);
      final List<ExampleItem> examples = resolvedExamples
          .whereType<Object>()
          .map(ExampleItem.fromDynamic)
          .toList(growable: false);
      await AppLog.instance.add(
        'SeedLoader: loaded ${words.length} words'
        '${seedSourceTable == null ? '' : ' from $seedSourceTable'}'
        ' and ${examples.length} examples.',
      );
      return SeedData(words: words, examples: examples);
    } catch (error, stackTrace) {
      await AppLog.instance.add(
        'SeedLoader: failed to load seed.json',
        error: error,
        stackTrace: stackTrace,
      );
      return const SeedData(words: <WordItem>[], examples: <ExampleItem>[]);
    }
  }

  Future<List<WordItem>> loadWords() async {
    final SeedData data = await loadData();
    return data.words;
  }

  Future<List<Object?>> _loadItemsFromAsset(String path) async {
    try {
      final String raw = await rootBundle.loadString(path);
      final SeedPayload payload = _decodePayload(raw);
      if (payload.items.isNotEmpty) {
        await AppLog.instance.add(
          'SeedLoader: loaded ${payload.items.length} items from $path.',
        );
      }
      return payload.items;
    } catch (error, stackTrace) {
      await AppLog.instance.add(
        'SeedLoader: failed to load $path',
        error: error,
        stackTrace: stackTrace,
      );
      return <Object?>[];
    }
  }

  Future<SeedPayload> _loadSeedPayload(String path) async {
    try {
      final String raw = await rootBundle.loadString(path);
      final SeedPayload payload = _decodePayload(raw);
      if (payload.items.isNotEmpty) {
        await AppLog.instance.add(
          'SeedLoader: loaded ${payload.items.length} items from $path'
          '${payload.sourceTable == null ? '' : ' (${payload.sourceTable})'}.',
        );
      }
      return payload;
    } catch (error, stackTrace) {
      await AppLog.instance.add(
        'SeedLoader: failed to load $path',
        error: error,
        stackTrace: stackTrace,
      );
      return const SeedPayload(items: <Object?>[]);
    }
  }

  SeedPayload _decodePayload(String raw) {
    final Object decoded = jsonDecode(raw);
    if (decoded is List) {
      return SeedPayload(items: decoded);
    }
    if (decoded is Map<String, dynamic>) {
      final Object? payload = decoded['items'];
      final Object? source = decoded['source_table'];
      return SeedPayload(
        items: payload is List ? payload : <Object?>[],
        sourceTable: source?.toString(),
      );
    }
    return const SeedPayload(items: <Object?>[]);
  }
}

class SeedPayload {
  const SeedPayload({
    required this.items,
    this.sourceTable,
  });

  final List<Object?> items;
  final String? sourceTable;
}
