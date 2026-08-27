import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';

import '../hymn/hymn_models.dart';

class PdfExportService {
  static List<LocalHymn> orderHymnsByIds({
    required List<String> hymnIds,
    required List<LocalHymn> hymns,
  }) {
    if (hymnIds.isEmpty) {
      return List<LocalHymn>.from(hymns);
    }

    final hymnMap = {
      for (final hymn in hymns) hymn.hymnId: hymn,
    };

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

  Future<void> saveHymnPdf({
    required List<LocalHymn> hymns,
  }) async {
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
      return;
    }

    debugPrint('PDF saved to selected path: $result');
  }

  Future<void> shareHymnPdf({
    required List<LocalHymn> hymns,
  }) async {
    final pdfBytes = await generateHymnPdf(hymns);

    final path = await writePdfToSafeDirectory(
      pdfBytes,
      fileName: 'Zion_Hymns.pdf',
      useTemporaryDirectory: true,
    );

    final file = File(path);
    debugPrint('Sharing PDF from generated file: ${file.path}');

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Zion Hymns',
      text: 'Please find the selected Zion hymns attached as a PDF.',
    );
  }

  Future<String> writePdfToSafeDirectory(
    List<int> pdfBytes, {
    required String fileName,
    bool useTemporaryDirectory = false,
  }) async {
    final dir = useTemporaryDirectory
        ? await getTemporaryDirectory()
        : await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(pdfBytes, flush: true);
    return file.path;
  }

  Future<Uint8List> generateHymnPdf(
    List<LocalHymn> hymns,
  ) async {
    // -------------------------------------------------------------
    // Load fonts from Flutter assets.
    // -------------------------------------------------------------

    final hindiFontBytes = await _loadAssetBytes(
      'assets/NotoSansDevanagari-Regular.ttf',
    );

    final malayalamFontBytes = await _loadAssetBytes(
      'assets/NotoSansMalayalam-Regular.ttf',
    );

    final englishFontBytes = await _loadAssetBytes(
      'assets/NotoSans-Regular.ttf',
    );

    final hindiBase64 = base64Encode(hindiFontBytes);
    final malayalamBase64 = base64Encode(malayalamFontBytes);
    final englishBase64 = base64Encode(englishFontBytes);

    // -------------------------------------------------------------
    // Build HTML.
    //
    // Hindi and Malayalam are deliberately kept as TWO columns.
    // -------------------------------------------------------------

    final hymnPages = hymns.map((hymn) {
      final hindi = _removeChords(
        hymn.hindiLyrics?.trim() ?? '',
      );

      final malayalam = _removeChords(
        hymn.malayalamLyrics?.trim() ?? '',
      );

      final title = _escapeHtml(
        hymn.title.trim().isNotEmpty
            ? hymn.title.trim()
            : hymn.hymnId,
      );

      return '''
        <section class="hymn-page">

          <div class="header">
            <div class="title">$title</div>
            <div class="title-line"></div>
          </div>

          <table class="lyrics-table">
            <tr>
              <td class="language-column hindi-column">
                <div class="language-title">Hindi</div>
                <div class="language-line"></div>
                <div class="lyrics hindi-lyrics">
                  ${_formatLyricsForHtml(hindi)}
                </div>
              </td>

              <td class="divider-column">
                <div class="divider"></div>
              </td>

              <td class="language-column malayalam-column">
                <div class="language-title">Malayalam</div>
                <div class="language-line"></div>
                <div class="lyrics malayalam-lyrics">
                  ${_formatLyricsForHtml(malayalam)}
                </div>
              </td>
            </tr>
          </table>

          <div class="footer">
            Zion Songs
          </div>

        </section>
      ''';
    }).join('');

    final html = '''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">

<style>

@font-face {
  font-family: 'ZionHindi';
  src: url(data:font/ttf;base64,$hindiBase64);
}

@font-face {
  font-family: 'ZionMalayalam';
  src: url(data:font/ttf;base64,$malayalamBase64);
}

@font-face {
  font-family: 'ZionEnglish';
  src: url(data:font/ttf;base64,$englishBase64);
}

@page {
  size: A4;
  margin: 18mm 15mm 18mm 15mm;
}

* {
  box-sizing: border-box;
}

html,
body {
  margin: 0;
  padding: 0;
  background: white;
  color: #111;
}

body {
  font-family: 'ZionEnglish', sans-serif;
}

.hymn-page {
  position: relative;
  width: 100%;
  page-break-after: always;
  padding-bottom: 15mm;
}

.hymn-page:last-child {
  page-break-after: auto;
}

/* -------------------------------------------------------------
   HEADER
   ------------------------------------------------------------- */

.header {
  width: 100%;
  text-align: center;
  margin-bottom: 8mm;
}

.title {
  font-family: 'ZionEnglish', sans-serif;
  font-size: 18pt;
  font-weight: bold;
  text-transform: uppercase;
  text-align: center;
}

.title-line {
  width: 100%;
  border-bottom: 1px solid #222;
  margin-top: 3mm;
}

/* -------------------------------------------------------------
   TWO LANGUAGE COLUMNS
   ------------------------------------------------------------- */

.lyrics-table {
  width: 100%;
  border-collapse: collapse;
  table-layout: fixed;
}

.language-column {
  width: 48%;
  vertical-align: top;
}

.hindi-column {
  padding-right: 4mm;
}

.malayalam-column {
  padding-left: 4mm;
}

.divider-column {
  width: 4%;
  vertical-align: top;
  text-align: center;
}

.divider {
  display: inline-block;
  width: 1px;
  min-height: 200mm;
  background: #999;
}

/* -------------------------------------------------------------
   LANGUAGE HEADINGS
   ------------------------------------------------------------- */

.language-title {
  font-family: 'ZionEnglish', sans-serif;
  font-size: 11pt;
  font-weight: bold;
  text-align: center;
  margin-bottom: 2mm;
}

.language-line {
  border-bottom: 1px solid #999;
  margin-bottom: 4mm;
}

/* -------------------------------------------------------------
   LYRICS
   ------------------------------------------------------------- */

.lyrics {
  white-space: pre-wrap;
  font-size: 11pt;
  line-height: 1.55;
  overflow-wrap: break-word;
  word-break: normal;
}

.hindi-lyrics {
  font-family: 'ZionHindi', sans-serif;
}

.malayalam-lyrics {
  font-family: 'ZionMalayalam', sans-serif;
}

/* -------------------------------------------------------------
   FOOTER
   ------------------------------------------------------------- */

.footer {
  margin-top: 10mm;
  border-top: 1px solid #999;
  padding-top: 2mm;
  text-align: center;
  font-family: 'ZionEnglish', sans-serif;
  font-size: 8pt;
  color: #555;
}

</style>
</head>

<body>

$hymnPages

</body>
</html>
''';

    // -------------------------------------------------------------
    // HTML -> PDF
    //
    // This uses the HTML rendering engine rather than the
    // pdf package's direct Indic text shaping.
    // -------------------------------------------------------------

    return Printing.convertHtml(
      html: html,
      format: PdfPageFormat.a4,
    );
  }

  Future<Uint8List> _loadAssetBytes(String path) async {
    final data = await rootBundle.load(path);

    return data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
  }

  // ---------------------------------------------------------------
  // FORMAT LYRICS FOR HTML
  //
  // Preserve line breaks while safely escaping HTML characters.
  // ---------------------------------------------------------------

  String _formatLyricsForHtml(String text) {
    if (text.trim().isEmpty) {
      return '';
    }

    return _escapeHtml(text);
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
        .replaceAll(
          RegExp(r'[ ]{2,}'),
          ' ',
        )
        .trim();
  }

  // ---------------------------------------------------------------
  // HTML ESCAPING
  // ---------------------------------------------------------------

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}