import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Standalone PDF test module for visual verification of dilapidation survey templates.
///
/// This file uses mock data only and is NOT connected to the database.
/// It exists to verify that the PDF layouts match the approved report templates
/// before integrating with the main export flow.
///
/// Margins: left=20mm, top=10mm, right=10mm, bottom=10mm (simulating binding gutter).
/// Debug borders are enabled on all main containers to inspect alignment and padding.
class PdfTestModuleScreen extends StatefulWidget {
  const PdfTestModuleScreen({super.key});

  @override
  State<PdfTestModuleScreen> createState() => _PdfTestModuleScreenState();
}

class _PdfTestModuleScreenState extends State<PdfTestModuleScreen> {
  pw.Document? _document;
  bool _showDebugBorders = true;

  // ───── Constants ─────
  static const double _marginLeft = 20; // mm (binding gutter)
  static const double _marginTop = 10; // mm
  static const double _marginRight = 10; // mm
  static const double _marginBottom = 10; // mm

  // Photo & column dimensions (scaled from template)
  static const double _photoWidthCm = 9.8;
  static const double _photoHeightCm = 8.8;
  static const double _itemColumnWidthCm = 1.45;
  static const double _gridBorderWidth = 0.8;

  double get _photoWidth => _photoWidthCm * PdfPageFormat.cm;
  double get _photoHeight => _photoHeightCm * PdfPageFormat.cm;
  double get _itemColumnWidth => _itemColumnWidthCm * PdfPageFormat.cm;
  double get _photoColumnWidth => _photoWidth + 6;
  double get _topRowHeight => _photoHeight + 6;
  double get _bottomRowHeight => 56.0;

  // ───── Builders ─────

