import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../hymn_models.dart';
import '../hymn_pin_button.dart';
import '../hymn_transpose_logic.dart';
import '../hymn_preferences_logic.dart';
import '../hymn_auth_service.dart';
import '../favorites_repository.dart';
import '../viewlist_medley_models.dart';
import '../../search/home_search_controller.dart';
import '../../search/home_search_result_tile.dart';
import '../../search/home_search_repository.dart';
import '../../../../services/speech_to_text_service.dart';
import '../../../../screens/folder_doc_screen.dart';
import '../../../home/repositories/folder_repository.dart';

class _FolderLocation {
  const _FolderLocation({
    required this.collection,
    required this.docId,
    required this.path,
    required this.label,
    required this.pathLabel,
  });

  final String collection;
  final String docId;
  final List<String> path;
  final String label;
  final String pathLabel;
}

class FloatingHymnInfoBar extends StatefulWidget {
  final LocalHymn hymn;
  final Isar isar;
  final bool pinned;
  final bool showChords;
  final VoidCallback onChanged;
  final VoidCallback onToggleChords;
  final VoidCallback onNotepadTapped;
  final VoidCallback onEditOpened;
  final VoidCallback? onToggleAppInfo;
  final VoidCallback? onSearchPressed;
  final ValueChanged<String>? onSearchResultSelected;
  final VoidCallback? onThemePressed;
  final VoidCallback? onDecreaseFont;
  final VoidCallback? onIncreaseFont;
  final ValueChanged<bool>? onExpandedChanged;
  final int refreshTrigger;

  const FloatingHymnInfoBar({
    super.key,
    required this.hymn,
    required this.isar,
    required this.pinned,
    required this.showChords,
    required this.onChanged,
    required this.onToggleChords,
    required this.onNotepadTapped,
    required this.onEditOpened,
    this.onToggleAppInfo,
    this.onSearchPressed,
    this.onSearchResultSelected,
    this.onThemePressed,
    this.onDecreaseFont,
    this.onIncreaseFont,
    this.onExpandedChanged,
    required this.refreshTrigger,
  });

  @override
  State<FloatingHymnInfoBar> createState() => _FloatingHymnInfoBarState();
}

class _FloatingHymnInfoBarState extends State<FloatingHymnInfoBar> {
  UserHymnPref? _pref;
  String? _detectedKey;
  int _noteCount = 0;
  int _favoriteCount = 0;
  int _viewListCount = 0;
  int _medleyCount = 0;
  List<String> _styles = [];
  List<String> _beats = [];
  bool _expanded = false;
  bool _searchMode = false;
  late final TextEditingController _tempoController;
  late final TextEditingController _beatController;
  late final TextEditingController _styleController;
  late final FavoritesRepository _favoritesRepository;
  late final TextEditingController _searchInputController;
  late final HomeSearchController _searchController;

  @override
  void initState() {
    super.initState();
    _tempoController = TextEditingController();
    _beatController = TextEditingController();
    _styleController = TextEditingController();
    _favoritesRepository = FavoritesRepository();
    _searchInputController = TextEditingController();
    _searchController = HomeSearchController(
      repository: HomeSearchRepository(isar: widget.isar),
      resultLimit: 4,
      actualSnippetForSearchText: true,
    );
    _searchController.addListener(_refreshSearch);
    _loadDetails();
    HymnPreferencesLogic.getStyles().then(
      (s) => mounted ? setState(() => _styles = s) : null,
    );
    final beats = HymnPreferencesLogic.getBeats();
    if (mounted) setState(() => _beats = beats);
  }

  @override
  void didUpdateWidget(covariant FloatingHymnInfoBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hymn.hymnId != widget.hymn.hymnId) {
      _loadDetails();
      return;
    }
    if (oldWidget.refreshTrigger != widget.refreshTrigger) {
      _refreshBadge();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_refreshSearch);
    _searchController.dispose();
    _searchInputController.dispose();
    _tempoController.dispose();
    _beatController.dispose();
    _styleController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    final existingPref = await widget.isar.userHymnPrefs
        .filter()
        .hymnIdEqualTo(widget.hymn.hymnId)
        .userIdEqualTo(AuthService.userId)
        .findFirst();

