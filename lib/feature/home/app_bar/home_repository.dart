import '../home_models.dart';
import '../controller/home_filter.dart' show TempoRange;

/// ===============================================================
/// HomeRepository
/// ---------------------------------------------------------------
///
/// OFFLINE FIRST
///
/// Home UI never talks directly to:
/// • Isar
/// • Firestore
/// • Sync Queue
///
/// Everything goes through this repository.
/// ===============================================================

abstract class HomeRepository {
  // ============================================================
  // HOME LIST
  // ============================================================

  Future<List<HomeHymn>> getAllHymns();

  Future<List<HomeHymn>> search({
    String keyword = '',
    Set<String> keys = const {},
    Set<String> dedicated = const {},
    Set<int> years = const {},
    Set<TempoRange> tempoRanges = const {},
    String? alphabet,
    HomeTab tab = HomeTab.allHymns,
  });

  // ============================================================
  // FAVORITES
  // ============================================================

  Future<void> addToFavorites(List<String> hymnIds);

  Future<void> removeFromFavorites(List<String> hymnIds);

  // ============================================================
  // VIEW LIST
  // ============================================================

  Future<void> addToViewList({
    required List<String> hymnIds,
    required String viewListId,
  });

  Future<List<HomeViewList>> getAllViewLists();

  // ============================================================
  // MEDLEY
  // ============================================================

  Future<void> addToMedley({
    required List<String> hymnIds,
    required String medleyId,
  });

  Future<List<HomeMedley>> getAllMedleys();

  // ============================================================
  // FILTER DATA
  // ============================================================

  Future<List<String>> getAvailableKeys();

  Future<List<String>> getAvailableDedicated();

  Future<List<int>> getAvailableYears();

  Future<List<TempoRange>> getAvailableTempoRanges();

  // ============================================================
  // EXPORT
  // ============================================================

  Future<String> exportPdf(List<String> hymnIds);

  Future<void> sharePdf(List<String> hymnIds);

  // ============================================================
  // IMPORT / EXPORT
  // ============================================================

  Future<void> importExcel();

  Future<void> exportExcel();

  // ============================================================
  // SETTINGS
  // ============================================================

  Future<void> changeTheme();

  Future<void> invertTheme();

  Future<void> presentationMode();

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  Future<void> openNotifications();

  // ============================================================
  // SETTINGS
  // ============================================================

  Future<void> openSettings();

  // ============================================================
  // STATISTICS
  // ============================================================

  Future<void> openStatistics();

  // ============================================================
  // HELP
  // ============================================================

  Future<void> openHelp();

  Future<void> sendFeedback();

  Future<void> openAbout();
}
