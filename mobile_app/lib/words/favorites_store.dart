import 'package:shared_preferences/shared_preferences.dart';

import '../app_log.dart';

class FavoritesStore {
  static const String _prefsKey = 'favorites_word_ids';

  Set<String> _favoriteIds = <String>{};
  bool _loaded = false;

  Set<String> get favoriteIds => _favoriteIds;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _favoriteIds = prefs.getStringList(_prefsKey)?.toSet() ?? <String>{};
    _loaded = true;
  }

  Future<bool> toggle(String id) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool isFavorite;
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
      isFavorite = false;
    } else {
      _favoriteIds.add(id);
      isFavorite = true;
    }
    await prefs.setStringList(_prefsKey, _favoriteIds.toList());
    await AppLog.instance.add('Favorites: toggle $id => $isFavorite');
    return isFavorite;
  }

  bool isFavorite(String id) => _favoriteIds.contains(id);

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _favoriteIds = <String>{};
    await prefs.remove(_prefsKey);
    await AppLog.instance.add('Favorites: cleared');
  }
}
