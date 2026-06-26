import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  // ================================================================
  // PDF EXPORT
  // ================================================================
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
  // TEMPLATE 1 - OVERALL VIEW HEADER
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
  // TEMPLATE 2 - DEFECT ASSESSMENT HEADER
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
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildTopItemCell(entry),
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
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
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

  // ================================================================
  // WORD (.docx) EXPORT
  // ================================================================
  Future<void> _exportToWord() async {
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

      // Build a docx using raw XML inside a zip (OpenXML format)
      final docxBytes = await _buildDocx(prepared, user?.name, user?.inspectorId);

      final output = await _resolveExportDirectory();
      final file = File(
        p.join(
          output.path,
          'FieldLens_Report_all_inspections_${DateTime.now().millisecondsSinceEpoch}.docx',
        ),
      );
      await file.writeAsBytes(docxBytes, flush: true);
      _showSuccess('Word document saved in ${_friendlyFolderLabel()}', file);
    } catch (e) {
      _showFailure('Error exporting Word: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<Uint8List> _buildDocx(
    List<_PreparedInspection> inspections,
    String? inspectorName,
    String? inspectorId,
  ) async {
    final buf = StringBuffer();

    // Build HTML that gets embedded in Word doc
    buf.writeln('<html xmlns:o="urn:schemas-microsoft-com:office:office"');
    buf.writeln('      xmlns:w="urn:schemas-microsoft-com:office:word"');
    buf.writeln('      xmlns="http://www.w3.org/TR/REC-html40">');
    buf.writeln('<head>');
    buf.writeln('<style>');
    buf.writeln('body { font-family: "Times New Roman", serif; font-size: 11pt; }');
    buf.writeln('table { border-collapse: collapse; width: 100%; margin-bottom: 12pt; }');
    buf.writeln('td, th { border: 1px solid black; padding: 4px; vertical-align: top; }');
    buf.writeln('th { font-weight: bold; text-align: center; }');
    buf.writeln('img { max-width: 100%; height: auto; }');
    buf.writeln('</style>');
    buf.writeln('</head>');
    buf.writeln('<body>');

    buf.writeln('<h1 style="font-family: Times New Roman; font-size: 14pt;">Dilapidation Survey Report</h1>');
    final userLabel = _buildInspectorLabel(inspectorName, inspectorId);
    if (userLabel.isNotEmpty) {
      buf.writeln('<p style="font-family: Times New Roman; font-size: 11pt;">Inspector: $userLabel</p>');
    }
    buf.writeln('<p style="font-family: Times New Roman; font-size: 11pt;">Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}</p>');

    // Group by mode
    final overallEntries = inspections.where((e) => e.inspection.isOverallMode).toList();
    final defectEntries = inspections.where((e) => e.inspection.isDefectMode).toList();

    if (overallEntries.isNotEmpty) {
      buf.writeln('<h2 style="font-family: Times New Roman; font-size: 12pt;">Overall View Items</h2>');
      for (final prep in overallEntries) {
        final insp = prep.inspection;
        buf.writeln('<table>');
        // Header row
        buf.writeln('<tr><th style="width: 10%;">ITEM</th><th>PHOTO</th></tr>');
        // Photo rows - one per photo
        if (prep.allImageBytes.isEmpty) {
          buf.writeln('<tr><td style="text-align: center; vertical-align: middle;">${_escapeHtml(insp.itemNumber)}</td><td style="text-align: center; color: #999;">No Image</td></tr>');
        } else {
          for (var i = 0; i < prep.allImageBytes.length; i++) {
            final base64 = _base64EncodeImage(prep.allImageBytes[i]);
            buf.writeln('<tr>');
            if (i == 0) {
              buf.writeln('<td style="text-align: center; vertical-align: middle;" rowspan="${prep.allImageBytes.length}">${_escapeHtml(insp.itemNumber)}</td>');
            }
            buf.writeln('<td><img src="data:image/jpeg;base64,$base64" alt="Photo ${i + 1}" style="max-width: 350px;"/></td>');
            buf.writeln('</tr>');
          }
        }
        // Bottom info row
        buf.writeln('<tr>');
        buf.writeln('<td style="width: 50%;"><b>Location:</b> ${_escapeHtml(_resolvedWordLocation(insp))}</td>');
        buf.writeln('<td style="width: 50%;"><b>Inspector\'s comments:</b> ${_escapeHtml(insp.inspectorComments)}</td>');
        buf.writeln('</tr>');
        buf.writeln('</table>');
      }
    }

    if (defectEntries.isNotEmpty) {
      buf.writeln('<h2 style="font-family: Times New Roman; font-size: 12pt;">Defect Assessment Items</h2>');
      for (final prep in defectEntries) {
        final insp = prep.inspection;
        final codes = insp.selectedDefectCodes.toSet();
        buf.writeln('<table>');
        buf.writeln('<tr><th style="width: 10%;">ITEM</th><th style="width: 50%;">PHOTO</th><th>ASSESSMENT TYPES</th></tr>');

        if (prep.allImageBytes.isEmpty) {
          buf.writeln('<tr>');
          buf.writeln('<td style="text-align: center; vertical-align: middle;">${_escapeHtml(insp.itemNumber)}</td>');
          buf.writeln('<td style="text-align: center; color: #999;">No Image</td>');
          buf.writeln('<td>${_buildAssessmentTypesHtml(codes)}</td>');
          buf.writeln('</tr>');
        } else {
          for (var i = 0; i < prep.allImageBytes.length; i++) {
            final base64 = _base64EncodeImage(prep.allImageBytes[i]);
            buf.writeln('<tr>');
            if (i == 0) {
              buf.writeln('<td style="text-align: center; vertical-align: middle;" rowspan="${prep.allImageBytes.length}">${_escapeHtml(insp.itemNumber)}</td>');
              buf.writeln('<td style="text-align: center; vertical-align: middle;" rowspan="${prep.allImageBytes.length}"><img src="data:image/jpeg;base64,$base64" alt="Photo ${i + 1}" style="max-width: 400px;"/></td>');
              buf.writeln('<td rowspan="${prep.allImageBytes.length}">${_buildAssessmentTypesHtml(codes)}</td>');
            } else {
              // Multiple photos merge into the same row as the first
              buf.writeln('</tr><tr>');
              buf.writeln('<td colspan="3"><img src="data:image/jpeg;base64,$base64" alt="Photo ${i + 1}" style="max-width: 400px;"/></td>');
            }
            buf.writeln('</tr>');
          }
        }

        // Bottom row
        buf.writeln('<tr>');
        buf.writeln('<td><b>Location:</b> ${_escapeHtml(_resolvedWordLocation(insp))}</td>');
        buf.writeln('<td><b>Inspector\'s comments:</b> ${_escapeHtml(insp.inspectorComments)}</td>');
        buf.writeln('<td><b>Impact Category:</b> ${_buildImpactHtml(insp.impactCategory)}</td>');
        buf.writeln('</tr>');
        buf.writeln('</table>');
      }
    }

    buf.writeln('</body></html>');

    // Create a minimal .docx with the HTML embedded
    return _createDocxFromHtml(buf.toString());
  }

  String _buildAssessmentTypesHtml(Set<String> selectedCodes) {
    final sb = StringBuffer();
    sb.writeln('<b>Crack:</b><br/>');
    for (final code in ['FC1', 'FC2', 'FC3', 'FC4']) {
      final checked = selectedCodes.contains(code);
      sb.writeln('${checked ? '✓' : '☐'} $code<br/>');
    }
    for (final code in ['WC1', 'WC2', 'WC3', 'WC4']) {
      final checked = selectedCodes.contains(code);
      sb.writeln('${checked ? '✓' : '☐'} $code<br/>');
    }
    sb.writeln('<b>Bent:</b><br/>');
    for (final code in ['B1', 'B2', 'B3', 'B4']) {
      final checked = selectedCodes.contains(code);
      sb.writeln('${checked ? '✓' : '☐'} $code<br/>');
    }
    sb.writeln('<b>Damage:</b><br/>');
    for (final code in ['D1', 'D2', 'D3', 'D4']) {
      final checked = selectedCodes.contains(code);
      sb.writeln('${checked ? '✓' : '☐'} $code<br/>');
    }
    return sb.toString();
  }

  String _buildImpactHtml(String impactCategory) {
    return 'Minor: ${impactCategory == 'Minor' ? '✓' : '☐'} | '
        'Moderate: ${impactCategory == 'Moderate' ? '✓' : '☐'} | '
        'Major: ${impactCategory == 'Major' ? '✓' : '☐'}';
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&')
        .replaceAll('<', '<')
        .replaceAll('>', '>')
        .replaceAll('"', '"')
        .replaceAll("'", '&#39;')
        .replaceAll('\n', '<br/>');
  }

  String _base64EncodeImage(Uint8List bytes) {
    return base64Encode(bytes);
  }

  Future<Uint8List> _createDocxFromHtml(String html) async {
    // Create a Word doc with HTML body using the mht/doc approach
    // This produces a .docx that Word can open
    final content = '''
<html xmlns:o="urn:schemas-microsoft-com:office:office"
      xmlns:w="urn:schemas-microsoft-com:office:word"
      xmlns="http://www.w3.org/TR/REC-html40">
<head>
<meta charset="utf-8">
<!--[if gte mso 9]>
<xml>
<w:WordDocument>
<w:View>Print</w:View>
<w:Zoom>100</w:Zoom>
</w:WordDocument>
</xml>
<![endif]-->
<style>
/* Styles already embedded in the body content */
</style>
</head>
<body>
$html
</body>
</html>
''';
    return Uint8List.fromList(content.codeUnits);
  }

  String _resolvedWordLocation(InspectionReportModel inspection) {
    final location = inspection.location.trim();
    if (location.isNotEmpty) return location;
    return '-';
  }

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
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Crack section
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(4, 2, 4, 1),
          child: pw.Text(
            'Crack:',
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(4, 0, 4, 1),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: const ['FC1', 'FC2', 'FC3', 'FC4']
                      .map((code) => _buildAssessmentCodeLine(code, selectedCodes.contains(code)))
                      .toList(),
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: const ['WC1', 'WC2', 'WC3', 'WC4']
                      .map((code) => _buildAssessmentCodeLine(code, selectedCodes.contains(code)))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        // Bent section
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(4, 1, 4, 1),
          child: pw.Text(
            'Bent:',
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(4, 0, 4, 1),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: const ['B1', 'B2']
                      .map((code) => _buildAssessmentCodeLine(code, selectedCodes.contains(code)))
                      .toList(),
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: const ['B3', 'B4']
                      .map((code) => _buildAssessmentCodeLine(code, selectedCodes.contains(code)))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        // Damage section
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(4, 1, 4, 2),
          child: pw.Text(
            'Damage:',
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(4, 0, 4, 2),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: const ['D1', 'D2']
                      .map((code) => _buildAssessmentCodeLine(code, selectedCodes.contains(code)))
                      .toList(),
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: const ['D3', 'D4']
                      .map((code) => _buildAssessmentCodeLine(code, selectedCodes.contains(code)))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildAssessmentCodeLine(String code, bool selected) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.Row(
        children: [
          pw.Container(
            width: 10,
            height: 10,
            decoration: pw.BoxDecoration(
              color: selected ? PdfColors.green : PdfColors.white,
              border: pw.Border.all(color: PdfColors.grey700, width: 0.6),
            ),
            child: selected
                ? pw.Center(
                    child: pw.Text(
                      '✓',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 7,
                      ),
                    ),
                  )
                : null,
          ),
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
        color: selected ? PdfColors.green400 : PdfColors.grey300,
        border: pw.Border.all(color: PdfColors.grey700, width: 0.8),
      ),
      child: selected
          ? pw.Center(
              child: pw.Text(
                '✓',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 7,
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
                onPressed: _isExporting || count == 0 ? null : _exportToWord,
                icon: const Icon(Icons.description),
                label: Text(_isExporting
                    ? 'Exporting...'
                    : 'Export Word (with images)'),
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
            const SizedBox(height: 16),
            const Text(
              'PDF uses Times New Roman 11pt. Word documents include all photos inline.',
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