import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class FirestoreInitializer {
  FirestoreInitializer._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int _maxRetryCount = 4;
  static final Duration _initialBackoff = const Duration(milliseconds: 250);
  static final Duration _maxBackoff = const Duration(seconds: 3);
  static const Set<String> _transientFirestoreCodes = {
    'unavailable',
    'deadline-exceeded',
    'aborted',
    'internal',
    'unknown',
    'resource-exhausted',
    'unimplemented',
  };

  static Future<void> initialize() async {
    await _seedOperation(() => _seedCollection('hierarchy'), 'hierarchy');
    await _seedOperation(() => _seedCollection('viewlists'), 'viewlists');
    await _seedOperation(() => _seedCollection('medleys'), 'medleys');
    await _seedOperation(_seedRoles, 'roles');
    await _seedOperation(_seedPermissions, 'permissions');
    await _seedOperation(_seedSpecialPermissions, 'special_permissions');
    await _seedOperation(_seedFellowships, 'fellowships');
    await _seedOperation(_seedSystemSettings, 'system_settings');
  }

  static Future<void> _seedOperation(
    Future<void> Function() operation,
    String name,
  ) async {
    try {
      await operation();
      _log('Firestore seed completed: $name');
    } catch (error, stackTrace) {
      _log('Firestore seed failed: $name', error, stackTrace);
    }
  }

  static Future<void> _seedCollection(String collectionName) async {
    final jsonString =
        await rootBundle.loadString('assets/firestore_seed/hierarchy.json');

    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    final List<dynamic> items = jsonMap['hierarchy'];

    for (final item in items) {
      if (item['parent'] == null) {
        await _seedCollectionItem(
          _firestore.collection(collectionName),
          item,
          items,
        );
      }
    }
  }

  static Future<void> _seedCollectionItem(
    CollectionReference<Map<String, dynamic>> collectionRef,
    Map<String, dynamic> item,
    List<dynamic> allItems,
  ) async {
    final itemId = item['id']?.toString();
    if (itemId == null || itemId.isEmpty) {
      _log('Skipping seed item with invalid id in ${collectionRef.path}');
      return;
    }

    final docRef = collectionRef.doc(itemId);
    try {
      final doc = await _getDocument(docRef);
      if (!doc.exists) {
        await _setDocument(
          docRef,
          {
            'id': item['id'],
            'name': item['name'],
            'type': item['type'],
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      }
    } catch (error, stackTrace) {
      _log('Skipping collection item ${docRef.path} due to Firestore error',
          error,
          stackTrace);
      return;
    }

    final childItems =
        allItems.where((child) => child['parent'] == itemId).toList();
    for (final childItem in childItems) {
      await _seedCollectionItem(
        collectionRef.doc(itemId).collection('folders'),
        childItem,
        allItems,
      );
    }
  }

  static Future<void> _seedRoles() async {
    final jsonString =
        await rootBundle.loadString('assets/firestore_seed/roles.json');
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    final List<dynamic> items = jsonMap['roles'];

    for (final item in items) {
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) {
        _log('Skipping role seed item with invalid id');
        continue;
      }

      final docRef = _firestore.collection('roles').doc(id);
      try {
        final doc = await _getDocument(docRef);
        if (!doc.exists) {
          await _setDocument(docRef, Map<String, dynamic>.from(item));
        }
      } catch (error, stackTrace) {
        _log('Skipping role $id due to Firestore error', error, stackTrace);
      }
    }
  }

  static Future<void> _seedPermissions() async {
    final jsonString =
        await rootBundle.loadString('assets/firestore_seed/permissions.json');
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    final Map<String, dynamic> items = Map<String, dynamic>.from(jsonMap['permissions'] ?? {});

    for (final entry in items.entries) {
      final id = entry.key.toString();
      final docRef = _firestore.collection('permissions').doc(id);
      try {
        final doc = await _getDocument(docRef);
        if (!doc.exists) {
          await _setDocument(docRef, Map<String, dynamic>.from(entry.value));
        }
      } catch (error, stackTrace) {
        _log('Skipping permission $id due to Firestore error', error, stackTrace);
      }
    }
  }

  static Future<void> _seedSpecialPermissions() async {
    final jsonString = await rootBundle.loadString(
      'assets/firestore_seed/special_permissions.json',
    );
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    final List<dynamic> items = jsonMap['specialPermissions'] ?? <dynamic>[];

    for (final item in items) {
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) {
        _log('Skipping special permission item with invalid id');
        continue;
      }

      final docRef = _firestore.collection('special_permissions').doc(id);
      try {
        final doc = await _getDocument(docRef);
        if (!doc.exists) {
          await _setDocument(docRef, Map<String, dynamic>.from(item));
        }
      } catch (error, stackTrace) {
        _log('Skipping special permission $id due to Firestore error',
            error,
            stackTrace);
      }
    }
  }

  static Future<void> _seedFellowships() async {
    final jsonString = await rootBundle.loadString(
      'assets/firestore_seed/fellowships.json',
    );
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    final List<dynamic> items = jsonMap['fellowships'] ?? <dynamic>[];

    for (final item in items) {
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) {
        _log('Skipping fellowship item with invalid id');
        continue;
      }

      final docRef = _firestore.collection('fellowships').doc(id);
      try {
        final doc = await _getDocument(docRef);
        if (!doc.exists) {
          await _setDocument(docRef, Map<String, dynamic>.from(item));
        }
      } catch (error, stackTrace) {
        _log('Skipping fellowship $id due to Firestore error', error, stackTrace);
      }
    }
  }

  static Future<void> _seedSystemSettings() async {
    final jsonString =
        await rootBundle.loadString('assets/firestore_seed/system_settings.json');
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    final docRef = _firestore.collection('system_settings').doc('app');

    try {
      final doc = await _getDocument(docRef);
      if (!doc.exists) {
        await _setDocument(docRef, Map<String, dynamic>.from(jsonMap['system']));
      }
    } catch (error, stackTrace) {
      _log('Skipping system settings due to Firestore error', error, stackTrace);
    }
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> _getDocument(
    DocumentReference<Map<String, dynamic>> docRef,
  ) async {
    return await _retryFirestore(
      () => docRef.get(),
      'get ${docRef.path}',
    );
  }

  static Future<void> _setDocument(
    DocumentReference<Map<String, dynamic>> docRef,
    Map<String, dynamic> data,
  ) async {
    await _retryFirestore(
      () => docRef.set(data),
      'set ${docRef.path}',
    );
  }

  static Future<T> _retryFirestore<T>(
    Future<T> Function() operation,
    String description,
  ) async {
    var attempt = 0;
    var backoff = _initialBackoff;

    while (true) {
      try {
        return await operation();
      } on FirebaseException catch (error, stackTrace) {
        if (_isTransientFirestoreError(error) && attempt < _maxRetryCount) {
          attempt += 1;
          _log(
            'Transient Firestore error for $description (attempt $attempt): '
            '${error.code} ${error.message}',
            error,
            stackTrace,
          );
          await Future.delayed(backoff);
          backoff = _nextBackoff(backoff);
          continue;
        }
        rethrow;
      } on TimeoutException catch (error, stackTrace) {
        if (attempt < _maxRetryCount) {
          attempt += 1;
          _log(
            'Timeout during $description (attempt $attempt): ${error.message}',
            error,
            stackTrace,
          );
          await Future.delayed(backoff);
          backoff = _nextBackoff(backoff);
          continue;
        }
        rethrow;
      } on SocketException catch (error, stackTrace) {
        if (attempt < _maxRetryCount) {
          attempt += 1;
          _log(
            'Network error during $description (attempt $attempt): ${error.message}',
            error,
            stackTrace,
          );
          await Future.delayed(backoff);
          backoff = _nextBackoff(backoff);
          continue;
        }
        rethrow;
      }
    }
  }

  static bool _isTransientFirestoreError(FirebaseException error) {
    return _transientFirestoreCodes.contains(error.code);
  }

  static Duration _nextBackoff(Duration previous) {
    final next = previous * 2;
    return next <= _maxBackoff ? next : _maxBackoff;
  }

  static void _log(String message, [Object? error, StackTrace? stackTrace]) {
    // ignore: avoid_print
    print('FirestoreInitializer: $message');
    if (error != null) {
      // ignore: avoid_print
      print('  error: $error');
    }
    if (stackTrace != null) {
      // ignore: avoid_print
      print(stackTrace);
    }
  }
}
