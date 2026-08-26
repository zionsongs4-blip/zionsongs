import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'favorite_song.dart';
import 'hymn_models.dart';
import 'viewlist_medley_models.dart';
import 'hymn_pin_button.dart';

class AppInitializer {
  static late Isar isar;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();

    isar = await Isar.open(
      [
        LocalHymnSchema,
        UserHymnPrefSchema,
        NoteFolderSchema,
        UserNoteSchema,
        EditProposalSchema,
        FavoriteSongSchema,

        ViewListFolderRecordSchema,
        ViewListItemRecordSchema,

        MedleyFolderRecordSchema,
        MedleyItemRecordSchema,
      ],
      directory: dir.path,
    );

    // NOTE: HymnMasterSyncService.start() is now called asynchronously
    // via AsyncInitializationService.start() after the app UI is visible.
    // This ensures offline-first behavior: local Isar opens immediately,
    // and Firestore sync happens in the background without blocking startup.

    await GlobalPinService().init();
  }
}