  void _generateOverallView() {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.only(
          left: _marginLeft * PdfPageFormat.mm,
          top: _marginTop * PdfPageFormat.mm,
          right: _marginRight * PdfPageFormat.mm,
          bottom: _marginBottom * PdfPageFormat.mm,
        ),
        build: (_) => _buildOverallViewPage(),
      ),
    );

    setState(() => _document = pdf);
  }

  void _generateAssessmentType() {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.only(
          left: _marginLeft * PdfPageFormat.mm,
          top: _marginTop * PdfPageFormat.mm,
          right: _marginRight * PdfPageFormat.mm,
          bottom: _marginBottom * PdfPageFormat.mm,
        ),
        build: (_) => _buildAssessmentTypePage(),
      ),
    );

    setState(() => _document = pdf);
  }

  // ================================================================
  // TEMPLATE 1 — OVERALL VIEW
  // ================================================================
  pw.Widget _buildOverallViewPage() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── PROJECT INFO SECTION ──
        _debugBorder(
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(0, 0, 0, 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DILAPIDATION SURVEY REPORT',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Project: Pusapahanas (Mock Data)',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    _infoField('Location:', 'Ground Floor - Main Entrance'),
                    pw.SizedBox(width: 20),
                    _infoField('Section:', 'L / Ground'),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    _infoField('REF. NO.:', 'B-ME-01'),
                    pw.SizedBox(width: 20),
                    _infoField('Item No.:', '001'),
                  ],
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 8),

        // ── SCOPE OF INSPECTION CHECKBOXES ──
        _debugBorder(
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Scope of Inspection:',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  children: [
                    _scopeCheckbox('Internal', true),
                    pw.SizedBox(width: 12),
                    _scopeCheckbox('External', false),
                    pw.SizedBox(width: 12),
                    _scopeCheckbox('M&E', true),
                    pw.SizedBox(width: 12),
                    _scopeCheckbox('Public Fac.', false),
                  ],
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 8),

        // ── HEADER ROW ──
        _debugBorder(
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: PdfColors.black,
                width: _gridBorderWidth,
              ),
            ),
            child: pw.Row(
              children: [
                _headerCell('ITEM', width: _itemColumnWidth),
                _headerCell('PHOTO', expand: true),
              ],
            ),
          ),
        ),

        // ── ITEM ROW ──
        _debugBorder(
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(
                  color: PdfColors.black,
                  width: _gridBorderWidth,
                ),
                right: pw.BorderSide(
                  color: PdfColors.black,
                  width: _gridBorderWidth,
                ),
                bottom: pw.BorderSide(
                  color: PdfColors.black,
                  width: _gridBorderWidth,
                ),
              ),
            ),
            child: pw.Column(
              children: [
                // Top: Item column + Photo column
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildItemCell(),
                    pw.Expanded(
                      child: _buildPhotoCell(),
                    ),
                  ],
                ),
                // Bottom: Location + Comments
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: _buildLocationBottomCell(
                        'Ground Floor - Main Entrance',
                      ),
                    ),
                    pw.Expanded(
                      flex: 7,
                      child: _buildCommentsBottomCell("Inspector's comments:"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ================================================================
  // TEMPLATE 2 — ASSESSMENT TYPE
  // ================================================================
  pw.Widget _buildAssessmentTypePage() {
    // Mock selected codes for testing
    final selectedCodes = <String>{'FC2', 'WC1', 'B3', 'D4'};

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── PROJECT INFO SECTION ──
        _debugBorder(
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(0, 0, 0, 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DILAPIDATION SURVEY REPORT',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Project: Pusapahanas (Mock Data)',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    _infoField('Location:', 'First Floor - Corridor A'),
                    pw.SizedBox(width: 20),
                    _infoField('Section:', 'M / First'),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    _infoField('REF. NO.:', 'B-ME-02'),
                    pw.SizedBox(width: 20),
                    _infoField('Item No.:', '002'),
                  ],
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 8),

        // ── SCOPE OF INSPECTION CHECKBOXES ──
        _debugBorder(
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Scope of Inspection:',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  children: [
                    _scopeCheckbox('Internal', true),
                    pw.SizedBox(width: 12),
                    _scopeCheckbox('External', true),
                    pw.SizedBox(width: 12),
                    _scopeCheckbox('M&E', false),
                    pw.SizedBox(width: 12),
                    _scopeCheckbox('Public Fac.', false),
                  ],
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 8),

        // ── HEADER ROW ──
        _debugBorder(
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: PdfColors.black,
                width: _gridBorderWidth,
              ),
            ),
            child: pw.Row(
              children: [
                _headerCell('ITEM', width: _itemColumnWidth),
                _headerCell('PHOTO', width: _photoColumnWidth),
                _headerCell('ASSESSMENT TYPES', expand: true),
              ],
            ),
          ),
        ),

        // ── ITEM ROW ──
        _debugBorder(
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(
                  color: PdfColors.black,
                  width: _gridBorderWidth,
                ),
                right: pw.BorderSide(
                  color: PdfColors.black,
                  width: _gridBorderWidth,
                ),
                bottom: pw.BorderSide(
                  color: PdfColors.black,
                  width: _gridBorderWidth,
                ),
              ),
            ),
            child: pw.Column(
              children: [
                // Top: Item | Photo | Assessment Types
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildItemCell(),
                    _buildPhotoCell(),
                    pw.Expanded(
                      child: _buildAssessmentTypesCell(selectedCodes),
                    ),
                  ],
                ),
                // Bottom: Location | Comments | Impact Category
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildLocationBottomCell('First Floor - Corridor A'),
                    _buildCommentsBottomCell(
                      "Fine crack noticed. Monitor for progression.",
                    ),
                    pw.Expanded(
                      child: _buildImpactCategoryCell('Moderate'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ================================================================
  // ASSESSMENT TYPES — 3-Column Grid
  // ================================================================
  pw.Widget _buildAssessmentTypesCell(Set<String> selectedCodes) {
    return pw.Container(
      height: _topRowHeight,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          right: pw.BorderSide(
            color: PdfColors.black,
            width: _gridBorderWidth,
          ),
        ),
      ),
      child: pw.Column(
        children: [
          // Crack section (WC + FC)
          pw.Expanded(
            flex: 5,
            child: _buildAssessmentSectionGrid(
              title: 'Crack:',
              leftCodes: const ['WC1', 'WC2', 'WC3', 'WC4'],
              rightCodes: const ['FC1', 'FC2', 'FC3', 'FC4'],
              selectedCodes: selectedCodes,
              showBottomBorder: true,
            ),
          ),
          // Bent section
          pw.Expanded(
            flex: 3,
            child: _buildAssessmentSectionGrid(
              title: 'Bent:',
              leftCodes: const ['B1', 'B2'],
              rightCodes: const ['B3', 'B4'],
              selectedCodes: selectedCodes,
              showBottomBorder: true,
            ),
          ),
          // Damage section
          pw.Expanded(
            flex: 3,
            child: _buildAssessmentSectionGrid(
              title: 'Damage:',
              leftCodes: const ['D1', 'D2'],
              rightCodes: const ['D3', 'D4'],
              selectedCodes: selectedCodes,
              showBottomBorder: false,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildAssessmentSectionGrid({
    required String title,
    required List<String> leftCodes,
    required List<String> rightCodes,
    required Set<String> selectedCodes,
    required bool showBottomBorder,
  }) {
    final border = showBottomBorder
        ? pw.Border(
            bottom: pw.BorderSide(
              color: PdfColors.black,
              width: _gridBorderWidth,
            ),
          )
        : null;

    return pw.Container(
      decoration: border == null ? null : pw.BoxDecoration(border: border),
      padding: const pw.EdgeInsets.fromLTRB(4, 3, 4, 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
            ),
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
                          .map((code) => _codeLine(
                                code,
                                selectedCodes.contains(code),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                pw.Container(
                  width: _gridBorderWidth,
                  color: PdfColors.black,
                ),
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 4),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: rightCodes
                          .map((code) => _codeLine(
                                code,
                                selectedCodes.contains(code),
                              ))
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

  pw.Widget _codeLine(String code, bool selected) {
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

  // ================================================================
  // IMPACT CATEGORY CELL
  // ================================================================
  pw.Widget _buildImpactCategoryCell(String selectedImpact) {
    return pw.Container(
      height: _bottomRowHeight,
      padding: const pw.EdgeInsets.fromLTRB(4, 2, 4, 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color: PdfColors.black,
            width: _gridBorderWidth,
          ),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Impact Category:',
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          _impactLine('Minor:', selectedImpact == 'Minor'),
          _impactLine('Moderate:', selectedImpact == 'Moderate'),
          _impactLine('Major:', selectedImpact == 'Major'),
        ],
      ),
    );
  }

  pw.Widget _impactLine(String label, bool selected) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8.3,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          _buildCheckBox(selected),
        ],
      ),
    );
  }

  // ================================================================
  // SHARED WIDGETS
  // ================================================================

  pw.Widget _infoField(String label, String value) {
    return pw.Row(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Text(
          value,
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  pw.Widget _scopeCheckbox(String label, bool selected) {
    return pw.Row(
      children: [
        _buildCheckBox(selected),
        pw.SizedBox(width: 3),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8.5),
        ),
      ],
    );
  }

  pw.Widget _headerCell(
    String text, {
    double? width,
    bool expand = false,
  }) {
    final cell = pw.Container(
      alignment: pw.Alignment.center,
      height: 14,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          right: pw.BorderSide(
            color: PdfColors.black,
            width: _gridBorderWidth,
          ),
        ),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );

    if (expand) {
      return pw.Expanded(
        child: pw.Container(
          height: 14,
          alignment: pw.Alignment.center,
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return pw.SizedBox(width: width, child: cell);
  }

  pw.Widget _buildItemCell() {
    return pw.Container(
      width: _itemColumnWidth,
      height: _topRowHeight,
      padding: const pw.EdgeInsets.only(left: 4, top: 4, right: 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          right: pw.BorderSide(
            color: PdfColors.black,
            width: _gridBorderWidth,
          ),
        ),
      ),
      alignment: pw.Alignment.topLeft,
      child: pw.Text(
        '001.',
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _buildPhotoCell() {
    return pw.Container(
      width: _photoColumnWidth,
      height: _topRowHeight,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          right: pw.BorderSide(
            color: PdfColors.black,
            width: _gridBorderWidth,
          ),
        ),
      ),
      child: pw.Container(
        margin: const pw.EdgeInsets.all(3),
        color: PdfColors.grey200,
        alignment: pw.Alignment.center,
        child: pw.Text(
          'PHOTO\nPLACEHOLDER',
          style: pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey600,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  pw.Widget _buildLocationBottomCell(String location) {
    return pw.Container(
      width: _itemColumnWidth,
      height: _bottomRowHeight,
      padding: const pw.EdgeInsets.fromLTRB(4, 2, 3, 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color: PdfColors.black,
            width: _gridBorderWidth,
          ),
          right: pw.BorderSide(
            color: PdfColors.black,
            width: _gridBorderWidth,
          ),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Location:',
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            location,
            style: const pw.TextStyle(fontSize: 7.8),
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCommentsBottomCell(String comments) {
    return pw.Container(
      width: _photoColumnWidth,
      height: _bottomRowHeight,
      padding: const pw.EdgeInsets.fromLTRB(6, 2, 6, 2),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color: PdfColors.black,
            width: _gridBorderWidth,
          ),
          right: pw.BorderSide(
            color: PdfColors.black,
            width: _gridBorderWidth,
          ),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Inspector's comments:",
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            comments,
            style: const pw.TextStyle(fontSize: 7.7),
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  // ── CHECKBOX RENDERING ──
  pw.Widget _buildCheckBox(bool selected) {
    return pw.Container(
      width: 10,
      height: 10,
      decoration: pw.BoxDecoration(
        color: selected ? PdfColors.green400 : PdfColors.grey300,
        border: pw.Border.all(color: PdfColors.grey700, width: 0.8),
      ),
      child: selected ? _buildCheckMark() : null,
    );
  }

  pw.Widget _buildCheckMark() {
    return pw.Stack(
      fit: pw.StackFit.expand,
      children: [
        pw.Positioned(
          right: 2.5,
          top: 2.5,
          child: pw.Transform.rotate(
            angle: 0.8,
            child: pw.Container(
              width: 1.5,
              height: 3.2,
              color: PdfColors.black,
            ),
          ),
        ),
        pw.Positioned(
          left: 2.8,
          bottom: 1.8,
          child: pw.Transform.rotate(
            angle: -0.6,
            child: pw.Container(
              width: 1.5,
              height: 5.8,
              color: PdfColors.black,
            ),
          ),
        ),
      ],
    );
  }

  // ── DEBUG BORDER WRAPPER ──
  pw.Widget _debugBorder(pw.Widget child) {
    if (!_showDebugBorders) return child;
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: PdfColors.red,
          width: 0.3,
        ),
      ),
      child: child,
    );
  }

  // ── UI ──
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Test Module'),
        actions: [
          IconButton(
            icon: Icon(
              _showDebugBorders
                  ? Icons.border_style
                  : Icons.border_clear,
            ),
            tooltip: 'Toggle debug borders',
            onPressed: () => setState(
              () => _showDebugBorders = !_showDebugBorders,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Action buttons ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _generateOverallView,
                      icon: const Icon(Icons.grid_view),
                      label: const Text('Overall View'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _generateAssessmentType,
                      icon: const Icon(Icons.assessment),
                      label: const Text('Assessment Type'),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Info text ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Margins: left=20mm, top=10mm, right=10mm, bottom=10mm | '
              'Debug borders: ${_showDebugBorders ? "ON" : "OFF"}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── PDF Preview ──
          Expanded(
            child: _document != null
                ? PdfPreview(
                    build: (_) => _document!.save(),
                    maxPageWidth: 600,
                    canChangePageFormat: false,
                    canDebug: false,
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.picture_as_pdf,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Click a button above to generate a PDF preview',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}