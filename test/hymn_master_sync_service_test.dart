import 'package:flutter_test/flutter_test.dart';
import 'package:zionsongs/feature/home/hymn/hymn_master_sync_service.dart';
import 'package:zionsongs/feature/home/hymn/hymn_models.dart';
import 'package:zionsongs/feature/home/hymn/hymn_sync_logic.dart';

void main() {
  group('HymnMasterSyncService', () {
    test('maps Firestore hymn fields into LocalHymn without dropping existing fields', () {
      final data = {
        'title': 'Amazing Grace',
        'lyrics': {
          'English': 'Amazing grace',
          'Hindi': 'Kya baat',
          'Malayalam': 'ചെറിയ വരി',
        },
        'Key': 'G',
        'Dedicated': 'John',
        'year': '2024',
        'tempo': 84,
        'searchText': 'amazing grace',
      };

      final hymn = HymnMasterSyncService.toLocalHymn('abc123', data);

      expect(hymn.hymnId, 'abc123');
      expect(hymn.title, 'Amazing Grace');
      expect(hymn.englishLyrics, 'Amazing grace');
      expect(hymn.hindiLyrics, 'Kya baat');
      expect(hymn.malayalamLyrics, 'ചെറിയ വരി');
      expect(hymn.originalLyrics, 'Amazing grace\n\nKya baat\n\nചെറിയ വരി');
      expect(hymn.key, 'G');
      expect(hymn.dedicated, 'John');
      expect(hymn.year, '2024');
      expect(hymn.tempo, 84);
      expect(hymn.searchText, 'amazing grace');
    });

    test('builds a direct hymn update payload for Firestore sync', () {
      final payload = SyncLogic.buildHymnEditPayload(
        title: 'Amazing Grace',
        originalLyrics: 'Amazing grace',
        hindiLyrics: 'Updated Hindi lyric',
        malayalamLyrics: 'Updated Malayalam lyric',
      );

      expect(payload['lyrics'], {
        'English': 'Amazing grace',
        'Hindi': 'Updated Hindi lyric',
        'Malayalam': 'Updated Malayalam lyric',
      });
      expect(payload['searchText'], contains('amazing grace'));
      expect(payload['searchText'], contains('updated hindi lyric'));
      expect(payload['searchText'], contains('updated malayalam lyric'));
    });
  });
}
