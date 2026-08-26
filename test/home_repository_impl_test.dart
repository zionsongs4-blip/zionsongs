import 'package:flutter_test/flutter_test.dart';
import 'package:zionsongs/feature/home/app_bar/home_repository_impl.dart';

void main() {
  group('HomeRepositoryImpl serial parsing', () {
    test('parses numeric serials from Firestore values', () {
      expect(HomeRepositoryImpl.parseSerialNumber('ZS0125'), 125);
      expect(HomeRepositoryImpl.parseSerialNumber('125'), 125);
      expect(HomeRepositoryImpl.parseSerialNumber('0012'), 12);
    });

    test('falls back to hymn ids when no explicit serial value exists', () {
      expect(HomeRepositoryImpl.parseSerialNumber(null, hymnId: 'ZS0125'), 125);
      expect(HomeRepositoryImpl.parseSerialNumber(null, hymnId: 'abc'), isNull);
    });
  });
}
