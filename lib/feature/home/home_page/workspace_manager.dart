import 'package:flutter/foundation.dart';

enum WorkspaceTabType {
  home,
  hymn,
  selection,
  favorites,
  viewList,
  medley,
}

class WorkspaceTab {
  final String id;
  final String title;
  final WorkspaceTabType type;
  final bool closable;
  final Map<String, dynamic> arguments;

  const WorkspaceTab({
    required this.id,
    required this.title,
    this.type = WorkspaceTabType.home,
    this.closable = true,
    this.arguments = const {},
  });

  WorkspaceTab copyWith({
    String? id,
    String? title,
    WorkspaceTabType? type,
    bool? closable,
    Map<String, dynamic>? arguments,
  }) {
    return WorkspaceTab(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      closable: closable ?? this.closable,
      arguments: arguments ?? this.arguments,
    );
  }
}

class WorkspaceManager extends ChangeNotifier {
  WorkspaceManager({List<WorkspaceTab>? initialTabs}) {
    _tabs = List<WorkspaceTab>.from(initialTabs ?? const <WorkspaceTab>[]);
  }

  late List<WorkspaceTab> _tabs;
  int _activeIndex = 0;

  List<WorkspaceTab> get tabs => List.unmodifiable(_tabs);
  int get activeIndex => _activeIndex;
  WorkspaceTab? get activeTab {
    if (_tabs.isEmpty || _activeIndex < 0 || _activeIndex >= _tabs.length) {
      return null;
    }
    return _tabs[_activeIndex];
  }

  void openTab(WorkspaceTab tab) {
    final existingIndex = _tabs.indexWhere((item) {
      return item.type == tab.type && item.id == tab.id;
    });

    if (existingIndex >= 0) {
      _activeIndex = existingIndex;
      notifyListeners();
      return;
    }

    _tabs.add(tab);
    _activeIndex = _tabs.length - 1;
    notifyListeners();
  }

  void upsertTab(WorkspaceTab tab) {
    final existingIndex = _tabs.indexWhere((item) {
      return item.type == tab.type && item.id == tab.id;
    });

    if (existingIndex >= 0) {
      _tabs[existingIndex] = tab;
      _activeIndex = existingIndex;
      notifyListeners();
      return;
    }

    _tabs.add(tab);
    _activeIndex = _tabs.length - 1;
    notifyListeners();
  }

  void activateTab(int index) {
    if (index < 0 || index >= _tabs.length || index == _activeIndex) {
      return;
    }
    _activeIndex = index;
    notifyListeners();
  }

  void closeTabAt(int index) {
    if (index < 0 || index >= _tabs.length) {
      return;
    }
    final tab = _tabs[index];
    if (!tab.closable) {
      return;
    }
    _tabs.removeAt(index);
    if (_tabs.isEmpty) {
      _activeIndex = 0;
      notifyListeners();
      return;
    }
    if (_activeIndex >= _tabs.length) {
      _activeIndex = _tabs.length - 1;
    } else if (index < _activeIndex) {
      _activeIndex -= 1;
    }
    notifyListeners();
  }

  void closeTabById(String id) {
    final index = _tabs.indexWhere((item) => item.id == id);
    if (index == -1) return;
    closeTabAt(index);
  }

  void reorderTabs(int oldIndex, int newIndex) {
    if (_tabs.isEmpty || oldIndex < 0 || oldIndex >= _tabs.length) {
      return;
    }
    if (newIndex < 0 || newIndex > _tabs.length) {
      return;
    }
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final tab = _tabs.removeAt(oldIndex);
    _tabs.insert(newIndex, tab);
    if (_activeIndex == oldIndex) {
      _activeIndex = newIndex;
    } else if (oldIndex < _activeIndex && newIndex >= _activeIndex) {
      _activeIndex -= 1;
    } else if (oldIndex > _activeIndex && newIndex <= _activeIndex) {
      _activeIndex += 1;
    }
    notifyListeners();
  }

  void replaceTabAt(int index, WorkspaceTab tab) {
    if (index < 0 || index >= _tabs.length) {
      return;
    }
    _tabs[index] = tab;
    notifyListeners();
  }

  int findExistingTabIndex(WorkspaceTabType type, {String? uniqueId}) {
    if (uniqueId != null) {
      final index = _tabs.indexWhere((item) => item.type == type && item.id == uniqueId);
      if (index >= 0) return index;
    }
    return _tabs.indexWhere((item) => item.type == type);
  }

  WorkspaceTab? findExistingTab(WorkspaceTabType type, {String? uniqueId}) {
    final index = findExistingTabIndex(type, uniqueId: uniqueId);
    if (index < 0) return null;
    return _tabs[index];
  }
}

class HymnTabWorkspaceController extends WorkspaceManager {
  HymnTabWorkspaceController({List<WorkspaceTab>? initialTabs})
      : super(initialTabs: initialTabs);
}
