import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar/isar.dart';

import '../hymn/app_initializer.dart';
import '../hymn/hymn_models.dart';
import '../hymn/viewlist_medley_models.dart';

class RelationshipFolderKey {
  const RelationshipFolderKey({
    required this.collection,
    required this.docId,
    required this.path,
  });

  final String collection;
  final String docId;
  final List<String> path;
}

String buildRelationshipFolderKey(
  String collection,
  String docId,
  List<String> path,
) {
  final parts = <String>[collection, docId, ...path];
  return parts.join('::');
}

RelationshipFolderKey parseRelationshipFolderKey(String key) {
  final parts = key.split('::');
  if (parts.length < 2) {
    return const RelationshipFolderKey(collection: '', docId: '', path: []);
  }
  return RelationshipFolderKey(
    collection: parts.first,
    docId: parts[1],
    path: parts.length > 2 ? parts.sublist(2) : const <String>[],
  );
}

String buildRelationshipItemKey(
  String collection,
  String docId,
  List<String> path,
  String hymnId,
) {
  return '${buildRelationshipFolderKey(collection, docId, path)}::$hymnId';
}

String resolveCopiedFolderName(
  String baseName,
  List<Map<String, dynamic>> siblings,
) {
  final normalizedBaseName = baseName.trim();
  if (normalizedBaseName.isEmpty) {
    return normalizedBaseName;
  }

  final existingNames = siblings.map((entry) {
    final name = entry['name'];
    return name is String ? name : '';
  }).toList();

  final hasDirectConflict = existingNames.any(
    (name) => name.toLowerCase() == normalizedBaseName.toLowerCase(),
  );
  if (!hasDirectConflict) {
    return normalizedBaseName;
  }

  var suffixIndex = 2;
  var candidate = '$normalizedBaseName (Copy)';
  while (existingNames.any(
    (name) => name.toLowerCase() == candidate.toLowerCase(),
  )) {
    candidate = '$normalizedBaseName (Copy $suffixIndex)';
    suffixIndex += 1;
  }
  return candidate;
}

class FolderRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _getFolderCollectionRef(
    String collection,
    String docId,
    List<String> path,
  ) {
    CollectionReference<Map<String, dynamic>> ref;
    if (docId == 'root') {
      ref = _db.collection(collection).withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => Map<String, dynamic>.from(
          snap.data() ?? const <String, dynamic>{},
        ),
        toFirestore: (data, _) => data,
      );
    } else {
      ref = _db
          .collection(collection)
          .doc(docId)
          .collection('folders')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => Map<String, dynamic>.from(
              snap.data() ?? const <String, dynamic>{},
            ),
            toFirestore: (data, _) => data,
          );
    }
    for (final folderId in path) {
      ref = ref
          .doc(folderId)
          .collection('folders')
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => Map<String, dynamic>.from(
              snap.data() ?? const <String, dynamic>{},
            ),
            toFirestore: (data, _) => data,
          );
    }
    return ref;
  }

  DocumentReference<Map<String, dynamic>> _getFolderDocRef(
    String collection,
    String docId,
    List<String> path,
  ) {
    if (path.isEmpty) {
      return _db
          .collection(collection)
          .doc(docId)
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => Map<String, dynamic>.from(
              snap.data() ?? const <String, dynamic>{},
            ),
            toFirestore: (data, _) => data,
          );
    }
    final folderId = path.last;
    final parentPath = path.sublist(0, path.length - 1);
    return _getFolderCollectionRef(collection, docId, parentPath)
        .doc(folderId)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => Map<String, dynamic>.from(
            snap.data() ?? const <String, dynamic>{},
          ),
          toFirestore: (data, _) => data,
        );
  }

  CollectionReference<Map<String, dynamic>> _getHymnEntryCollectionRef(
    String collection,
    String docId,
    List<String> path,
  ) {
    return _getFolderDocRef(collection, docId, path)
        .collection('hymn_entries')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => Map<String, dynamic>.from(
            snap.data() ?? const <String, dynamic>{},
          ),
          toFirestore: (data, _) => data,
        );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchFolderCollection(
    String collection,
    String docId,
    List<String> path,
  ) {
    return _getFolderCollectionRef(collection, docId, path).snapshots();
  }

  Future<void> createFolder(
    String collection,
    String docId,
    List<String> parentPath,
    String folderId,
    String name, {
    String userId = 'local-user',
    String deviceId = 'device-1',
  }) async {
    final colRef = _getFolderCollectionRef(collection, docId, parentPath);
    final siblings = await colRef.get();
    final displayOrder = siblings.docs.length + 1;
    await colRef.doc(folderId).set({
      'folderId': folderId,
      'parentFolderId': parentPath.isEmpty ? null : parentPath.last,
      'name': name,
      'displayOrder': displayOrder,
      'hymnIds': <String, bool>{},
      'hymnOrder': <String>[],
      ..._buildFolderMetadata(
        'CREATE',
        userId: userId,
        deviceId: deviceId,
        create: true,
      ),
    });
    await _syncFolderRelationshipRecords(
      collection,
      docId,
      [...parentPath, folderId],
      userId: userId,
      deviceId: deviceId,
    );
  }

  Future<void> renameFolder(
    String collection,
    String docId,
    List<String> path,
    String newName, {
    String userId = 'local-user',
    String deviceId = 'device-1',
  }) async {
    final docRef = _getFolderDocRef(collection, docId, path);
    final current = await docRef.get();
    final data = Map<String, dynamic>.from(
      current.data() ?? const <String, dynamic>{},
    );
    await docRef.update({
      'name': newName,
      ..._buildFolderMetadata(
        'RENAME',
        userId: userId,
        deviceId: deviceId,
        previousData: data,
      ),
    });
    await _syncFolderRelationshipRecords(
      collection,
      docId,
      path,
      userId: userId,
      deviceId: deviceId,
    );
  }

  Future<void> addHymnToFolder(
    String collection,
    String docId,
    List<String> path,
    String hymnId, {
    String userId = 'local-user',
    String deviceId = 'device-1',
  }) async {
    final docRef = _getFolderDocRef(collection, docId, path);
    final doc = await docRef.get();
    if (!doc.exists) return;
    final data = Map<String, dynamic>.from(
      doc.data() ?? const <String, dynamic>{},
    );
    final existingHymnIds = _safeStringKeyedMap(data['hymnIds'], 'hymnIds');
    final existingOrder = _safeStringList(data['hymnOrder'], 'hymnOrder');
    existingHymnIds[hymnId] = true;
    if (!existingOrder.contains(hymnId)) {
      existingOrder.add(hymnId);
    }
    final entryRef = _getHymnEntryCollectionRef(
      collection,
      docId,
      path,
    ).doc(hymnId);
    await docRef.update({
      'hymnIds': existingHymnIds,
      'hymnOrder': existingOrder,
      ..._buildFolderMetadata(
        'ADD_HYMN',
        userId: userId,
        deviceId: deviceId,
        previousData: data,
      ),
    });
    await entryRef.set({
      'hymnId': hymnId,
      'displayOrder': existingOrder.indexOf(hymnId) + 1,
      'addedAt': FieldValue.serverTimestamp(),
      'addedBy': userId,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
      'deletedAt': null,
      'deletedBy': null,
      'isDeleted': false,
      'version': 1,
      'deviceId': deviceId,
      'lastAction': 'ADD',
    });
    await _syncFolderRelationshipRecords(
      collection,
      docId,
      path,
      userId: userId,
      deviceId: deviceId,
    );
  }

  Future<void> removeHymnFromFolder(
    String collection,
    String docId,
    List<String> path,
    String hymnId, {
    String userId = 'local-user',
    String deviceId = 'device-1',
  }) async {
    final docRef = _getFolderDocRef(collection, docId, path);
    final doc = await docRef.get();
    if (!doc.exists) return;
    final data = Map<String, dynamic>.from(
      doc.data() ?? const <String, dynamic>{},
    );
    final existingHymnIds = _safeStringKeyedMap(data['hymnIds'], 'hymnIds');
    final existingOrder = _safeStringList(data['hymnOrder'], 'hymnOrder');
    existingHymnIds.remove(hymnId);
    existingOrder.remove(hymnId);
    final entryRef = _getHymnEntryCollectionRef(
      collection,
      docId,
      path,
    ).doc(hymnId);
    await docRef.update({
      'hymnIds': existingHymnIds,
      'hymnOrder': existingOrder,
      ..._buildFolderMetadata(
        'REMOVE_HYMN',
        userId: userId,
        deviceId: deviceId,
        previousData: data,
      ),
    });
    await entryRef.update({
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': userId,
      'isDeleted': true,
      'version': FieldValue.increment(1),
      'deviceId': deviceId,
      'lastAction': 'REMOVE',
    });
    await _syncFolderRelationshipRecords(
      collection,
      docId,
      path,
      userId: userId,
      deviceId: deviceId,
    );
  }

  Future<void> reorderHymns(
    String collection,
    String docId,
    List<String> path,
    List<String> hymnOrder, {
    String userId = 'local-user',
    String deviceId = 'device-1',
  }) async {
    final docRef = _getFolderDocRef(collection, docId, path);
    final current = await docRef.get();
    final data = Map<String, dynamic>.from(
      current.data() ?? const <String, dynamic>{},
    );
    await docRef.update({
      'hymnOrder': hymnOrder,
      ..._buildFolderMetadata(
        'REORDER_HYMN',
        userId: userId,
        deviceId: deviceId,
        previousData: data,
      ),
    });
    final entriesRef = _getHymnEntryCollectionRef(collection, docId, path);
    final entries = await entriesRef.get();
    for (final entry in entries.docs) {
      final hymnId = entry.id;
      final displayOrder = hymnOrder.indexOf(hymnId) + 1;
      await entriesRef.doc(hymnId).update({
        'displayOrder': displayOrder,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userId,
        'version': FieldValue.increment(1),
        'deviceId': deviceId,
        'lastAction': 'REORDER',
      });
    }
  }

  Future<List<Map<String, dynamic>>> getHymnEntries(
    String collection,
    String docId,
    List<String> path,
  ) async {
    final snapshot = await _getHymnEntryCollectionRef(
      collection,
      docId,
      path,
    ).where('isDeleted', isEqualTo: false).get();
    return snapshot.docs
        .map((doc) => Map<String, dynamic>.from(doc.data()))
        .toList();
  }

  Future<void> copyFolder(
    String collection,
    String docId,
    List<String> sourcePath,
    List<String> destPath, {
    String userId = 'local-user',
    String deviceId = 'device-1',
  }) async {
    if (sourcePath.isEmpty) return;
    final sourceRef = _getFolderDocRef(collection, docId, sourcePath);
    final sourceDoc = await sourceRef.get();
    if (!sourceDoc.exists) return;
    final sourceData = Map<String, dynamic>.from(
      sourceDoc.data() ?? const <String, dynamic>{},
    );
    final newId = '${sourcePath.last}_${DateTime.now().millisecondsSinceEpoch}';
    final destSiblingsSnapshot = await _getFolderCollectionRef(
      collection,
      docId,
      destPath,
    ).get();
    final destSiblings = destSiblingsSnapshot.docs
        .map(
          (doc) => Map<String, dynamic>.from(
            doc.data() ?? const <String, dynamic>{},
          ),
        )
        .toList();
    final resolvedName = resolveCopiedFolderName(
      sourceData['name'] ?? sourcePath.last,
      destSiblings,
    );
    await _copyFolderSubtree(
      collection,
      docId,
      sourcePath,
      destPath,
      newId,
      userId: userId,
      deviceId: deviceId,
      action: 'COPY',
    );
    await _syncFolderSubtreeRelationshipRecords(
      collection,
      docId,
      [...destPath, newId],
      userId: userId,
      deviceId: deviceId,
    );
    final destRef = _getFolderCollectionRef(
      collection,
      docId,
      destPath,
    ).doc(newId);
    final copiedData = Map<String, dynamic>.from(sourceData)
      ..['folderId'] = newId
      ..['parentFolderId'] = destPath.isEmpty ? null : destPath.last
      ..['name'] = resolvedName;
    await destRef.update({
      ...copiedData,
      ..._buildFolderMetadata(
        'COPY',
        userId: userId,
        deviceId: deviceId,
        previousData: sourceData,
      ),
    });
  }

  Future<void> copyFolderBetweenDocs(
    String srcCollection,
    String srcDocId,
    List<String> sourcePath,
    String destCollection,
    String destDocId,
    List<String> destPath, {
    String userId = 'local-user',
    String deviceId = 'device-1',
  }) async {
    if (sourcePath.isEmpty) return;
    final sourceRef = _getFolderDocRef(srcCollection, srcDocId, sourcePath);
    final sourceDoc = await sourceRef.get();
    if (!sourceDoc.exists) return;
    final sourceData = Map<String, dynamic>.from(
      sourceDoc.data() ?? const <String, dynamic>{},
    );
    final newId = '${sourcePath.last}_${DateTime.now().millisecondsSinceEpoch}';
    final destSiblingsSnapshot = await _getFolderCollectionRef(
      destCollection,
      destDocId,
      destPath,
    ).get();
    final destSiblings = destSiblingsSnapshot.docs
        .map(
          (doc) => Map<String, dynamic>.from(
            doc.data() ?? const <String, dynamic>{},
          ),
        )
        .toList();
    final resolvedName = resolveCopiedFolderName(
      sourceData['name'] ?? sourcePath.last,
      destSiblings,
    );
    await _copyFolderSubtree(
      srcCollection,
      srcDocId,
      sourcePath,
      destPath,
      newId,
      destCollection: destCollection,
      destDocId: destDocId,
      userId: userId,
      deviceId: deviceId,
      action: 'COPY',
    );
    await _syncFolderSubtreeRelationshipRecords(
      destCollection,
      destDocId,
      [...destPath, newId],
      userId: userId,
      deviceId: deviceId,
    );
    final destRef = _getFolderCollectionRef(
      destCollection,
      destDocId,
      destPath,
    ).doc(newId);
    await destRef.update({
      'name': resolvedName,
      ..._buildFolderMetadata(
        'COPY',
        userId: userId,
        deviceId: deviceId,
        previousData: sourceData,
      ),
    });
  }

  Future<void> moveFolder(
    String collection,
    String docId,
    List<String> sourcePath,
    List<String> destPath, {
    String userId = 'local-user',
    String deviceId = 'device-1',
  }) async {
    if (sourcePath.isEmpty || _isSameOrDescendantPath(sourcePath, destPath)) {
      return;
    }
    final sourceRef = _getFolderDocRef(collection, docId, sourcePath);
    final sourceDoc = await sourceRef.get();
    if (!sourceDoc.exists) return;
    final sourceData = Map<String, dynamic>.from(
      sourceDoc.data() ?? const <String, dynamic>{},
    );
    await _copyFolderSubtree(
      collection,
      docId,
      sourcePath,
      destPath,
      sourcePath.last,
      userId: userId,
      deviceId: deviceId,
      action: 'MOVE',
    );
    await _deleteFolderSubtree(
      collection,
      docId,
      sourcePath,
      userId: userId,
      deviceId: deviceId,
    );
    await _deleteFolderSubtreeRelationships(collection, docId, sourcePath);
    final destRef = _getFolderCollectionRef(
      collection,
      docId,
      destPath,
    ).doc(sourcePath.last);
    await destRef.update({
      'parentFolderId': destPath.isEmpty ? null : destPath.last,
      ..._buildFolderMetadata(
        'MOVE',
        userId: userId,
        deviceId: deviceId,
        previousData: sourceData,
      ),
    });
    await _syncFolderSubtreeRelationshipRecords(
      collection,
      docId,
      destPath,
      userId: userId,
      deviceId: deviceId,
    );
  }

  Future<void> moveHymnBetweenFolders(
    String collection,
    String docId,
    List<String> sourcePath,
    String hymnId,
    List<String> destPath, {
    String userId = 'local-user',
    String deviceId = 'device-1',
  }) async {
    if (_isSameOrDescendantPath(sourcePath, destPath)) return;
    final sourceFolderRef = _getFolderDocRef(collection, docId, sourcePath);
    final sourceFolderDoc = await sourceFolderRef.get();
    if (!sourceFolderDoc.exists) return;
    final sourceData = Map<String, dynamic>.from(
      sourceFolderDoc.data() ?? const <String, dynamic>{},
    );
    final sourceHymnIds = _safeStringKeyedMap(sourceData['hymnIds'], 'hymnIds');
    final sourceHymnOrder = _safeStringList(
      sourceData['hymnOrder'],
      'hymnOrder',
    );
    sourceHymnIds.remove(hymnId);
    sourceHymnOrder.remove(hymnId);
    await sourceFolderRef.update({
      'hymnIds': sourceHymnIds,
      'hymnOrder': sourceHymnOrder,
      ..._buildFolderMetadata(
        'MOVE_HYMN',
        userId: userId,
        deviceId: deviceId,
        previousData: sourceData,
      ),
    });

    final destFolderRef = _getFolderDocRef(collection, docId, destPath);
    final destFolderDoc = await destFolderRef.get();
    if (!destFolderDoc.exists) return;
    final destData = Map<String, dynamic>.from(
      destFolderDoc.data() ?? const <String, dynamic>{},
    );
    final destHymnIds = _safeStringKeyedMap(destData['hymnIds'], 'hymnIds');
    final destHymnOrder = _safeStringList(destData['hymnOrder'], 'hymnOrder');
    destHymnIds[hymnId] = true;
    if (!destHymnOrder.contains(hymnId)) {
      destHymnOrder.add(hymnId);
    }
    await destFolderRef.update({
      'hymnIds': destHymnIds,
      'hymnOrder': destHymnOrder,
      ..._buildFolderMetadata(
        'MOVE_HYMN',
        userId: userId,
        deviceId: deviceId,
        previousData: destData,
      ),
    });

    final sourceEntryRef = _getHymnEntryCollectionRef(
      collection,
      docId,
      sourcePath,
    ).doc(hymnId);
    final sourceEntryDoc = await sourceEntryRef.get();
    if (!sourceEntryDoc.exists) return;
    final sourceEntryData = Map<String, dynamic>.from(
      sourceEntryDoc.data() ?? const <String, dynamic>{},
    );
    final destEntryRef = _getHymnEntryCollectionRef(
      collection,
      docId,
      destPath,
    ).doc(hymnId);
    await destEntryRef.set({
      ...sourceEntryData,
      'displayOrder': destHymnOrder.indexOf(hymnId) + 1,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
      'deviceId': deviceId,
      'lastAction': 'MOVE',
      'version': ((sourceEntryData['version'] as num?)?.toInt() ?? 0) + 1,
    });
    await sourceEntryRef.delete();
  }

  Future<void> moveHymnBetweenDocs(
    String srcCollection,
    String srcDocId,
    List<String> sourcePath,
    String hymnId,
    String destCollection,
    String destDocId,
    List<String> destPath, {
    String userId = 'local-user',
    String deviceId = 'device-1',
  }) async {
    if (_isSameOrDescendantPath(sourcePath, destPath)) return;
    final sourceFolderRef = _getFolderDocRef(
      srcCollection,
      srcDocId,
      sourcePath,
    );
    final sourceFolderDoc = await sourceFolderRef.get();
    if (!sourceFolderDoc.exists) return;
    final sourceData = Map<String, dynamic>.from(
      sourceFolderDoc.data() ?? const <String, dynamic>{},
    );
    final sourceHymnIds = _safeStringKeyedMap(sourceData['hymnIds'], 'hymnIds');
    final sourceHymnOrder = _safeStringList(
      sourceData['hymnOrder'],
      'hymnOrder',
    );
    sourceHymnIds.remove(hymnId);
    sourceHymnOrder.remove(hymnId);
    await sourceFolderRef.update({
      'hymnIds': sourceHymnIds,
      'hymnOrder': sourceHymnOrder,
      ..._buildFolderMetadata(
        'MOVE_HYMN',
        userId: userId,
        deviceId: deviceId,
        previousData: sourceData,
      ),
    });

    final destFolderRef = _getFolderDocRef(destCollection, destDocId, destPath);
    final destFolderDoc = await destFolderRef.get();
    if (!destFolderDoc.exists) return;
    final destData = Map<String, dynamic>.from(
      destFolderDoc.data() ?? const <String, dynamic>{},
    );
    final destHymnIds = _safeStringKeyedMap(destData['hymnIds'], 'hymnIds');
    final destHymnOrder = _safeStringList(destData['hymnOrder'], 'hymnOrder');
    destHymnIds[hymnId] = true;
    if (!destHymnOrder.contains(hymnId)) {
      destHymnOrder.add(hymnId);
    }
    await destFolderRef.update({
      'hymnIds': destHymnIds,
      'hymnOrder': destHymnOrder,
      ..._buildFolderMetadata(
        'MOVE_HYMN',
        userId: userId,
        deviceId: deviceId,
        previousData: destData,
      ),
    });

    final sourceEntryRef = _getHymnEntryCollectionRef(
      srcCollection,
      srcDocId,
      sourcePath,
    ).doc(hymnId);
    final sourceEntryDoc = await sourceEntryRef.get();
    if (!sourceEntryDoc.exists) return;
    final sourceEntryData = Map<String, dynamic>.from(
      sourceEntryDoc.data() ?? const <String, dynamic>{},
    );
    final destEntryRef = _getHymnEntryCollectionRef(
      destCollection,
      destDocId,
      destPath,
    ).doc(hymnId);
    await destEntryRef.set({
      ...sourceEntryData,
      'displayOrder': destHymnOrder.indexOf(hymnId) + 1,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
      'deviceId': deviceId,
      'lastAction': 'MOVE',
      'version': ((sourceEntryData['version'] as num?)?.toInt() ?? 0) + 1,
    });
    await sourceEntryRef.delete();
    await _syncFolderRelationshipRecords(
      srcCollection,
      srcDocId,
      sourcePath,
      userId: userId,
      deviceId: deviceId,
    );
    await _syncFolderRelationshipRecords(
      destCollection,
      destDocId,
      destPath,
      userId: userId,
      deviceId: deviceId,
    );
  }

  Future<void> copyHymnBetweenFolders(
    String collection,
    String docId,
    List<String> sourcePath,
    String hymnId,
    List<String> destPath, {
    String userId = 'local-user',
    String deviceId = 'device-1',
  }) async {
    final sourceFolderRef = _getFolderDocRef(collection, docId, sourcePath);
    final sourceFolderDoc = await sourceFolderRef.get();
    if (!sourceFolderDoc.exists) return;
    final sourceData = Map<String, dynamic>.from(
      sourceFolderDoc.data() ?? const <String, dynamic>{},
    );
    final sourceHymnIds = _safeStringKeyedMap(sourceData['hymnIds'], 'hymnIds');
    if (!sourceHymnIds.containsKey(hymnId)) return;

    final destFolderRef = _getFolderDocRef(collection, docId, destPath);
    final destFolderDoc = await destFolderRef.get();
    if (!destFolderDoc.exists) return;
    final destData = Map<String, dynamic>.from(
      destFolderDoc.data() ?? const <String, dynamic>{},
    );
    final destHymnIds = _safeStringKeyedMap(destData['hymnIds'], 'hymnIds');
    final destHymnOrder = _safeStringList(destData['hymnOrder'], 'hymnOrder');
    destHymnIds[hymnId] = true;
    if (!destHymnOrder.contains(hymnId)) {
      destHymnOrder.add(hymnId);
    }
    await destFolderRef.update({
      'hymnIds': destHymnIds,
      'hymnOrder': destHymnOrder,
      ..._buildFolderMetadata(
        'COPY_HYMN',
        userId: userId,
        deviceId: deviceId,
        previousData: destData,
      ),
    });

    final sourceEntryRef = _getHymnEntryCollectionRef(
      collection,
      docId,
      sourcePath,
    ).doc(hymnId);
    final sourceEntryDoc = await sourceEntryRef.get();
    if (!sourceEntryDoc.exists) return;
    final sourceEntryData = Map<String, dynamic>.from(
      sourceEntryDoc.data() ?? const <String, dynamic>{},
    );
    final destEntryRef = _getHymnEntryCollectionRef(
      collection,
      docId,
      destPath,
    ).doc(hymnId);
    await destEntryRef.set({
      ...sourceEntryData,
      'displayOrder': destHymnOrder.indexOf(hymnId) + 1,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
      'deviceId': deviceId,
      'lastAction': 'COPY',
      'version': ((sourceEntryData['version'] as num?)?.toInt() ?? 0) + 1,
    });
    await _syncFolderRelationshipRecords(
      collection,
      docId,
      sourcePath,
      userId: userId,
      deviceId: deviceId,
    );
    await _syncFolderRelationshipRecords(
      collection,
      docId,
      destPath,
      userId: userId,
      deviceId: deviceId,
    );
  }

  Future<void> copyHymnBetweenDocs(
    String srcCollection,
    String srcDocId,
    List<String> sourcePath,
    String hymnId,
    String destCollection,
    String destDocId,
    List<String> destPath, {
    String userId = 'local-user',
    String deviceId = 'device-1',
  }) async {
    final sourceFolderRef = _getFolderDocRef(
      srcCollection,
      srcDocId,
      sourcePath,
    );
    final sourceFolderDoc = await sourceFolderRef.get();
    if (!sourceFolderDoc.exists) return;
    final sourceData = Map<String, dynamic>.from(
      sourceFolderDoc.data() ?? const <String, dynamic>{},
    );
    final sourceHymnIds = _safeStringKeyedMap(sourceData['hymnIds'], 'hymnIds');
    if (!sourceHymnIds.containsKey(hymnId)) return;

    final destFolderRef = _getFolderDocRef(destCollection, destDocId, destPath);
    final destFolderDoc = await destFolderRef.get();
    if (!destFolderDoc.exists) return;
    final destData = Map<String, dynamic>.from(
      destFolderDoc.data() ?? const <String, dynamic>{},
    );
    final destHymnIds = _safeStringKeyedMap(destData['hymnIds'], 'hymnIds');
    final destHymnOrder = _safeStringList(destData['hymnOrder'], 'hymnOrder');
    destHymnIds[hymnId] = true;
    if (!destHymnOrder.contains(hymnId)) {
      destHymnOrder.add(hymnId);
    }
    await destFolderRef.update({
      'hymnIds': destHymnIds,
      'hymnOrder': destHymnOrder,
      ..._buildFolderMetadata(
        'COPY_HYMN',
        userId: userId,
        deviceId: deviceId,
        previousData: destData,
      ),
    });

    final sourceEntryRef = _getHymnEntryCollectionRef(
      srcCollection,
      srcDocId,
      sourcePath,
    ).doc(hymnId);
    final sourceEntryDoc = await sourceEntryRef.get();
    if (!sourceEntryDoc.exists) return;
    final sourceEntryData = Map<String, dynamic>.from(
      sourceEntryDoc.data() ?? const <String, dynamic>{},
    );
    final destEntryRef = _getHymnEntryCollectionRef(
      destCollection,
      destDocId,
      destPath,
    ).doc(hymnId);
    await destEntryRef.set({
      ...sourceEntryData,
      'displayOrder': destHymnOrder.indexOf(hymnId) + 1,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
      'deviceId': deviceId,
      'lastAction': 'COPY',
      'version': ((sourceEntryData['version'] as num?)?.toInt() ?? 0) + 1,
    });
    await _syncFolderRelationshipRecords(
      srcCollection,
      srcDocId,
      sourcePath,
      userId: userId,
      deviceId: deviceId,
    );
    await _syncFolderRelationshipRecords(
      destCollection,
      destDocId,
      destPath,
      userId: userId,
      deviceId: deviceId,
    );
  }

  Future<void> moveFolderBetweenDocs(
    String srcCollection,
    String srcDocId,
    List<String> sourcePath,
    String destCollection,
    String destDocId,
    List<String> destPath, {
    String userId = 'local-user',
    String deviceId = 'device-1',
  }) async {
    if (sourcePath.isEmpty || _isSameOrDescendantPath(sourcePath, destPath)) {
      return;
    }
    final sourceRef = _getFolderDocRef(srcCollection, srcDocId, sourcePath);
    final sourceDoc = await sourceRef.get();
    if (!sourceDoc.exists) return;
    final sourceData = Map<String, dynamic>.from(
      sourceDoc.data() ?? const <String, dynamic>{},
    );
    await _copyFolderSubtree(
      srcCollection,
      srcDocId,
      sourcePath,
      destPath,
      sourcePath.last,
      destCollection: destCollection,
      destDocId: destDocId,
      userId: userId,
      deviceId: deviceId,
      action: 'MOVE',
    );
    await _deleteFolderSubtree(
      srcCollection,
      srcDocId,
      sourcePath,
      userId: userId,
      deviceId: deviceId,
    );
    await _deleteFolderSubtreeRelationships(srcCollection, srcDocId, sourcePath);
    final destRef = _getFolderCollectionRef(
      destCollection,
      destDocId,
      destPath,
    ).doc(sourcePath.last);
    await destRef.update({
      'parentFolderId': destPath.isEmpty ? null : destPath.last,
      ..._buildFolderMetadata(
        'MOVE',
        userId: userId,
        deviceId: deviceId,
        previousData: sourceData,
      ),
    });
    await _syncFolderSubtreeRelationshipRecords(
      destCollection,
      destDocId,
      destPath,
      userId: userId,
      deviceId: deviceId,
    );
  }

  Future<void> deleteFolder(
    String collection,
    String docId,
    List<String> path, {
    String userId = 'local-user',
    String deviceId = 'device-1',
  }) async {
    final docRef = _getFolderDocRef(collection, docId, path);
    final current = await docRef.get();
    if (!current.exists) return;
    final data = Map<String, dynamic>.from(
      current.data() ?? const <String, dynamic>{},
    );
    await docRef.update({
      ..._buildFolderMetadata(
        'DELETE',
        userId: userId,
        deviceId: deviceId,
        previousData: data,
        isDeleted: true,
      ),
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': userId,
      'isDeleted': true,
    });
    await _markFolderDeleted(
      collection,
      docId,
      path,
      userId: userId,
      deviceId: deviceId,
    );
    await _deleteFolderSubtreeRelationships(collection, docId, path);
  }

  Future<void> restoreFolder(
    String collection,
    String docId,
    List<String> path, {
    String userId = 'local-user',
    String deviceId = 'device-1',
  }) async {
    final docRef = _getFolderDocRef(collection, docId, path);
    final current = await docRef.get();
    if (!current.exists) return;
    final data = Map<String, dynamic>.from(
      current.data() ?? const <String, dynamic>{},
    );
    await docRef.update({
      ..._buildFolderMetadata(
        'RESTORE',
        userId: userId,
        deviceId: deviceId,
        previousData: data,
      ),
      'deletedAt': null,
      'deletedBy': null,
      'isDeleted': false,
    });
    await _syncFolderRelationshipRecords(
      collection,
      docId,
      path,
      userId: userId,
      deviceId: deviceId,
    );
  }

  Future<void> _syncFolderRelationshipRecords(
    String collection,
    String docId,
    List<String> path, {
    required String userId,
    required String deviceId,
  }) async {
    final folderDocRef = _getFolderDocRef(collection, docId, path);
    final folderDoc = await folderDocRef.get();
    if (!folderDoc.exists) {
      await _deleteFolderSubtreeRelationships(collection, docId, path);
      return;
    }

    final data = Map<String, dynamic>.from(
      folderDoc.data() ?? const <String, dynamic>{},
    );
    final folderKey = buildRelationshipFolderKey(collection, docId, path);
    final parentPath = path.length > 1
        ? path.sublist(0, path.length - 1)
        : <String>[];
    final parentKey = path.isEmpty
        ? null
        : buildRelationshipFolderKey(collection, docId, parentPath);

    if (collection == 'viewlists') {
      final existing = await AppInitializer.isar.viewListFolderRecords
          .filter()
          .folderIdEqualTo(folderKey)
          .findFirst();
      final record = existing ?? ViewListFolderRecord()
        ..folderId = folderKey;
      record.name = data['name']?.toString() ?? path.last;
      record.parentId = parentKey;
      record.userId = userId;
      record.depth = path.length;
      record.modifiedOn = DateTime.now().millisecondsSinceEpoch;
      record.version = (data['version'] as num?)?.toInt() ?? record.version;
      record.syncStatus = SyncStatus.local;
      await AppInitializer.isar.writeTxn(
        () => AppInitializer.isar.viewListFolderRecords.put(record),
      );
    } else {
      final existing = await AppInitializer.isar.medleyFolderRecords
          .filter()
          .folderIdEqualTo(folderKey)
          .findFirst();
      final record = existing ?? MedleyFolderRecord()
        ..folderId = folderKey;
      record.name = data['name']?.toString() ?? path.last;
      record.parentId = parentKey;
      record.userId = userId;
      record.depth = path.length;
      record.modifiedOn = DateTime.now().millisecondsSinceEpoch;
      record.version = (data['version'] as num?)?.toInt() ?? record.version;
      record.syncStatus = SyncStatus.local;
      await AppInitializer.isar.writeTxn(
        () => AppInitializer.isar.medleyFolderRecords.put(record),
      );
    }

    await _syncFolderItemRelationshipRecords(
      collection,
      docId,
      path,
      userId: userId,
    );
  }

  Future<void> _syncFolderItemRelationshipRecords(
    String collection,
    String docId,
    List<String> path, {
    required String userId,
  }) async {
    final folderDocRef = _getFolderDocRef(collection, docId, path);
    final folderDoc = await folderDocRef.get();
    if (!folderDoc.exists) return;

    final data = Map<String, dynamic>.from(
      folderDoc.data() ?? const <String, dynamic>{},
    );
    final hymnIds = _safeStringKeyedMap(data['hymnIds'], 'hymnIds');
    final folderKey = buildRelationshipFolderKey(collection, docId, path);
    final targetItemIds = <String>{};

    for (final hymnId in hymnIds.keys) {
      final itemKey = buildRelationshipItemKey(
        collection,
        docId,
        path,
        hymnId.toString(),
      );
      targetItemIds.add(itemKey);

      if (collection == 'viewlists') {
        final existing = await AppInitializer.isar.viewListItemRecords
            .filter()
            .itemIdEqualTo(itemKey)
            .findFirst();
        final record = existing ?? ViewListItemRecord()
          ..itemId = itemKey;
        record.folderId = folderKey;
        record.hymnId = hymnId.toString();
        record.userId = userId;
        record.modifiedOn = DateTime.now().millisecondsSinceEpoch;
        record.version = (data['version'] as num?)?.toInt() ?? record.version;
        record.syncStatus = SyncStatus.local;
        await AppInitializer.isar.writeTxn(
          () => AppInitializer.isar.viewListItemRecords.put(record),
        );
      } else {
        final existing = await AppInitializer.isar.medleyItemRecords
            .filter()
            .itemIdEqualTo(itemKey)
            .findFirst();
        final record = existing ?? MedleyItemRecord()
          ..itemId = itemKey;
        record.folderId = folderKey;
        record.hymnId = hymnId.toString();
        record.userId = userId;
        record.modifiedOn = DateTime.now().millisecondsSinceEpoch;
        record.version = (data['version'] as num?)?.toInt() ?? record.version;
        record.syncStatus = SyncStatus.local;
        await AppInitializer.isar.writeTxn(
          () => AppInitializer.isar.medleyItemRecords.put(record),
        );
      }
    }

    if (collection == 'viewlists') {
      final existingRecords = await AppInitializer.isar.viewListItemRecords
          .filter()
          .folderIdEqualTo(folderKey)
          .findAll();
      for (final record in existingRecords) {
        if (!targetItemIds.contains(record.itemId)) {
          await AppInitializer.isar.writeTxn(
            () => AppInitializer.isar.viewListItemRecords.delete(record.id),
          );
        }
      }
    } else {
      final existingRecords = await AppInitializer.isar.medleyItemRecords
          .filter()
          .folderIdEqualTo(folderKey)
          .findAll();
      for (final record in existingRecords) {
        if (!targetItemIds.contains(record.itemId)) {
          await AppInitializer.isar.writeTxn(
            () => AppInitializer.isar.medleyItemRecords.delete(record.id),
          );
        }
      }
    }
  }

  Future<void> _syncFolderSubtreeRelationshipRecords(
    String collection,
    String docId,
    List<String> path, {
    required String userId,
    required String deviceId,
  }) async {
    await _syncFolderRelationshipRecords(
      collection,
      docId,
      path,
      userId: userId,
      deviceId: deviceId,
    );
    final childFolders = await _getFolderCollectionRef(
      collection,
      docId,
      path,
    ).get();
    for (final child in childFolders.docs) {
      await _syncFolderSubtreeRelationshipRecords(
        collection,
        docId,
        [...path, child.id],
        userId: userId,
        deviceId: deviceId,
      );
    }
  }

  Future<void> _deleteFolderSubtreeRelationships(
    String collection,
    String docId,
    List<String> path,
  ) async {
    if (path.isEmpty) return;
    final folderKey = buildRelationshipFolderKey(collection, docId, path);
    if (collection == 'viewlists') {
      final folderRecord = await AppInitializer.isar.viewListFolderRecords
          .filter()
          .folderIdEqualTo(folderKey)
          .findFirst();
      if (folderRecord != null) {
        await AppInitializer.isar.writeTxn(
          () =>
              AppInitializer.isar.viewListFolderRecords.delete(folderRecord.id),
        );
      }
      final itemRecords = await AppInitializer.isar.viewListItemRecords
          .filter()
          .folderIdEqualTo(folderKey)
          .findAll();
      for (final itemRecord in itemRecords) {
        await AppInitializer.isar.writeTxn(
          () => AppInitializer.isar.viewListItemRecords.delete(itemRecord.id),
        );
      }
    } else {
      final folderRecord = await AppInitializer.isar.medleyFolderRecords
          .filter()
          .folderIdEqualTo(folderKey)
          .findFirst();
      if (folderRecord != null) {
        await AppInitializer.isar.writeTxn(
          () => AppInitializer.isar.medleyFolderRecords.delete(folderRecord.id),
        );
      }
      final itemRecords = await AppInitializer.isar.medleyItemRecords
          .filter()
          .folderIdEqualTo(folderKey)
          .findAll();
      for (final itemRecord in itemRecords) {
        await AppInitializer.isar.writeTxn(
          () => AppInitializer.isar.medleyItemRecords.delete(itemRecord.id),
        );
      }
    }

    final children = await _getFolderCollectionRef(
      collection,
      docId,
      path,
    ).get();
    for (final child in children.docs) {
      await _deleteFolderSubtreeRelationships(collection, docId, [
        ...path,
        child.id,
      ]);
    }
  }

  Future<void> _copyFolderSubtree(
    String collection,
    String docId,
    List<String> sourcePath,
    List<String> destPath,
    String newFolderId, {
    String? destCollection,
    String? destDocId,
    required String userId,
    required String deviceId,
    required String action,
  }) async {
    final sourceRef = _getFolderDocRef(collection, docId, sourcePath);
    final sourceDoc = await sourceRef.get();
    if (!sourceDoc.exists) return;
    final sourceData = Map<String, dynamic>.from(
      sourceDoc.data() ?? const <String, dynamic>{},
    );
    final targetCollection = destCollection ?? collection;
    final targetDocId = destDocId ?? docId;
    final targetCollectionRef = _getFolderCollectionRef(
      targetCollection,
      targetDocId,
      destPath,
    );
    final siblingSnapshot = await targetCollectionRef.get();
    final siblings = siblingSnapshot.docs
        .map(
          (doc) => Map<String, dynamic>.from(
            doc.data() ?? const <String, dynamic>{},
          ),
        )
        .toList();
    final resolvedName = resolveCopiedFolderName(
      sourceData['name'] ?? sourcePath.last,
      siblings,
    );
    await targetCollectionRef.doc(newFolderId).set({
      ...sourceData,
      'folderId': newFolderId,
      'parentFolderId': destPath.isEmpty ? null : destPath.last,
      'name': resolvedName,
      ..._buildFolderMetadata(
        action,
        userId: userId,
        deviceId: deviceId,
        previousData: sourceData,
      ),
    });
    final sourceEntries = await _getHymnEntryCollectionRef(
      collection,
      docId,
      sourcePath,
    ).get();
    final targetEntriesRef = _getFolderDocRef(targetCollection, targetDocId, [
      ...destPath,
      newFolderId,
    ]).collection('hymn_entries');
    for (final entry in sourceEntries.docs) {
      final entryData = Map<String, dynamic>.from(entry.data());
      await targetEntriesRef.doc(entry.id).set({
        ...entryData,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userId,
        'deviceId': deviceId,
        'lastAction': action,
        'version': ((entryData['version'] as num?)?.toInt() ?? 0) + 1,
      });
    }
    final childFolders = await _getFolderCollectionRef(
      collection,
      docId,
      sourcePath,
    ).get();
    for (final child in childFolders.docs) {
      await _copyFolderSubtree(
        collection,
        docId,
        [...sourcePath, child.id],
        [...destPath, newFolderId],
        child.id,
        destCollection: targetCollection,
        destDocId: targetDocId,
        userId: userId,
        deviceId: deviceId,
        action: action,
      );
    }
  }

  Future<void> _markFolderDeleted(
    String collection,
    String docId,
    List<String> path, {
    required String userId,
    required String deviceId,
  }) async {
    if (path.isEmpty) return;
    final folderRef = _getFolderDocRef(collection, docId, path);
    final current = await folderRef.get();
    if (!current.exists) return;
    final data = Map<String, dynamic>.from(
      current.data() ?? const <String, dynamic>{},
    );
    await folderRef.update({
      ..._buildFolderMetadata(
        'DELETE',
        userId: userId,
        deviceId: deviceId,
        previousData: data,
        isDeleted: true,
      ),
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': userId,
      'isDeleted': true,
    });
    final children = await _getFolderCollectionRef(
      collection,
      docId,
      path,
    ).get();
    for (final child in children.docs) {
      await _markFolderDeleted(
        collection,
        docId,
        [...path, child.id],
        userId: userId,
        deviceId: deviceId,
      );
    }
  }

  Future<void> _deleteFolderSubtree(
    String collection,
    String docId,
    List<String> path, {
    required String userId,
    required String deviceId,
  }) async {
    if (path.isEmpty) return;
    final childFolders = await _getFolderCollectionRef(
      collection,
      docId,
      path,
    ).get();
    for (final child in childFolders.docs) {
      await _deleteFolderSubtree(
        collection,
        docId,
        [...path, child.id],
        userId: userId,
        deviceId: deviceId,
      );
    }
    final entryRef = _getHymnEntryCollectionRef(collection, docId, path);
    final entries = await entryRef.get();
    for (final entry in entries.docs) {
      await entry.reference.delete();
    }
    await _getFolderDocRef(collection, docId, path).delete();
  }

  Map<String, dynamic> _buildFolderMetadata(
    String action, {
    required String userId,
    required String deviceId,
    Map<String, dynamic>? previousData,
    bool create = false,
    bool isDeleted = false,
  }) {
    final version = ((previousData?['version'] as num?)?.toInt() ?? 0) + 1;
    final base = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
      'deletedAt': null,
      'deletedBy': null,
      'isDeleted': isDeleted,
      'version': version,
      'deviceId': deviceId,
      'lastAction': action,
    };
    if (create) {
      base['createdAt'] = FieldValue.serverTimestamp();
      base['createdBy'] = userId;
    }
    return base;
  }

  bool _isSameOrDescendantPath(List<String> sourcePath, List<String> destPath) {
    if (sourcePath.isEmpty) return false;
    if (destPath.length <= sourcePath.length) {
      return _listsEqual(sourcePath, destPath);
    }
    for (var index = 0; index < sourcePath.length; index++) {
      if (sourcePath[index] != destPath[index]) return false;
    }
    return true;
  }

  bool _listsEqual(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  Map<String, dynamic> _safeStringKeyedMap(Object? value, String context) {
    if (value == null) return <String, dynamic>{};
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    print(
      'Unexpected Firestore type for $context: ${value.runtimeType}; using empty map.',
    );
    return <String, dynamic>{};
  }

  List<String> _safeStringList(Object? value, String context) {
    if (value == null) return <String>[];
    if (value is List) {
      return value
          .map((entry) => entry.toString())
          .where((entry) => entry.isNotEmpty)
          .toList();
    }
    print(
      'Unexpected Firestore type for $context: ${value.runtimeType}; using empty list.',
    );
    return <String>[];
  }
}
