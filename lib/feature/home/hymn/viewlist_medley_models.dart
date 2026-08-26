import 'package:isar/isar.dart';

import 'hymn_models.dart';

part 'viewlist_medley_models.g.dart';

int _now() => DateTime.now().millisecondsSinceEpoch;

// ===============================================================
// View List Folder
// ===============================================================

@collection
class ViewListFolderRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String folderId;

  late String name;

  String? parentId;

  late String userId;

  int depth = 0;

  int createdOn = _now();

  int modifiedOn = _now();

  int? lastSyncedOn;

  @enumerated
  SyncStatus syncStatus = SyncStatus.local;

  int version = 1;
}

// ===============================================================
// View List Item
// ===============================================================

@collection
class ViewListItemRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String itemId;

  @Index()
  late String folderId;

  @Index()
  late String hymnId;

  late String userId;

  int sortOrder = 0;

  int createdOn = _now();

  int modifiedOn = _now();

  int? lastSyncedOn;

  @enumerated
  SyncStatus syncStatus = SyncStatus.local;

  int version = 1;
}

// ===============================================================
// Medley Folder
// ===============================================================

@collection
class MedleyFolderRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String folderId;

  late String name;

  String? parentId;

  late String userId;

  int depth = 0;

  int createdOn = _now();

  int modifiedOn = _now();

  int? lastSyncedOn;

  @enumerated
  SyncStatus syncStatus = SyncStatus.local;

  int version = 1;
}

// ===============================================================
// Medley Item
// ===============================================================

@collection
class MedleyItemRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String itemId;

  @Index()
  late String folderId;

  @Index()
  late String hymnId;

  late String userId;

  int sortOrder = 0;

  /// Optional manual key override for this hymn inside this medley.
  String? manualKey;

  int createdOn = _now();

  int modifiedOn = _now();

  int? lastSyncedOn;

  @enumerated
  SyncStatus syncStatus = SyncStatus.local;

  int version = 1;
}