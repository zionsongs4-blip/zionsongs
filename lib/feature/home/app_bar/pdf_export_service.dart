import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../hymn/hymn_models.dart';

class PdfExportService {
  static List<LocalHymn> orderHymnsByIds({
    required List<String> hymnIds,
    required List<LocalHymn> hymns,
  }) {
    if (hymnIds.isEmpty) {
      return List<LocalHymn>.from(hymns);
    }

    final hymnMap = {for (final hymn in hymns) hymn.hymnId: hymn};

    final ordered = <LocalHymn>[];
    final seen = <String>{};

    for (final hymnId in hymnIds) {
      final hymn = hymnMap[hymnId];
      if (hymn == null || seen.contains(hymn.hymnId)) {
        continue;
      }
      seen.add(hymn.hymnId);
      ordered.add(hymn);
    }

    for (final hymn in hymns) {
      if (!seen.contains(hymn.hymnId)) {
        ordered.add(hymn);
      }
    }

    return ordered;
  }

  Future<String> saveHymnPdf({required List<LocalHymn> hymns}) async {
    _requireHymns(hymns);
    if (Platform.isAndroid) {
      await Permission.storage.request();
    }
    final pdfBytes = await generateHymnPdf(hymns);

    String? result;

    try {
      final downloadsDir = await getDownloadsDirectory();
      final initialDirectory =
          downloadsDir?.path ?? '/storage/emulated/0/Download';

      if (Platform.isAndroid) {
        result = await FilePicker.saveFile(
          dialogTitle: 'Save PDF',
          fileName: 'Zion_Hymns.pdf',
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          initialDirectory: initialDirectory,
          bytes: pdfBytes,
        );
      } else {
        result = await FilePicker.saveFile(
          fileName: 'Zion_Hymns.pdf',
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          initialDirectory: initialDirectory,
          bytes: pdfBytes,
        );
      }
    } catch (e, s) {
      debugPrint('FilePicker.saveFile failed: $e');
      debugPrint('$s');
      result = null;
    }

    if (result == null) {
      final fallbackPath = await writePdfToSafeDirectory(
        pdfBytes,
        fileName: 'Zion_Hymns.pdf',
      );
      debugPrint('PDF saved to fallback path: $fallbackPath');
      return fallbackPath;
    }

    debugPrint('PDF saved to selected path: $result');
    return result;
  }

  Future<void> shareHymnPdf({required List<LocalHymn> hymns}) async {
    _requireHymns(hymns);
    final pdfBytes = await generateHymnPdf(hymns);

    final path = await writePdfToSafeDirectory(
      pdfBytes,
      fileName: 'Zion_Hymns.pdf',
      useTemporaryDirectory: true,
    );

    final file = File(path);
    debugPrint('Sharing PDF from generated file: ${file.path}');

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Zion Hymns',
        text: 'Please find the selected Zion hymns attached as a PDF.',
      ),
    );
  }

  void _requireHymns(List<LocalHymn> hymns) {
    if (hymns.isEmpty) {
      throw StateError('No selected hymns were available for PDF generation.');
    }
  }

  Future<String> writePdfToSafeDirectory(
    List<int> pdfBytes, {
    required String fileName,
    bool useTemporaryDirectory = false,
  }) async {
    final dir = useTemporaryDirectory
        ? await getTemporaryDirectory()
        : Platform.isAndroid
        ? await getExternalStorageDirectory() ??
              await getApplicationDocumentsDirectory()
        : await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(pdfBytes, flush: true);
    return file.path;
  }

  Future<Uint8List> generateHymnPdf(List<LocalHymn> hymns) async {
    final hindiFontBytes = await _loadAssetBytes(
      'assets/NotoSansDevanagari-Regular.ttf',
    );

    final malayalamFontBytes = await _loadAssetBytes(
      'assets/NotoSansMalayalam-Regular.ttf',
    );

    final englishFontBytes = await _loadAssetBytes(
      'assets/NotoSans-Regular.ttf',
    );

    final hindiFont = pw.Font.ttf(ByteData.sublistView(hindiFontBytes));
    final malayalamFont = pw.Font.ttf(ByteData.sublistView(malayalamFontBytes));
    final englishFont = pw.Font.ttf(ByteData.sublistView(englishFontBytes));
    final document = pw.Document(title: 'Zion Hymns', author: 'Zion Songs');

    for (final hymn in hymns) {
      final hindi = _removeChords(hymn.hindiLyrics?.trim() ?? '');
      final malayalam = _removeChords(hymn.malayalamLyrics?.trim() ?? '');
      final english = _removeChords(hymn.englishLyrics?.trim() ?? '');
      final secondLanguage = malayalam.isNotEmpty ? malayalam : english;
      final secondFont = malayalam.isNotEmpty ? malayalamFont : englishFont;
      final title = hymn.title.trim().isNotEmpty
          ? hymn.title.trim()
          : hymn.hymnId;

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(43, 51, 43, 51),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey)),
            ),
            child: pw.Text(
              'Zion Songs',
              style: pw.TextStyle(
                font: englishFont,
                fontSize: 8,
                color: PdfColors.grey,
              ),
            ),
          ),
          build: (context) => [
            pw.Center(
              child: pw.Text(
                title.toUpperCase(),
                style: pw.TextStyle(
                  font: englishFont,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Divider(color: PdfColors.black),
            pw.SizedBox(height: 16),
            pw.Table(
              columnWidths: const {
                0: pw.FlexColumnWidth(1),
                1: pw.FixedColumnWidth(12),
                2: pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  children: [
                    _lyricsColumn(
                      'Hindi',
                      hindi,
                      hindiFont,
                      fallbackFont: englishFont,
                      rightPadding: 12,
                    ),
                    pw.Container(
                      width: 1,
                      color: PdfColors.grey,
                      constraints: const pw.BoxConstraints(minHeight: 200),
                    ),
                    _lyricsColumn(
                      malayalam.isNotEmpty ? 'Malayalam' : 'English',
                      secondLanguage,
                      secondFont,
                      fallbackFont: englishFont,
                      leftPadding: 12,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    return document.save();
  }

  pw.Widget _lyricsColumn(
    String language,
    String lyrics,
    pw.Font font, {
    pw.Font? fallbackFont,
    double leftPadding = 0,
    double rightPadding = 0,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(left: leftPadding, right: rightPadding),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(
            child: pw.Text(
              language,
              style: pw.TextStyle(
                font: font,
                fontFallback: fallbackFont == null
                    ? const <pw.Font>[]
                    : <pw.Font>[fallbackFont],
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Divider(color: PdfColors.grey),
          pw.Text(
            lyrics,
            style: pw.TextStyle(
              font: font,
              fontFallback: fallbackFont == null
                  ? const <pw.Font>[]
                  : <pw.Font>[fallbackFont],
              fontSize: 11,
              lineSpacing: 5,
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _loadAssetBytes(String path) async {
    final data = await rootBundle.load(path);

    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  // ---------------------------------------------------------------
  // REMOVE CHORDS
  // ---------------------------------------------------------------

  String _removeChords(String text) {
    return text
        .replaceAll(
          RegExp(
            r'(?<![A-Za-z])'
            r'(?:[A-G](?:#|b)?'
            r'(?:m|maj|min|sus|dim|aug)?'
            r'(?:\d+)?'
            r'(?:/[A-G](?:#|b)?)?)'
            r'(?![A-Za-z])',
          ),
          '',
        )
        .replaceAll(RegExp(r'[ ]{2,}'), ' ')
        .trim();
  }
}
