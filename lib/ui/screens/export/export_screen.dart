import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import '../../../core/models/inspection_report_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/inspection_provider.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  static const _exportPresetPref = 'fieldlens_export_preset';
  static const _downloadsPreset = 'downloads';
  static const _documentsPreset = 'documents';
  static const double _pdfPhotoWidthCm = 9.8;
  static const double _pdfPhotoHeightCm = 8.8;
  static const double _pdfMarginLeftCm = 1.80;
  static const double _pdfMarginRightCm = 1.73;
  static const double _pdfMarginTopCm = 2.12;
  static const double _pdfMarginBottomCm = 2.47;
  static const double _pdfGridBorderWidth = 0.8;

  bool _isExporting = false;
  String _exportPreset = _downloadsPreset;

  double get _pdfPhotoWidth => _pdfPhotoWidthCm * PdfPageFormat.cm;
  double get _pdfPhotoHeight => _pdfPhotoHeightCm * PdfPageFormat.cm;
  double get _pdfItemColumnWidth => 1.45 * PdfPageFormat.cm;
  double get _pdfPhotoColumnWidth => _pdfPhotoWidth + 6;
  double get _pdfTopRowHeight => _pdfPhotoHeight + 6;
  double get _pdfBottomRowHeight => 56;

  @override
  void initState() {
    super.initState();
    _loadExportPreset();
  }

  Future<void> _loadExportPreset() async {
    final prefs = await SharedPreferences.getInstance();
    final preset = prefs.getString(_exportPresetPref);
    if (preset == _downloadsPreset || preset == _documentsPreset) {
      setState(() => _exportPreset = preset!);
    }
  }

  Future<void> _setExportPreset(String preset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_exportPresetPref, preset);
    if (!mounted) return;
    setState(() => _exportPreset = preset);
  }

  Future<Directory> _resolveExportDirectory() async {
    if (Platform.isAndroid) {
      final base = _exportPreset == _documentsPreset
          ? '/storage/emulated/0/Documents'
          : '/storage/emulated/0/Download';
      final target = Directory('$base/FieldLens Reports');
      try {
        if (!await target.exists()) {
          await target.create(recursive: true);
        }
        return target;
      } catch (_) {}
    }

    final appDir = await getApplicationDocumentsDirectory();
    final fallback = Directory('${appDir.path}/FieldLens Reports');
    if (!await fallback.exists()) {
      await fallback.create(recursive: true);
    }
    return fallback;
  }

  String _friendlyFolderLabel() {
    if (_exportPreset == _documentsPreset) {
      return 'Documents > FieldLens Reports';
    }
    return 'Downloads > FieldLens Reports';
  }

  Future<void> _exportToPDF() async {
    setState(() => _isExporting = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final inspectionProvider = context.read<InspectionProvider>();
      final inspections = List<InspectionReportModel>.from(
       inspectionProvider.inspections,
      )..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (inspections.isEmpty) {
        throw Exception('No inspections available');
      }

      final user = authProvider.currentUser;
      final prepared = await Future.wait(
        inspections.map((entry) async {
          final List<Uint8List> allBytes = [];
          for (final path in entry.photoPaths) {
            if (path.isNotEmpty) {
              final file = File(path);
              if (await file.exists()) {
                allBytes.add(await file.readAsBytes());
              }
            }
          }
          return _PreparedInspection(entry, allBytes);
        }),
      );

      final pdf = pw.Document();

      final photoEntries = _expandPhotoEntries(prepared, user?.name, user?.inspectorId);
      for (var start = 0; start < photoEntries.length; start += 2) {
        final pageEntries = photoEntries.skip(start).take(2).toList();
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.only(
              left: _pdfMarginLeftCm * PdfPageFormat.cm,
              right: _pdfMarginRightCm * PdfPageFormat.cm,
              top: _pdfMarginTopCm * PdfPageFormat.cm,
              bottom: _pdfMarginBottomCm * PdfPageFormat.cm,
            ),
            build: (_) => _buildPdfPage(pageEntries),
          ),
        );
      }

      final output = await _resolveExportDirectory();
      final file = File(
        p.join(
          output.path,
          'FieldLens_Report_all_inspections_${DateTime.now().millisecondsSinceEpoch}.pdf',
        ),
      );
      await file.writeAsBytes(await pdf.save());
      _showSuccess('PDF saved in ${_friendlyFolderLabel()}', file);
    } catch (e) {
      _showFailure('Error exporting PDF: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  pw.Widget _buildPdfPage(List<_PreparedPhotoEntry> pageEntries) {
    // Check if all entries on this page use overall mode or defect mode
    // We need a unified header row - check first entry's mode
    final firstEntry = pageEntries.first;
    final isOverallPage = firstEntry.prepared.inspection.isOverallMode;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (isOverallPage)
          _buildOverallGridHeaderRow()
        else
          _buildDefectGridHeaderRow(),
        ...pageEntries.map((entry) {
          if (entry.prepared.inspection.isOverallMode) {
            return _buildOverallItemBlock(entry);
          } else {
            return _buildDefectItemBlock(entry);
          }
        }),
      ],
    );
  }

  // ================================================================
  // TEMPLATE 1 - OVERALL VIEW HEADER (image_211c29.png style)
  // ================================================================
  pw.Widget _buildOverallGridHeaderRow() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: PdfColors.black,
          width: _pdfGridBorderWidth,
        ),
      ),
      child: pw.Row(
        children: [
          _headerCell('ITEM', width: _pdfItemColumnWidth),
          _headerCell('PHOTO', expand: true),
        ],
      ),
    );
  }

  // ================================================================
  // TEMPLATE 2 - DEFECT ASSESSMENT HEADER (image_211ca5.png style)
  // ================================================================
  pw.Widget _buildDefectGridHeaderRow() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: PdfColors.black,
          width: _pdfGridBorderWidth,
        ),
      ),
      child: pw.Row(
        children: [
          _headerCell('ITEM', width: _pdfItemColumnWidth),
          _headerCell('PHOTO', width: _pdfPhotoColumnWidth),
          _headerCell('ASSESSMENT TYPES', expand: true),
        ],
      ),
    );
  }

  pw.Widget _headerCell(String text, {double? width, bool expand = false}) {
    final child = pw.Container(
      alignment: pw.Alignment.center,
      height: 14,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          right: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
        ),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
      ),
    );

    if (expand) {
      return pw.Expanded(
        child: pw.Container(
          height: 14,
          alignment: pw.Alignment.center,
          child: pw.Text(
            text,
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
        ),
      );
    }

    return pw.SizedBox(width: width, child: child);
  }

  List<_PreparedPhotoEntry> _expandPhotoEntries(
    List<_PreparedInspection> inspections,
    String? inspectorName,
    String? inspectorId,
  ) {
    final entries = <_PreparedPhotoEntry>[];

    for (var index = 0; index < inspections.length; index++) {
      final prepared = inspections[index];
      final itemLabel = prepared.inspection.itemNumber.isNotEmpty
          ? prepared.inspection.itemNumber
          : (index + 1).toString();

      if (prepared.allImageBytes.isEmpty) {
        entries.add(
          _PreparedPhotoEntry(
            prepared: prepared,
            itemLabel: itemLabel,
            inspectorLabel: _buildInspectorLabel(inspectorName, inspectorId),
          ),
        );
        continue;
      }

      for (var photoIndex = 0;
          photoIndex < prepared.allImageBytes.length;
          photoIndex++) {
        entries.add(
          _PreparedPhotoEntry(
            prepared: prepared,
            itemLabel: itemLabel,
            inspectorLabel: _buildInspectorLabel(inspectorName, inspectorId),
            imageBytes: prepared.allImageBytes[photoIndex],
            photoIndex: photoIndex,
            totalPhotos: prepared.allImageBytes.length,
          ),
        );
      }
    }

    return entries;
  }

  String _buildInspectorLabel(String? inspectorName, String? inspectorId) {
    final name = (inspectorName ?? '').trim();
    final id = (inspectorId ?? '').trim();
    if (name.isEmpty && id.isEmpty) return '';
    if (name.isEmpty) return id;
    if (id.isEmpty) return name;
    return '$name ($id)';
  }

  // ================================================================
  // TEMPLATE 1 - OVERALL VIEW ITEM BLOCK
  // Two columns: "ITEM" (Narrow) and "PHOTO" (Wide, spans rest)
  // Bottom: "Location:" (Left) and "Inspector's comments:" (Right)
  // ================================================================
  pw.Widget _buildOverallItemBlock(_PreparedPhotoEntry entry) {
    final inspection = entry.prepared.inspection;

    pw.Widget photoWidget;
    if (entry.imageBytes != null) {
      photoWidget = pw.Image(
        pw.MemoryImage(entry.imageBytes!),
        width: _pdfPhotoWidth,
        height: _pdfPhotoHeight,
        fit: pw.BoxFit.cover,
      );
    } else {
      photoWidget = pw.Container(
        width: _pdfPhotoWidth,
        height: _pdfPhotoHeight,
        alignment: pw.Alignment.center,
        color: PdfColors.grey200,
        child: pw.Text('No Image',
            style: const pw.TextStyle(color: PdfColors.grey600)),
      );
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: const pw.Border(
          left: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
          right: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
          bottom: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
        ),
      ),
      child: pw.Column(
        children: [
          // Top row: ITEM | PHOTO (full remaining width)
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildTopItemCell(entry),
              // Photo spans remaining width (no assessment column)
              pw.Expanded(
                child: pw.Container(
                  height: _pdfTopRowHeight,
                  padding: const pw.EdgeInsets.all(3),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      right: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
                    ),
                  ),
                  child: photoWidget,
                ),
              ),
            ],
          ),
          // Bottom row: Location | Inspector's comments (both span full width)
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // "Location:" left side (proportional width ~30%)
              pw.Expanded(
                flex: 3,
                child: pw.Container(
                  height: _pdfBottomRowHeight,
                  padding: const pw.EdgeInsets.fromLTRB(4, 2, 3, 2),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
                      right: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Location:',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        _resolvedPdfLocation(inspection),
                        style: const pw.TextStyle(fontSize: 7.8),
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),
              // "Inspector's comments:" right side (remaining ~70%)
              pw.Expanded(
                flex: 7,
                child: _buildOverallCommentsCell(entry, inspection),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildOverallCommentsCell(
    _PreparedPhotoEntry entry,
    InspectionReportModel inspection,
  ) {
    final lines = _formatComments(inspection.inspectorComments);
    return pw.Container(
      height: _pdfBottomRowHeight,
      padding: const pw.EdgeInsets.fromLTRB(6, 2, 6, 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
          right: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Inspector's comments:",
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
          if (lines.isNotEmpty) pw.SizedBox(height: 1.5),
          ...lines.map(
            (line) => pw.Text(
              line,
              style: const pw.TextStyle(fontSize: 7.7),
              maxLines: 1,
            ),
          ),
          if (entry.inspectorLabel.isNotEmpty) ...[
            pw.SizedBox(height: 1.5),
            pw.Text(
              'Inspector: ${entry.inspectorLabel}',
              style: const pw.TextStyle(fontSize: 7.1),
              maxLines: 1,
            ),
          ],
        ],
      ),
    );
  }

  // ================================================================
  // TEMPLATE 2 - DEFECT ASSESSMENT ITEM BLOCK
  // Three columns: "ITEM", "PHOTO", "ASSESSMENT TYPES"
  // Bottom: "Location:", "Inspector's comments:", "Impact Category:"
  // ================================================================
  pw.Widget _buildDefectItemBlock(_PreparedPhotoEntry entry) {
    final inspection = entry.prepared.inspection;
    final assessmentWidget = _buildAssessmentCell(
      inspection.selectedDefectCodes.toSet(),
    );

    pw.Widget photoWidget;
    if (entry.imageBytes != null) {
      photoWidget = pw.Image(
        pw.MemoryImage(entry.imageBytes!),
        width: _pdfPhotoWidth,
        height: _pdfPhotoHeight,
        fit: pw.BoxFit.cover,
      );
    } else {
      photoWidget = pw.Container(
        width: _pdfPhotoWidth,
        height: _pdfPhotoHeight,
        alignment: pw.Alignment.center,
        color: PdfColors.grey200,
        child: pw.Text('No Image',
            style: const pw.TextStyle(color: PdfColors.grey600)),
      );
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: const pw.Border(
          left: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
          right: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
          bottom: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
        ),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildTopItemCell(entry),
              _buildTopPhotoCell(photoWidget),
              pw.Expanded(child: _buildTopAssessmentCell(assessmentWidget)),
            ],
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildBottomLocationCell(inspection),
              _buildBottomCommentsCell(entry, inspection),
              pw.Expanded(child: _buildBottomImpactCell(inspection)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);
    try {
      final inspectionProvider = context.read<InspectionProvider>();
      final rows = List<InspectionReportModel>.from(
       inspectionProvider.inspections,
      )..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (rows.isEmpty) {
       throw Exception('No inspections available');
      }

      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];
      sheet.name = 'Dilapidation Survey Report';

      final headers = [
       'Item No.',
       'REF. NO.',
       'Section',
       'Scope (Internal)',
       'Scope (External)',
       'Scope (M&E)',
       'Scope (Public Fac.)',
       'WC1', 'WC2', 'WC3', 'WC4',
       'FC1', 'FC2', 'FC3', 'FC4',
       'B1', 'B2', 'B3', 'B4',
       'D1', 'D2', 'D3', 'D4',
       'Status',
       'Impact Category',
       'Location',
       "Inspector's Comments",
       'Date Time',
       'Photo',
       'Report Mode',
      ];

      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.getRangeByIndex(1, i + 1);
        cell.setText(headers[i]);
        cell.cellStyle.bold = true;
        cell.cellStyle.backColor = '#1565C0';
        cell.cellStyle.fontColor = '#FFFFFF';
        cell.cellStyle.wrapText = true;
      }

      sheet.getRangeByIndex(1, 1, 1, headers.length).rowHeight = 36;
      for (var i = 1; i <= headers.length; i++) {
        sheet.getRangeByIndex(1, i).columnWidth = 12;
      }
      sheet.getRangeByIndex(1, 4).columnWidth = 24;
      sheet.getRangeByIndex(1, 27).columnWidth = 36;
      sheet.getRangeByIndex(1, 28).columnWidth = 18;
      sheet.getRangeByIndex(1, headers.length).columnWidth = 14;

      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        final inspection = rows[rowIndex];
        final excelRow = rowIndex + 2;
        final codes = inspection.selectedDefectCodes.toSet();

        sheet.getRangeByIndex(excelRow, 1).setText(inspection.itemNumber);
        sheet.getRangeByIndex(excelRow, 2).setText(inspection.refNo);
        sheet.getRangeByIndex(excelRow, 3).setText(inspection.section);
        sheet.getRangeByIndex(excelRow, 4).setText(inspection.scopeInternal ? '✓' : '');
        sheet.getRangeByIndex(excelRow, 5).setText(inspection.scopeExternal ? '✓' : '');
        sheet.getRangeByIndex(excelRow, 6).setText(inspection.scopeME ? '✓' : '');
        sheet
            .getRangeByIndex(excelRow, 7)
            .setText(inspection.scopePublicFacilities ? '✓' : '');

        const allCodeOrder = [
          'WC1', 'WC2', 'WC3', 'WC4',
          'FC1', 'FC2', 'FC3', 'FC4',
          'B1', 'B2', 'B3', 'B4',
          'D1', 'D2', 'D3', 'D4',
        ];
        for (var c = 0; c < allCodeOrder.length; c++) {
          final code = allCodeOrder[c];
          sheet
              .getRangeByIndex(excelRow, 8 + c)
              .setText(codes.contains(code) ? '✓' : '');
          sheet
              .getRangeByIndex(excelRow, 8 + c)
              .cellStyle
              .hAlign = xlsio.HAlignType.center;
        }

        sheet.getRangeByIndex(excelRow, 24).setText(inspection.status);
        sheet.getRangeByIndex(excelRow, 25).setText(inspection.impactCategory);
        sheet.getRangeByIndex(excelRow, 26).setText(inspection.location);
        sheet.getRangeByIndex(excelRow, 27).setText(inspection.inspectorComments);
        sheet
            .getRangeByIndex(excelRow, 28)
            .setText(DateFormat('dd/MM/yyyy HH:mm').format(inspection.timestamp));

        final imagePath = inspection.primaryPhotoPath;
        if (imagePath.isNotEmpty) {
          final imgFile = File(imagePath);
          if (await imgFile.exists()) {
            try {
              final bytes = await imgFile.readAsBytes();
              final picture = sheet.pictures.addStream(excelRow, 29, bytes);
              picture.width = 80;
              picture.height = 80;
              sheet.getRangeByIndex(excelRow, 1).rowHeight = 65;
            } catch (_) {
              sheet.getRangeByIndex(excelRow, 29).setText('Image error');
            }
          } else {
            sheet.getRangeByIndex(excelRow, 29).setText('File missing');
          }
        } else {
          sheet.getRangeByIndex(excelRow, 29).setText('No image');
        }

        // Report Mode column
        sheet
            .getRangeByIndex(excelRow, 30)
            .setText(inspection.isOverallMode ? 'Overall View' : 'Defect Assessment');

        sheet.getRangeByIndex(excelRow, 27).cellStyle.wrapText = true;
      }

      final output = await _resolveExportDirectory();
      final file = File(
        p.join(
          output.path,
          'FieldLens_Report_all_inspections_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        ),
      );
      final bytes = workbook.saveAsStream();
      workbook.dispose();
      await file.writeAsBytes(bytes, flush: true);

      _showSuccess('Excel saved in ${_friendlyFolderLabel()}', file);
    } catch (e) {
      _showFailure('Error exporting Excel: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToDocx() async {
    setState(() => _isExporting = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final inspectionProvider = context.read<InspectionProvider>();
      final inspections = List<InspectionReportModel>.from(
        inspectionProvider.inspections,
      )..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (inspections.isEmpty) {
        throw Exception('No inspections available');
      }

      final user = authProvider.currentUser;
      final prepared = await Future.wait(
        inspections.map((entry) async {
          final List<Uint8List> allBytes = [];
          for (final path in entry.photoPaths) {
            if (path.isNotEmpty) {
              final file = File(path);
              if (await file.exists()) {
                allBytes.add(await file.readAsBytes());
              }
            }
          }
          return _PreparedInspection(entry, allBytes);
        }),
      );

      final photoEntries = _expandPhotoEntries(
        prepared,
        user?.name,
        user?.inspectorId,
      );
      final bytes = _buildDocxBytes(photoEntries, user?.name, user?.inspectorId);

      final output = await _resolveExportDirectory();
      final file = File(
        p.join(
          output.path,
          'FieldLens_Report_all_inspections_${DateTime.now().millisecondsSinceEpoch}.docx',
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
      _showSuccess('Word saved in ${_friendlyFolderLabel()}', file);
    } catch (e) {
      _showFailure('Error exporting Word document: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Uint8List _buildDocxBytes(
    List<_PreparedPhotoEntry> entries,
    String? inspectorName,
    String? inspectorId,
  ) {
    final pageGroups = <List<_PreparedPhotoEntry>>[];
    for (var i = 0; i < entries.length; i += 2) {
      pageGroups.add(entries.skip(i).take(2).toList());
    }

    final mediaAssets = <_DocxMediaAsset>[];
    final body = StringBuffer();
    for (var i = 0; i < pageGroups.length; i++) {
      final pageEntries = pageGroups[i];
      final isOverallPage = pageEntries.first.prepared.inspection.isOverallMode;
      body.write(_buildDocxPageXml(pageEntries, isOverallPage, mediaAssets));
      if (i != pageGroups.length - 1) {
        body.write(_docxPageBreak());
      }
    }

    final documentXml = _buildDocxDocumentXml(body.toString());
    final relsXml = _buildDocxDocumentRels(mediaAssets);
    final stylesXml = _buildDocxStylesXml();
    final contentTypesXml = _buildDocxContentTypes(mediaAssets);
    final appXml = _buildDocxAppXml();
    final coreXml = _buildDocxCoreXml();

    final archive = Archive()
      ..addFile(ArchiveFile.string('[Content_Types].xml', contentTypesXml))
      ..addFile(ArchiveFile.string('_rels/.rels', _buildDocxRootRelsXml()))
      ..addFile(ArchiveFile.string('docProps/app.xml', appXml))
      ..addFile(ArchiveFile.string('docProps/core.xml', coreXml))
      ..addFile(ArchiveFile.string('word/document.xml', documentXml))
      ..addFile(ArchiveFile.string('word/_rels/document.xml.rels', relsXml))
      ..addFile(ArchiveFile.string('word/styles.xml', stylesXml));

    for (final asset in mediaAssets) {
      archive.addFile(ArchiveFile(asset.path, asset.bytes.length, asset.bytes));
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw Exception('Failed to build DOCX archive');
    }
    return Uint8List.fromList(encoded);
  }

  String _buildDocxPageXml(
    List<_PreparedPhotoEntry> pageEntries,
    bool isOverallPage,
    List<_DocxMediaAsset> mediaAssets,
  ) {
    final rowBuilder = StringBuffer();
    rowBuilder.write(_docxTableStart(
      isOverallPage ? [822, 9082] : [822, 5557, 3525],
      header: true,
    ));
    if (isOverallPage) {
      rowBuilder.write(_docxHeaderRow(['ITEM', 'PHOTO'], [822, 9082]));
    } else {
      rowBuilder.write(_docxHeaderRow(['ITEM', 'PHOTO', 'ASSESSMENT TYPES'], [822, 5557, 3525]));
    }

    for (final entry in pageEntries) {
      if (isOverallPage) {
        rowBuilder.write(_buildDocxOverallEntryRows(entry, mediaAssets));
      } else {
        rowBuilder.write(_buildDocxDefectEntryRows(entry, mediaAssets));
      }
    }

    rowBuilder.write(_docxTableEnd());
    return rowBuilder.toString();
  }

  String _buildDocxOverallEntryRows(
    _PreparedPhotoEntry entry,
    List<_DocxMediaAsset> mediaAssets,
  ) {
    final inspection = entry.prepared.inspection;
    final itemLabel = _formatItemLabel(entry.itemLabel);
    final photoXml = entry.imageBytes != null
        ? _docxImageXml(
            entry.imageBytes!,
            mediaAssets,
            _emuFromCm(9.8),
            _emuFromCm(8.8),
          )
        : _docxParagraph('No Image', sizePt: 7.5, color: '808080', align: 'center');

    final commentXml = _docxCommentsCell(entry, inspection);
    final locationXml = _docxLocationCell(inspection);

    return [
      _docxTableRow([
        _docxCell(
          _docxParagraph(itemLabel, bold: true, sizePt: 9.5),
          widthTwips: 822,
          vAlign: 'top',
        ),
        _docxCell(
          photoXml,
          widthTwips: 9082,
          paddingTwips: 60,
          vAlign: 'top',
          align: 'center',
        ),
      ], heightTwips: 5050),
      _docxTableRow([
        _docxCell(locationXml, widthTwips: 2971, paddingTwips: 48, vAlign: 'top'),
        _docxCell(commentXml, widthTwips: 6933, paddingTwips: 72, vAlign: 'top'),
      ], heightTwips: 1000),
    ].join();
  }

  String _buildDocxDefectEntryRows(
    _PreparedPhotoEntry entry,
    List<_DocxMediaAsset> mediaAssets,
  ) {
    final inspection = entry.prepared.inspection;
    final itemLabel = _formatItemLabel(entry.itemLabel);
    final photoXml = entry.imageBytes != null
        ? _docxImageXml(
            entry.imageBytes!,
            mediaAssets,
            _emuFromCm(9.8),
            _emuFromCm(8.8),
          )
        : _docxParagraph('No Image', sizePt: 7.5, color: '808080', align: 'center');

    final assessmentXml = _docxAssessmentCell(inspection.selectedDefectCodes.toSet());
    final locationXml = _docxLocationCell(inspection);
    final commentsXml = _docxCommentsCell(entry, inspection);
    final impactXml = _docxImpactCell(inspection);

    return [
      _docxTableRow([
        _docxCell(
          _docxParagraph(itemLabel, bold: true, sizePt: 9.5),
          widthTwips: 822,
          vAlign: 'top',
        ),
        _docxCell(
          photoXml,
          widthTwips: 5557,
          paddingTwips: 60,
          vAlign: 'top',
          align: 'center',
        ),
        _docxCell(
          assessmentXml,
          widthTwips: 3525,
          paddingTwips: 40,
          vAlign: 'top',
        ),
      ], heightTwips: 5050),
      _docxTableRow([
        _docxCell(locationXml, widthTwips: 822, paddingTwips: 48, vAlign: 'top'),
        _docxCell(commentsXml, widthTwips: 5557, paddingTwips: 72, vAlign: 'top'),
        _docxCell(impactXml, widthTwips: 3525, paddingTwips: 48, vAlign: 'top'),
      ], heightTwips: 1000),
    ].join();
  }

  String _docxCommentsCell(
    _PreparedPhotoEntry entry,
    InspectionReportModel inspection,
  ) {
    final lines = _formatComments(inspection.inspectorComments);
    final buffer = StringBuffer();
    buffer.write(_docxParagraph("Inspector's comments:", bold: true, sizePt: 8.5));
    for (final line in lines) {
      buffer.write(_docxParagraph(line, sizePt: 7.7));
    }
    if (entry.inspectorLabel.isNotEmpty) {
      buffer.write(_docxParagraph(
        'Inspector: ${entry.inspectorLabel}',
        sizePt: 7.1,
      ));
    }
    return buffer.toString();
  }

  String _docxLocationCell(InspectionReportModel inspection) {
    return [
      _docxParagraph('Location:', bold: true, sizePt: 8.5),
      _docxParagraph(_resolvedPdfLocation(inspection), sizePt: 7.8),
    ].join();
  }

  String _docxImpactCell(InspectionReportModel inspection) {
    final buffer = StringBuffer();
    buffer.write(_docxParagraph('Impact Category:', bold: true, sizePt: 8.5));
    for (final item in [
      ('Minor:', inspection.impactCategory == 'Minor'),
      ('Moderate:', inspection.impactCategory == 'Moderate'),
      ('Major:', inspection.impactCategory == 'Major'),
    ]) {
      buffer.write(_docxTwoColumnLine(item.$1, item.$2));
    }
    return buffer.toString();
  }

  String _docxAssessmentCell(Set<String> selectedCodes) {
    final buffer = StringBuffer();
    buffer.write(_docxAssessmentSection(
      'Crack:',
      const ['FC1', 'FC2', 'FC3', 'FC4'],
      const ['WC1', 'WC2', 'WC3', 'WC4'],
      selectedCodes,
      spacingAfterTwips: 40,
    ));
    buffer.write(_docxAssessmentSection(
      'Bent:',
      const ['B1', 'B2'],
      const ['B3', 'B4'],
      selectedCodes,
      spacingAfterTwips: 40,
    ));
    buffer.write(_docxAssessmentSection(
      'Damage:',
      const ['D1', 'D2'],
      const ['D3', 'D4'],
      selectedCodes,
      spacingAfterTwips: 0,
    ));
    return buffer.toString();
  }

  String _docxAssessmentSection(
    String title,
    List<String> leftCodes,
    List<String> rightCodes,
    Set<String> selectedCodes, {
    required int spacingAfterTwips,
  }) {
    final buffer = StringBuffer();
    buffer.write(_docxParagraph(title, bold: true, sizePt: 8.5));
    buffer.write('<w:tbl>');
    buffer.write(_docxAssessmentTblPr());
    buffer.write('<w:tblGrid><w:gridCol w:w="1700"/><w:gridCol w:w="1700"/></w:tblGrid>');
    for (var i = 0; i < leftCodes.length; i++) {
      buffer.write('<w:tr>');
      buffer.write(_docxCell(
        _docxParagraph('${_docxCheckbox(selectedCodes.contains(leftCodes[i]))} ${leftCodes[i]}', sizePt: 8.2),
        widthTwips: 1700,
        paddingTwips: 20,
        vAlign: 'top',
        bordersXml: _docxAssessmentCellBorders(rightBorder: true),
      ));
      buffer.write(_docxCell(
        _docxParagraph('${_docxCheckbox(selectedCodes.contains(rightCodes[i]))} ${rightCodes[i]}', sizePt: 8.2),
        widthTwips: 1700,
        paddingTwips: 20,
        vAlign: 'top',
        bordersXml: _docxAssessmentCellBorders(),
      ));
      buffer.write('</w:tr>');
    }
    buffer.write('</w:tbl>');
    if (spacingAfterTwips > 0) {
      buffer.write(_docxSpacerParagraph(spacingAfterTwips));
    }
    return buffer.toString();
  }

  String _docxTwoColumnLine(String label, bool selected) {
    return '''
<w:tbl>
  ${_docxAssessmentTblPr()}
  <w:tblGrid><w:gridCol w:w="2500"/><w:gridCol w:w="380"/></w:tblGrid>
  <w:tr>
    ${_docxCell(
      _docxParagraph(label, bold: true, sizePt: 8.3),
      widthTwips: 2500,
      paddingTwips: 0,
      vAlign: 'top',
      bordersXml: _docxNoBorderCellBorders(),
    )}
    ${_docxCell(
      _docxParagraph(_docxCheckbox(selected), bold: true, sizePt: 8.3, align: 'center'),
      widthTwips: 380,
      paddingTwips: 0,
      vAlign: 'top',
      bordersXml: _docxNoBorderCellBorders(),
    )}
  </w:tr>
</w:tbl>''';
  }

  int _emuFromCm(double cm) => (cm * 360000).round();

  String _docxCheckbox(bool selected) => selected ? '☑' : '☐';

  String _docxImageXml(
    Uint8List bytes,
    List<_DocxMediaAsset> mediaAssets,
    int widthEmu,
    int heightEmu,
  ) {
    final asset = _DocxMediaAsset(
      path: 'word/media/image${mediaAssets.length + 1}.jpg',
      bytes: bytes,
      contentType: 'image/jpeg',
      relationshipId: 'rIdImage${mediaAssets.length + 1}',
    );
    mediaAssets.add(asset);
    return '''
<w:p>
  <w:pPr><w:jc w:val="center"/></w:pPr>
  <w:r>
    <w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
        <wp:extent cx="$widthEmu" cy="$heightEmu"/>
        <wp:docPr id="${mediaAssets.length}" name="Image ${mediaAssets.length}"/>
        <wp:cNvGraphicFramePr>
          <a:graphicFrameLocks noChangeAspect="1" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"/>
        </wp:cNvGraphicFramePr>
        <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
              <pic:nvPicPr>
                <pic:cNvPr id="${mediaAssets.length}" name="Image ${mediaAssets.length}"/>
                <pic:cNvPicPr/>
              </pic:nvPicPr>
              <pic:blipFill>
                <a:blip r:embed="${asset.relationshipId}" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
                <a:stretch><a:fillRect/></a:stretch>
              </pic:blipFill>
              <pic:spPr>
                <a:xfrm><a:off x="0" y="0"/><a:ext cx="$widthEmu" cy="$heightEmu"/></a:xfrm>
                <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
              </pic:spPr>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>
''';
  }

  String _docxParagraph(
    String text, {
    bool bold = false,
    double sizePt = 8.0,
    String color = '000000',
    String align = 'left',
    String? rightText,
  }) {
    final runs = <String>[];
    runs.add(_docxRun(text, bold: bold, sizePt: sizePt, color: color));
    if (rightText != null) {
      runs.add(_docxRun(rightText, bold: true, sizePt: sizePt, color: color));
    }
    return '''
<w:p>
  <w:pPr><w:jc w:val="$align"/><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/></w:pPr>
  ${runs.join()}
</w:p>
''';
  }

  String _docxRun(
    String text, {
    bool bold = false,
    double sizePt = 8.0,
    String color = '000000',
  }) {
    return '''
<w:r>
  <w:rPr>
    ${bold ? '<w:b/>' : ''}
    <w:rFonts w:ascii="Helvetica" w:hAnsi="Helvetica" w:eastAsia="Helvetica"/>
    <w:sz w:val="${(sizePt * 2).round()}"/>
    <w:szCs w:val="${(sizePt * 2).round()}"/>
    <w:color w:val="$color"/>
  </w:rPr>
  <w:t>${_xmlEscape(text)}</w:t>
</w:r>
''';
  }

  String _docxCell(
    String innerXml, {
    required int widthTwips,
    int paddingTwips = 0,
    String vAlign = 'top',
    String align = 'left',
    String? bordersXml,
  }) {
    return '''
<w:tc>
  <w:tcPr>
    <w:tcW w:w="$widthTwips" w:type="dxa"/>
    <w:vAlign w:val="$vAlign"/>
    <w:tcMar>
      <w:top w:w="$paddingTwips" w:type="dxa"/>
      <w:left w:w="$paddingTwips" w:type="dxa"/>
      <w:bottom w:w="$paddingTwips" w:type="dxa"/>
      <w:right w:w="$paddingTwips" w:type="dxa"/>
    </w:tcMar>
    ${bordersXml ?? _docxDefaultCellBorders()}
  </w:tcPr>
  ${innerXml.isEmpty ? '<w:p/>' : innerXml}
</w:tc>
''';
  }

  String _docxDefaultCellBorders() {
    return '''
<w:tcBorders>
  <w:top w:val="single" w:sz="6" w:color="000000"/>
  <w:left w:val="single" w:sz="6" w:color="000000"/>
  <w:bottom w:val="single" w:sz="6" w:color="000000"/>
  <w:right w:val="single" w:sz="6" w:color="000000"/>
</w:tcBorders>''';
  }

  String _docxAssessmentCellBorders({bool rightBorder = false}) {
    return '''
<w:tcBorders>
  <w:top w:val="nil"/>
  <w:left w:val="nil"/>
  <w:bottom w:val="nil"/>
  <w:right ${rightBorder ? 'w:val="single" w:sz="6" w:color="000000"' : 'w:val="nil"'} />
</w:tcBorders>''';
  }

  String _docxNoBorderCellBorders() {
    return '''
<w:tcBorders>
  <w:top w:val="nil"/>
  <w:left w:val="nil"/>
  <w:bottom w:val="nil"/>
  <w:right w:val="nil"/>
</w:tcBorders>''';
  }

  String _docxAssessmentTblPr() {
    return '''
<w:tblW w:w="0" w:type="auto"/>
<w:tblBorders>
  <w:top w:val="nil"/>
  <w:left w:val="nil"/>
  <w:bottom w:val="nil"/>
  <w:right w:val="nil"/>
  <w:insideH w:val="nil"/>
  <w:insideV w:val="nil"/>
</w:tblBorders>
<w:tblCellMar>
  <w:top w:w="0" w:type="dxa"/>
  <w:left w:w="0" w:type="dxa"/>
  <w:bottom w:w="0" w:type="dxa"/>
  <w:right w:w="0" w:type="dxa"/>
</w:tblCellMar>''';
  }

  String _docxSpacerParagraph(int afterTwips) {
    return '<w:p><w:pPr><w:spacing w:after="$afterTwips"/></w:pPr></w:p>';
  }

  String _docxTableRow(List<String> cells, {int? heightTwips}) {
    final buffer = StringBuffer('<w:tr>');
    if (heightTwips != null) {
      buffer.write('<w:trPr><w:trHeight w:val="$heightTwips" w:hRule="atLeast"/></w:trPr>');
    }
    for (final cell in cells) {
      buffer.write(cell);
    }
    buffer.write('</w:tr>');
    return buffer.toString();
  }

  String _docxHeaderRow(List<String> titles, List<int> widths) {
    final cells = <String>[];
    for (var i = 0; i < titles.length; i++) {
      cells.add(_docxCell(
        _docxParagraph(titles[i], bold: true, sizePt: 8.5, align: 'center'),
        widthTwips: widths[i],
        paddingTwips: 0,
        vAlign: 'center',
        align: 'center',
      ));
    }
    return _docxTableRow(cells, heightTwips: 240);
  }

  String _docxTableStart(List<int> widths, {bool header = false}) {
    final grid = widths.map((w) => '<w:gridCol w:w="$w"/>').join();
    return '<w:tbl><w:tblPr>${_docxTblPr(borderTwips: 6)}</w:tblPr><w:tblGrid>$grid</w:tblGrid>';
  }

  String _docxTableEnd() => '</w:tbl>';

  String _docxTblPr({required int borderTwips}) {
    return '''
<w:tblW w:w="0" w:type="auto"/>
<w:tblBorders>
  <w:top w:val="single" w:sz="$borderTwips" w:color="000000"/>
  <w:left w:val="single" w:sz="$borderTwips" w:color="000000"/>
  <w:bottom w:val="single" w:sz="$borderTwips" w:color="000000"/>
  <w:right w:val="single" w:sz="$borderTwips" w:color="000000"/>
  <w:insideH w:val="single" w:sz="$borderTwips" w:color="000000"/>
  <w:insideV w:val="single" w:sz="$borderTwips" w:color="000000"/>
</w:tblBorders>
<w:tblCellMar>
  <w:top w:w="0" w:type="dxa"/>
  <w:left w:w="0" w:type="dxa"/>
  <w:bottom w:w="0" w:type="dxa"/>
  <w:right w:w="0" w:type="dxa"/>
</w:tblCellMar>
''';
  }

  String _docxPageBreak() => '<w:p><w:r><w:br w:type="page"/></w:r></w:p>';

  String _buildDocxDocumentXml(String bodyXml) {
    final pageWidth = 11906;
    final pageHeight = 16838;
    final marginLeft = (1.80 * 567).round();
    final marginRight = (1.73 * 567).round();
    final marginTop = (2.12 * 567).round();
    final marginBottom = (2.47 * 567).round();

    return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
 xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
 xmlns:v="urn:schemas-microsoft-com:vml"
 xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing"
 xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
 xmlns:w10="urn:schemas-microsoft-com:office:word"
 xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
 xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"
 xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup"
 xmlns:wpi="http://schemas.microsoft.com/office/word/2010/wordprocessingInk"
 xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml"
 xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"
 mc:Ignorable="w14 wp14">
  <w:body>
    $bodyXml
    <w:sectPr>
      <w:pgSz w:w="$pageWidth" w:h="$pageHeight"/>
      <w:pgMar w:top="$marginTop" w:right="$marginRight" w:bottom="$marginBottom" w:left="$marginLeft" w:header="0" w:footer="0" w:gutter="0"/>
      <w:cols w:space="720"/>
      <w:docGrid w:linePitch="360"/>
    </w:sectPr>
  </w:body>
</w:document>
''';
  }

  String _buildDocxDocumentRels(List<_DocxMediaAsset> mediaAssets) {
    final buffer = StringBuffer('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">''');
    for (var i = 0; i < mediaAssets.length; i++) {
      final asset = mediaAssets[i];
      buffer.write('''
  <Relationship Id="${asset.relationshipId}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="${asset.path.replaceFirst('word/', '')}"/>''');
    }
    buffer.write('</Relationships>');
    return buffer.toString();
  }

  String _buildDocxRootRelsXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>''';
  }

  String _buildDocxStylesXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:qFormat/>
    <w:rPr>
      <w:rFonts w:ascii="Helvetica" w:hAnsi="Helvetica" w:eastAsia="Helvetica"/>
      <w:sz w:val="22"/>
      <w:szCs w:val="22"/>
    </w:rPr>
  </w:style>
</w:styles>''';
  }

  String _buildDocxContentTypes(List<_DocxMediaAsset> mediaAssets) {
    final defaults = <String, String>{
      'rels': 'application/vnd.openxmlformats-package.relationships+xml',
      'xml': 'application/xml',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
    };
    final seenExt = <String>{};
    final buffer = StringBuffer('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="${defaults['rels']}"/>
  <Default Extension="xml" ContentType="${defaults['xml']}"/>''');
    for (final asset in mediaAssets) {
      final ext = p.extension(asset.path).replaceFirst('.', '').toLowerCase();
      if (seenExt.add(ext)) {
        buffer.write('\n  <Default Extension="$ext" ContentType="${defaults[ext] ?? 'image/jpeg'}"/>');
      }
    }
    buffer.write('''
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>''');
    return buffer.toString();
  }

  String _buildDocxAppXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"
 xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Microsoft Word</Application>
</Properties>''';
  }

  String _buildDocxCoreXml() {
    final now = DateTime.now().toUtc().toIso8601String();
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
 xmlns:dc="http://purl.org/dc/elements/1.1/"
 xmlns:dcterms="http://purl.org/dc/terms/"
 xmlns:dcmitype="http://purl.org/dc/dcmitype/"
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>FieldLens Report</dc:title>
  <dc:creator>FieldLens</dc:creator>
  <cp:lastModifiedBy>FieldLens</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">$now</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">$now</dcterms:modified>
</cp:coreProperties>''';
  }

  String _xmlEscape(String text) => const HtmlEscape(HtmlEscapeMode.element).convert(text);

  pw.Widget _buildTopItemCell(_PreparedPhotoEntry entry) {
    return pw.Container(
      width: _pdfItemColumnWidth,
      height: _pdfTopRowHeight,
      padding: const pw.EdgeInsets.only(left: 4, top: 4, right: 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          right: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
        ),
      ),
      alignment: pw.Alignment.topLeft,
      child: pw.Text(
        _formatItemLabel(entry.itemLabel),
        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _buildTopPhotoCell(pw.Widget photoWidget) {
    return pw.Container(
      width: _pdfPhotoColumnWidth,
      height: _pdfTopRowHeight,
      padding: const pw.EdgeInsets.all(3),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          right: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
        ),
      ),
      child: photoWidget,
    );
  }

  pw.Widget _buildTopAssessmentCell(pw.Widget assessmentWidget) {
    return pw.Container(
      height: _pdfTopRowHeight,
      child: assessmentWidget,
    );
  }

  pw.Widget _buildBottomLocationCell(InspectionReportModel inspection) {
    return pw.Container(
      width: _pdfItemColumnWidth,
      height: _pdfBottomRowHeight,
      padding: const pw.EdgeInsets.fromLTRB(4, 2, 3, 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
          right: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Location:',
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            _resolvedPdfLocation(inspection),
            style: const pw.TextStyle(fontSize: 7.8),
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  String _resolvedPdfLocation(InspectionReportModel inspection) {
    final location = inspection.location.trim();
    if (location.isNotEmpty) {
      return location;
    }

    return '-';
  }

  pw.Widget _buildBottomCommentsCell(
    _PreparedPhotoEntry entry,
    InspectionReportModel inspection,
  ) {
    final lines = _formatComments(inspection.inspectorComments);
    return pw.Container(
      width: _pdfPhotoColumnWidth,
      height: _pdfBottomRowHeight,
      padding: const pw.EdgeInsets.fromLTRB(6, 2, 6, 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
          right: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Inspector's comments:",
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
          if (lines.isNotEmpty) pw.SizedBox(height: 1.5),
          ...lines.map(
            (line) => pw.Text(
              line,
              style: const pw.TextStyle(fontSize: 7.7),
              maxLines: 1,
            ),
          ),
          if (entry.inspectorLabel.isNotEmpty) ...[
            pw.SizedBox(height: 1.5),
            pw.Text(
              'Inspector: ${entry.inspectorLabel}',
              style: const pw.TextStyle(fontSize: 7.1),
              maxLines: 1,
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildBottomImpactCell(InspectionReportModel inspection) {
    return pw.Container(
      height: _pdfBottomRowHeight,
      padding: const pw.EdgeInsets.fromLTRB(4, 2, 4, 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Impact Category:',
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          _buildImpactLine('Minor:', inspection.impactCategory == 'Minor'),
          _buildImpactLine('Moderate:', inspection.impactCategory == 'Moderate'),
          _buildImpactLine('Major:', inspection.impactCategory == 'Major'),
        ],
      ),
    );
  }

  pw.Widget _buildAssessmentCell(Set<String> selectedCodes) {
    return pw.Column(
      children: [
        pw.Expanded(
          flex: 5,
          child: _buildAssessmentSection(
            title: 'Crack:',
            leftCodes: const ['FC1', 'FC2', 'FC3', 'FC4'],
            rightCodes: const ['WC1', 'WC2', 'WC3', 'WC4'],
            selectedCodes: selectedCodes,
            bottomSpacing: 2,
          ),
        ),
        pw.Expanded(
          flex: 3,
          child: _buildAssessmentSection(
            title: 'Bent:',
            leftCodes: const ['B1', 'B2'],
            rightCodes: const ['B3', 'B4'],
            selectedCodes: selectedCodes,
            bottomSpacing: 2,
          ),
        ),
        pw.Expanded(
          flex: 3,
          child: _buildAssessmentSection(
            title: 'Damage:',
            leftCodes: const ['D1', 'D2'],
            rightCodes: const ['D3', 'D4'],
            selectedCodes: selectedCodes,
            bottomSpacing: 0,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildAssessmentSection({
    required String title,
    required List<String> leftCodes,
    required List<String> rightCodes,
    required Set<String> selectedCodes,
    required double bottomSpacing,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 1.5),
          pw.Expanded(
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 4),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: leftCodes
                          .map((code) => _buildAssessmentCodeLine(code, selectedCodes.contains(code)))
                          .toList(),
                    ),
                  ),
                ),
                pw.Container(width: _pdfGridBorderWidth, color: PdfColors.black),
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 4),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: rightCodes
                          .map((code) => _buildAssessmentCodeLine(code, selectedCodes.contains(code)))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (bottomSpacing > 0) pw.SizedBox(height: bottomSpacing),
        ],
      ),
    );
  }

  pw.Widget _buildAssessmentCodeLine(String code, bool selected) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          _buildCheckBox(selected),
          pw.SizedBox(width: 3),
          pw.Text(code, style: const pw.TextStyle(fontSize: 8.2)),
        ],
      ),
    );
  }

  pw.Widget _buildImpactLine(String label, bool selected) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 8.3, fontWeight: pw.FontWeight.bold),
            ),
          ),
          _buildCheckBox(selected),
        ],
      ),
    );
  }

  pw.Widget _buildCheckBox(bool selected) {
    return pw.Container(
      width: 10,
      height: 10,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey700, width: 0.8),
      ),
      child: selected
          ? pw.Center(
              child: pw.Text(
                '✓',
                style: pw.TextStyle(
                  color: PdfColors.black,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                ),
              ),
            )
          : null,
    );
  }

  String _formatItemLabel(String itemLabel) {
    final trimmed = itemLabel.trim();
    if (trimmed.isEmpty) return '-';
    return trimmed.endsWith('.') ? trimmed : '$trimmed.';
  }

  List<String> _formatComments(String comments) {
    final normalized = comments
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (normalized.isEmpty) {
      return const ['-'];
    }

    if (normalized.length > 1) {
      return normalized
          .asMap()
          .entries
          .take(3)
          .map((entry) => '${entry.key + 1}. ${entry.value}')
          .toList();
    }

    final value = normalized.first;
    if (value.startsWith(RegExp(r'\d+\.'))) {
      return [value];
    }
    return ['1. $value'];
  }

  Future<void> _shareFile(File file) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'FieldLens inspection report',
      ),
    );
  }

  void _showSuccess(String message, File file) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Share',
          onPressed: () => _shareFile(file),
        ),
      ),
    );
  }

  void _showFailure(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inspectionProvider = context.watch<InspectionProvider>();
    final allInspections = List<InspectionReportModel>.from(
      inspectionProvider.inspections,
    )..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final count = allInspections.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Export Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total inspections: $count'),
                    const SizedBox(height: 8),
                    const Text('Save location'),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: _downloadsPreset,
                          label: Text('Downloads'),
                          icon: Icon(Icons.download),
                        ),
                        ButtonSegment(
                          value: _documentsPreset,
                          label: Text('Documents'),
                          icon: Icon(Icons.description),
                        ),
                      ],
                      selected: {_exportPreset},
                      onSelectionChanged: _isExporting
                          ? null
                          : (value) => _setExportPreset(value.first),
                    ),
                    const SizedBox(height: 8),
                    Text('Files will be saved in: ${_friendlyFolderLabel()}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isExporting || count == 0 ? null : _exportToPDF,
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(
                    _isExporting ? 'Exporting...' : 'Export PDF (with images)'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isExporting || count == 0 ? null : _exportToExcel,
                icon: const Icon(Icons.table_chart),
                label: Text(_isExporting
                    ? 'Exporting...'
                    : 'Export Excel (with images)'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isExporting || count == 0 ? null : _exportToDocx,
                icon: const Icon(Icons.description),
                label: Text(
                    _isExporting ? 'Exporting...' : 'Export Word (DOCX)'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Excel now embeds image thumbnails directly in each row.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PreparedInspection {
  final InspectionReportModel inspection;
  final List<Uint8List> allImageBytes;

  _PreparedInspection(this.inspection, this.allImageBytes);
}

class _PreparedPhotoEntry {
  final _PreparedInspection prepared;
  final String itemLabel;
  final String inspectorLabel;
  final Uint8List? imageBytes;
  final int photoIndex;
  final int totalPhotos;

  _PreparedPhotoEntry({
    required this.prepared,
    required this.itemLabel,
    this.inspectorLabel = '',
    this.imageBytes,
    this.photoIndex = 0,
    this.totalPhotos = 0,
  });
}

class _DocxMediaAsset {
  final String path;
  final Uint8List bytes;
  final String contentType;
  final String relationshipId;

  _DocxMediaAsset({
    required this.path,
    required this.bytes,
    required this.contentType,
    required this.relationshipId,
  });
}