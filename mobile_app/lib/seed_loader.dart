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

class SeedLoader {
  const SeedLoader();

  Future<List<WordItem>> loadWords() async {
    try {
      final String raw = await rootBundle.loadString(
        'assets/db/seed.json',
      );
      final Object decoded = jsonDecode(raw);
      List<Object?> items = <Object?>[];
      String? sourceTable;
      if (decoded is Map<String, dynamic>) {
        final Object? payload = decoded['items'];
        if (payload is List) {
          items = payload;
        }
        final Object? source = decoded['source_table'];
        if (source != null) {
          sourceTable = source.toString();
        }
      } else if (decoded is List) {
        items = decoded;
      }

      if (items.isEmpty) {
        await AppLog.instance.add(
          'SeedLoader: JSON payload contains no items.',
          error: decoded.runtimeType,
        );
        return <WordItem>[];
      }

      final List<WordItem> words = items
          .whereType<Object>()
          .map(WordItem.fromDynamic)
          .toList(growable: false);
      await AppLog.instance.add(
        'SeedLoader: loaded ${words.length} items'
        '${sourceTable == null ? '' : ' from $sourceTable'}.',
      );
      return words;
    } catch (error, stackTrace) {
      await AppLog.instance.add(
        'SeedLoader: failed to load seed.json',
        error: error,
        stackTrace: stackTrace,
      );
      return <WordItem>[];
    }
  }
}
