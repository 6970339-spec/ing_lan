class WordItem {
  const WordItem({
    required this.id,
    this.seq,
    required this.ingush,
    required this.russian,
    this.transcription,
  });

  final int id;
  final int? seq;
  final String ingush;
  final String russian;
  final String? transcription;

  @override
  String toString() {
    return 'WordItem(id: $id, seq: $seq, ingush: $ingush, russian: $russian, '
        'transcription: $transcription)';
  }
}

class ExampleItem {
  const ExampleItem({
    required this.id,
    required this.wordId,
    required this.ing,
    required this.rus,
  });

  final int id;
  final int wordId;
  final String ing;
  final String rus;

  @override
  String toString() {
    return 'ExampleItem(id: $id, wordId: $wordId, ing: $ing, rus: $rus)';
  }
}