    if (existingPref != null) {
      _pref = existingPref;
      _detectedKey = existingPref.manualKey?.isNotEmpty == true 
          ? existingPref.manualKey 
          : HymnTransposeLogic.detectKey(widget.hymn.originalLyrics);
    } else {
      _detectedKey = HymnTransposeLogic.detectKey(
        widget.hymn.originalLyrics,
      );

      _pref = UserHymnPref()
        ..hymnId = widget.hymn.hymnId
        ..userId = AuthService.userId
        ..manualKey = _detectedKey ?? 'C'
        ..transposeOffset = 0
        ..preferFlats = false;

      await widget.isar.writeTxn(() async {
        await widget.isar.userHymnPrefs.put(_pref!);
      });
    }

    _syncControllers(_pref!);
    await _refreshBadge();
    if (mounted) setState(() {});
  }

  String _resolveTextValue(String? prefValue, String? hymnValue) {
    final prefText = prefValue?.trim();
    if (prefText != null && prefText.isNotEmpty) {
      return prefText;
    }
    final hymnText = hymnValue?.trim();
    if (hymnText != null && hymnText.isNotEmpty) {
      return hymnText;
    }
    return '';
  }

  String _resolveTempoValue(UserHymnPref pref) {
    if (pref.tempo != null && pref.tempo! > 0) {
      return pref.tempo.toString();
    }
    if (widget.hymn.tempo != null && widget.hymn.tempo! > 0) {
      return widget.hymn.tempo.toString();
    }
    return '';
  }

  void _syncControllers(UserHymnPref pref) {
    _tempoController.text = _resolveTempoValue(pref);
    _beatController.text = _resolveTextValue(pref.beat, widget.hymn.beat);
    _styleController.text = _resolveTextValue(pref.style, widget.hymn.style);
  }

  Future<void> _refreshBadge() async {
    final noteCount = await widget.isar.userNotes
        .filter()
        .hymnIdEqualTo(widget.hymn.hymnId)
        .userIdEqualTo(AuthService.userId)
        .count();
    final favoriteCount =
        await _favoritesRepository.isFavorite(widget.hymn.hymnId) ? 1 : 0;

    final viewListRecords = await widget.isar.viewListItemRecords
        .filter()
        .hymnIdEqualTo(widget.hymn.hymnId)
        .userIdEqualTo(AuthService.userId)
        .findAll();
    final viewListFolderIds = <String>{
      for (final record in viewListRecords) record.folderId,
    };

    final medleyRecords = await widget.isar.medleyItemRecords
        .filter()
        .hymnIdEqualTo(widget.hymn.hymnId)
        .userIdEqualTo(AuthService.userId)
        .findAll();
    final medleyFolderIds = <String>{
      for (final record in medleyRecords) record.folderId,
    };

    if (mounted) {
      setState(() {
        _noteCount = noteCount;
        _favoriteCount = favoriteCount;
        _viewListCount = viewListFolderIds.length;
        _medleyCount = medleyFolderIds.length;
      });
    }
  }

  Future<void> _onChanged() async {
    await _refreshBadge();
    widget.onChanged();
  }

  Future<void> _toggleFavorite() async {
    await _favoritesRepository.toggleFavorite(widget.hymn.hymnId);
    await _onChanged();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Favorites updated')));
  }

  Future<void> _showFolderNames(String type) async {
    if (!mounted) return;

    final locations = <_FolderLocation>[];
    final folderIds = <String>{};

    if (type == NOTE_TYPE_VIEWLIST) {
      final records = await widget.isar.viewListItemRecords
          .filter()
          .hymnIdEqualTo(widget.hymn.hymnId)
          .userIdEqualTo(AuthService.userId)
          .findAll();

      for (final record in records) {
        if (!folderIds.add(record.folderId)) continue;
        final folder = await widget.isar.viewListFolderRecords
            .filter()
            .folderIdEqualTo(record.folderId)
            .userIdEqualTo(AuthService.userId)
            .findFirst();
        final parsed = parseRelationshipFolderKey(record.folderId);
        if (parsed.collection.isEmpty) continue;
        locations.add(
          _FolderLocation(
            collection: parsed.collection,
            docId: parsed.docId,
            path: parsed.path,
            label: folder?.name.isNotEmpty == true
                ? folder!.name
                : (parsed.path.isEmpty ? 'Root' : parsed.path.last),
            pathLabel: parsed.path.isEmpty ? 'Root' : parsed.path.join(' / '),
          ),
        );
      }
    } else {
      final records = await widget.isar.medleyItemRecords
          .filter()
          .hymnIdEqualTo(widget.hymn.hymnId)
          .userIdEqualTo(AuthService.userId)
          .findAll();

      for (final record in records) {
        if (!folderIds.add(record.folderId)) continue;
        final folder = await widget.isar.medleyFolderRecords
            .filter()
            .folderIdEqualTo(record.folderId)
            .userIdEqualTo(AuthService.userId)
            .findFirst();
        final parsed = parseRelationshipFolderKey(record.folderId);
        if (parsed.collection.isEmpty) continue;
        locations.add(
          _FolderLocation(
            collection: parsed.collection,
            docId: parsed.docId,
            path: parsed.path,
            label: folder?.name.isNotEmpty == true
                ? folder!.name
                : (parsed.path.isEmpty ? 'Root' : parsed.path.last),
            pathLabel: parsed.path.isEmpty ? 'Root' : parsed.path.join(' / '),
          ),
        );
      }
    }

    if (!mounted) return;
    if (locations.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No folders found.')));
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          type == NOTE_TYPE_VIEWLIST
              ? 'View List Locations'
              : 'Medley Locations',
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: locations.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final location = locations[index];
              return ListTile(
                dense: true,
                title: Text(location.label),
                subtitle: Text(location.pathLabel),
                onTap: () async {
                  Navigator.pop(dialogContext);
                  if (!mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FolderDocScreen(
                        collection: location.collection,
                        docId: location.docId,
                        docName: location.label,
                        initialPath: location.path,
                        initialHighlightHymnId: widget.hymn.hymnId,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePin() async {
    await globalPin.togglePin(widget.hymn.hymnId);
    await _onChanged();
  }

  Future<void> _saveStyle(String value) async {
    final pref = _pref ?? UserHymnPref()
      ..hymnId = widget.hymn.hymnId
      ..userId = AuthService.userId;
    await HymnPreferencesLogic.saveStyle(pref, value);
    if (mounted) {
      setState(() {
        _pref = pref;
        _styleController.text = pref.style ?? '';
      });
    }
    await _onChanged();
  }

  Future<void> _saveBeat(String value) async {
    final pref = _pref ?? UserHymnPref()
      ..hymnId = widget.hymn.hymnId
      ..userId = AuthService.userId;
    await HymnPreferencesLogic.saveBeat(pref, value);
    if (mounted) {
      setState(() {
        _pref = pref;
        _beatController.text = pref.beat ?? '';
      });
    }
    await _onChanged();
  }

  Future<void> _saveTempo(String value) async {
    final pref = _pref ?? UserHymnPref()
      ..hymnId = widget.hymn.hymnId
      ..userId = AuthService.userId;
    await HymnPreferencesLogic.saveTempo(pref, value);
    if (mounted) {
      setState(() {
        _pref = pref;
        _tempoController.text = pref.tempo.toString();
      });
    }
    await _onChanged();
  }

  Widget _buildCompactField({
    required String prefix,
    required TextEditingController controller,
    required bool isNumeric,
    required Future<void> Function(String) onSubmitted,
    required Iterable<String> suggestions,
    double? width,
  }) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Autocomplete<String>(
        initialValue: TextEditingValue(text: controller.text),
        optionsBuilder: (value) {
          final query = value.text.trim().toLowerCase();
          if (query.isEmpty) {
            return suggestions;
          }
          return suggestions.where(
            (option) => option.toLowerCase().contains(query),
          );
        },
        onSelected: (value) async => onSubmitted(value),
        fieldViewBuilder:
            (context, fieldController, focusNode, onFieldSubmitted) {
              if (fieldController.text != controller.text) {
                fieldController.text = controller.text;
              }
              return SizedBox(
                width: width ?? (isNumeric ? 58 : null),
                child: TextField(
                  controller: fieldController,
                  focusNode: focusNode,
                  keyboardType: isNumeric
                      ? TextInputType.number
                      : TextInputType.text,
                  inputFormatters: isNumeric
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : null,
                  textAlign: isNumeric ? TextAlign.center : TextAlign.left,
                  style: TextStyle(fontSize: 12, color: textColor),
                  decoration: const InputDecoration(
                    prefixText: '',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (value) async => onSubmitted(value),
                ),
              );
            },
      ),
    );
  }

  Widget _buildBadgeIcon({
    required IconData icon,
    required int count,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon),
          if (count > 0)
            Positioned(
              right: -4,
              top: -2,
              child: CircleAvatar(
                radius: 7,
                backgroundColor: Colors.red,
                child: Text(
                  '$count',
                  style: const TextStyle(fontSize: 8, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  Future<void> _changeTranspose(int delta) async {
    final pref = _pref ?? UserHymnPref()
      ..hymnId = widget.hymn.hymnId
      ..userId = AuthService.userId;
    pref.transposeOffset += delta;
    await HymnTransposeLogic.savePref(pref);
    if (mounted) {
      setState(() {
        _pref = pref;
        _detectedKey = pref.manualKey?.isNotEmpty == true 
            ? pref.manualKey 
            : HymnTransposeLogic.detectKey(widget.hymn.originalLyrics);
      });
    }
    widget.onChanged();
  }

  void _refreshSearch() {
    if (mounted) {
      setState(() {});
    }
  }

  void _enterSearchMode() {
    setState(() {
      _searchMode = true;
    });
  }

  void _exitSearchMode() {
    _searchInputController.clear();
    _searchController.clear();
    setState(() {
      _searchMode = false;
    });
  }

  Widget _buildSearchModeContent() {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.dividerColor, width: 1.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchInputController,
                  autofocus: true,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: const InputDecoration(
                    hintText: 'Search hymns',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: _searchController.onQueryChanged,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.mic, size: 18),
                tooltip: 'Voice search',
                onPressed: _listenForSearch,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Close search',
                onPressed: _exitSearchMode,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_searchController.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (_searchController.results.isEmpty &&
            _searchInputController.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No results found', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface)),
          )
        else if (_searchController.results.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _searchController.results.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final result = _searchController.results[index];
                return HomeSearchResultTile(
                  result: result,
                  onTap: () async {
                    widget.onSearchResultSelected?.call(result.srNo);
                    _exitSearchMode();
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _listenForSearch() async {
    final outcome = await SpeechToTextService.instance.listenForText(
      fieldKind: SpeechFieldKind.malayalamHindi,
    );
    if (!mounted) return;
    if (!outcome.success || outcome.text.trim().isEmpty) {
      if (outcome.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(outcome.errorMessage!)),
        );
      }
      return;
    }

    _searchInputController.text = outcome.text;
    _searchInputController.selection = TextSelection.collapsed(
      offset: outcome.text.length,
    );
    _searchController.onQueryChanged(outcome.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final bpmSuggestions = HymnPreferencesLogic.getBpms();

    if (_searchMode) {
      return Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border.all(
              color: theme.dividerColor,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: _buildSearchModeContent(),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border.all(color: theme.dividerColor, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.hymn.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 34,
                                minHeight: 34,
                              ),
                              icon: Icon(
                                widget.pinned
                                    ? Icons.push_pin
                                    : Icons.push_pin_outlined,
                              ),
                              color: widget.pinned ? Colors.amber : null,
                              onPressed: _togglePin,
                            ),
                          ),
                        ),

                        if (!_expanded)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'Hymn Info',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: textColor,
                              ),
                            ),
                          ),

                        SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 34,
                                minHeight: 34,
                              ),
                              icon: Icon(
                                _expanded
                                    ? Icons.keyboard_arrow_down
                                    : Icons.play_arrow,
                              ),
                              onPressed: () {
                                setState(() {
                                  _expanded = !_expanded;
                                });

                                widget.onExpandedChanged?.call(_expanded);
                              },
                            ),
                          ),
                        ),

                        if (_expanded) ...[
                          SizedBox(
                            width: 54,
                            height: 36,
                            child: Center(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  minimumSize: const Size(0, 36),
                                ),
                                onPressed: widget.onToggleChords,
                                child: Text(
                                  widget.showChords ? '[ CH ✕ ]' : '[ CH ]',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(
                            width: 36,
                            height: 36,
                            child: Center(
                              child: IconButton(
                                icon: const Icon(Icons.remove),
                                tooltip: 'Transpose down',
                                onPressed: () => _changeTranspose(-1),
                              ),
                            ),
                          ),

                          SizedBox(
                            width: 54,
                            height: 36,
                            child: Center(
                              child: Text(
                                _detectedKey ?? 'C',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(
                            width: 36,
                            height: 36,
                            child: Center(
                              child: IconButton(
                                icon: const Icon(Icons.add),
                                tooltip: 'Transpose up',
                                onPressed: () => _changeTranspose(1),
                              ),
                            ),
                          ),

                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text('T', style: TextStyle(color: textColor)),
                          ),

                          _buildCompactField(
                            prefix: '',
                            controller: _tempoController,
                            isNumeric: true,
                            onSubmitted: _saveTempo,
                            suggestions: bpmSuggestions,
                            width: 56,
                          ),

                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text('B', style: TextStyle(color: textColor)),
                          ),

                          _buildCompactField(
                            prefix: '',
                            controller: _beatController,
                            isNumeric: false,
                            onSubmitted: _saveBeat,
                            suggestions: _beats,
                            width: 70,
                          ),
                        ],

                        const SizedBox(width: 6),
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: IconButton(
                              icon: const Icon(Icons.present_to_all),
                              tooltip: 'Presentation',
                              onPressed: widget.onToggleAppInfo,
                            ),
                          ),
                        ),

                        const SizedBox(width: 6),
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: _buildBadgeIcon(
                              icon: Icons.note_alt_outlined,
                              count: _noteCount,
                              tooltip: 'Notes',
                              onPressed: widget.onNotepadTapped,
                            ),
                          ),
                        ),

                        const SizedBox(width: 6),
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: IconButton(
                              icon: Icon(
                                _favoriteCount > 0
                                    ? Icons.star
                                    : Icons.star_border,
                                color: _favoriteCount > 0 ? Colors.amber : null,
                              ),
                              tooltip: 'Favorites',
                              onPressed: _toggleFavorite,
                            ),
                          ),
                        ),

                        const SizedBox(width: 6),
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: _buildBadgeIcon(
                              icon: Icons.church_outlined,
                              count: _viewListCount,
                              tooltip: 'View List',
                              onPressed: () =>
                                  _showFolderNames(NOTE_TYPE_VIEWLIST),
                            ),
                          ),
                        ),

                        const SizedBox(width: 6),
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: _buildBadgeIcon(
                              icon: Icons.public_outlined,
                              count: _medleyCount,
                              tooltip: 'Medley',
                              onPressed: () =>
                                  _showFolderNames(NOTE_TYPE_MEDLEY),
                            ),
                          ),
                        ),

                        const SizedBox(width: 6),
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.dividerColor,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.search),
                                tooltip: 'Search',
                                onPressed: () {
                                  widget.onSearchPressed?.call();
                                  _enterSearchMode();
                                },
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 6),
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.dividerColor,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.brightness_6_outlined),
                                tooltip: 'Theme',
                                onPressed: widget.onThemePressed,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 6),
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              tooltip: 'Decrease font',
                              onPressed: widget.onDecreaseFont,
                            ),
                          ),
                        ),

                        const SizedBox(width: 6),
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              tooltip: 'Increase font',
                              onPressed: widget.onIncreaseFont,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (_expanded) ...[
              const SizedBox(height: 6),

              Row(
                children: [
                  Text(
                    'STY',
                    style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                  ),

                  const SizedBox(width: 6),

                  Expanded(
                    child: _buildCompactField(
                      prefix: '',
                      controller: _styleController,
                      isNumeric: false,
                      onSubmitted: _saveStyle,
                      suggestions: _styles,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}