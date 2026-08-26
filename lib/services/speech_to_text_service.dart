import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as st;

enum SpeechFieldKind {
  english,
  hindi,
  malayalamHindi,
}

class SpeechInputResult {
  const SpeechInputResult({
    required this.success,
    this.text = '',
    this.errorMessage,
  });

  final bool success;
  final String text;
  final String? errorMessage;
}

class SpeechToTextService {
  SpeechToTextService._();

  static final SpeechToTextService instance = SpeechToTextService._();

  final st.SpeechToText _speech = st.SpeechToText();

  bool _initialized = false;
  bool _isListening = false;
  String? _lastError;

  bool get isListening => _isListening;
  String? get lastError => _lastError;

  Future<bool> initialize() async {
    if (_initialized) {
      return true;
    }

    try {
      _initialized = await _speech.initialize(
        onError: (error) {
          final message = error.errorMsg;
          _lastError = message.isEmpty ? 'Voice recognition error' : message;
          _isListening = false;
        },
        onStatus: (status) {
          _isListening = status == 'listening';
          if (status == 'notListening' || status == 'done') {
            _isListening = false;
          }
        },
      );
    } catch (_) {
      _initialized = false;
      _lastError = 'Speech recognition is not available on this device.';
    }

    return _initialized;
  }

  Future<PermissionStatus> ensurePermission() async {
    final available = await initialize();
    if (!available) {
      return PermissionStatus.denied;
    }

    final status = await Permission.microphone.status;
    if (status.isGranted || status.isPermanentlyDenied) {
      return status;
    }

    return Permission.microphone.request();
  }

  Future<SpeechInputResult> listenForText({
    required SpeechFieldKind fieldKind,
  }) async {
    try {
      final permission = await ensurePermission();
      if (!permission.isGranted) {
        if (permission.isPermanentlyDenied) {
          return const SpeechInputResult(
            success: false,
            errorMessage:
                'Microphone access is permanently disabled. Please enable it in Android Settings.',
          );
        }

        return const SpeechInputResult(
          success: false,
          errorMessage:
              'Microphone permission is required for voice input. Please allow it and try again.',
        );
      }

      final locales = await _speech.locales();
      final localeId = resolveLocaleIdForField(
        supportedLocaleIds: locales.map((locale) => locale.localeId).toList(),
        fieldKind: fieldKind,
      );

      if (localeId == null) {
        return SpeechInputResult(
          success: false,
          errorMessage:
              'No supported speech language is available for ${_describeField(fieldKind)} on this device.',
        );
      }

      final completer = Completer<SpeechInputResult>();

      _speech.listen(
        listenOptions: st.SpeechListenOptions(
          localeId: localeId,
          cancelOnError: true,
          partialResults: true,
        ),
        onResult: (result) {
          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            if (!completer.isCompleted) {
              completer.complete(
                SpeechInputResult(
                  success: true,
                  text: result.recognizedWords.trim(),
                ),
              );
            }
          }
        },
      );

      _isListening = true;

      final outcome = await completer.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () => const SpeechInputResult(
          success: false,
          errorMessage: 'Voice input timed out. Please try again.',
        ),
      );

      return outcome;
    } catch (_) {
      return const SpeechInputResult(
        success: false,
        errorMessage: 'Voice input failed. Please try again.',
      );
    } finally {
      await stopListening();
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) {
      return;
    }

    try {
      await _speech.stop();
    } catch (_) {
      // Ignore stop errors; the UI should continue normally.
    }

    _isListening = false;
  }

  Future<void> dispose() async {
    await stopListening();
    _initialized = false;
  }

  @visibleForTesting
  static String? resolveLocaleIdForField({
    required List<String> supportedLocaleIds,
    required SpeechFieldKind fieldKind,
  }) {
    if (supportedLocaleIds.isEmpty) {
      return null;
    }

    final normalized = supportedLocaleIds
        .map((localeId) => localeId.trim())
        .where((localeId) => localeId.isNotEmpty)
        .toList();

    if (normalized.isEmpty) {
      return null;
    }

    final candidates = <String>[];

    switch (fieldKind) {
      case SpeechFieldKind.english:
        candidates.addAll(['en_US', 'en_GB', 'en_AU', 'en_IN', 'en']);
        break;
      case SpeechFieldKind.hindi:
        candidates.addAll(['hi_IN', 'hi', 'mr_IN', 'mr']);
        break;
      case SpeechFieldKind.malayalamHindi:
        candidates.addAll(['hi_IN', 'hi', 'en_US', 'en']);
        break;
    }

    for (final candidate in candidates) {
      final match = normalized.firstWhere(
        (localeId) =>
            localeId.toLowerCase() == candidate.toLowerCase() ||
            localeId.toLowerCase().startsWith('${candidate.toLowerCase()}_') ||
            localeId.toLowerCase().startsWith('${candidate.toLowerCase()}-'),
        orElse: () => '',
      );

      if (match.isNotEmpty) {
        return match;
      }
    }

    if (fieldKind == SpeechFieldKind.english) {
      final english = normalized.firstWhere(
        (localeId) => localeId.toLowerCase().startsWith('en'),
        orElse: () => '',
      );
      if (english.isNotEmpty) return english;
    }

    if (fieldKind == SpeechFieldKind.hindi || fieldKind == SpeechFieldKind.malayalamHindi) {
      final hindiLike = normalized.firstWhere(
        (localeId) => localeId.toLowerCase().startsWith('hi') ||
            localeId.toLowerCase().startsWith('mr'),
        orElse: () => '',
      );
      if (hindiLike.isNotEmpty) return hindiLike;
    }

    return normalized.first;
  }

  String _describeField(SpeechFieldKind fieldKind) {
    switch (fieldKind) {
      case SpeechFieldKind.english:
        return 'English';
      case SpeechFieldKind.hindi:
        return 'Hindi';
      case SpeechFieldKind.malayalamHindi:
        return 'Malayalam/Devanagari';
    }
  }
}
