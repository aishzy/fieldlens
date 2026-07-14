import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'lib/core/models/inspection_report_model.dart';

// =============================================================================
// Standalone PDF Testing Module (generate_pdf_v9)
// =============================================================================
// Purpose:
//   Generates a sample PDF document using the exact same PDF layout logic
//   from ExportScreenV3 (export_screenV3.dart) to verify that generated PDFs
//   follow the template requirements.
//
// TWO USAGE MODES:
//
//   MODE 1 — Terminal / CLI (run directly from command line):
//     dart run generate_pdf_v9.dart
//     Output: ./pdf_output/FieldLens_TestPDF_<timestamp>.pdf
//
//   MODE 2 — Inside Flutter app (import and call methods):
//     import 'generate_pdf_v9.dart';
//     final file = await PdfTestGenerator.generateTestPdf();
//     final file2 = await PdfTestGenerator.generateFromInspectionData(
//       inspections, inspectorName: name, inspectorId: id);
//
// This module:
//   - Uses the actual InspectionReportModel from the app's data layer
//   - Creates mock inspection data for both Overall View & Defect Assessment
//   - Uses the same layout constants, grid dimensions, and widget builders
//   - Does NOT modify any existing PDF format or template code
//   - In terminal mode: saves to ./pdf_output/ directory
//   - In Flutter mode: saves to app's Documents/FieldLens Reports directory
// =============================================================================

