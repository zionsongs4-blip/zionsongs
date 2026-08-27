import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../hymn/hymn_models.dart';

typedef PdfHtmlConverter =
    Future<Uint8List> Function(String html, PdfPageFormat format);

class PdfExportService {
  PdfExportService({
    PdfHtmlConverter? htmlConverter,
    Duration? conversionTimeout,
  }) : _htmlConverter = htmlConverter ?? _convertHtmlNatively,
       _conversionTimeout = conversionTimeout ?? const Duration(seconds: 30);

  final PdfHtmlConverter _htmlConverter;
  final Duration _conversionTimeout;

  static Future<Uint8List> _convertHtmlNatively(
    String html,
    PdfPageFormat format,
  ) {
    if (Platform.isAndroid) {
      return const MethodChannel('zionsongs.pdf')
          .invokeMethod<Uint8List>('convertHtmlToPdf', {'html': html})
          .then((bytes) {
            if (bytes == null) {
              throw StateError('Android PDF renderer returned no data.');
            }
            return bytes;
          });
    }

    // Native WebView shaping is required for Hindi and Malayalam conjuncts.
    // ignore: deprecated_member_use
    return Printing.convertHtml(html: html, format: format);
  }

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
    final html = await buildHymnHtml(hymns, embedFonts: !Platform.isAndroid);
    debugPrint(
      'PDF generation: converting ${hymns.length} hymn(s), '
      'htmlBytes=${html.length}',
    );
    final pdfBytes = await _htmlConverter(html, PdfPageFormat.a4).timeout(
      _conversionTimeout,
      onTimeout: () => throw StateError(
        'PDF conversion timed out after ${_conversionTimeout.inSeconds} seconds.',
      ),
    );
    if (pdfBytes.length < 4 ||
        String.fromCharCodes(pdfBytes.take(4)) != '%PDF') {
      throw StateError('PDF conversion returned invalid PDF data.');
    }
    debugPrint('PDF generation: produced ${pdfBytes.length} bytes');
    return pdfBytes;
  }

  @visibleForTesting
  Future<String> buildHymnHtml(
    List<LocalHymn> hymns, {
    bool embedFonts = true,
  }) async {
    final hindiFontBytes = await _loadAssetBytes(
      'assets/NotoSansDevanagari-Regular.ttf',
    );

    final malayalamFontBytes = await _loadAssetBytes(
      'assets/NotoSansMalayalam-Regular.ttf',
    );

    final englishFontBytes = await _loadAssetBytes(
      'assets/NotoSans-Regular.ttf',
    );

    final hindiSource = embedFonts
        ? 'data:font/ttf;base64,${base64Encode(hindiFontBytes)}'
        : 'assets/NotoSansDevanagari-Regular.ttf';
    final malayalamSource = embedFonts
        ? 'data:font/ttf;base64,${base64Encode(malayalamFontBytes)}'
        : 'assets/NotoSansMalayalam-Regular.ttf';
    final englishSource = embedFonts
        ? 'data:font/ttf;base64,${base64Encode(englishFontBytes)}'
        : 'assets/NotoSans-Regular.ttf';
    final pages = hymns
        .map((hymn) {
          final hindi = _removeChords(hymn.hindiLyrics?.trim() ?? '');
          final malayalam = _removeChords(hymn.malayalamLyrics?.trim() ?? '');
          final english = _removeChords(hymn.englishLyrics?.trim() ?? '');
          final secondText = malayalam.isNotEmpty ? malayalam : english;
          final secondClass = malayalam.isNotEmpty ? 'malayalam' : 'english';
          final title = hymn.title.trim().isNotEmpty
              ? hymn.title.trim()
              : hymn.hymnId;
          return '''
<section class="hymn-page">
  <h1>${_escapeHtml(title.toUpperCase())}</h1>
      <table class="columns"><tr>
        <td class="language hindi"><h2>Hindi</h2><div class="lyrics">${_escapeHtml(hindi)}</div></td>
        <td class="divider-cell"><div class="divider"></div></td>
        <td class="language $secondClass"><h2>${malayalam.isNotEmpty ? 'Malayalam' : 'English'}</h2><div class="lyrics">${_escapeHtml(secondText)}</div></td>
      </tr></table>
  <footer>Zion Songs</footer>
</section>''';
        })
        .join('');

    final html =
        '''<!doctype html><html><head><meta charset="UTF-8"><style>
@font-face{font-family:Hindi;src:url($hindiSource)}
@font-face{font-family:Malayalam;src:url($malayalamSource)}
@font-face{font-family:English;src:url($englishSource)}
@page{size:A4;margin:18mm 15mm}*{box-sizing:border-box}body{margin:0;color:#111;font-family:English,sans-serif}
.hymn-page{page-break-after:always}.hymn-page:last-child{page-break-after:auto}h1{text-align:center;font: bold 18pt English;border-bottom:1px solid #222;padding-bottom:3mm}.columns{width:100%;border-collapse:collapse;table-layout:fixed}.language{width:48%;vertical-align:top;white-space:pre-wrap;font-size:11pt;line-height:1.55;overflow-wrap:break-word}.language h2{text-align:center;font: bold 11pt English;border-bottom:1px solid #999;padding-bottom:2mm}.hindi .lyrics{font-family:Hindi,English,sans-serif}.malayalam .lyrics{font-family:Malayalam,English,sans-serif}.english .lyrics{font-family:English,sans-serif}.divider-cell{width:4%;vertical-align:top;text-align:center}.divider{display:inline-block;width:1px;min-height:200mm;background:#999}footer{text-align:center;border-top:1px solid #999;margin-top:10mm;padding-top:2mm;color:#555;font-size:8pt}
</style></head><body>$pages</body></html>''';

    return html;
  }

  Future<Uint8List> _loadAssetBytes(String path) async {
    final data = await rootBundle.load(path);

    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
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
