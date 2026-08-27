import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'feature/access_control/login_screen.dart';
import 'feature/home/hymn/hymn_auth_service.dart';
import 'feature/home/hymn/app_initializer.dart';
import 'feature/home/app_bar/theme_service.dart';
import 'feature/home/home_page/home_page.dart';
import 'services/async_initialization_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.red,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            details.exceptionAsString(),
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  try {
    print('📱 Zion Songs: Starting app initialization');

    // PHASE 1: MANDATORY LOCAL STARTUP (no network required)
    print('🔹 Phase 1: Initializing local storage...');
    await AppInitializer.init();
    print('✅ Local storage (Isar) ready');

    // PHASE 2: OPTIONAL REMOTE INITIALIZATION (background, can fail)
    print('🔹 Phase 2: Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized');

    // NOTE: FirestoreInitializer.initialize() and HymnMasterSyncService.start()
    // are now called asynchronously after the app UI loads via AsyncInitializationService.
    // This ensures the app never waits for network connectivity to display the home screen.

    print('🎉 App ready to display');
    runApp(const MyApp());
  } catch (e, s) {
    print('❌ Critical startup error: $e');
    print(s);
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.red,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                "$e\n\n$s",
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Start background initialization after the first frame is rendered.
    // This ensures the UI is visible to the user before we attempt remote sync.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AsyncInitializationService.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ThemeService.mode,
      builder: (context, ThemeMode mode, _) {
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            final user = snapshot.data ?? FirebaseAuth.instance.currentUser;
            final isAuthenticated = user != null;
            if (user != null && AuthService.userId != user.uid) {
              unawaited(AuthService.init(user.uid));
            }

            return MaterialApp(
              debugShowCheckedModeBanner: false,
              themeMode: mode,
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              home: isAuthenticated ? const HomePage() : const LoginScreen(),
            );
          },
        );
      },
    );
  }
}
