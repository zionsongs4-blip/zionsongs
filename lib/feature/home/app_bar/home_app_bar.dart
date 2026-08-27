import 'package:flutter/material.dart';

import '../../../services/speech_to_text_service.dart';
import 'home_app_bar_logic.dart';
import 'home_selection_controller.dart';
import '../search/home_search_controller.dart';
import '../search/home_search_models.dart';
import '../search/search_service.dart';

bool shouldShowSearchBarClearButton({
  required bool hasFocus,
  required String text,
  required bool hasActiveSuggestions,
}) {
  final trimmedText = text.trim();
  return hasFocus || trimmedText.isNotEmpty || hasActiveSuggestions;
}

/// Note: Converted to StatefulWidget to support in-appbar search mode with
/// live suggestions and focus handling.

/// ===============================================================
/// HomeAppBar
/// ---------------------------------------------------------------
/// Global AppBar used throughout Zion Songs.
/// ===============================================================
class HomeAppBar extends StatefulWidget implements PreferredSizeWidget {
  const HomeAppBar({
    super.key,
    required this.title,
    required this.logic,
    required this.selectionController,
    required this.canShowPresentation,
    this.onSearchChanged,
    this.onOpenHymn,
  });

  final String title;
  final HomeAppBarLogic logic;
  final HomeSelectionController selectionController;
  final bool canShowPresentation;
  final void Function(String text, List<HomeSearchResult> results)?
  onSearchChanged;
  final void Function(String hymnId)? onOpenHymn;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 350);

  @override
  State<HomeAppBar> createState() => _HomeAppBarState();
}

