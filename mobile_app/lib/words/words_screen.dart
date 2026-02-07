import 'package:flutter/material.dart';

import '../app_log.dart';
import '../seed_loader.dart';

class WordsScreen extends StatefulWidget {
  const WordsScreen({super.key});

  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends State<WordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SeedLoader _seedLoader = const SeedLoader();
  List<WordItem> _items = <WordItem>[];
  bool _loading = true;

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
    final List<WordItem> loaded = await _seedLoader.loadWords();
    if (!mounted) {
      return;
    }
    setState(() {
      _items = loaded;
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
    if (query.isEmpty) {
      return _items;
    }
    return _items.where((WordItem item) {
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
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) =>
                                      WordDetailScreen(item: item),
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

class WordDetailScreen extends StatelessWidget {
  const WordDetailScreen({super.key, required this.item});

  final WordItem item;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
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
        ],
      ),
    );
  }
}
