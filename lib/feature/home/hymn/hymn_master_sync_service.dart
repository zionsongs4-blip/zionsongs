import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar/isar.dart';

import 'app_initializer.dart';
import 'hymn_models.dart';

class HymnMasterSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  static bool _started = false;

  static Future<void> start() async {
    if (_started) {
      return;
    }

    _started = true;
    print('🔄 Hymn real-time sync listener initialized (non-blocking)');

    // Set up the listener immediately without waiting for a result.
    // This allows the app to continue even if Firestore is unavailable.
    // The listener will reconnect automatically when connectivity returns.
    _subscription = _firestore
        .collection('hymns')
        .snapshots()
        .listen(
          _handleSnapshot,
          onError: (Object error, StackTrace stackTrace) {
            print('⚠️ Hymn sync error (app continues offline): $error');
            print(stackTrace);
          },
        );

    // Return immediately after setting up the listener.
    // Do not wait for the first snapshot.
    return Future.value();
  }

  static void stop() {
    _subscription?.cancel();
    _subscription = null;
    _started = false;
  }

  static Future<void> _handleSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    try {
      for (final change in snapshot.docChanges) {
        final docId = change.doc.id;
        final data = change.doc.data();

        switch (change.type) {
          case DocumentChangeType.added:
            print('➕ Hymn added: $docId');
            final hymn = toLocalHymn(docId, data);
            await _saveHymnToIsar(hymn);
            break;
          case DocumentChangeType.modified:
            print('✏️ Hymn updated: $docId');
            final hymn = toLocalHymn(docId, data);
            await _saveHymnToIsar(hymn);
            break;
          case DocumentChangeType.removed:
            print('🗑️ Hymn removed: $docId');
            await AppInitializer.isar.writeTxn(() async {
              await AppInitializer.isar.localHymns
                  .filter()
                  .hymnIdEqualTo(docId)
                  .deleteFirst();
            });
            break;
          default:
            break;
        }
      }

      print('✅ Hymn sync applied to Isar');
    } catch (error, stackTrace) {
      print('❌ Hymn sync error: $error');
      print(stackTrace);
    }
  }

  static Future<void> _saveHymnToIsar(LocalHymn hymn) async {
    await AppInitializer.isar.writeTxn(() async {
      await AppInitializer.isar.localHymns.putByHymnId(hymn);
    });
  }

  static LocalHymn toLocalHymn(String hymnId, Map<String, dynamic>? data) {
    final payload = data ?? const <String, dynamic>{};
    final lyrics = payload['lyrics'] is Map
        ? Map<String, dynamic>.from(payload['lyrics'] as Map)
        : <String, dynamic>{};

    final englishLyrics = lyrics['English']?.toString() ?? '';
    final hindiLyrics = lyrics['Hindi']?.toString() ?? '';
    final malayalamLyrics = lyrics['Malayalam']?.toString() ?? '';

    final hymn = LocalHymn()
      ..hymnId = hymnId
      ..title = payload['title']?.toString() ?? 'Untitled Hymn'
      ..englishLyrics = englishLyrics
      ..hindiLyrics = hindiLyrics
      ..malayalamLyrics = malayalamLyrics
      ..originalLyrics = [
        englishLyrics,
        hindiLyrics,
        malayalamLyrics,
      ].where((e) => e.trim().isNotEmpty).join('\n\n')
      ..key = (payload['Key'] ?? payload['key'] ?? payload['code'])?.toString()
      ..dedicated = (payload['Dedicated'] ?? payload['dedicated'])?.toString()
      ..year = payload['year']?.toString()
      ..searchText = (payload['searchText'] ?? payload['search_text'])?.toString();

    final tempoValue = payload['tempo'];
    if (tempoValue is int) {
      hymn.tempo = tempoValue;
    } else if (tempoValue is String) {
      hymn.tempo = int.tryParse(tempoValue);
    }

    return hymn;
  }
}
