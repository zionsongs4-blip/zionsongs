import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';

import '../app_initializer.dart';
import '../hymn_auth_service.dart';
import '../hymn_models.dart';
import '../hymn_pin_button.dart';
import '../hymn_transpose_logic.dart';
import '../edit_lyrics_page.dart';
import '../hymn_section_parser.dart';
import 'chord_lyrics_widget.dart';
import 'chord_preference_service.dart';
import 'floating_hymn_info_bar.dart';
import 'floating_notepad_window.dart';

enum ViewerMode {
  displayAll,
  displayChorus,
  displayIntro,
  displayVerse,
}

class HymnViewerWidget extends StatefulWidget {
  final String initialHymnId;
  final List<String> hymnIds;
  final LocalHymn? initialHymn;
  final ViewerMode mode;
  final ValueChanged<String>? onPageChanged;
  final ValueNotifier<double>? lyricsScaleNotifier;

  const HymnViewerWidget({
    super.key,
    required this.initialHymnId,
    required this.hymnIds,
    this.initialHymn,
    this.mode = ViewerMode.displayAll,
    this.onPageChanged,
    this.lyricsScaleNotifier,
  });

  @override
  State<HymnViewerWidget> createState() => _HymnViewerWidgetState();
}

class _HymnViewerWidgetState extends State<HymnViewerWidget> {
  final ScrollController _scrollController = ScrollController();
  final TransformationController _transformationController =
      TransformationController();
  final Map<String, GlobalKey> _hymnKeys = {};

  LocalHymn? _currentHymn;
  LocalHymn? _pinnedHymn;
  List<LocalHymn> _sourceHymns = [];
  int _currentIndex = 0;
  bool _showNotepad = false;
  bool _showChords = false;
  bool _infoBarExpanded = false;
  bool _presentationMode = false;
  bool _loading = true;
  bool _appBarHiddenByScroll = false;
  double _lyricsScale = 1.0;
  double _zoom = 1.0;
  bool _showHindi = true;
  bool _showMalayalam = true;
  ValueNotifier<double>? _externalLyricsScaleNotifier;
  UserHymnPref? _currentPreference;
  ViewerMode _displayMode = ViewerMode.displayAll;
  final Set<String> _hiddenHymnIds = <String>{};
  final Map<String, List<HymnSection>> _parsedSectionCache = {};
  int _scrollStopTrigger = 0;
  Timer? _scrollStopTimer;

  LocalHymn? get _activeHymn => _pinnedHymn ?? _currentHymn;
  bool get _pinned =>
      _pinnedHymn != null && _pinnedHymn!.hymnId != _currentHymn?.hymnId;

