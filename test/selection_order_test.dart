import 'package:flutter_test/flutter_test.dart';
import 'package:zionsongs/feature/home/app_bar/home_selection_controller.dart';

void main() {
  group('HomeSelectionController', () {
    test('preserves selection order when adding hymns', () {
      final controller = HomeSelectionController();

      // Select hymns in a specific order
      controller.select('h1');
      controller.select('h2');
      controller.select('h3');

      // Convert to list and verify order is preserved
      final ids = List<String>.from(controller.selectedHymnIds);
      expect(ids, equals(['h1', 'h2', 'h3']));
    });

    test('preserves order when toggling selections', () {
      final controller = HomeSelectionController();

      controller.select('h1');
      controller.select('h2');
      controller.toggle('h1'); // Remove h1
      controller.toggle('h4'); // Add h4

      final ids = List<String>.from(controller.selectedHymnIds);
      // Should be: h2 (still there), h4 (added after toggle)
      expect(ids, equals(['h2', 'h4']));
    });

    test('preserves order when using selectAll', () {
      final controller = HomeSelectionController();

      controller.selectAll(['h3', 'h1', 'h2']);

      final ids = List<String>.from(controller.selectedHymnIds);
      expect(ids, equals(['h3', 'h1', 'h2']));
    });

    test('clear removes all selections', () {
      final controller = HomeSelectionController();

      controller.select('h1');
      controller.select('h2');
      controller.clear();

      expect(controller.selectedHymnIds, isEmpty);
    });
  });
}
