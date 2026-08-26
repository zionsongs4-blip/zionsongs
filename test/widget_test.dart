// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:zionsongs/feature/home/app_bar/home_app_bar.dart';
import 'package:zionsongs/feature/home/home_page/home_page.dart';
import 'package:zionsongs/feature/home/home_page/workspace_manager.dart';
import 'package:zionsongs/feature/home/search/home_search_repository.dart';

void main() {
  group('shouldShowSearchBarClearButton', () {
    test('returns true when focus is active', () {
      expect(
        shouldShowSearchBarClearButton(
          hasFocus: true,
          text: '',
          hasActiveSuggestions: false,
        ),
        isTrue,
      );
    });

    test('returns true when the text field contains text', () {
      expect(
        shouldShowSearchBarClearButton(
          hasFocus: false,
          text: 'test',
          hasActiveSuggestions: false,
        ),
        isTrue,
      );
    });

    test('returns true when search suggestions are present', () {
      expect(
        shouldShowSearchBarClearButton(
          hasFocus: false,
          text: '',
          hasActiveSuggestions: true,
        ),
        isTrue,
      );
    });

    test('returns false when search is empty and inactive', () {
      expect(
        shouldShowSearchBarClearButton(
          hasFocus: false,
          text: '',
          hasActiveSuggestions: false,
        ),
        isFalse,
      );
    });

    test('preserves Hindi text during normalization', () {
      expect(
        normalizeSearchText('अर्जुन की पुकार'),
        'अर्जुन की पुकार',
      );
    });

    test('excludes Home and Continuous tabs from eligible open destinations', () {
      expect(
        isEligibleOpenDestinationTab(const WorkspaceTab(
          id: 'home',
          title: 'Home',
          type: WorkspaceTabType.home,
        )),
        isFalse,
      );

      expect(
        isEligibleOpenDestinationTab(const WorkspaceTab(
          id: 'continuous_viewer',
          title: 'Continuous',
          type: WorkspaceTabType.hymn,
          arguments: {'viewerMode': 'continuous'},
        )),
        isFalse,
      );
    });

    test('allows hymn and selection tabs as eligible open destinations', () {
      expect(
        isEligibleOpenDestinationTab(const WorkspaceTab(
          id: 'tab_1',
          title: 'Sunday Service',
          type: WorkspaceTabType.hymn,
          arguments: {'viewerMode': 'standalone'},
        )),
        isTrue,
      );

      expect(
        isEligibleOpenDestinationTab(const WorkspaceTab(
          id: 'tab_2',
          title: 'Custom Selection',
          type: WorkspaceTabType.selection,
        )),
        isTrue,
      );
    });
  });
}
