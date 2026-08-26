import 'package:firebase_core/firebase_core.dart';

import '../feature/access_control/firestore_initializer.dart';
import '../feature/home/hymn/hymn_master_sync_service.dart';

/// ================================================================
/// AsyncInitializationService
/// ================================================================
/// Handles background initialization tasks that don't need to block
/// the app startup. This service is designed for offline-first apps
/// where the user can interact with local data while remote sync
/// happens in the background.
///
/// This service runs AFTER the main app UI is visible to the user.
/// ================================================================
class AsyncInitializationService {
  static bool _started = false;

  /// Start background initialization tasks.
  /// - Firestore database seeding (non-blocking, errors logged)
  /// - Firestore real-time hymn synchronization (non-blocking listener)
  /// - Firebase initialization (already done in main.dart, but ensures it's ready)
  ///
  /// Call this after the app UI is visible (e.g., in HomePage or after
  /// MyApp completes its first build).
  static Future<void> start() async {
    if (_started) {
      return;
    }

    _started = true;
    print('🚀 AsyncInitializationService: Starting background initialization');

    // Ensure Firebase is initialized (should already be done in main.dart)
    if (!Firebase.apps.isEmpty) {
      print('✅ Firebase already initialized');
    }

    // Start background Firestore seeding
    _startFirestoreSeeding();

    // Start background Firestore real-time sync
    _startRealtimeSync();

    print('🌍 AsyncInitializationService: Background tasks scheduled');
  }

  /// Seed Firestore collections in the background.
  /// Errors are logged but do not affect app functionality.
  static void _startFirestoreSeeding() {
    print('📋 Starting Firestore seeding...');

    FirestoreInitializer.initialize().then((_) {
      print('✅ Firestore seeding completed');
    }).catchError((error, stackTrace) {
      print('⚠️ Firestore seeding failed (app can continue offline)');
      print('  Error: $error');
      print('  This is expected when offline.');
    });
  }

  /// Start real-time Firestore sync for hymns.
  /// This runs as a long-lived listener, not awaited.
  /// Errors are handled internally by HymnMasterSyncService.
  static void _startRealtimeSync() {
    print('🔄 Starting real-time Firestore sync...');

    // Fire-and-forget: do NOT await this
    HymnMasterSyncService.start().catchError((error, stackTrace) {
      print('⚠️ Real-time sync failed to start (app can continue offline)');
      print('  Error: $error');
    });
  }

  /// Stop background tasks (e.g., on app shutdown).
  static void stop() {
    HymnMasterSyncService.stop();
    _started = false;
    print('⛔ AsyncInitializationService stopped');
  }
}