  @override
  void initState() {
    super.initState();
    _displayMode = widget.mode;
    _scrollController.addListener(_onScroll);
    _transformationController.addListener(_syncZoomFromTransform);
    globalPin.addListener(_onPinChanged);

    _externalLyricsScaleNotifier = widget.lyricsScaleNotifier;
    if (_externalLyricsScaleNotifier != null) {
      _lyricsScale = _externalLyricsScaleNotifier!.value;
      _externalLyricsScaleNotifier!.addListener(_handleExternalLyricsScaleChange);
    }

    _loadScreen();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _transformationController.removeListener(_syncZoomFromTransform);
    globalPin.removeListener(_onPinChanged);
    _externalLyricsScaleNotifier?.removeListener(_handleExternalLyricsScaleChange);
    _scrollStopTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadScreen() async {
    await _loadSourceList();
    await _loadChordPreference();
    await _loadPinnedHymn();
    await _loadCurrentHymn();
    setState(() {
      _loading = false;
    });
  }

  Future<void> _loadSourceList() async {
    final effectiveHymnIds = widget.hymnIds.isNotEmpty
        ? widget.hymnIds
        : [widget.initialHymnId];
    if (effectiveHymnIds.isEmpty) {
      _sourceHymns = [];
      _currentIndex = 0;
      return;
    }

    _sourceHymns = [];

    for (final id in effectiveHymnIds) {
      final hymn = await AppInitializer.isar.localHymns
          .filter()
          .hymnIdEqualTo(id)
          .findFirst();

      if (hymn != null) {
        _sourceHymns.add(hymn);
      }
    }

    final map = {for (final h in _sourceHymns) h.hymnId: h};

    _sourceHymns = effectiveHymnIds
        .where(map.containsKey)
        .map((id) => map[id]!)
        .toList();

    // Prepare keys for each hymn so we can scroll to them later.
    _hymnKeys.clear();
    for (final h in _sourceHymns) {
      _hymnKeys[h.hymnId] = GlobalKey();
    }

    final requestedId = widget.initialHymnId;
    final requestedIndex = effectiveHymnIds.indexOf(requestedId);
    _currentIndex = requestedIndex >= 0 && requestedIndex < _sourceHymns.length
        ? requestedIndex
        : _sourceHymns.indexWhere((hymn) => hymn.hymnId == requestedId);

    if (_currentIndex < 0 || _currentIndex >= _sourceHymns.length) {
      _currentIndex = 0;
    }
  }

  Future<void> _loadChordPreference() async {
    final enabled = await ChordPreferenceService.loadChordEnabled();
    setState(() {
      _showChords = enabled;
    });
  }

  Future<void> _loadPinnedHymn() async {
    final pinnedId = globalPin.value;
    if (pinnedId != null) {
      _pinnedHymn = await AppInitializer.isar.localHymns
          .filter()
          .hymnIdEqualTo(pinnedId)
          .findFirst();
    } else {
      _pinnedHymn = null;
    }
    if (mounted) {
      setState(() {});
    }
    // After the current hymn is set, schedule a scroll to the hymn widget
    // once the frame has been rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentHymn();
    });
  }

  Future<void> _scrollToCurrentHymn() async {
    try {
      final id = _currentHymn?.hymnId ?? widget.initialHymnId;
      final key = _hymnKeys[id];
      if (key != null && key.currentContext != null) {
        await Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 250),
          alignment: 0.0,
        );
      }
    } catch (_) {}
  }

  Future<void> _loadCurrentHymn() async {
    if (_sourceHymns.isNotEmpty) {
      final requestedId = widget.initialHymn?.hymnId ??
          widget.initialHymnId;
      final requestedHymn = _sourceHymns.firstWhere(
        (hymn) => hymn.hymnId == requestedId,
        orElse: () => _sourceHymns.first,
      );
      final requestedIndex = _sourceHymns.indexOf(requestedHymn);

      if (requestedIndex >= 0) {
        _currentIndex = requestedIndex;
        _currentHymn = requestedHymn;
      } else {
        _currentIndex = 0;
        _currentHymn = _sourceHymns.first;
      }
    } else if (widget.initialHymn != null) {
      _currentHymn = widget.initialHymn;
    } else {
      _currentHymn = await AppInitializer.isar.localHymns
          .filter()
          .hymnIdEqualTo(widget.initialHymnId)
          .findFirst();
    }

    if (_currentHymn != null) {
      _currentPreference = await AppInitializer.isar.userHymnPrefs
          .filter()
          .hymnIdEqualTo(_currentHymn!.hymnId)
          .userIdEqualTo(AuthService.userId)
          .findFirst();

      _currentPreference ??= UserHymnPref()
        ..hymnId = _currentHymn!.hymnId
        ..userId = AuthService.userId
        ..manualKey = HymnTransposeLogic.detectKey(
          _currentHymn!.originalLyrics,
        ) ?? 'C'
        ..transposeOffset = 0
        ..preferFlats = false;
    } else {
      _currentPreference = null;
    }

    _applyLayoutForHymn(_currentHymn);

    await _loadPinnedHymn();

    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentHymn();
      });
    }
  }

  void _onPinChanged() {
    unawaited(_loadPinnedHymn());
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _sourceHymns.isEmpty) return;

    final direction = _scrollController.position.userScrollDirection;
    if (direction == ScrollDirection.reverse && !_appBarHiddenByScroll) {
      setState(() {
        _appBarHiddenByScroll = true;
      });
    } else if (direction == ScrollDirection.forward && _appBarHiddenByScroll) {
      setState(() {
        _appBarHiddenByScroll = false;
      });
    }

    final viewportHeight = _scrollController.position.viewportDimension;
    final offset = _scrollController.offset;
    final estimatedIndex = (offset / math.max(1.0, viewportHeight * 0.8))
        .round()
        .clamp(0, _sourceHymns.length - 1);

    final hymn = _sourceHymns[estimatedIndex];
    if (_currentIndex != estimatedIndex) {
      _currentIndex = estimatedIndex;
      _currentHymn = hymn;

      if (!_pinned) {
        _applyLayoutForHymn(_currentHymn);
        if (widget.onPageChanged != null) {
          widget.onPageChanged!(hymn.hymnId);
        }
      }
    }

    _scheduleScrollStop();
  }

  void _scheduleScrollStop() {
    _scrollStopTimer?.cancel();
    _scrollStopTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _scrollStopTrigger += 1;
      });
    });
  }

  void _syncZoomFromTransform() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final nextZoom = scale.clamp(0.45, 2.6);
    if ((_zoom - nextZoom).abs() > 0.01) {
      setState(() {
        _zoom = nextZoom;
      });
    }
  }

  Future<void> _toggleChords() async {
    final enabled = !_showChords;
    await ChordPreferenceService.saveChordEnabled(enabled);
    setState(() {
      _showChords = enabled;
    });
  }

  Future<void> _toggleNotepad() async {
    setState(() {
      _showNotepad = !_showNotepad;
    });
  }

  Future<void> _togglePresentationMode() async {
    setState(() {
      _presentationMode = !_presentationMode;
    });

    await SystemChrome.setEnabledSystemUIMode(
      _presentationMode
          ? SystemUiMode.immersiveSticky
          : SystemUiMode.edgeToEdge,
    );
  }

  void _handleExternalLyricsScaleChange() {
    final newScale = _externalLyricsScaleNotifier?.value;
    if (newScale == null || newScale == _lyricsScale) return;
    setState(() {
      _lyricsScale = newScale;
    });
  }

  void _updateLyricsScale(double newScale) {
    final clamped = newScale.clamp(0.8, 2.2);
    setState(() {
      _lyricsScale = clamped;
    });
    widget.lyricsScaleNotifier?.value = clamped;
  }

  void _handleLyricsScaleUpdate(ScaleUpdateDetails details) {
    if (details.scale == 1.0) return;
    _updateLyricsScale(_lyricsScale * details.scale);
  }

  void _decreaseLyricsFont() {
    _updateLyricsScale(_lyricsScale - 0.1);
  }

  void _increaseLyricsFont() {
    _updateLyricsScale(_lyricsScale + 0.1);
  }

  Future<void> _openSearch() async {
    // Search is handled inline in the hymn info bar.
  }

  void _themePlaceholder() {}

  void _openEditPage() {
    if (_currentHymn == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditLyricsPage(
          isar: AppInitializer.isar,
          hymnId: _currentHymn!.hymnId,
          originalLyrics: _currentHymn!.originalLyrics,
          hindiLyrics: _currentHymn!.hindiLyrics,
          malayalamLyrics: _currentHymn!.malayalamLyrics,
        ),
      ),
    );
  }

  bool _hasLyrics(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  void _applyLayoutForHymn(LocalHymn? hymn) {
    if (hymn == null) {
      _showHindi = true;
      _showMalayalam = true;
      return;
    }

    final hasHindi = _hasLyrics(hymn.hindiLyrics);
    final hasMalayalam = _hasLyrics(hymn.malayalamLyrics);

    if (hasHindi && hasMalayalam) {
      _showHindi = true;
      _showMalayalam = true;
      return;
    }

    _showHindi = hasHindi;
    _showMalayalam = hasMalayalam;
  }

  String _lyricsForLanguage(LocalHymn hymn, String language) {
    switch (language) {
      case 'malayalam':
        return hymn.malayalamLyrics ?? '';

      case 'original':
        return hymn.originalLyrics;

      case 'hindi':
      default:
        return hymn.hindiLyrics ?? '';
    }
  }

  String _displayedLyricsForLanguage(LocalHymn hymn, String language) {
    final rawLyrics = _lyricsForLanguage(hymn, language);
    return HymnTransposeLogic.transposeLyrics(
      rawLyrics,
      _currentPreference?.transposeOffset ?? 0,
      _currentPreference?.preferFlats ?? false,
    );
  }

  List<HymnSection> _getParsedSections(LocalHymn hymn, String language) {
    final key = '${hymn.hymnId}-$language';
    return _parsedSectionCache.putIfAbsent(key, () {
      final rawLyrics = _lyricsForLanguage(hymn, language);
      return HymnSectionParser.parse(rawLyrics);
    });
  }

  List<HymnSection> _getSectionsForMode(
    List<HymnSection> sections,
    ViewerMode mode,
  ) {
    switch (mode) {
      case ViewerMode.displayAll:
        return sections;
      case ViewerMode.displayIntro:
        return sections
            .where((section) => section.sectionType == HymnSectionType.intro)
            .toList();
      case ViewerMode.displayChorus:
        return sections
            .where((section) =>
                section.sectionType == HymnSectionType.chorus ||
                section.sectionType == HymnSectionType.refrain)
            .toList();
      case ViewerMode.displayVerse:
        return sections
            .where((section) => section.sectionType == HymnSectionType.verse)
            .toList();
    }
  }

  Widget _buildAdaptiveLyricsPanel({
    required LocalHymn hymn,
    required String language,
    required bool showRestoreButton,
    required bool showCloseButton,
    required bool isPrimary,
  }) {
    final lyrics = _displayedLyricsForLanguage(hymn, language);
    final label = language == 'hindi'
        ? 'Hindi'
        : _detectSecondaryLanguageLabel(lyrics);
    final theme = Theme.of(context);
    final sections = _getParsedSections(hymn, language);
    final effectiveSections = _getSectionsForMode(sections, _displayMode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showRestoreButton || showCloseButton)
          Row(
            children: [
              if (showRestoreButton)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (language == 'hindi') {
                        _showHindi = true;
                      } else {
                        _showMalayalam = true;
                      }
                    });
                  },
                  icon: const Icon(Icons.unfold_more, size: 18),
                  label: Text('Show $label'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                )
              else
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (showCloseButton)
                IconButton(
                  tooltip: 'Hide $label',
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: () {
                    setState(() {
                      if (language == 'hindi') {
                        _showHindi = false;
                      } else {
                        _showMalayalam = false;
                      }
                    });
                  },
                ),
            ],
          ),
        const SizedBox(height: 4),
        GestureDetector(
          onScaleUpdate: _handleLyricsScaleUpdate,
          child: _buildSectionedLyrics(effectiveSections, language: language),
        ),
      ],
    );
  }

  String _detectSecondaryLanguageLabel(String lyrics) {
    final devanagariCount = RegExp(r'[\u0900-\u097F]').allMatches(lyrics).length;
    final latinCount = RegExp(r'[A-Za-z]').allMatches(lyrics).length;
    if (devanagariCount > latinCount) {
      return 'Malayalam';
    }
    return 'English';
  }

  Widget _buildSectionedLyrics(List<HymnSection> sections, {required String language}) {
    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDualLanguage = language == 'hindi' || language == 'malayalam';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in sections)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (section.sectionType != HymnSectionType.unknown ||
                    section.originalHeading.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      section.headingLabel,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                if (section.lyrics.trim().isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(left: isDualLanguage ? 12 : 0),
                    child: ChordLyricsWidget(
                      lyrics: section.lyrics,
                      showChords: _showChords,
                      fontSize: math.max(14.0, 16.0 * _zoom * _lyricsScale),
                    ),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAdaptiveLyricsContent(LocalHymn hymn, {required double width, required bool isPrimary}) {
    final hasHindi = _hasLyrics(hymn.hindiLyrics);
    final hasMalayalam = _hasLyrics(hymn.malayalamLyrics);
    final showHindi = hasHindi && _showHindi;
    final showMalayalam = hasMalayalam && _showMalayalam;

    if (showHindi && showMalayalam) {
      final hiddenLanguages = <String>[];
      if (hasHindi && !_showHindi) hiddenLanguages.add('hindi');
      if (hasMalayalam && !_showMalayalam) hiddenLanguages.add('malayalam');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hiddenLanguages.isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                for (final language in hiddenLanguages)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        if (language == 'hindi') {
                          _showHindi = true;
                        } else if (language == 'malayalam') {
                          _showMalayalam = true;
                        }
                      });
                    },
                    icon: const Icon(Icons.unfold_more, size: 18),
                    label: Text('Show ${language == 'hindi' ? 'Hindi' : 'Malayalam'}'),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildAdaptiveLyricsPanel(
                  hymn: hymn,
                  language: 'hindi',
                  showRestoreButton: false,
                  showCloseButton: true,
                  isPrimary: isPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAdaptiveLyricsPanel(
                  hymn: hymn,
                  language: 'malayalam',
                  showRestoreButton: false,
                  showCloseButton: true,
                  isPrimary: isPrimary,
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (showHindi) {
      return _buildAdaptiveLyricsPanel(
        hymn: hymn,
        language: 'hindi',
        showRestoreButton: false,
        showCloseButton: false,
        isPrimary: isPrimary,
      );
    }

    if (showMalayalam) {
      return _buildAdaptiveLyricsPanel(
        hymn: hymn,
        language: 'malayalam',
        showRestoreButton: false,
        showCloseButton: false,
        isPrimary: isPrimary,
      );
    }

    if (hasHindi) {
      return _buildAdaptiveLyricsPanel(
        hymn: hymn,
        language: 'hindi',
        showRestoreButton: true,
        showCloseButton: false,
        isPrimary: isPrimary,
      );
    }

    if (hasMalayalam) {
      return _buildAdaptiveLyricsPanel(
        hymn: hymn,
        language: 'malayalam',
        showRestoreButton: true,
        showCloseButton: false,
        isPrimary: isPrimary,
      );
    }

    return _buildAdaptiveLyricsPanel(
      hymn: hymn,
      language: 'original',
      showRestoreButton: false,
      showCloseButton: false,
      isPrimary: isPrimary,
    );
  }

  Widget _buildHymnPage(LocalHymn hymn, {required double width, required bool isPrimary}) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_presentationMode)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Exit Presentation',
                visualDensity: VisualDensity.compact,
                onPressed: _togglePresentationMode,
              ),
            ),
          if (!isPrimary)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Hide hymn',
                onPressed: () {
                  setState(() {
                    _hiddenHymnIds.add(hymn.hymnId);
                  });
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hymn.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Divider(
                        thickness: 2,
                        color: theme.colorScheme.primary,
                        height: 0,
                      ),
                    ],
                  ),
                ),
                _buildAdaptiveLyricsContent(hymn, width: width, isPrimary: isPrimary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _currentHymn == null) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final headerHeight =
        MediaQuery.of(context).padding.top + 92 + (_infoBarExpanded ? 28 : 0);
    final visibleHymns = _sourceHymns
        .where((hymn) => !_hiddenHymnIds.contains(hymn.hymnId))
        .toList(growable: false);

    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (_) => false,
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.45,
              maxScale: 2.6,
              panEnabled: true,
              scaleEnabled: true,
              clipBehavior: Clip.none,
              boundaryMargin: const EdgeInsets.all(0),
              onInteractionEnd: (_) => _syncZoomFromTransform(),
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.only(top: headerHeight + 12, bottom: 24),
                children: [
                  for (var index = 0; index < visibleHymns.length; index++)
                    Padding(
                      key: _hymnKeys[visibleHymns[index].hymnId],
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _buildHymnPage(
                        visibleHymns[index],
                        width: MediaQuery.of(context).size.width - 12,
                        isPrimary: index == 0,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  FloatingHymnInfoBar(
                    hymn: _activeHymn ?? _currentHymn!,
                    isar: AppInitializer.isar,
                    pinned:
                        _pinned &&
                        (_activeHymn?.hymnId == _currentHymn?.hymnId),
                    refreshTrigger: _scrollStopTrigger,
                    showChords: _showChords,
                    onChanged: () async {
                      await _loadCurrentHymn();
                      setState(() {});
                    },
                    onToggleChords: _toggleChords,
                    onNotepadTapped: _toggleNotepad,
                    onEditOpened: _openEditPage,
                    onToggleAppInfo: _togglePresentationMode,
                    onSearchPressed: _openSearch,
                    onThemePressed: _themePlaceholder,
                    onDecreaseFont: _decreaseLyricsFont,
                    onIncreaseFont: _increaseLyricsFont,
                    onExpandedChanged: (expanded) {
                      setState(() {
                        _infoBarExpanded = expanded;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_showNotepad)
            FloatingNotepadWindow(
              isar: AppInitializer.isar,
              hymnId: _activeHymn!.hymnId,
              hymnTitle: _activeHymn!.title,
              onClosed: () {
                setState(() {
                  _showNotepad = false;
                });
              },
              onSaved: () async {},
            ),
        ],
      ),
    );
  }
}
