// Standalone script to generate a sample PDF showing the assessment types layout
// Run with: dart test_pdf_generation.dart

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const double _pdfPhotoWidthCm = 9.8;
const double _pdfPhotoHeightCm = 8.8;
const double _pdfMarginLeftCm = 1.80;
const double _pdfMarginRightCm = 1.73;
const double _pdfMarginTopCm = 2.12;
const double _pdfMarginBottomCm = 2.47;
const double _pdfGridBorderWidth = 0.8;

double get _pdfPhotoWidth => _pdfPhotoWidthCm * PdfPageFormat.cm;
double get _pdfPhotoHeight => _pdfPhotoHeightCm * PdfPageFormat.cm;
double get _pdfItemColumnWidth => 1.45 * PdfPageFormat.cm;
double get _pdfPhotoColumnWidth => _pdfPhotoWidth + 6;
double get _pdfTopRowHeight => _pdfPhotoHeight + 6;
double get _pdfBottomRowHeight => 56;

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

void main() async {
  final pdf = pw.Document();

  // Page 1: Defect Assessment with some codes selected
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.only(
        left: _pdfMarginLeftCm * PdfPageFormat.cm,
        right: _pdfMarginRightCm * PdfPageFormat.cm,
        top: _pdfMarginTopCm * PdfPageFormat.cm,
        bottom: _pdfMarginBottomCm * PdfPageFormat.cm,
      ),
      build: (_) {
        final selectedCodes = {'FC2', 'FC4', 'WC1', 'B3', 'D1', 'D2'};
        return pw.Column(
          children: [
            // Header row
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: _pdfGridBorderWidth),
              ),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: _pdfItemColumnWidth,
                    height: 14,
                    alignment: pw.Alignment.center,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        right: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
                      ),
                    ),
                    child: pw.Text('ITEM', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Container(
                    width: _pdfPhotoColumnWidth,
                    height: 14,
                    alignment: pw.Alignment.center,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        right: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
                      ),
                    ),
                    child: pw.Text('PHOTO', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    child: pw.Container(
                      height: 14,
                      alignment: pw.Alignment.center,
                      child: pw.Text('ASSESSMENT TYPES', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            // Item row
            pw.Container(
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
                    children: [
                      // Item cell
                      pw.Container(
                        width: _pdfItemColumnWidth,
                        height: _pdfTopRowHeight,
                        padding: const pw.EdgeInsets.only(left: 4, top: 4),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            right: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
                          ),
                        ),
                        child: pw.Text('001.', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                      ),
                      // Photo cell (placeholder)
                      pw.Container(
                        width: _pdfPhotoColumnWidth,
                        height: _pdfTopRowHeight,
                        padding: const pw.EdgeInsets.all(3),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            right: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
                          ),
                        ),
                        child: pw.Container(
                          color: PdfColors.grey200,
                          alignment: pw.Alignment.center,
                          child: pw.Text('PHOTO', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
                        ),
                      ),
                      // Assessment cell
                      pw.Expanded(
                        child: pw.Container(
                          height: _pdfTopRowHeight,
                          child: _buildAssessmentCell(selectedCodes),
                        ),
                      ),
                    ],
                  ),
                  // Bottom row
                  pw.Row(
                    children: [
                      pw.Container(
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
                            pw.Text('Location:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 2),
                            pw.Text('Kitchen', style: const pw.TextStyle(fontSize: 7.8), maxLines: 4),
                          ],
                        ),
                      ),
                      pw.Container(
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
                            pw.Text("Inspector's comments:", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 1.5),
                            pw.Text('1. Hairline crack observed on wall surface.', style: const pw.TextStyle(fontSize: 7.7)),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Container(
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
                              pw.Text('Impact Category:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 2),
                              _buildImpactLine('Minor:', false),
                              _buildImpactLine('Moderate:', true),
                              _buildImpactLine('Major:', false),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  // Page 2: Overall View sample
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.only(
        left: _pdfMarginLeftCm * PdfPageFormat.cm,
        right: _pdfMarginRightCm * PdfPageFormat.cm,
        top: _pdfMarginTopCm * PdfPageFormat.cm,
        bottom: _pdfMarginBottomCm * PdfPageFormat.cm,
      ),
      build: (_) {
        return pw.Column(
          children: [
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: _pdfGridBorderWidth),
              ),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: _pdfItemColumnWidth,
                    height: 14,
                    alignment: pw.Alignment.center,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        right: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
                      ),
                    ),
                    child: pw.Text('ITEM', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    child: pw.Container(
                      height: 14,
                      alignment: pw.Alignment.center,
                      child: pw.Text('PHOTO', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            pw.Container(
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
                    children: [
                      pw.Container(
                        width: _pdfItemColumnWidth,
                        height: _pdfTopRowHeight,
                        padding: const pw.EdgeInsets.only(left: 4, top: 4),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            right: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
                          ),
                        ),
                        child: pw.Text('002.', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Expanded(
                        child: pw.Container(
                          height: _pdfTopRowHeight,
                          padding: const pw.EdgeInsets.all(3),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              right: pw.BorderSide(color: PdfColors.black, width: _pdfGridBorderWidth),
                            ),
                          ),
                          child: pw.Container(
                            color: PdfColors.grey200,
                            alignment: pw.Alignment.center,
                            child: pw.Text('PHOTO', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.Row(
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
                              pw.Text('Location:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 2),
                              pw.Text('Living Room', style: const pw.TextStyle(fontSize: 7.8), maxLines: 4),
                            ],
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 7,
                        child: pw.Container(
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
                              pw.Text("Inspector's comments:", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 1.5),
                              pw.Text('1. Area in satisfactory condition.', style: const pw.TextStyle(fontSize: 7.7)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  final file = File('sample_report_output.pdf');
  await file.writeAsBytes(await pdf.save());
  print('PDF generated: ${file.absolute.path}');
  print('File size: ${await file.length()} bytes');
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