import 'package:isar/isar.dart';

part 'favorite_song.g.dart';

@collection
class FavoriteSong {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String hymnId;

  late DateTime createdAt;
}
