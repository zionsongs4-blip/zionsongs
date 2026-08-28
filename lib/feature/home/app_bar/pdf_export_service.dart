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
          .invokeMethod<Uint8List>(
            'convertHtmlToPdf',
            {'html': html},
          )
          .then((bytes) {
            if (bytes == null) {
              throw StateError(
                'Android PDF renderer returned no data.',
              );
            }
            return bytes;
          });
    }

    // Native WebView shaping is required for Hindi and Malayalam conjuncts.
    // ignore: deprecated_member_use
    return Printing.convertHtml(
      html: html,
      format: format,
    );
  }

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

  Future<String> saveHymnPdf({
    required List<LocalHymn> hymns,
  }) async {
    _requireHymns(hymns);

    if (Platform.isAndroid) {
      await Permission.storage.request();
    }

    final pdfBytes = await generateHymnPdf(hymns);

    String? result;

    try {
      final downloadsDir = await getDownloadsDirectory();

      final initialDirectory =
          downloadsDir?.path ??
          '/storage/emulated/0/Download';

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

      debugPrint(
        'PDF saved to fallback path: $fallbackPath',
      );

      return fallbackPath;
    }

    debugPrint(
      'PDF saved to selected path: $result',
    );

    return result;
  }

  Future<void> shareHymnPdf({
    required List<LocalHymn> hymns,
  }) async {
    _requireHymns(hymns);

    final pdfBytes = await generateHymnPdf(hymns);

    final path = await writePdfToSafeDirectory(
      pdfBytes,
      fileName: 'Zion_Hymns.pdf',
      useTemporaryDirectory: true,
    );

    final file = File(path);

    debugPrint(
      'Sharing PDF from generated file: ${file.path}',
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Zion Hymns',
        text:
            'Please find the selected Zion hymns attached as a PDF.',
      ),
    );
  }

  void _requireHymns(List<LocalHymn> hymns) {
    if (hymns.isEmpty) {
      throw StateError(
        'No selected hymns were available for PDF generation.',
      );
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

    final file = File(
      '${dir.path}/$fileName',
    );

    await file.writeAsBytes(
      pdfBytes,
      flush: true,
    );

    return file.path;
  }

  Future<Uint8List> generateHymnPdf(
    List<LocalHymn> hymns,
  ) async {
    final html = await buildHymnHtml(
      hymns,
      embedFonts: !Platform.isAndroid,
    );

    debugPrint(
      'PDF generation: converting ${hymns.length} hymn(s), '
      'htmlBytes=${html.length}',
    );

    final pdfBytes = await _htmlConverter(
      html,
      PdfPageFormat.a4,
    ).timeout(
      _conversionTimeout,
      onTimeout: () => throw StateError(
        'PDF conversion timed out after '
        '${_conversionTimeout.inSeconds} seconds.',
      ),
    );

    if (pdfBytes.length < 4 ||
        String.fromCharCodes(
              pdfBytes.take(4),
            ) !=
            '%PDF') {
      throw StateError(
        'PDF conversion returned invalid PDF data.',
      );
    }

    debugPrint(
      'PDF generation: produced ${pdfBytes.length} bytes',
    );

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

    final sections = hymns.map((hymn) {
      final hindi = _removeChords(
        hymn.hindiLyrics?.trim() ?? '',
      );

      final malayalam = _removeChords(
        hymn.malayalamLyrics?.trim() ?? '',
      );

      final english = _removeChords(
        hymn.englishLyrics?.trim() ?? '',
      );

      final title = hymn.title.trim().isNotEmpty
          ? hymn.title.trim()
          : hymn.hymnId;

      final hasHindi = hindi.isNotEmpty;
      final hasMalayalam = malayalam.isNotEmpty;
      final hasEnglish = english.isNotEmpty;

      final languageCount = [
        hasHindi,
        hasMalayalam,
        hasEnglish,
      ].where((value) => value).length;

      final titleHtml = '''
<h1 class="hymn-title">
  <span>${_escapeHtml(title.toUpperCase())}</span>
</h1>
''';

      // -----------------------------------------------------------
      // ONE LANGUAGE (Left aligned, no divider)
      // -----------------------------------------------------------

      if (languageCount <= 1) {
        String languageClass;
        String languageName;
        String lyrics;

        if (hasHindi) {
          languageClass = 'hindi';
          languageName = 'Hindi';
          lyrics = hindi;
        } else if (hasMalayalam) {
          languageClass = 'malayalam';
          languageName = 'Malayalam';
          lyrics = malayalam;
        } else {
          languageClass = 'english';
          languageName = 'English';
          lyrics = english;
        }

        return '''
<section class="hymn-section">
  $titleHtml

  <div class="single-language $languageClass">
    <h2>$languageName</h2>
    <div class="lyrics">${_escapeHtml(lyrics)}</div>
  </div>

  <footer>Zion Songs</footer>
</section>
''';
      }

      // -----------------------------------------------------------
      // TWO LANGUAGES (Side-by-side with vertical divider line)
      // -----------------------------------------------------------

      String leftClass;
      String leftName;
      String leftLyrics;

      String rightClass;
      String rightName;
      String rightLyrics;

      if (hasHindi && hasMalayalam) {
        leftClass = 'hindi';
        leftName = 'Hindi';
        leftLyrics = hindi;

        rightClass = 'malayalam';
        rightName = 'Malayalam';
        rightLyrics = malayalam;
      } else if (hasHindi && hasEnglish) {
        leftClass = 'hindi';
        leftName = 'Hindi';
        leftLyrics = hindi;

        rightClass = 'english';
        rightName = 'English';
        rightLyrics = english;
      } else {
        leftClass = 'malayalam';
        leftName = 'Malayalam';
        leftLyrics = malayalam;

        rightClass = 'english';
        rightName = 'English';
        rightLyrics = english;
      }

      return '''
<section class="hymn-section">
  $titleHtml

  <table class="two-language-table">
    <tr>
      <td class="language-column $leftClass">
        <h2>$leftName</h2>
        <div class="lyrics">${_escapeHtml(leftLyrics)}</div>
      </td>
      <td class="language-divider" aria-hidden="true"></td>
      <td class="language-column $rightClass">
        <h2>$rightName</h2>
        <div class="lyrics">${_escapeHtml(rightLyrics)}</div>
      </td>
    </tr>
  </table>

  <footer>Zion Songs</footer>
</section>
''';
    }).join('\n');

    final html = '''
<!doctype html>
<html>
<head>
<meta charset="UTF-8">

<style>

@font-face {
  font-family: Hindi;
  src: url($hindiSource);
}

@font-face {
  font-family: Malayalam;
  src: url($malayalamSource);
}

@font-face {
  font-family: English;
  src: url($englishSource);
}

/* -------------------------------------------------------------
   PAGE
   ------------------------------------------------------------- */

@page {
  size: A4;
  margin: 15mm;
}

* {
  box-sizing: border-box;
}

html,
body {
  margin: 0;
  padding: 0;
}

body {
  color: #111;
  font-family: English, sans-serif;
  font-size: 11pt;
  line-height: 1.5;
}

/* -------------------------------------------------------------
   HYMN
   ------------------------------------------------------------- */

.hymn-section {
  width: 100%;
  margin: 0 0 10mm 0;
  padding: 0;
  page-break-inside: auto;
  break-inside: auto;
}

.hymn-section:last-child {
  margin-bottom: 0;
}

/* -------------------------------------------------------------
   TITLE (Centered, Underlined text)
   ------------------------------------------------------------- */

.hymn-title {
  width: 100%;
  margin: 0 0 5mm 0;
  padding: 0 0 2mm 0;

  text-align: center;

  font-family: English, Hindi, Malayalam, sans-serif;
  font-size: 16pt;
  font-weight: bold;
  line-height: 1.25;

  page-break-after: avoid;
  break-after: avoid;
}

.hymn-title span {
  border-bottom: 1px solid #222;
  padding-bottom: 2mm;
}

/* -------------------------------------------------------------
   LANGUAGE HEADINGS
   ------------------------------------------------------------- */

h2 {
  margin: 0 0 3mm 0;
  padding: 0 0 1.5mm 0;

  text-align: center;

  font-family: English, Hindi, Malayalam, sans-serif;
  font-size: 11pt;
  font-weight: bold;

  line-height: 1.25;

  border-bottom: 1px solid #999;

  page-break-after: avoid;
  break-after: avoid;
}

/* -------------------------------------------------------------
   LYRICS (Left-indexed by default, preventing character breaking)
   ------------------------------------------------------------- */

.lyrics {
  margin: 0;
  padding: 0;

  text-align: left;
  white-space: pre-wrap;
  word-break: normal;
  overflow-wrap: break-word;

  font-size: 11pt;
  line-height: 1.6;
}

/* -------------------------------------------------------------
   ONE LANGUAGE
   ------------------------------------------------------------- */

.single-language {
  width: 100%;
  margin: 0;
  padding: 0;

  page-break-inside: auto;
  break-inside: auto;
}

.single-language.hindi .lyrics {
  font-family: Hindi, English, sans-serif;
}

.single-language.malayalam .lyrics {
  font-family: Malayalam, English, sans-serif;
}

.single-language.english .lyrics {
  font-family: English, sans-serif;
}

/* -------------------------------------------------------------
   TWO LANGUAGES (Side-by-side table with center vertical rule)
   ------------------------------------------------------------- */

.two-language-table {
  width: 100%;
  border-collapse: collapse;
  margin: 0;
  padding: 0;

  page-break-inside: auto;
  break-inside: auto;
}

.language-column {
  width: 48.5%;
  vertical-align: top;
  margin: 0;
  padding: 0;

  page-break-inside: auto;
  break-inside: auto;
}

.language-column.hindi .lyrics {
  font-family: Hindi, English, sans-serif;
}

.language-column.malayalam .lyrics {
  font-family: Malayalam, English, sans-serif;
}

.language-column.english .lyrics {
  font-family: English, sans-serif;
}

.language-divider {
  width: 3%;
  border-left: 1px solid #999;
  padding: 0;
  margin: 0;
}

/* -------------------------------------------------------------
   FOOTER
   ------------------------------------------------------------- */

footer {
  width: 100%;
  text-align: center;
  border-top: 1px solid #999;

  margin-top: 6mm;
  padding-top: 2mm;

  color: #555;
  font-family: English, sans-serif;
  font-size: 8pt;

  page-break-inside: avoid;
  break-inside: avoid;
}

/* -------------------------------------------------------------
   PRINT/PAGINATION SAFETY
   ------------------------------------------------------------- */

h1,
h2 {
  orphans: 3;
  widows: 3;
}

.lyrics {
  orphans: 2;
  widows: 2;
}

</style>
</head>

<body>
$sections
</body>
</html>
''';

    return html;
  }

  Future<Uint8List> _loadAssetBytes(
    String path,
  ) async {
    final data = await rootBundle.load(path);

    return data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
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
        .replaceAll(
          RegExp(r'[ ]{2,}'),
          ' ',
        )
        .trim();
  }
}