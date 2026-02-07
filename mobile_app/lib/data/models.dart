import 'dart:convert';

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

    String readString(String key) {
      final Object? value = json[key];
      if (value == null) {
        return '';
      }
      return value.toString();
    }

    String? readNullableString(String key) {
      final Object? value = json[key];
      if (value == null) {
        return null;
      }
      final String stringValue = value.toString();
      return stringValue.isEmpty ? null : stringValue;
    }

    final String wordValue = readString('word');
    final String translationValue = readString('translation');
    if (wordValue.isEmpty || translationValue.isEmpty) {
      return WordItem(
        id: readInt('id'),
        word: jsonEncode(json),
        translation: '',
        transcription: readNullableString('transcription'),
        example: readNullableString('example'),
      );
    }

    return WordItem(
      id: readInt('id'),
      word: wordValue,
      translation: translationValue,
      transcription: readNullableString('transcription'),
      example: readNullableString('example'),
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
