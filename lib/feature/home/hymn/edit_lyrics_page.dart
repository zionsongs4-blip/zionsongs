import 'package:flutter/material.dart'; 
import 'package:isar/isar.dart'; 
import '../../../services/speech_to_text_service.dart';
import 'hymn_models.dart'; 
import 'hymn_sync_logic.dart'; 

class EditLyricsPage extends StatefulWidget { 
  final Isar isar; 
  final String hymnId; 
  final String originalLyrics; 
  final String? hindiLyrics; 
  final String? malayalamLyrics; 
  
  const EditLyricsPage({
    super.key, 
    required this.isar, 
    required this.hymnId, 
    required this.originalLyrics,
    this.hindiLyrics,
    this.malayalamLyrics,
  }); 
  
  @override 
  State<EditLyricsPage> createState() => _EditLyricsPageState(); 
} 

class _EditLyricsPageState extends State<EditLyricsPage> { 
  late final TextEditingController _originalController; 
  late final TextEditingController _hindiController; 
  late final TextEditingController _malayalamController; 
  bool _isSaving = false; 
  bool _showHindi = true; 
  bool _showMalayalam = true; 
  bool _isListening = false;
  
  @override 
  void initState() { 
    super.initState(); 
    _originalController = TextEditingController(text: widget.originalLyrics); 
    _hindiController = TextEditingController(text: widget.hindiLyrics ?? '');
    _malayalamController = TextEditingController(text: widget.malayalamLyrics ?? '');
  } 
  
  @override 
  void dispose() { 
    _originalController.dispose();
    _hindiController.dispose();
    _malayalamController.dispose();
    super.dispose();
  } 
  
  Future<void> _submit() async {
    final englishText = _originalController.text;
    final hindiText = _hindiController.text;
    final malayalamText = _malayalamController.text;

    final sameAsOriginal = englishText == widget.originalLyrics &&
        hindiText == (widget.hindiLyrics ?? '') &&
        malayalamText == (widget.malayalamLyrics ?? '');

    if (sameAsOriginal) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);

    final localHymn = await widget.isar.localHymns
        .filter()
        .hymnIdEqualTo(widget.hymnId)
        .findFirst();

    await SyncLogic.syncDirectHymnEdit(
      isar: widget.isar,
      hymnId: widget.hymnId,
      title: localHymn?.title ?? '',
      originalLyrics: widget.originalLyrics,
      englishLyrics: englishText,
      hindiLyrics: hindiText,
      malayalamLyrics: malayalamText,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lyrics updated and synced to Firestore.")),
      );
      Navigator.pop(context);
    }
  }
  
  Future<void> _handleVoiceInputFor(TextEditingController controller, SpeechFieldKind fieldKind) async {
    setState(() => _isListening = true);

    final result = await SpeechToTextService.instance.listenForText(fieldKind: fieldKind);

    if (!mounted) return;

    setState(() => _isListening = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Voice input unavailable.')),
      );
      return;
    }

    final text = result.text.trim();
    if (text.isEmpty) return;

    final selection = controller.selection;
    final currentText = controller.text;
    final updatedText = selection.isValid
        ? '${currentText.substring(0, selection.start)}$text${currentText.substring(selection.end)}'
        : '$currentText$text';

    controller.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: updatedText.length),
    );
  }

  InputDecoration _voiceInputDecoration(String label) {
    return InputDecoration(
      border: const OutlineInputBorder(),
      suffixIcon: IconButton(
        tooltip: 'Voice input for $label',
        icon: _isListening
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.mic),
        onPressed: _isListening ? null : () {
          if (label == 'Hindi') {
            _handleVoiceInputFor(_hindiController, SpeechFieldKind.hindi);
          } else if (label == 'Malayalam') {
            _handleVoiceInputFor(_malayalamController, SpeechFieldKind.malayalamHindi);
          } else {
            _handleVoiceInputFor(_originalController, SpeechFieldKind.english);
          }
        },
      ),
    );
  }

  @override 
  Widget build(BuildContext context) { 
    return Scaffold(
      appBar: AppBar(title: const Text("Propose Edit")), 
      body: Padding(
        padding: const EdgeInsets.all(16), 
        child: Column(children: [
          Row(
            children: [
              if (widget.hindiLyrics != null)
                TextButton.icon(
                  onPressed: () => setState(() => _showHindi = !_showHindi),
                  icon: Icon(_showHindi ? Icons.visibility : Icons.visibility_off),
                  label: const Text('Hindi'),
                ),
              if (widget.malayalamLyrics != null)
                TextButton.icon(
                  onPressed: () => setState(() => _showMalayalam = !_showMalayalam),
                  icon: Icon(_showMalayalam ? Icons.visibility : Icons.visibility_off),
                  label: const Text('Malayalam'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_showHindi && widget.hindiLyrics != null)
                  Expanded(
                    child: Column(
                      children: [
                        Text('Hindi', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _hindiController,
                            maxLines: null,
                            expands: true,
                            decoration: _voiceInputDecoration('Hindi'),
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_showHindi && _showMalayalam && widget.hindiLyrics != null && widget.malayalamLyrics != null)
                  const VerticalDivider(width: 16),
                if (_showMalayalam && widget.malayalamLyrics != null)
                  Expanded(
                    child: Column(
                      children: [
                        Text('Malayalam', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _malayalamController,
                            maxLines: null,
                            expands: true,
                            decoration: _voiceInputDecoration('Malayalam'),
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!_showHindi && !_showMalayalam)
                  Expanded(
                    child: TextFormField(
                      controller: _originalController,
                      maxLines: null,
                      expands: true,
                      decoration: _voiceInputDecoration('English'),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
              ],
            ),
          ), 
          const SizedBox(height: 16), 
          ElevatedButton(
            onPressed: _isSaving ? null : _submit,
            child: Text(_isSaving ? "Saving..." : "Save Changes"),
          )
        ])
      )
    ); 
  } 
}