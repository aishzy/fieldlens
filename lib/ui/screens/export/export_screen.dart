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

  bool _isExporting = false;
  String _exportPreset = _downloadsPreset;

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
      final inspections = inspectionProvider.inspections;
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

      // Group by project name for section headers
      final projectGroups = <String, List<_PreparedInspection>>{};
      for (final p in prepared) {
        final key = p.inspection.projectName.isNotEmpty
            ? p.inspection.projectName
            : 'Uncategorised';
        projectGroups.putIfAbsent(key, () => []).add(p);
      }

      final pdf = pw.Document();

      for (final entry in projectGroups.entries) {
        final projectName = entry.key;
        final group = entry.value;
        final sampleInspection = group.first.inspection;

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
            header: (_) => _buildPdfHeader(
                projectName, sampleInspection, user?.name, user?.inspectorId),
            footer: (ctx) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
            build: (_) => [
              ...group
                  .asMap()
                  .entries
                  .map((e) => _buildItemBlock(e.key + 1, e.value)),
            ],
          ),
        );
      }

      final output = await _resolveExportDirectory();
      final file = File(
        p.join(
          output.path,
          'FieldLens_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
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

  pw.Widget _buildPdfHeader(
    String projectName,
    InspectionReportModel sample,
    String? inspectorName,
    String? inspectorId,
  ) {
    final scopes = <String>[];
    if (sample.scopeInternal) scopes.add('Internal');
    if (sample.scopeExternal) scopes.add('External');
    if (sample.scopeME) scopes.add('M&E');
    if (sample.scopePublicFacilities) scopes.add('Public Facilities');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text(
            'DETAIL DILAPIDATION SURVEY REPORT',
            style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.5),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfRow('Project', projectName),
              _pdfRow('Site Location', sample.projectSiteLocation),
              _pdfRow('Project Code', sample.projectCode),
              _pdfRow('Inspector', '${inspectorName ?? 'N/A'} (ID: ${inspectorId ?? 'N/A'})'),
              _pdfRow('Scope', scopes.isEmpty ? 'N/A' : scopes.join(' | ')),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          color: PdfColors.blueGrey800,
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 36,
                child: pw.Text('ITEM',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9)),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                flex: 3,
                child: pw.Text('PHOTO',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9)),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                flex: 5,
                child: pw.Text('ASSESSMENT TYPES',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9)),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 4),
      ],
    );
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text('$label:',
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: const pw.TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildItemBlock(int itemNo, _PreparedInspection prepared) {
    final inspection = prepared.inspection;
    final codes = inspection.selectedDefectCodes;

    // All possible codes per category
    const wc = ['WC1', 'WC2', 'WC3', 'WC4'];
    const fc = ['FC1', 'FC2', 'FC3', 'FC4'];
    const b = ['B1', 'B2', 'B3', 'B4'];
    const d = ['D1', 'D2', 'D3', 'D4'];

    // Build assessment checkbox grid
    pw.Widget checkRow(String label, List<String> codelist) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          children: [
            pw.SizedBox(
              width: 28,
              child: pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ),
            ...codelist.map((code) {
              final ticked = codes.contains(code);
              return pw.Padding(
                padding: const pw.EdgeInsets.only(right: 6),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 8,
                      height: 8,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 0.8),
                        color: ticked ? PdfColors.blue800 : PdfColors.white,
                      ),
                      child: ticked
                          ? pw.Center(
                              child: pw.Text('✓',
                                  style: pw.TextStyle(
                                      color: PdfColors.white, fontSize: 6)),
                            )
                          : null,
                    ),
                    pw.SizedBox(width: 2),
                    pw.Text(code, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    }

    final assessmentWidget = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Crack (WC)',
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey600)),
        checkRow('', wc),
        pw.SizedBox(height: 2),
        pw.Text('Crack (FC)',
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey600)),
        checkRow('', fc),
        pw.SizedBox(height: 2),
        pw.Text('Bent',
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey600)),
        checkRow('', b),
        pw.SizedBox(height: 2),
        pw.Text('Damage',
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey600)),
        checkRow('', d),
      ],
    );

    // Impact checkboxes
    pw.Widget impactCheckbox(String label, bool ticked) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(right: 10),
        child: pw.Row(
          children: [
            pw.Container(
              width: 8,
              height: 8,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 0.8),
                color: ticked ? PdfColors.blue800 : PdfColors.white,
              ),
              child: ticked
                  ? pw.Center(
                      child: pw.Text('✓',
                          style: pw.TextStyle(
                              color: PdfColors.white, fontSize: 6)))
                  : null,
            ),
            pw.SizedBox(width: 3),
            pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      );
    }

    final impact = inspection.impactCategory;
    final impactRow = pw.Row(children: [
      pw.Text('Impact: ',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
      impactCheckbox('Minor', impact == 'Minor'),
      impactCheckbox('Moderate', impact == 'Moderate'),
      impactCheckbox('Major', impact == 'Major'),
    ]);

    // Build photo widget (first photo)
    pw.Widget photoWidget;
    if (prepared.allImageBytes.isNotEmpty) {
      photoWidget = pw.Image(
        pw.MemoryImage(prepared.allImageBytes.first),
        width: 130,
        height: 130,
        fit: pw.BoxFit.cover,
      );
    } else {
      photoWidget = pw.Container(
        width: 130,
        height: 130,
        alignment: pw.Alignment.center,
        color: PdfColors.grey200,
        child: pw.Text('No Image',
            style: const pw.TextStyle(color: PdfColors.grey600)),
      );
    }

    // Extra photos below
    final extraPhotos = prepared.allImageBytes.skip(1).toList();

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        children: [
          // Main row: Item | Photo | Assessment
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
                // Item number cell
                pw.Container(
                  width: 36,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                        right: pw.BorderSide(color: PdfColors.grey400)),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      '$itemNo',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
                // Photo cell
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                        right: pw.BorderSide(color: PdfColors.grey400)),
                  ),
                  child: pw.Column(
                    children: [
                      photoWidget,
                      if (extraPhotos.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Wrap(
                          children: extraPhotos
                              .take(3)
                              .map((bytes) => pw.Padding(
                                    padding: const pw.EdgeInsets.only(right: 4),
                                    child: pw.Image(
                                      pw.MemoryImage(bytes),
                                      width: 38,
                                      height: 38,
                                      fit: pw.BoxFit.cover,
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                // Assessment types cell
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: assessmentWidget,
                  ),
                ),
              ],
            ),
          // Bottom row: Location | Inspector's comments | Impact
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
              color: PdfColors.grey100,
            ),
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Location: ',
                        style: pw.TextStyle(
                            fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Expanded(
                        child: pw.Text(inspection.location,
                            style: const pw.TextStyle(fontSize: 8))),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text("Inspector's Comments:",
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(inspection.inspectorComments,
                    style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    impactRow,
                    pw.Spacer(),
                    pw.Text(
                      'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(inspection.timestamp)}',
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);
    try {
      final inspectionProvider = context.read<InspectionProvider>();
      final rows = inspectionProvider.inspections;
      if (rows.isEmpty) {
        throw Exception('No inspections available');
      }

      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];
      sheet.name = 'Dilapidation Survey Report';

      // ---- Build headers matching reference report columns ----
      final headers = [
        'Report Number', // A
        'Item No.', // B
        'REF. NO.', // C
        'Project Name', // D
        'Project Code', // E
        'Site Location', // F
        'Section', // G
        'Scope (Internal)', // H
        'Scope (External)', // I
        'Scope (M&E)', // J
        'Scope (Public Fac.)', // K
        // Crack (WC)
        'WC1', 'WC2', 'WC3', 'WC4', // L-O
        // Crack (FC)
        'FC1', 'FC2', 'FC3', 'FC4', // P-S
        // Bent
        'B1', 'B2', 'B3', 'B4', // T-W
        // Damage
        'D1', 'D2', 'D3', 'D4', // X-AA
        'Status', // AB
        'Impact Category', // AC
        'Location', // AD
        "Inspector's Comments", // AE
        'Date Time', // AF
        'GPS Lat', // AG
        'GPS Lng', // AH
        'Address', // AI
        'Photo', // AJ
      ];

      // Style the header row
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.getRangeByIndex(1, i + 1);
        cell.setText(headers[i]);
        cell.cellStyle.bold = true;
        cell.cellStyle.backColor = '#1565C0';
        cell.cellStyle.fontColor = '#FFFFFF';
        cell.cellStyle.wrapText = true;
      }

      sheet.getRangeByIndex(1, 1, 1, headers.length).rowHeight = 36;

      // Column widths
      for (var i = 1; i <= headers.length; i++) {
        sheet.getRangeByIndex(1, i).columnWidth = 12;
      }
      // Wider for text-heavy columns
      sheet.getRangeByIndex(1, 4).columnWidth = 24; // Project Name
      sheet.getRangeByIndex(1, 31).columnWidth = 36; // Inspector Comments
      sheet.getRangeByIndex(1, 30).columnWidth = 18; // Location
      sheet.getRangeByIndex(1, headers.length).columnWidth = 14; // Photo

      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        final inspection = rows[rowIndex];
        final excelRow = rowIndex + 2;
        final codes = inspection.selectedDefectCodes.toSet();

        sheet.getRangeByIndex(excelRow, 1).setText(inspection.reportNumber);
        sheet.getRangeByIndex(excelRow, 2).setText(inspection.itemNumber);
        sheet.getRangeByIndex(excelRow, 3).setText(inspection.refNo);
        sheet.getRangeByIndex(excelRow, 4).setText(inspection.projectName);
        sheet.getRangeByIndex(excelRow, 5).setText(inspection.projectCode);
        sheet
            .getRangeByIndex(excelRow, 6)
            .setText(inspection.projectSiteLocation);
        sheet.getRangeByIndex(excelRow, 7).setText(inspection.section);
        sheet
            .getRangeByIndex(excelRow, 8)
            .setText(inspection.scopeInternal ? '✓' : '');
        sheet
            .getRangeByIndex(excelRow, 9)
            .setText(inspection.scopeExternal ? '✓' : '');
        sheet
            .getRangeByIndex(excelRow, 10)
            .setText(inspection.scopeME ? '✓' : '');
        sheet
            .getRangeByIndex(excelRow, 11)
            .setText(inspection.scopePublicFacilities ? '✓' : '');

        // Defect codes: columns 12-27
        const allCodeOrder = [
          'WC1', 'WC2', 'WC3', 'WC4',
          'FC1', 'FC2', 'FC3', 'FC4',
          'B1', 'B2', 'B3', 'B4',
          'D1', 'D2', 'D3', 'D4',
        ];
        for (var c = 0; c < allCodeOrder.length; c++) {
          final code = allCodeOrder[c];
          sheet
              .getRangeByIndex(excelRow, 12 + c)
              .setText(codes.contains(code) ? '✓' : '');
          sheet
              .getRangeByIndex(excelRow, 12 + c)
              .cellStyle
              .hAlign = xlsio.HAlignType.center;
        }

        sheet.getRangeByIndex(excelRow, 28).setText(inspection.status);
        sheet.getRangeByIndex(excelRow, 29).setText(inspection.impactCategory);
        sheet.getRangeByIndex(excelRow, 30).setText(inspection.location);
        sheet
            .getRangeByIndex(excelRow, 31)
            .setText(inspection.inspectorComments);
        sheet.getRangeByIndex(excelRow, 32).setText(
            DateFormat('dd/MM/yyyy HH:mm').format(inspection.timestamp));
        sheet
            .getRangeByIndex(excelRow, 33)
            .setText(inspection.latitude?.toStringAsFixed(6) ?? '');
        sheet
            .getRangeByIndex(excelRow, 34)
            .setText(inspection.longitude?.toStringAsFixed(6) ?? '');
        sheet.getRangeByIndex(excelRow, 35).setText(inspection.address ?? '');

        // Photo embedding
        final imagePath = inspection.primaryPhotoPath;
        if (imagePath.isNotEmpty) {
          final imgFile = File(imagePath);
          if (await imgFile.exists()) {
            try {
              final bytes = await imgFile.readAsBytes();
              final picture =
                  sheet.pictures.addStream(excelRow, 36, bytes);
              picture.width = 80;
              picture.height = 80;
              sheet.getRangeByIndex(excelRow, 1).rowHeight = 65;
            } catch (_) {
              sheet.getRangeByIndex(excelRow, 36).setText('Image error');
            }
          } else {
            sheet.getRangeByIndex(excelRow, 36).setText('File missing');
          }
        } else {
          sheet.getRangeByIndex(excelRow, 36).setText('No image');
        }

        // Wrap text for comment cell
        sheet.getRangeByIndex(excelRow, 31).cellStyle.wrapText = true;
      }

      final output = await _resolveExportDirectory();
      final file = File(
        p.join(
          output.path,
          'FieldLens_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx',
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
    final count = inspectionProvider.inspectionCount;

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
