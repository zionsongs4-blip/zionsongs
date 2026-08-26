import 'package:flutter/material.dart';

enum ScreenMode { home, filter, custom }

class HymnTabItem {
  final String id;
  final String title;
  final ScreenMode mode;
  final List<String> hymnIds;
  final String? hymnId;
  final dynamic sourceFilter;
  final bool isFullIndexViewer;

  const HymnTabItem({
    required this.id,
    required this.title,
    this.mode = ScreenMode.home,
    this.hymnIds = const [],
    this.hymnId,
    this.sourceFilter,
    this.isFullIndexViewer = false,
  });

  const HymnTabItem.empty({
    required this.id,
    required this.title,
    this.mode = ScreenMode.home,
    this.hymnIds = const [],
    this.hymnId,
    this.sourceFilter,
    this.isFullIndexViewer = false,
  });
}

class HymnTabWorkspaceController extends ChangeNotifier {
  HymnTabWorkspaceController({
    List<HymnTabItem>? initialTabs,
  }) {
    _tabs = List<HymnTabItem>.from(
      initialTabs ?? const <HymnTabItem>[],
    );
  }

  late List<HymnTabItem> _tabs;

  int _activeIndex = 0;

  List<HymnTabItem> get tabs => List.unmodifiable(_tabs);

  int get activeIndex => _activeIndex;

  HymnTabItem? get activeTab {
    if (_tabs.isEmpty ||
        _activeIndex < 0 ||
        _activeIndex >= _tabs.length) {
      return null;
    }

    return _tabs[_activeIndex];
  }

  void openTab(HymnTabItem tab) {
    final existingIndex = _tabs.indexWhere(
      (item) => item.id == tab.id,
    );

    if (existingIndex >= 0) {
      _activeIndex = existingIndex;
      notifyListeners();
      return;
    }

    _tabs.add(tab);
    _activeIndex = _tabs.length - 1;

    notifyListeners();
  }

  void openScreen(HymnTabItem tab) {
    openTab(tab);
  }

  void selectTab(int index) {
    if (index < 0 ||
        index >= _tabs.length ||
        _activeIndex == index) {
      return;
    }

    _activeIndex = index;
    notifyListeners();
  }

  void reorderTabs(int oldIndex, int newIndex) {
    if (_tabs.isEmpty ||
        oldIndex < 0 ||
        oldIndex >= _tabs.length) {
      return;
    }

    if (newIndex < 0 || newIndex >= _tabs.length) {
      return;
    }

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final tab = _tabs.removeAt(oldIndex);

    _tabs.insert(newIndex, tab);

    if (_activeIndex == oldIndex) {
      _activeIndex = newIndex;
    } else if (oldIndex < _activeIndex &&
        newIndex >= _activeIndex) {
      _activeIndex -= 1;
    } else if (oldIndex > _activeIndex &&
        newIndex <= _activeIndex) {
      _activeIndex += 1;
    }

    notifyListeners();
  }

  void closeTabAt(int index) {
    if (_tabs.isEmpty ||
        index < 0 ||
        index >= _tabs.length) {
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
}

class HymnTabWorkspace extends StatefulWidget {
  const HymnTabWorkspace({
    super.key,
    required this.controller,
    required this.builder,
    this.onCloseTab,
  });

  final HymnTabWorkspaceController controller;
  final Widget Function(BuildContext context, HymnTabItem tab) builder;
  final void Function(int index)? onCloseTab;

  @override
  State<HymnTabWorkspace> createState() =>
      _HymnTabWorkspaceState();
}

class _HymnTabWorkspaceState extends State<HymnTabWorkspace> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.controller.tabs;

    if (tabs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ReorderableListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            buildDefaultDragHandles: false,
            onReorder: widget.controller.reorderTabs,
            children: List.generate(
              tabs.length,
              (index) {
                final tab = tabs[index];
                final active =
                    index == widget.controller.activeIndex;

                return Container(
                  key: ValueKey(tab.id),
                  margin: const EdgeInsets.only(right: 8),
                  child: Chip(
                    label: Text(
                      tab.title,
                      overflow: TextOverflow.ellipsis,
                    ),
                    deleteIcon:
                        const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      widget.onCloseTab?.call(index);
                      widget.controller.closeTabAt(index);
                    },
                  ),
                );
              },
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: widget.controller.activeIndex,
            children: tabs
                .map(
                  (tab) => widget.builder(context, tab),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}