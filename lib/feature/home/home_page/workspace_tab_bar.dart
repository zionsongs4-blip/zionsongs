import 'package:flutter/material.dart';

import 'workspace_manager.dart';

class WorkspaceTabBar extends StatelessWidget {
  const WorkspaceTabBar({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onSelect,
    required this.onClose,
    required this.onAddTab,
    required this.onReorder,
  });

  final List<WorkspaceTab> tabs;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;
  final VoidCallback onAddTab;
  final void Function(int oldIndex, int newIndex) onReorder;

  String _titleForDisplay(WorkspaceTab tab) {
    final isContinuousViewer =
        tab.type == WorkspaceTabType.hymn && tab.arguments['viewerMode'] == 'continuous';
    if (isContinuousViewer) {
      return 'continuous';
    }

    final value = tab.title.trim();
    return value.isEmpty ? 'Untitled' : value;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            Expanded(
              child: ReorderableListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                buildDefaultDragHandles: false,
                onReorder: onReorder,
                children: List.generate(tabs.length, (index) {
                  final tab = tabs[index];
                  final isActive = index == activeIndex;
                  return Container(
                    key: ValueKey(tab.id),
                    margin: const EdgeInsets.only(right: 6, top: 2, bottom: 2),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => onSelect(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isActive
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  Icons.drag_indicator,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                _titleForDisplay(tab),
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                  color: isActive
                                      ? Theme.of(context).colorScheme.onPrimaryContainer
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (tab.closable)
                              GestureDetector(
                                onTap: () => onClose(index),
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New tab',
              onPressed: onAddTab,
            ),
          ],
        ),
      ),
    );
  }
}
