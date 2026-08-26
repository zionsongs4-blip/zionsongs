import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar/isar.dart';
import 'package:flutter/foundation.dart';

import '../hymn/app_initializer.dart';
import '../hymn/favorites_repository.dart';
import '../hymn/hymn_auth_service.dart';
import '../hymn/hymn_master_sync_service.dart';
import '../hymn/hymn_models.dart';
import '../hymn/hymn_sync_logic.dart';
import '../home_models.dart' as home;
import '../controller/home_filter.dart' show TempoRange;
import '../../home/repositories/folder_repository.dart';
import '../search/home_search_repository.dart';
import 'home_repository.dart';
import 'pdf_export_service.dart';
import 'theme_service.dart';

class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static int? parseSerialNumber(
    Object? value, {
    String? hymnId,
  }) {
    if (value is int) return value;

    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) {
      final digits = RegExp(r'\d+').allMatches(text).toList();
      if (digits.isNotEmpty) {
        final match = digits.last.group(0);
        if (match != null) {
          return int.tryParse(match);
        }
      }
    }

    if (hymnId != null) {
      final digits = RegExp(r'\d+').allMatches(hymnId).toList();
      if (digits.isNotEmpty) {
        final match = digits.last.group(0);
        if (match != null) {
          return int.tryParse(match);
        }
      }
    }

    return null;
  }

  final FirebaseFirestore _firestore;

  final FolderRepository _folderRepository = FolderRepository();
  final FavoritesRepository _favoritesRepository = FavoritesRepository();

  Future<void> _syncLater() async {
    final userId = AuthService.userId;
    if (userId.isEmpty) return;

    try {
      await SyncLogic.attemptSync(AppInitializer.isar, userId);
    } catch (_) {}
  }

  Future<void> _syncHymnsFromFirestore() async {
    await HymnMasterSyncService.start();
  }

  Future<home.HomeHymn> _convertToHomeHymn(
    LocalHymn hymn,
    int index, {
    bool favorite = false,
  }) async {
    // Try to get user's overrides
    String? key = hymn.key;
    int? tempo = hymn.tempo;
    String? dedicated = hymn.dedicated;
    String? year = hymn.year;

    try {
      final pref = await AppInitializer.isar.userHymnPrefs
          .filter()
          .hymnIdEqualTo(hymn.hymnId)
          .findFirst();

      if (pref != null) {
        key = pref.manualKey ?? key;

        tempo = pref.tempo != 0 ? pref.tempo : tempo;
      }
    } catch (_) {}

    final serialNo = parseSerialNumber(
      hymn.hymnId,
      hymnId: hymn.hymnId,
    );

    return home.HomeHymn(
      hymnId: hymn.hymnId,
      serialNo: serialNo ?? index + 1,
      pageNo: 0,
      title: hymn.title,
      favorite: favorite,
      key: key,
      dedicated: dedicated,
      year: year,
      tempo: tempo,
    );
  }

  Future<List<home.HomeHymn>> _loadLocalHymns() async {
    final localHymns = await AppInitializer.isar.localHymns.where().findAll();

    final list = <home.HomeHymn>[];
    for (final entry in localHymns.asMap().entries) {
      final h = await _convertToHomeHymn(entry.value, entry.key);
      list.add(h);
    }
    return list;
  }

  Future<List<home.HomeHymn>> _returnWithLog(List<home.HomeHymn> hymns) async {
    // ignore: avoid_print
    print('Returning hymns: ${hymns.length}');
    return hymns;
  }

  Future<List<home.HomeHymn>> _loadFavoriteHymns() async {
    final hymnIds = await _favoritesRepository.getFavoriteIds();
    if (hymnIds.isEmpty) return [];

    final favorites = await AppInitializer.isar.localHymns
        .filter()
        .anyOf(hymnIds, (q, value) => q.hymnIdEqualTo(value))
        .findAll();

    final list = <home.HomeHymn>[];
    for (final entry in favorites.asMap().entries) {
      final h = await _convertToHomeHymn(
        entry.value,
        entry.key,
        favorite: true,
      );
      list.add(h);
    }
    return list;
  }

  bool _matchesFilter(
    home.HomeHymn hymn,
    Set<String> keys,
    Set<String> dedicated,
    Set<int> years,
    Set<TempoRange> tempoRanges,
    [String? alphabet]
  ) {
    if (keys.isNotEmpty) {
      if (hymn.key == null || !keys.contains(hymn.key)) {
        return false;
      }
    }

    if (dedicated.isNotEmpty) {
      if (hymn.dedicated == null ||
          !dedicated.contains(hymn.dedicated)) {
        return false;
      }
    }

    if (years.isNotEmpty) {
      final year = hymn.year != null
          ? int.tryParse(hymn.year!)
          : null;

      if (year == null || !years.contains(year)) {
        return false;
      }
    }

    if (tempoRanges.isNotEmpty) {
      if (hymn.tempo == null ||
          !tempoRanges.any(
            (range) => range.contains(hymn.tempo!),
          )) {
        return false;
      }
    }

    if (alphabet != null && alphabet.isNotEmpty) {
      final title = hymn.title.trim();
      if (title.isEmpty) {
        return false;
      }

      final first = title[0].toUpperCase();
      if (alphabet == '#') {
        if (RegExp(r'[A-Z]').hasMatch(first)) {
          return false;
        }
      } else if (first != alphabet.toUpperCase()) {
        return false;
      }
    }

    return true;
  }

  List<home.HomeHymn> _applySearch(
    List<home.HomeHymn> hymns,
    String searchText,
  ) {
    if (searchText.isEmpty) return hymns;

    final query = searchText.toLowerCase();
    return hymns.where((hymn) {
      return hymn.title.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Future<List<home.HomeHymn>> getAllHymns() {
    return _loadLocalHymns().then((h) => _returnWithLog(h));
  }

  @override
  Future<List<home.HomeHymn>> search({
    String keyword = '',
    Set<String> keys = const {},
    Set<String> dedicated = const {},
    Set<int> years = const {},
    Set<TempoRange> tempoRanges = const {},
    String? alphabet,
    home.HomeTab tab = home.HomeTab.allHymns,
  }) async {
    // Ensuring local DB is synchronized so offline search works seamlessly.
    await _loadLocalHymns();

    List<home.HomeHymn> source;

    switch (tab) {
      case home.HomeTab.favorites:
        source = await _loadFavoriteHymns();
        break;

      case home.HomeTab.allHymns:
        source = await _loadLocalHymns();
        break;

      case home.HomeTab.viewLists:
      case home.HomeTab.medleys:
        source = [];
        break;
    }

    final filtered = source
        .where((hymn) => _matchesFilter(
              hymn,
              keys,
              dedicated,
              years,
              tempoRanges,
              alphabet,
            ))
        .toList();

    if (keyword.trim().isEmpty) {
      return filtered;
    }

    // Offline-first comprehensive search across all fields matching index rules:
    // searchText -> Hindi -> Malayalam -> English -> Title -> Serial number
    final query = normalizeSearchText(keyword);
    final matchedHymns = <home.HomeHymn>[];

    for (final homeHymn in filtered) {
      final localHymn = await AppInitializer.isar.localHymns
          .filter()
          .hymnIdEqualTo(homeHymn.hymnId)
          .findFirst();

      if (localHymn == null) continue;

      final searchText = normalizeSearchText(localHymn.searchText ?? '');
      final hindi = normalizeSearchText(localHymn.hindiLyrics ?? '');
      final malayalam = normalizeSearchText(localHymn.malayalamLyrics ?? '');
      final english = normalizeSearchText(localHymn.englishLyrics ?? '');
      final title = normalizeSearchText(localHymn.title);
      final serialNoStr = homeHymn.serialNo.toString();

      if (searchText.contains(query) ||
          hindi.contains(query) ||
          malayalam.contains(query) ||
          english.contains(query) ||
          title.contains(query) ||
          serialNoStr.contains(query)) {
        matchedHymns.add(homeHymn);
      }
    }

    return matchedHymns;
  }

  @override
  Future<List<home.HomeViewList>> getAllViewLists() async {
    return const <home.HomeViewList>[];
  }

  // ============================================================
  // FILTER DATA IMPLEMENTATIONS
  // ============================================================

  @override
  Future<List<String>> getAvailableKeys() async {
    final hymns = await AppInitializer.isar.localHymns.where().findAll();
    final set = <String>{};
    for (final h in hymns) {
      if (h.key != null && h.key!.trim().isNotEmpty) set.add(h.key!.trim());
    }
    return set.toList()..sort();
  }

  @override
  Future<List<String>> getAvailableDedicated() async {
    final hymns = await AppInitializer.isar.localHymns.where().findAll();

    debugPrint('========== DEDICATED FILTER ==========');
    debugPrint('Total hymns in Isar = ${hymns.length}');

    final set = <String>{};

    for (final h in hymns) {
      debugPrint('Title=${h.title} | Dedicated=${h.dedicated}');

      if (h.dedicated != null && h.dedicated!.trim().isNotEmpty) {
        set.add(h.dedicated!.trim());
      }
    }

    debugPrint('Dedicated values found = $set');
    debugPrint('=====================================');

    return set.toList()..sort();
  }

  @override
  Future<List<int>> getAvailableYears() async {
    final hymns = await AppInitializer.isar.localHymns.where().findAll();

    final years = <int>{};

    for (final h in hymns) {
      final year = int.tryParse(h.year ?? '');
      if (year != null) {
        years.add(year);
      }
    }

    return years.toList()..sort();
  }

  @override
  Future<List<TempoRange>> getAvailableTempoRanges() async {
    return [
      TempoRange(min: 50, max: 70),
      TempoRange(min: 70, max: 90),
      TempoRange(min: 90, max: 110),
      TempoRange(min: 110, max: 130),
      TempoRange(min: 130, max: 150),
      TempoRange(min: 150, max: 170),
      TempoRange(min: 170, max: 190),
      TempoRange(min: 190, max: 210),
    ];
  }

  @override
  Future<List<home.HomeMedley>> getAllMedleys() async {
    return const <home.HomeMedley>[];
  }

  @override
  Future<void> addToFavorites(List<String> hymnIds) async {
    for (final hymnId in hymnIds) {
      await _favoritesRepository.addFavorite(hymnId);
    }
  }

  @override
  Future<void> removeFromFavorites(List<String> hymnIds) async {
    for (final hymnId in hymnIds) {
      await _favoritesRepository.removeFavorite(hymnId);
    }
  }

  @override
  Future<void> addToViewList({
    required List<String> hymnIds,
    required String viewListId,
  }) async {
    for (final hymnId in hymnIds) {
      await _folderRepository.addHymnToFolder(
        'viewlists',
        viewListId,
        const <String>[],
        hymnId,
      );
    }

    unawaited(_syncLater());
  }

  @override
  Future<void> addToMedley({
    required List<String> hymnIds,
    required String medleyId,
  }) async {
    for (final hymnId in hymnIds) {
      await _folderRepository.addHymnToFolder(
        'medleys',
        medleyId,
        const <String>[],
        hymnId,
      );
    }

    unawaited(_syncLater());
  }

  @override
  Future<void> exportPdf(List<String> hymnIds) async {
    final hymns = await AppInitializer.isar.localHymns
        .filter()
        .anyOf(hymnIds, (q, id) => q.hymnIdEqualTo(id))
        .findAll();

    final orderedHymns = PdfExportService.orderHymnsByIds(
      hymnIds: hymnIds,
      hymns: hymns,
    );

    await PdfExportService().saveHymnPdf(hymns: orderedHymns);
  }

  @override
  Future<void> sharePdf(List<String> hymnIds) async {
    final hymns = await AppInitializer.isar.localHymns
        .filter()
        .anyOf(hymnIds, (q, id) => q.hymnIdEqualTo(id))
        .findAll();

    final orderedHymns = PdfExportService.orderHymnsByIds(
      hymnIds: hymnIds,
      hymns: hymns,
    );

    await PdfExportService().shareHymnPdf(hymns: orderedHymns);
  }

  @override
  Future<void> importExcel() async {}

  @override
  Future<void> exportExcel() async {}

  @override
  Future<void> changeTheme() async {
    ThemeService.changeTheme();
  }

  @override
  Future<void> invertTheme() async {
    ThemeService.invertTheme();
  }

  @override
  Future<void> presentationMode() async {}

  @override
  Future<void> openNotifications() async {}

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> openStatistics() async {}

  @override
  Future<void> openHelp() async {}

  @override
  Future<void> sendFeedback() async {}

  @override
  Future<void> openAbout() async {}
}