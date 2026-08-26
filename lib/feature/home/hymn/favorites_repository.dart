import 'package:isar/isar.dart';

import 'app_initializer.dart';
import 'favorite_song.dart';

class FavoritesRepository {
  Future<void> addFavorite(String hymnId) async {
    if (hymnId.trim().isEmpty) return;

    final existing = await AppInitializer.isar.favoriteSongs
        .filter()
        .hymnIdEqualTo(hymnId)
        .findFirst();

    if (existing != null) return;

    final favorite = FavoriteSong()
      ..hymnId = hymnId
      ..createdAt = DateTime.now();

    await AppInitializer.isar.writeTxn(
      () => AppInitializer.isar.favoriteSongs.put(favorite),
    );
  }

  Future<void> removeFavorite(String hymnId) async {
    if (hymnId.trim().isEmpty) return;

    final existing = await AppInitializer.isar.favoriteSongs
        .filter()
        .hymnIdEqualTo(hymnId)
        .findFirst();

    if (existing == null) return;

    await AppInitializer.isar.writeTxn(
      () => AppInitializer.isar.favoriteSongs.delete(existing.id),
    );
  }

  Future<void> toggleFavorite(String hymnId) async {
    final isFavorite = await this.isFavorite(hymnId);
    if (isFavorite) {
      await removeFavorite(hymnId);
    } else {
      await addFavorite(hymnId);
    }
  }

  Future<bool> isFavorite(String hymnId) async {
    if (hymnId.trim().isEmpty) return false;
    final existing = await AppInitializer.isar.favoriteSongs
        .filter()
        .hymnIdEqualTo(hymnId)
        .findFirst();
    return existing != null;
  }

  Future<List<String>> getFavoriteIds() async {
    final favorites = await AppInitializer.isar.favoriteSongs.where().findAll();
    return favorites.map((favorite) => favorite.hymnId).toList();
  }

  Future<void> clearFavorites() async {
    final favorites = await AppInitializer.isar.favoriteSongs.where().findAll();
    if (favorites.isEmpty) return;

    final ids = favorites.map((favorite) => favorite.id).toList();
    await AppInitializer.isar.writeTxn(
      () => AppInitializer.isar.favoriteSongs.deleteAll(ids),
    );
  }
}
