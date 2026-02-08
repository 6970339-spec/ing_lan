import 'package:shared_preferences/shared_preferences.dart';

import '../app_log.dart';

class FavoritesStore {
  static const String _prefsKey = 'favorites_word_ids';

  Set<int> _favoriteIds = <int>{};
  bool _loaded = false;

  Set<int> get favoriteIds => _favoriteIds;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> rawIds =
        prefs.getStringList(_prefsKey) ?? <String>[];
    _favoriteIds = rawIds
        .map((String value) => int.tryParse(value))
        .whereType<int>()
        .toSet();
    _loaded = true;
  }

  Future<bool> toggle(int id) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool isFavorite;
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
      isFavorite = false;
    } else {
      _favoriteIds.add(id);
      isFavorite = true;
    }
    await prefs.setStringList(
      _prefsKey,
      _favoriteIds.map((int value) => value.toString()).toList(),
    );
    await AppLog.instance.i(
      'Favorites: toggle $id => $isFavorite (size=${_favoriteIds.length})',
    );
    return isFavorite;
  }

  bool isFavorite(int id) => _favoriteIds.contains(id);

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _favoriteIds = <int>{};
    await prefs.remove(_prefsKey);
    await AppLog.instance.i('Favorites: cleared');
  }
}