// ═════════════════════════════════════════════════════════════════════════════
// CLI ENTRY POINT — run with:  dart run generate_pdf_v9.dart
// ═════════════════════════════════════════════════════════════════════════════
void main() async {
  print('=== FieldLens PDF Test Generator (v9) ===');
  print('');
  print('Generating sample PDF with mock inspection data...');
  print('');

  try {
    final pdfBytes = await PdfTestGenerator._generatePdfBytes();
    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final outputDir = Directory('pdf_output');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final file = File('${outputDir.path}/FieldLens_TestPDF_$timestamp.pdf');
    await file.writeAsBytes(pdfBytes);

    print('✅ PDF generated successfully!');
    print('   File: ${file.path}');
    print('   Absolute: ${file.absolute.path}');
    print('');
    print('You can now open this PDF to verify the template format.');
    print('Checklist:');
    print('  [ ] Overall View template (ITEM + PHOTO columns)');
    print('  [ ] Defect Assessment template (ITEM + PHOTO + ASSESSMENT TYPES)');
    print('  [ ] Assessment checkboxes (FC1-FC4, WC1-WC4, B1-B4, D1-D4)');
    print('  [ ] Impact Category checkboxes (Minor / Moderate / Major)');
    print('  [ ] Location and Inspector\'s comments fields');
    print('  [ ] Item labels end with "."');
    print('  [ ] Inspector name/ID label');
  } catch (e, st) {
    print('❌ ERROR: $e');
    print(st);
    exitCode = 1;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PDF TEST GENERATOR — usable from both CLI and Flutter app
// ═════════════════════════════════════════════════════════════════════════════

class PdfTestGenerator {
  PdfTestGenerator._();

  // ── Layout Constants (exact copy from export_screenV3.dart) ─────────────
  static const double _pdfPhotoWidthCm = 9.8;
  static const double _pdfPhotoHeightCm = 8.8;
  static const double _pdfMarginLeftCm = 1.80;
  static const double _pdfMarginRightCm = 1.73;
  static const double _pdfMarginTopCm = 2.12;
  static const double _pdfMarginBottomCm = 2.47;
  static const double _pdfGridBorderWidth = 0.8;

  static double get _pdfPhotoWidth => _pdfPhotoWidthCm * PdfPageFormat.cm;
  static double get _pdfPhotoHeight => _pdfPhotoHeightCm * PdfPageFormat.cm;
  static double get _pdfItemColumnWidth => 1.6 * PdfPageFormat.cm;
  static double get _pdfPhotoColumnWidth => _pdfPhotoWidth + 6;
  static double get _pdfTopRowHeight => _pdfPhotoHeight + 6;
  static double get _pdfBottomRowHeight => 56;

  // ── Public API (Flutter app usage) ───────────────────────────────────────

  /// Generates a test PDF with sample mock data and saves it.
  /// Uses [outputDir] or defaults to current working directory.
  /// Returns the generated [File].
  static Future<File> generateTestPdf({Directory? outputDir}) async {
    final bytes = await _generatePdfBytes();
    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final dir = outputDir ?? Directory('pdf_output');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final file = File('${dir.path}/FieldLens_TestPDF_$timestamp.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Generates a PDF from real inspection data instead of mock data.
  /// Accepts a list of [InspectionReportModel] and optional inspector info.
  /// Uses [outputDir] or defaults to current working directory.
  static Future<File> generateFromInspectionData(
    List<InspectionReportModel> inspections, {
    String? inspectorName,
    String? inspectorId,
    Directory? outputDir,
  }) async {
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

    final photoEntries =
        _expandPhotoEntriesWithLabel(prepared, inspectorName, inspectorId);
    final pdf = pw.Document();

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

    final bytes = await pdf.save();
    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final dir = outputDir ?? Directory('pdf_output');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final file = File('${dir.path}/FieldLens_Report_$timestamp.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  // ── Internal: generate PDF bytes from mock data ─────────────────────────

  static Future<Uint8List> _generatePdfBytes() async {
    final mockInspections = _buildMockInspections();
    final photoEntries = _expandPhotoEntries(mockInspections);
    final pdf = pw.Document();

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

    return await pdf.save();
  }

  // ── Mock Data ────────────────────────────────────────────────────────────

  static List<_PreparedInspection> _buildMockInspections() {
    final now = DateTime.now();
    return [
      // ── Overall View (no image) ──
      _PreparedInspection(
        InspectionReportModel(
          id: 'mock-overall-1',
          userId: 'test-user',
          itemNumber: 'OV-001',
          photoPaths: [],
          defectType: 'General',
          defectCode: 'ND0',
          location: 'Level 5, Corridor A - East Wing',
          inspectorComments:
              'General visual inspection completed. No visible cracks or structural concerns.',
          impactCategory: 'Minor',
          status: 'No Defect',
          refNo: 'REF-A-2026-001',
          section: 'Block A',
          scopeInternal: true,
          scopeExternal: false,
          scopeME: false,
          scopePublicFacilities: false,
          selectedDefectCodes: [],
          timestamp: now.subtract(const Duration(hours: 2)),
          inspectionMode: 'overall',
        ),
        [],
      ),
      // ── Overall View (no image) ──
      _PreparedInspection(
        InspectionReportModel(
          id: 'mock-overall-2',
          userId: 'test-user',
          itemNumber: 'OV-002',
          photoPaths: [],
          defectType: 'General',
          defectCode: 'ND0',
          location: 'Level 5, Corridor B - West Wing',
          inspectorComments:
              'Ceiling finish in good condition. Minor staining near HVAC vent.\nRecommend annual inspection.',
          impactCategory: 'Minor',
          status: 'No Defect',
          refNo: 'REF-A-2026-002',
          section: 'Block A',
          scopeInternal: true,
          scopeExternal: false,
          scopeME: true,
          scopePublicFacilities: false,
          selectedDefectCodes: [],
          timestamp: now.subtract(const Duration(hours: 1)),
          inspectionMode: 'overall',
        ),
        [],
      ),
      // ── Defect Assessment (no image) ──
      _PreparedInspection(
        InspectionReportModel(
          id: 'mock-defect-1',
          userId: 'test-user',
          itemNumber: 'DA-001',
          photoPaths: [],
          defectType: 'Cracking',
          defectCode: 'FC2',
          location: 'Beam B3/4 - Junction with Column C3',
          inspectorComments:
              'Hairline crack approx 0.3mm width, 450mm length.\nLocated on beam soffit. Monitor quarterly.',
          impactCategory: 'Moderate',
          status: 'Defect Found',
          refNo: 'REF-B-2026-015',
          section: 'Block B',
          scopeInternal: false,
          scopeExternal: true,
          scopeME: false,
          scopePublicFacilities: false,
          selectedDefectCodes: ['FC2', 'FC3', 'WC1', 'B1'],
          timestamp: now.subtract(const Duration(minutes: 45)),
          inspectionMode: 'defect',
        ),
        [],
      ),
      // ── Defect Assessment (no image) ──
      _PreparedInspection(
        InspectionReportModel(
          id: 'mock-defect-2',
          userId: 'test-user',
          itemNumber: 'DA-002',
          photoPaths: [],
          defectType: 'Damage',
          defectCode: 'D4',
          location: 'External wall Panel 7, Ground Floor - South Facade',
          inspectorComments:
              'Spalling concrete with exposed reinforcement. Approx 200x300mm area.\nUrgent repair required. Area cordoned off.',
          impactCategory: 'Major',
          status: 'Defect Found',
          refNo: 'REF-C-2026-042',
          section: 'Block C',
          scopeInternal: false,
          scopeExternal: true,
          scopeME: false,
          scopePublicFacilities: false,
          selectedDefectCodes: ['D3', 'D4', 'B3', 'FC4'],
          timestamp: now.subtract(const Duration(minutes: 30)),
          inspectionMode: 'defect',
        ),
        [],
      ),
    ];
  }

  // ── Photo Entry Expansion (mirrors export_screenV3) ──────────────────────

  static List<_PreparedPhotoEntry> _expandPhotoEntries(
    List<_PreparedInspection> inspections,
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
            inspectorLabel: 'Test Inspector (TEST-001)',
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
            inspectorLabel: 'Test Inspector (TEST-001)',
            imageBytes: prepared.allImageBytes[photoIndex],
            photoIndex: photoIndex,
            totalPhotos: prepared.allImageBytes.length,
          ),
        );
      }
    }
    return entries;
  }

  static List<_PreparedPhotoEntry> _expandPhotoEntriesWithLabel(
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
      final inspectorLabel =
          _buildInspectorLabel(inspectorName, inspectorId);

      if (prepared.allImageBytes.isEmpty) {
        entries.add(
          _PreparedPhotoEntry(
            prepared: prepared,
            itemLabel: itemLabel,
            inspectorLabel: inspectorLabel,
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
            inspectorLabel: inspectorLabel,
            imageBytes: prepared.allImageBytes[photoIndex],
            photoIndex: photoIndex,
            totalPhotos: prepared.allImageBytes.length,
          ),
        );
      }
    }
    return entries;
  }

  static String _buildInspectorLabel(
      String? inspectorName, String? inspectorId) {
    final name = (inspectorName ?? '').trim();
    final id = (inspectorId ?? '').trim();
    if (name.isEmpty && id.isEmpty) return '';
    if (name.isEmpty) return id;
    if (id.isEmpty) return name;
    return '$name ($id)';
  }

  // ── Page Builder (mirrors export_screenV3) ───────────────────────────────

  static pw.Widget _buildPdfPage(List<_PreparedPhotoEntry> pageEntries) {
    final firstEntry = pageEntries.first;
    final isOverallPage = firstEntry.prepared.inspection.isOverallMode;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildPdfPageHeader(firstEntry.prepared.inspection),
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

  // ── Page Header (mirrors export_screenV3) ────────────────────────────────

  static pw.Widget _buildPdfPageHeader(InspectionReportModel inspection) {
    final locationText = inspection.location.trim().isNotEmpty ? inspection.location.trim() : '-';
    final sectionText = inspection.section.trim().isNotEmpty ? inspection.section.trim() : '-';

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Location: ',
                      style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        locationText,
                        style: const pw.TextStyle(fontSize: 7.8),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Section: ',
                      style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        sectionText,
                        style: const pw.TextStyle(fontSize: 7.8),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            flex: 4,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildHeaderScopeLine('Internal', inspection.scopeInternal)),
                      pw.Expanded(child: _buildHeaderScopeLine('M&E', inspection.scopeME)),
                    ],
                  ),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildHeaderScopeLine('External', inspection.scopeExternal)),
                      pw.Expanded(child: _buildHeaderScopeLine('Public facilities', inspection.scopePublicFacilities)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildHeaderScopeLine(String label, bool selected) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          _buildCheckBox(selected),
          pw.SizedBox(width: 4),
          pw.Text(label, style: const pw.TextStyle(fontSize: 7.8)),
        ],
      ),
    );
  }

  // ── Grid Headers (mirrors export_screenV3) ───────────────────────────────

  static pw.Widget _buildOverallGridHeaderRow() {
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

  static pw.Widget _buildDefectGridHeaderRow() {
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

  static pw.Widget _headerCell(String text,
      {double? width, bool expand = false}) {
    final child = pw.Container(
      alignment: pw.Alignment.center,
      height: 14,
      decoration: pw.BoxDecoration(
        border: pw.Border(
          right: pw.BorderSide(
              color: PdfColors.black, width: _pdfGridBorderWidth),
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

  // ── Overall View Item Block (mirrors export_screenV3) ─────────────────────

  static pw.Widget _buildOverallItemBlock(_PreparedPhotoEntry entry) {
    final inspection = entry.prepared.inspection;

    pw.Widget photoWidget;
    if (entry.imageBytes != null) {
      photoWidget = pw.Image(
        pw.MemoryImage(entry.imageBytes!),
        fit: pw.BoxFit.cover,
      );
    } else {
      photoWidget = pw.Container(
        alignment: pw.Alignment.center,
        color: PdfColors.white,
        child: pw.Text('No Image',
            style: const pw.TextStyle(color: PdfColors.grey600)),
      );
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(
              color: PdfColors.black, width: _pdfGridBorderWidth),
          right: pw.BorderSide(
              color: PdfColors.black, width: _pdfGridBorderWidth),
          bottom: pw.BorderSide(
              color: PdfColors.black, width: _pdfGridBorderWidth),
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
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      right: pw.BorderSide(
                          color: PdfColors.black, width: _pdfGridBorderWidth),
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
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(
                          color: PdfColors.black, width: _pdfGridBorderWidth),
                      right: pw.BorderSide(
                          color: PdfColors.black, width: _pdfGridBorderWidth),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Location:',
                        style: pw.TextStyle(
                            fontSize: 8.5, fontWeight: pw.FontWeight.bold),
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

  static pw.Widget _buildOverallCommentsCell(
    _PreparedPhotoEntry entry,
    InspectionReportModel inspection,
  ) {
    final lines = _formatComments(inspection.inspectorComments);
    return pw.Container(
      height: _pdfBottomRowHeight,
      padding: const pw.EdgeInsets.fromLTRB(6, 2, 6, 2),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
              color: PdfColors.black, width: _pdfGridBorderWidth),
          right: pw.BorderSide(
              color: PdfColors.black, width: _pdfGridBorderWidth),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Inspector's comments:",
            style:
                pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
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

  // ── Defect Assessment Item Block (mirrors export_screenV3) ────────────────

  static pw.Widget _buildDefectItemBlock(_PreparedPhotoEntry entry) {
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
        border: pw.Border(
          left: pw.BorderSide(
              color: PdfColors.black, width: _pdfGridBorderWidth),
          right: pw.BorderSide(
              color: PdfColors.black, width: _pdfGridBorderWidth),
          bottom: pw.BorderSide(
              color: PdfColors.black, width: _pdfGridBorderWidth),
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

  // ── Cell Builders (mirrors export_screenV3) ──────────────────────────────

  static pw.Widget _buildTopItemCell(_PreparedPhotoEntry entry) {
    return pw.Container(
      width: _pdfItemColumnWidth,
      height: _pdfTopRowHeight,
      padding: const pw.EdgeInsets.only(left: 4, top: 4, right: 2),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          right: pw.BorderSide(
              color: PdfColors.black, width: _pdfGridBorderWidth),
        ),
      ),
      alignment: pw.Alignment.topLeft,
      child: pw.Text(
        _formatItemLabel(entry.itemLabel),
        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _buildTopPhotoCell(pw.Widget photoWidget) {
    return pw.Container(
      width: _pdfPhotoColumnWidth,
      height: _pdfTopRowHeight,
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          right: pw.BorderSide(
              color: PdfColors.black, width: _pdfGridBorderWidth),
        ),
      ),
      child: photoWidget,
    );
  }

  static pw.Widget _buildTopAssessmentCell(pw.Widget assessmentWidget) {
    return pw.Container(
      height: _pdfTopRowHeight,
      child: assessmentWidget,
    );
  }

  static pw.Widget _buildBottomLocationCell(
      InspectionReportModel inspection) {
    return pw.Container(
      width: _pdfItemColumnWidth,
      height: _pdfBottomRowHeight,
      padding: const pw.EdgeInsets.fromLTRB(4, 2, 3, 2),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
              color: PdfColors.black, width: _pdfGridBorderWidth),
          right: pw.BorderSide(
              color: PdfColors.black, width: _pdfGridBorderWidth),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Location:',
            style:
                pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
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

  static String _resolvedPdfLocation(InspectionReportModel inspection) {
    final location = inspection.location.trim();
    if (location.isNotEmpty) {
      return location;
    }
    return '-';
  }

  static pw.Widget _buildBottomCommentsCell(
    _PreparedPhotoEntry entry,
    InspectionReportModel inspection,
  ) {
    final lines = _formatComments(inspection.inspectorComments);
    return pw.Container(
      width: _pdfPhotoColumnWidth,
      height: _pdfBottomRowHeight,
      padding: const pw.EdgeInsets.fromLTRB(6, 2, 6, 2),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
              color: PdfColors.black, width: _pdfGridBorderWidth),
          right: pw.BorderSide(
              color: PdfColors.black, width: _pdfGridBorderWidth),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Inspector's comments:",
            style:
                pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
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

  static pw.Widget _buildBottomImpactCell(InspectionReportModel inspection) {
    return pw.Container(
      height: _pdfBottomRowHeight,
      padding: const pw.EdgeInsets.fromLTRB(4, 2, 4, 2),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
              color: PdfColors.black, width: _pdfGridBorderWidth),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Impact Category:',
            style:
                pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          _buildImpactLine('Minor:', inspection.impactCategory == 'Minor'),
          _buildImpactLine(
              'Moderate:', inspection.impactCategory == 'Moderate'),
          _buildImpactLine('Major:', inspection.impactCategory == 'Major'),
        ],
      ),
    );
  }

  static pw.Widget _buildAssessmentCell(Set<String> selectedCodes) {
    return pw.Column(
      children: [
        pw.Expanded(
          flex: 5,
          child: _buildAssessmentSection(
            title: 'Crack:',
            leftCodes: const ['FC1', 'FC2', 'FC3', 'FC4'],
            rightCodes: const ['WC1', 'WC2', 'WC3', 'WC4'],
            selectedCodes: selectedCodes,
            showBottomBorder: true,
          ),
        ),
        pw.Expanded(
          flex: 3,
          child: _buildAssessmentSection(
            title: 'Bent:',
            leftCodes: const ['B1', 'B2'],
            rightCodes: const ['B3', 'B4'],
            selectedCodes: selectedCodes,
            showBottomBorder: true,
          ),
        ),
        pw.Expanded(
          flex: 3,
          child: _buildAssessmentSection(
            title: 'Damage:',
            leftCodes: const ['D1', 'D2'],
            rightCodes: const ['D3', 'D4'],
            selectedCodes: selectedCodes,
            showBottomBorder: false,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildAssessmentSection({
    required String title,
    required List<String> leftCodes,
    required List<String> rightCodes,
    required Set<String> selectedCodes,
    required bool showBottomBorder,
  }) {
    final border = showBottomBorder
        ? pw.Border(
            bottom: pw.BorderSide(
                color: PdfColors.black, width: _pdfGridBorderWidth),
          )
        : null;

    return pw.Container(
      decoration: border == null ? null : pw.BoxDecoration(border: border),
      padding: const pw.EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style:
                pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
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
                          .map((code) => _buildAssessmentCodeLine(
                              code, selectedCodes.contains(code)))
                          .toList(),
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 4),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: rightCodes
                          .map((code) => _buildAssessmentCodeLine(
                              code, selectedCodes.contains(code)))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildAssessmentCodeLine(String code, bool selected) {
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

  static pw.Widget _buildImpactLine(String label, bool selected) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style:
                  pw.TextStyle(fontSize: 8.3, fontWeight: pw.FontWeight.bold),
            ),
          ),
          _buildCheckBox(selected),
        ],
      ),
    );
  }

  static pw.Widget _buildCheckBox(bool selected) {
    return pw.Container(
      width: 10,
      height: 10,
      decoration: pw.BoxDecoration(
        color: selected ? PdfColors.green400 : PdfColors.grey300,
        border: pw.Border.all(color: PdfColors.grey700, width: 0.8),
      ),
      child: selected
          ? pw.Center(
              child: pw.SizedBox(
                width: 8,
                height: 8,
                child: pw.CustomPaint(
                  painter: (PdfGraphics canvas, PdfPoint size) {
                    final w = size.x;
                    final h = size.y;
                    canvas
                      ..setColor(PdfColors.white)
                      ..setLineWidth(1.3)
                      ..setLineCap(PdfLineCap.round)
                      ..setLineJoin(PdfLineJoin.round)
                      ..moveTo(w * 0.18, h * 0.52)
                      ..lineTo(w * 0.40, h * 0.20)
                      ..lineTo(w * 0.85, h * 0.75)
                      ..strokePath();
                  },
                ),
              ),
            )
          : null,
    );
  }

  // ── Formatting Helpers (mirrors export_screenV3) ─────────────────────────

  static String _formatItemLabel(String itemLabel) {
    final trimmed = itemLabel.trim();
    if (trimmed.isEmpty) return '-';
    return trimmed.endsWith('.') ? trimmed : '$trimmed.';
  }

  static List<String> _formatComments(String comments) {
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
}

// ── Private Data Classes (mirrors export_screenV3) ─────────────────────────

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