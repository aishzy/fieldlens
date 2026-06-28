import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';

import '../models/inspection_report_model.dart';

class DocxBuilder {
  static Uint8List buildReport(
    List<InspectionReportModel> inspections,
    String inspectorName,
    String inspectorId,
    List<List<Uint8List>> allPhotos, {
    String siteLocation = '',
  }) {
    final archive = Archive();
    final imgRels = <String, String>{};
    var imgCounter = 0;
    final body = StringBuffer();
    final e = _e;

    // ---- Header ----
    body.write('<w:p><w:pPr><w:jc w:val="center"/></w:pPr>'
        '<w:r><w:rPr><w:b/><w:sz w:val="28"/><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/></w:rPr>'
        '<w:t>Dilapidation Survey Report</w:t></w:r></w:p>');

    // Site Location
    if (siteLocation.trim().isNotEmpty) {
      body.write('<w:p><w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/></w:rPr>');
      body.write('<w:t>Site Location: ${e(siteLocation.trim())}</w:t></w:r></w:p>');
    }

    final label = inspectorName.trim();
    if (label.isNotEmpty) {
      body.write('<w:p><w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/></w:rPr>');
      body.write('<w:t>Inspector: ${e(label)} (${e(inspectorId)})</w:t></w:r></w:p>');
    }
    body.write('<w:p><w:r><w:rPr><w:sz w:val="22"/><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/></w:rPr>');
    body.write('<w:t>Generated: ${DateFormat('"'"'dd/MM/yyyy HH:mm'"'"').format(DateTime.now())}</w:t></w:r></w:p>');

    final overall = <int>[];
    final defect = <int>[];
    for (var i = 0; i < inspections.length; i++) {
      if (inspections[i].isOverallMode) overall.add(i);
      else defect.add(i);
    }

    // ---- Overall View Items ----
    if (overall.isNotEmpty) {
      body.write('<w:p><w:r><w:rPr><w:b/><w:sz w:val="24"/><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/></w:rPr>');
      body.write('<w:t>Overall View Items</w:t></w:r></w:p>');
      for (final idx in overall) {
        final insp = inspections[idx];
        final photos = idx < allPhotos.length ? allPhotos[idx] : <Uint8List>[];
        body.write('<w:tbl><w:tblGrid><w:gridCol w:w="1200"/><w:gridCol w:w="10800"/></w:tblGrid>');
        body.write('<w:tr><w:tc><w:tcPr><w:tcW w:w="1200" w:type="dxa"/><w:shd w:fill="D9E2F3"/></w:tcPr>');
        body.write('<w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t>ITEM</w:t></w:r></w:p></w:tc>');
        body.write('<w:tc><w:tcPr><w:tcW w:w="10800" w:type="dxa"/><w:shd w:fill="D9E2F3"/></w:tcPr>');
        body.write('<w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t>PHOTO</w:t></w:r></w:p></w:tc></w:tr>');

        if (photos.isEmpty) {
          body.write('<w:tr><w:tc><w:tcPr><w:tcW w:w="1200" w:type="dxa"/></w:tcPr>');
          body.write('<w:p><w:r><w:t>${e(insp.itemNumber)}</w:t></w:r></w:p></w:tc>');
          body.write('<w:tc><w:tcPr><w:tcW w:w="10800" w:type="dxa"/></w:tcPr>');
          body.write('<w:p><w:r><w:rPr><w:color w:val="999999"/></w:rPr><w:t>No Image</w:t></w:r></w:p></w:tc></w:tr>');
        } else {
          for (var pi = 0; pi < photos.length; pi++) {
            imgCounter++;
            final rId = 'i$imgCounter';
            imgRels[rId] = 'image$imgCounter.jpg';
            archive.addFile(ArchiveFile('"'"'word/media/image$imgCounter.jpg'"'"', photos[pi].length, photos[pi]));
            body.write('<w:tr>');
            if (pi == 0) {
              body.write('<w:tc><w:tcPr><w:tcW w:w="1200" w:type="dxa"/><w:vMerge w:val="restart"/></w:tcPr>');
              body.write('<w:p><w:r><w:t>${e(insp.itemNumber)}</w:t></w:r></w:p></w:tc>');
            } else {
              body.write('<w:tc><w:tcPr><w:tcW w:w="1200" w:type="dxa"/><w:vMerge/></w:tcPr></w:tc>');
            }
            body.write('<w:tc><w:tcPr><w:tcW w:w="10800" w:type="dxa"/></w:tcPr>');
            body.write('<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r>');
            body.write('<w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">'
                '<wp:extent cx="5486400" cy="4114800"/>'
                '<wp:effectExtent l="0" t="0" r="0" b="0"/>'
                '<wp:docPr id="$imgCounter" name="Image $imgCounter" descr="Photo"/>'
                '<wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/></wp:cNvGraphicFramePr>'
                '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
                '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
                '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
                '<pic:nvPicPr><pic:cNvPr id="0" name="Image $imgCounter"/><pic:nvPicPrNameLocks/></pic:nvPicPr>'
                '<pic:blipFill><a:blip r:embed="$rId" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
                '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="5486400" cy="4114800"/></a:xfrm><a:prstGeom prst="rect"/></pic:spPr>'
                '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing>');
            body.write('</w:r></w:p></w:tc></w:tr>');
          }
        }
        // Bottom info row for Overall View: Location + Comments
        body.write('<w:tr>');
        body.write('<w:tc><w:tcPr><w:tcW w:w="1200" w:type="dxa"/></w:tcPr>');
        body.write('<w:p><w:r><w:rPr><w:b/><w:sz w:val="18"/></w:rPr><w:t>Location:</w:t></w:r></w:p>');
        body.write('<w:p><w:r><w:rPr><w:sz w:val="18"/></w:rPr><w:t>${e(_loc(insp))}</w:t></w:r></w:p></w:tc>');
        body.write('<w:tc><w:tcPr><w:tcW w:w="10800" w:type="dxa"/></w:tcPr>');
        body.write("<w:p><w:r><w:rPr><w:b/><w:sz w:val=\"18\"/></w:rPr><w:t>Inspector's comments:</w:t></w:r></w:p>");
        body.write('<w:p><w:r><w:rPr><w:sz w:val="18"/></w:rPr><w:t>${e(insp.inspectorComments)}</w:t></w:r></w:p></w:tc>');
        body.write('</w:tr></w:tbl>');
      }
    }

    // ---- Defect Assessment Items ----
    if (defect.isNotEmpty) {
      body.write('<w:p><w:r><w:rPr><w:b/><w:sz w:val="24"/><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/></w:rPr>');
      body.write('<w:t>Defect Assessment Items</w:t></w:r></w:p>');
      for (final idx in defect) {
        final insp = inspections[idx];
        final photos = idx < allPhotos.length ? allPhotos[idx] : <Uint8List>[];
        final codes = insp.selectedDefectCodes.toSet();
        final types = _types(codes);
        body.write('<w:tbl><w:tblGrid>'
            '<w:gridCol w:w="1200"/><w:gridCol w:w="6000"/><w:gridCol w:w="4800"/>'
            '</w:tblGrid>');
        body.write('<w:tr><w:tc><w:tcPr><w:tcW w:w="1200" w:type="dxa"/><w:shd w:fill="D9E2F3"/></w:tcPr>');
        body.write('<w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t>ITEM</w:t></w:r></w:p></w:tc>');
        body.write('<w:tc><w:tcPr><w:tcW w:w="6000" w:type="dxa"/><w:shd w:fill="D9E2F3"/></w:tcPr>');
        body.write('<w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t>PHOTO</w:t></w:r></w:p></w:tc>');
        body.write('<w:tc><w:tcPr><w:tcW w:w="4800" w:type="dxa"/><w:shd w:fill="D9E2F3"/></w:tcPr>');
        body.write('<w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t>ASSESSMENT TYPES</w:t></w:r></w:p></w:tc></w:tr>');

        if (photos.isEmpty) {
          body.write('<w:tr><w:tc><w:tcPr><w:tcW w:w="1200" w:type="dxa"/></w:tcPr>');
          body.write('<w:p><w:r><w:t>${e(insp.itemNumber)}</w:t></w:r></w:p></w:tc>');
          body.write('<w:tc><w:tcPr><w:tcW w:w="6000" w:type="dxa"/></w:tcPr>');
          body.write('<w:p><w:r><w:rPr><w:color w:val="999999"/></w:rPr><w:t>No Image</w:t></w:r></w:p></w:tc>');
          body.write('<w:tc><w:tcPr><w:tcW w:w="4800" w:type="dxa"/></w:tcPr>');
          body.write('<w:p><w:r><w:rPr><w:sz w:val="18"/></w:rPr><w:t>${e(types)}</w:t></w:r></w:p></w:tc></w:tr>');
        } else {
          for (var pi = 0; pi < photos.length; pi++) {
            imgCounter++;
            final rId = 'i$imgCounter';
            imgRels[rId] = 'image$imgCounter.jpg';
            archive.addFile(ArchiveFile('"'"'word/media/image$imgCounter.jpg'"'"', photos[pi].length, photos[pi]));
            body.write('<w:tr>');
            if (pi == 0) {
              body.write('<w:tc><w:tcPr><w:tcW w:w="1200" w:type="dxa"/><w:vMerge w:val="restart"/></w:tcPr>');
              body.write('<w:p><w:r><w:t>${e(insp.itemNumber)}</w:t></w:r></w:p></w:tc>');
            } else {
              body.write('<w:tc><w:tcPr><w:tcW w:w="1200" w:type="dxa"/><w:vMerge/></w:tcPr></w:tc>');
            }
            body.write('<w:tc><w:tcPr><w:tcW w:w="6000" w:type="dxa"/></w:tcPr>');
            body.write('<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r>');
            body.write('<w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">'
                '<wp:extent cx="3048000" cy="2286000"/>'
                '<wp:effectExtent l="0" t="0" r="0" b="0"/>'
                '<wp:docPr id="$imgCounter" name="Image $imgCounter" descr="Photo"/>'
                '<wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/></wp:cNvGraphicFramePr>'
                '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
                '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
                '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
                '<pic:nvPicPr><pic:cNvPr id="0" name="Image $imgCounter"/><pic:nvPicPrNameLocks/></pic:nvPicPr>'
                '<pic:blipFill><a:blip r:embed="$rId" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
                '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="3048000" cy="2286000"/></a:xfrm><a:prstGeom prst="rect"/></pic:spPr>'
                '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing>');
            body.write('</w:r></w:p></w:tc>');
            if (pi == 0) {
              body.write('<w:tc><w:tcPr><w:tcW w:w="4800" w:type="dxa"/><w:vMerge w:val="restart"/></w:tcPr>');
              body.write('<w:p><w:r><w:rPr><w:sz w:val="18"/></w:rPr><w:t>${e(types)}</w:t></w:r></w:p></w:tc>');
            } else {
              body.write('<w:tc><w:tcPr><w:tcW w:w="4800" w:type="dxa"/><w:vMerge/></w:tcPr></w:tc>');
            }
            body.write('</w:tr>');
          }
        }
        // Bottom row: Location + Comments + Impact
        body.write('<w:tr>');
        body.write('<w:tc><w:tcPr><w:tcW w:w="1200" w:type="dxa"/></w:tcPr>');
        body.write('<w:p><w:r><w:rPr><w:b/><w:sz w:val="18"/></w:rPr><w:t>Location:</w:t></w:r></w:p>');
        body.write('<w:p><w:r><w:rPr><w:sz w:val="18"/></w:rPr><w:t>${e(_loc(insp))}</w:t></w:r></w:p></w:tc>');
        body.write('<w:tc><w:tcPr><w:tcW w:w="6000" w:type="dxa"/></w:tcPr>');
        body.write('<w:p><w:r><w:rPr><w:b/><w:sz w:val="18"/></w:rPr><w:t>Inspector\'s comments:</w:t></w:r></w:p>');
        body.write("<w:p><w:r><w:rPr><w:b/><w:sz w:val=\"18\"/></w:rPr><w:t>Inspector's comments:</w:t></w:r></w:p>");
        body.write('<w:p><w:r><w:rPr><w:sz w:val="18"/></w:rPr><w:t>${e(insp.inspectorComments)}</w:t></w:r></w:p></w:tc>');
        body.write('<w:tc><w:tcPr><w:tcW w:w="4800" w:type="dxa"/></w:tcPr>');
        body.write('<w:p><w:r><w:rPr><w:b/><w:sz w:val="18"/></w:rPr><w:t>Impact Category:</w:t></w:r></w:p>');
        body.write('<w:p><w:r><w:rPr><w:sz w:val="18"/></w:rPr><w:t>${e(_impact(insp.impactCategory))}</w:t></w:r></w:p></w:tc>');
        body.write('</w:tr></w:tbl>');
      }
    }

    // ---- Build archive ----
    final documentXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'
        ' xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"'
        ' xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"'
        ' xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"'
        ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<w:body>'
        '${body.toString()}'
        '<w:sectPr>'
        '<w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" w:header="0" w:footer="0"/>'
        '</w:sectPr>'
        '</w:body>'
        '</w:document>';

    final settingsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:defaultTabStop w:val="720"/>'
        '</w:settings>';

    archive.addFile(ArchiveFile('[Content_Types].xml', _contentTypes().length, utf8.encode(_contentTypes())));
    archive.addFile(ArchiveFile('_rels/.rels', _packageRels().length, utf8.encode(_packageRels())));
    archive.addFile(ArchiveFile('word/document.xml', documentXml.length, utf8.encode(documentXml)));
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', _docRels(imgRels).length, utf8.encode(_docRels(imgRels))));
    archive.addFile(ArchiveFile('word/styles.xml', _styles().length, utf8.encode(_styles())));
    archive.addFile(ArchiveFile('word/settings.xml', settingsXml.length, utf8.encode(settingsXml)));

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded!);
  }

  static String _contentTypes() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Default Extension="jpg" ContentType="image/jpeg"/>'
        '<Default Extension="png" ContentType="image/png"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
        '<Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>'
        '</Types>';
  }

  static String _packageRels() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>';
  }

  static String _docRels(Map<String, String> imgRels) {
    final sb = StringBuffer();
    sb.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    for (final entry in imgRels.entries) {
      sb.write('<Relationship Id="${entry.key}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/${entry.value}"/>');
    }
    sb.write('</Relationships>');
    return sb.toString();
  }

  static String _styles() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
        '<w:name w:val="Normal"/>'
        '<w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/>'
        '<w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>'
        '<w:pPr><w:spacing w:after="120" w:line="276" w:lineRule="auto"/></w:pPr>'
        '</w:style>'
        '<w:style w:type="table" w:default="1" w:styleId="TableGrid">'
        '<w:name w:val="Table Grid"/>'
        '<w:tblPr><w:tblBorders>'
        '<w:top w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
        '<w:left w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
        '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
        '<w:right w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
        '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
        '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
        '</w:tblBorders></w:tblPr>'
        '</w:style>'
        '</w:styles>';
  }

  static String _loc(InspectionReportModel insp) {
    final loc = insp.location.trim();
    return loc.isNotEmpty ? loc : '-';
  }

  static String _types(Set<String> codes) {
    final sb = StringBuffer();
    sb.writeln('Crack:');
    for (final code in ['FC1', 'FC2', 'FC3', 'FC4']) {
      sb.writeln('${codes.contains(code) ? "\u2611" : "\u2610"} $code');
    }
    for (final code in ['WC1', 'WC2', 'WC3', 'WC4']) {
      sb.writeln('${codes.contains(code) ? "\u2611" : "\u2610"} $code');
    }
    sb.writeln('Bent:');
    for (final code in ['B1', 'B2', 'B3', 'B4']) {
      sb.writeln('${codes.contains(code) ? "\u2611" : "\u2610"} $code');
    }
    sb.writeln('Damage:');
    for (final code in ['D1', 'D2', 'D3', 'D4']) {
      sb.writeln('${codes.contains(code) ? "\u2611" : "\u2610"} $code');
    }
    return sb.toString();
  }

  static String _impact(String category) {
    return 'Minor: ${category == "Minor" ? "\u2611" : "\u2610"} | '
        'Moderate: ${category == "Moderate" ? "\u2611" : "\u2610"} | '
        'Major: ${category == "Major" ? "\u2611" : "\u2610"}';
  }

  /// Escape XML special characters to prevent invalid XML in the DOCX.
  static String _e(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll('\'', '&apos;');
  }
}
