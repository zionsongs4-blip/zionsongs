import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import 'home_search_controller.dart';
import 'search_service.dart';

class HomeSearchDialog extends StatefulWidget {
  const HomeSearchDialog({
    super.key,
    required this.isar,
    this.onOpenHymn,
  });

  final Isar isar;
  final void Function(String hymnId)? onOpenHymn;

  @override
  State<HomeSearchDialog> createState() => _HomeSearchDialogState();
}

class _HomeSearchDialogState extends State<HomeSearchDialog> {
  late final HomeSearchController _controller;
  late final TextEditingController _textEditingController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();

    _textEditingController = TextEditingController();
    _focusNode = FocusNode();

    _controller = SearchService.instance.controller;
    _controller.addListener(_refresh);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _focusNode.dispose();
    _textEditingController.dispose();
    super.dispose();
  }

  Widget _buildSuggestionText(BuildContext context, String suggestion) {
    final query = _textEditingController.text.trim();
    if (query.isEmpty) {
      return Text(
        suggestion,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyLarge,
      );
    }

    final lowerSuggestion = suggestion.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerSuggestion.indexOf(lowerQuery);

    if (index == -1) {
      return Text(
        suggestion,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyLarge,
      );
    }

    final before = suggestion.substring(0, index);
    final match = suggestion.substring(index, index + query.length);
    final after = suggestion.substring(index + query.length);

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyLarge,
        children: [
          if (before.isNotEmpty)
            TextSpan(text: before),
          TextSpan(
            text: match,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (after.isNotEmpty)
            TextSpan(
              text: after,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    final maxHeight = (mediaQuery.size.height * 0.88).clamp(
      320.0,
      mediaQuery.size.height - 24.0,
    );

    final maxWidth = mediaQuery.size.width - 24.0;

    final suggestions = _controller.suggestions.take(10).toList();

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: maxWidth),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _textEditingController,
                  focusNode: _focusNode,
                  cursorColor: Theme.of(context).colorScheme.primary,
                  maxLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Search hymns (title or lyrics)...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _textEditingController,
                      builder: (context, value, _) {
                        return IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            if (value.text.isNotEmpty) {
                              _textEditingController.clear();
                              _controller.onQueryChanged('');
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                        );
                      },
                    ),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: _controller.onQueryChanged,
                ),
              ),

              if (_controller.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                ),
              Expanded(
                child: !_controller.loading &&
                        suggestions.isEmpty &&
                        _textEditingController.text.isNotEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No suggestions found',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          4,
                          0,
                          4,
                          MediaQuery.of(context).viewInsets.bottom +
                              kMinInteractiveDimension * 4,
                        ),
                        itemCount: suggestions.length,
                        itemBuilder: (_, index) {
                          final suggestion = suggestions[index];
                          return ListTile(
                            title: _buildSuggestionText(context, suggestion),
                            onTap: () async {
                              await _controller.searchImmediately(suggestion);
                              _focusNode.unfocus();
                              Navigator.of(context).pop(suggestion);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
