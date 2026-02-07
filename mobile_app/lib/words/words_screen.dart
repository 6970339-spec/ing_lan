import 'package:flutter/material.dart';

import '../app_log.dart';
import '../data/data_repo.dart';
import '../data/models.dart';
import 'favorites_store.dart';

class WordsScreen extends StatefulWidget {
  const WordsScreen({super.key});

  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends State<WordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DataRepo _dataRepo = const DataRepo();
  final FavoritesStore _favoritesStore = FavoritesStore();
  List<WordItem> _items = <WordItem>[];
  List<ExampleItem> _examples = <ExampleItem>[];
  bool _loading = true;
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    await _favoritesStore.load();
    final List<WordItem> words = await _dataRepo.loadWords();
    final List<ExampleItem> examples = await _dataRepo.loadExamples();
    if (!mounted) {
      return;
    }
    setState(() {
      _items = words;
      _examples = examples;
      _loading = false;
    });
  }

  void _onSearchChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  List<WordItem> _filteredItems() {
    final String query = _searchController.text.trim().toLowerCase();
    return _items.where((WordItem item) {
      if (_favoritesOnly &&
          !_favoritesStore.isFavorite(item.id.toString())) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final String word = item.word.toLowerCase();
      final String translation = item.translation.toLowerCase();
      final String transcription = item.transcription?.toLowerCase() ?? '';
      return word.contains(query) ||
          translation.contains(query) ||
          transcription.contains(query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final List<WordItem> filtered = _filteredItems();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Слова'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Поиск',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Только избранное'),
            value: _favoritesOnly,
            onChanged: (bool value) {
              setState(() {
                _favoritesOnly = value;
              });
            },
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text('Нет слов'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 24),
                        itemBuilder: (BuildContext context, int index) {
                          final WordItem item = filtered[index];
                          return ListTile(
                            title: Text(item.word.isEmpty ? '—' : item.word),
                            subtitle: Text(
                              item.translation.isEmpty
                                  ? 'Нет перевода'
                                  : item.translation,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _favoritesStore
                                            .isFavorite(item.id.toString())
                                        ? Icons.star
                                        : Icons.star_border,
                                  ),
                                  onPressed: () async {
                                    await _favoritesStore.toggle(
                                      item.id.toString(),
                                    );
                                    if (mounted) {
                                      setState(() {});
                                    }
                                  },
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                      builder: (BuildContext context) =>
                                      WordDetailScreen(
                                        item: item,
                                        examples: _examples,
                                        favoritesStore: _favoritesStore,
                                        onToggle: () {
                                          setState(() {});
                                        },
                                      ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class WordDetailScreen extends StatefulWidget {
  const WordDetailScreen({
    super.key,
    required this.item,
    required this.examples,
    required this.favoritesStore,
    required this.onToggle,
  });

  final WordItem item;
  final List<ExampleItem> examples;
  final FavoritesStore favoritesStore;
  final VoidCallback onToggle;

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  bool get _isFavorite =>
      widget.favoritesStore.isFavorite(widget.item.id.toString());
  List<ExampleItem> _linkedExamples = <ExampleItem>[];
  String? _linkFieldUsed;

  @override
  void initState() {
    super.initState();
    _linkedExamples = widget.examples
        .where(
          (ExampleItem example) =>
              example.wordId == widget.item.id ||
              (example.wordValue != null &&
                  example.wordValue == widget.item.word),
        )
        .toList(growable: false);
    _linkFieldUsed = _linkedExamples
        .map((ExampleItem example) => example.linkField)
        .firstWhere(
          (String? value) => value != null && value.isNotEmpty,
          orElse: () => null,
        );
    AppLog.instance.add(
      _linkFieldUsed == null
          ? 'WordDetail: link field not found for examples.'
          : 'WordDetail: linked examples by $_linkFieldUsed.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final WordItem item = widget.item;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Слово'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            item.word.isEmpty ? '—' : item.word,
            style: textTheme.headlineMedium,
          ),
          if (item.transcription != null) ...[
            const SizedBox(height: 8),
            Text(
              item.transcription!,
              style: textTheme.titleMedium?.copyWith(
                color: Colors.blueGrey,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            item.translation.isEmpty ? 'Нет перевода' : item.translation,
            style: textTheme.titleLarge,
          ),
          if (item.example != null) ...[
            const SizedBox(height: 24),
            Text(
              'Пример',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(item.example!),
          ],
          if (_linkedExamples.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Примеры',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._linkedExamples.map(
              (ExampleItem example) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(example.text),
                    if (example.translation != null)
                      Text(
                        example.translation!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.blueGrey,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              await AppLog.instance.add(
                'Viewed word: ${item.word} (${item.translation})',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Запись добавлена в лог'),
                  ),
                );
              }
            },
            child: const Text('Записать в лог'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              final bool nowFavorite =
                  await widget.favoritesStore.toggle(item.id.toString());
              widget.onToggle();
              if (mounted) {
                setState(() {});
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      nowFavorite ? 'В избранном' : 'Убрано из избранного',
                    ),
                  ),
                );
              }
            },
            child: Text(_isFavorite ? 'Убрать' : 'В избранное'),
          ),
        ],
      ),
    );
  }
}