class _HomeAppBarState extends State<HomeAppBar> {
  bool _searchActive = false;
  bool _isListeningForSearch = false;
  bool _searchUsesHindiFont = false;
  late final TextEditingController _searchController;
  late final FocusNode _focusNode;
  late final HomeSearchController? _searchControllerBackend;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);

    _searchControllerBackend = SearchService.instance.controller;
    _searchControllerBackend?.addListener(_onSearchResults);
  }

  void _onSearchResults() {
    if (!mounted) return;
    final backend = _searchControllerBackend;
    widget.onSearchChanged?.call(
      _searchController.text,
      backend == null
          ? const <HomeSearchResult>[]
          : List<HomeSearchResult>.from(backend.results),
    );
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _searchControllerBackend?.removeListener(_onSearchResults);
    // Do not dispose the shared controller.
    super.dispose();
  }

  void _closeSearch() {
    _searchController.clear();
    _searchControllerBackend?.clear();
    widget.onSearchChanged?.call('', const <HomeSearchResult>[]);
    _focusNode.unfocus();

    setState(() {
      _searchActive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.selectionController,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              elevation: 0,
              centerTitle: false,
              titleSpacing: _searchActive ? 0 : 12,
              automaticallyImplyLeading: false,
                leading: !_searchActive &&
                      widget.selectionController.mode == HomeSelectionMode.none
                  ? Builder(
                      builder: (context) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: IconButton(
                            icon: const Icon(Icons.menu),
                            tooltip: 'Menu',
                            onPressed: () {
                              Scaffold.of(context).openDrawer();
                            },
                          ),
                        );
                      },
                    )
                  : null,
              title: _searchActive
                  ? Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          tooltip: 'Back',
                          onPressed: _closeSearch,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _buildSearchField(),
                          ),
                        ),
                      ],
                    )
                  : _buildTitle(),
              actions: _searchActive ? const [] : _buildActionButtons(context),
            ),
            if (_searchActive) _buildSearchResults(context),
          ],
        );
      },
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final backend = _searchControllerBackend;
    final suggestions = backend == null ? const <String>[] : backend.suggestions;

    if (_searchController.text.trim().isEmpty || suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 6,
      color: Theme.of(context).cardColor,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 350),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: suggestions.length,
            separatorBuilder: (context, index) => const Divider(height: 0.5, thickness: 0.5),
          itemBuilder: (context, index) {
            final text = suggestions[index].trim();
            return ListTile(
              dense: true,
              visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              title: _buildSuggestionText(context, text),
              onTap: () async {
                final backend = _searchControllerBackend;
                if (backend != null) {
                  await backend.searchImmediately(text);
                }

                final allResults = backend == null
                    ? const <HomeSearchResult>[]
                    : List<HomeSearchResult>.from(backend.results);

                widget.onSearchChanged?.call(text, allResults);
                _searchController.text = text;
                _focusNode.unfocus();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTitle() {
    switch (widget.selectionController.mode) {
      case HomeSelectionMode.none:
        return IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: () {
            setState(() {
              _searchActive = true;
            });
            _focusNode.requestFocus();
          },
        );

      case HomeSelectionMode.single:
      case HomeSelectionMode.multiple:
        return Text('${widget.selectionController.selectedCount} Selected');
    }
  }

  List<Widget> _buildActionButtons(BuildContext context) {
    List<Widget> buttons;
    switch (widget.selectionController.mode) {
      case HomeSelectionMode.none:
        buttons = _normalButtons(context);
        break;
      case HomeSelectionMode.single:
        buttons = _singleSelectionButtons(context);
        break;
      case HomeSelectionMode.multiple:
        buttons = _multipleSelectionButtons(context);
        break;
    }

    return [
      SizedBox(
        width: MediaQuery.sizeOf(context).width * 0.72,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: buttons,
          ),
        ),
      ),
    ];
  }

  // ==========================================================
  // NORMAL MODE
  // ==========================================================

  List<Widget> _normalButtons(BuildContext context) {
    return [
      _buildCompactActionButton(
        icon: Icons.star_border,
        label: 'Fav',
        onPressed: () => widget.logic.onAddToFavorites(context),
      ),
      _buildCompactActionButton(
        icon: Icons.folder_outlined,
        label: 'View',
        onPressed: () => widget.logic.onAddToViewList(context),
      ),
      _buildCompactActionButton(
        icon: Icons.queue_music,
        label: 'Medley',
        onPressed: () => widget.logic.onAddToMedley(context),
      ),
      _buildCompactActionButton(
        icon: Icons.notifications_none,
        label: 'Notify',
        onPressed: widget.logic.onNotifications,
      ),
      _buildCompactActionButton(
        icon: Icons.settings_outlined,
        label: 'Settings',
        onPressed: widget.logic.onSettings,
      ),
    ];
  }

  // ==========================================================
  // SINGLE SELECTION
  // ==========================================================

  List<Widget> _singleSelectionButtons(BuildContext context) {
    return [
      _buildCompactActionButton(
        icon: Icons.edit,
        label: 'Edit',
        onPressed: () => widget.logic.onEdit(context),
      ),
      _buildCompactActionButton(
        icon: Icons.star_border,
        label: 'Fav',
        onPressed: () => widget.logic.onAddToFavorites(context),
      ),
      _buildCompactActionButton(
        icon: Icons.folder_outlined,
        label: 'View',
        onPressed: () => widget.logic.onAddToViewList(context),
      ),
      _buildCompactActionButton(
        icon: Icons.queue_music,
        label: 'Medley',
        onPressed: () => widget.logic.onAddToMedley(context),
      ),
      _buildCompactActionButton(
        icon: Icons.note_add_outlined,
        label: 'Add',
        onPressed: () => widget.logic.onAddSelectedToNewScreen(context),
      ),
      _buildCompactActionButton(
        icon: Icons.playlist_add,
        label: 'Save',
        onPressed: () => widget.logic.onAddSelectedToExistingScreen(context),
      ),
      _buildCompactActionButton(
        icon: Icons.open_in_new,
        label: 'Open',
        onPressed: () => widget.logic.onOpenSelection(context),
      ),
      _buildCompactActionButton(
        icon: Icons.picture_as_pdf_outlined,
        label: 'PDF',
        onPressed: () => widget.logic.onExportPdf(context),
      ),
      _buildCompactActionButton(
        icon: Icons.share_outlined,
        label: 'Share',
        onPressed: () => widget.logic.onShareSelection(context),
      ),
      _buildCompactActionButton(
        icon: Icons.palette_outlined,
        label: 'Theme',
        onPressed: widget.logic.onTheme,
      ),
      _buildCompactActionButton(
        icon: Icons.invert_colors,
        label: 'Invert',
        onPressed: widget.logic.onInvertTheme,
      ),
      if (widget.canShowPresentation)
        _buildCompactActionButton(
          icon: Icons.slideshow,
          label: 'Slide',
          onPressed: widget.logic.onPresentation,
        ),
      _buildCompactActionButton(
        icon: Icons.notifications_none,
        label: 'Notify',
        onPressed: widget.logic.onNotifications,
      ),
      _buildCompactActionButton(
        icon: Icons.settings_outlined,
        label: 'Settings',
        onPressed: widget.logic.onSettings,
      ),
      _buildCompactActionButton(
        icon: Icons.close,
        label: 'Close',
        onPressed: () => widget.logic.onCancelSelection(context),
      ),
    ];
  }

  // ==========================================================
  // MULTIPLE SELECTION
  // ==========================================================

  List<Widget> _multipleSelectionButtons(BuildContext context) {
    return [
      _buildCompactActionButton(
        icon: Icons.star_border,
        label: 'Fav',
        onPressed: () => widget.logic.onAddToFavorites(context),
      ),
      _buildCompactActionButton(
        icon: Icons.folder_outlined,
        label: 'View',
        onPressed: () => widget.logic.onAddToViewList(context),
      ),
      _buildCompactActionButton(
        icon: Icons.queue_music,
        label: 'Medley',
        onPressed: () => widget.logic.onAddToMedley(context),
      ),
      _buildCompactActionButton(
        icon: Icons.note_add_outlined,
        label: 'Add',
        onPressed: () => widget.logic.onAddSelectedToNewScreen(context),
      ),
      _buildCompactActionButton(
        icon: Icons.playlist_add,
        label: 'Save',
        onPressed: () => widget.logic.onAddSelectedToExistingScreen(context),
      ),
      _buildCompactActionButton(
        icon: Icons.open_in_new,
        label: 'Open',
        onPressed: () => widget.logic.onOpenSelection(context),
      ),
      _buildCompactActionButton(
        icon: Icons.picture_as_pdf_outlined,
        label: 'PDF',
        onPressed: () => widget.logic.onExportPdf(context),
      ),
      _buildCompactActionButton(
        icon: Icons.share_outlined,
        label: 'Share',
        onPressed: () => widget.logic.onShareSelection(context),
      ),
      _buildCompactActionButton(
        icon: Icons.notifications_none,
        label: 'Notify',
        onPressed: widget.logic.onNotifications,
      ),
      _buildCompactActionButton(
        icon: Icons.settings_outlined,
        label: 'Settings',
        onPressed: widget.logic.onSettings,
      ),
      _buildCompactActionButton(
        icon: Icons.close,
        label: 'Close',
        onPressed: () => widget.logic.onCancelSelection(context),
      ),
    ];
  }

  Widget _buildCompactActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 68,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: colorScheme.onSurface),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurface,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final clearButton = shouldShowSearchBarClearButton(
          hasFocus: _focusNode.hasFocus,
          text: _searchController.text,
          hasActiveSuggestions:
              (_searchControllerBackend?.suggestions.isNotEmpty ?? false) ||
              (_searchControllerBackend?.results.isNotEmpty ?? false),
        )
        ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              _searchControllerBackend?.clear();
              widget.onSearchChanged?.call(
                '',
                const <HomeSearchResult>[],
              );
              _focusNode.requestFocus();
              setState(() {});
            },
          )
        : null;

    return TextField(
      controller: _searchController,
      focusNode: _focusNode,
      autofocus: true,
      style: TextStyle(
        fontFamily: _searchUsesHindiFont ? 'NotoSansDevanagari' : 'NotoSans',
      ),
      textInputAction: TextInputAction.search,
      onSubmitted: (value) {
        final backend = _searchControllerBackend;
        final results = backend == null
            ? const <HomeSearchResult>[]
            : List<HomeSearchResult>.from(backend.results);

        widget.onSearchChanged?.call(value.trim(), results);
        _focusNode.unfocus();
      },
      decoration: InputDecoration(
        hintText: 'Search hymns',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isListeningForSearch)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              PopupMenuButton<SpeechFieldKind>(
                icon: const Icon(Icons.mic),
                tooltip: 'Voice search',
                onSelected: _handleSearchVoiceInput,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: SpeechFieldKind.english,
                    child: Text('English'),
                  ),
                  PopupMenuItem(
                    value: SpeechFieldKind.hindi,
                    child: Text('Hindi'),
                  ),
                ],
              ),
            clearButton ?? const SizedBox.shrink(),
          ],
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        hintStyle: TextStyle(
          color: Theme.of(context).hintColor,
        ),
      ),
      onChanged: (value) {
        setState(() {
          _searchUsesHindiFont = _containsDevanagari(value);
        });
        _searchControllerBackend?.onQueryChanged(value);
      },
    );
  }

  Future<void> _handleSearchVoiceInput(SpeechFieldKind fieldKind) async {
    final service = SpeechToTextService.instance;
    setState(() => _isListeningForSearch = true);

    final result = await service.listenForText(fieldKind: fieldKind);

    if (!mounted) return;

    setState(() => _isListeningForSearch = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Voice search unavailable.')),
      );
      return;
    }

    final text = result.text.trim();
    if (text.isEmpty) return;

    _searchController.text = text;
    setState(() {
      _searchUsesHindiFont = _containsDevanagari(text);
    });
    _searchControllerBackend?.onQueryChanged(text);
    _focusNode.requestFocus();
  }

  bool _containsDevanagari(String text) {
    return RegExp(r'[\u0900-\u097F]').hasMatch(text);
  }

  Widget _buildSuggestionText(BuildContext context, String suggestion) {
    final query = _searchController.text.trim();
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.2);
    final hintStyle = Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor, fontSize: 13, height: 1.2);

    if (query.isEmpty) {
      return Text(suggestion,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
          style: bodyStyle);
    }

    final lowerSuggestion = suggestion.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerSuggestion.indexOf(lowerQuery);

    if (index == -1) {
      return Text(suggestion,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
          style: bodyStyle);
    }

    final before = suggestion.substring(0, index);
    final match = suggestion.substring(index, index + query.length);
    final after = suggestion.substring(index + query.length);

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: bodyStyle,
        children: [
          if (before.isNotEmpty)
            TextSpan(text: before, style: bodyStyle),
          TextSpan(text: match, style: bodyStyle?.copyWith(fontWeight: FontWeight.bold)),
          if (after.isNotEmpty)
            TextSpan(text: after, style: hintStyle),
        ],
      ),
    );
  }
}
