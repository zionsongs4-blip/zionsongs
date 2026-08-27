import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:zionsongs/screens/hymn_collection_page.dart';
import 'package:zionsongs/screens/collection_locations_screen.dart';
import 'package:zionsongs/feature/home/hymn/hymn_models.dart';
import 'package:zionsongs/utils/folder_navigation_utils.dart';

LocalHymn _hymn(String id) {
  return LocalHymn()
    ..hymnId = id
    ..title = id
    ..originalLyrics = 'Original $id';
}

void main() {
  test('clicked hymn becomes primary while preserving collection order', () {
    final layout = splitCollectionHymnsForDisplay(
      hymns: [_hymn('ZS0020'), _hymn('ZS0024'), _hymn('ZS0029')],
      primaryHymnId: 'ZS0024',
    );

    expect(layout.primaryHymn.hymnId, 'ZS0024');
    expect(layout.otherHymns.map((hymn) => hymn.hymnId), ['ZS0020', 'ZS0029']);
  });

  test('collection content includes every available language', () {
    final hymn = _hymn('ZS0024')
      ..hindiLyrics = 'Hindi lyrics'
      ..malayalamLyrics = 'Malayalam lyrics'
      ..englishLyrics = 'English lyrics';

    expect(
      buildCollectionLanguageContent(hymn).map((content) => content.label),
      ['Hindi', 'Malayalam', 'English'],
    );
  });

  test('relationship ownership includes legacy local records after auth', () {
    expect(
      isVisibleRelationshipUser(
        recordUserId: 'local-user',
        activeUserId: 'signed-in-user',
      ),
      isTrue,
    );
    expect(
      isVisibleRelationshipUser(
        recordUserId: 'other-user',
        activeUserId: 'signed-in-user',
      ),
      isFalse,
    );
  });

  test('batch folder IDs are deduplicated without changing order', () {
    expect(uniqueIdsPreservingOrder(['folder-a', 'folder-b', 'folder-a']), [
      'folder-a',
      'folder-b',
    ]);
  });

  test('batch navigation reconstructs the complete nested folder path', () {
    for (final collection in ['viewlists', 'medleys']) {
      expect(
        resolveRelationshipFolderPath(
          folderId: 'child',
          collection: collection,
          docId: 'all-zones',
          encodedPath: ['child'],
          parentById: {'child': 'parent', 'parent': null},
        ),
        ['parent', 'child'],
      );
    }
  });

  testWidgets('locations page shows names without exposing backend paths', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CollectionLocationsScreen(
          collection: 'viewlists',
          hymnId: 'ZS0024',
          locations: const [
            CollectionLocation(
              collection: 'viewlists',
              docId: 'all-zones',
              path: ['central-india', 'mum-central-zone'],
              folderName: 'Mum Central Zone',
            ),
            CollectionLocation(
              collection: 'viewlists',
              docId: 'sunday-service',
              path: ['sunday-service'],
              folderName: 'Sunday Service',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Mum Central Zone'), findsOneWidget);
    expect(find.text('Sunday Service'), findsOneWidget);
    expect(find.textContaining('central-india'), findsNothing);
    expect(find.textContaining('viewlists::'), findsNothing);
  });
}
