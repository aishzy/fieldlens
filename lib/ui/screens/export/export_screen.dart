import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' hide Border;
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/inspection_provider.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _isExporting = false;

  Future<void> _exportToPDF() async {
    setState(() => _isExporting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final inspectionProvider =
          Provider.of<InspectionProvider>(context, listen: false);

      final user = authProvider.currentUser;
      final inspections = inspectionProvider.inspections;

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) => [
            // Header
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Dilapidation Survey Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Inspector: ${user?.name ?? 'N/A'}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Inspector ID: ${user?.inspectorId ?? 'N/A'}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Report Generated: ${DateTime.now().toString().split('.')[0]}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Total Items: ${inspections.length}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 20),
              ],
            ),
            // Table
            pw.TableHelper.fromTextArray(
              headers: [
                'Item No',
                'Location',
                'Defect Code',
                'Type',
                'Impact',
                'Comments',
              ],
              data: inspections
                  .map(
                    (inspection) => [
                      inspection.itemNumber,
                      inspection.location,
                      inspection.defectCode,
                      inspection.defectType,
                      inspection.impactCategory,
                      inspection.inspectorComments.length > 30
                          ? '${inspection.inspectorComments.substring(0, 30)}...'
                          : inspection.inspectorComments,
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerLeft,
                5: pw.Alignment.centerLeft,
              },
              border: pw.TableBorder.all(),
            ),
          ],
        ),
      );

      final output = await getApplicationDocumentsDirectory();
      final fileName =
          'DilapidationReport_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${output.path}/$fileName');

      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to: ${file.path}'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => _shareFile(file),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);

    try {
      final inspectionProvider =
          Provider.of<InspectionProvider>(context, listen: false);

      final inspections = inspectionProvider.inspections;

      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Add headers
      sheet.appendRow([
        TextCellValue('Item Number'),
        TextCellValue('Location'),
        TextCellValue('Defect Type'),
        TextCellValue('Defect Code'),
        TextCellValue('Impact Category'),
        TextCellValue('Comments'),
        TextCellValue('Date'),
      ]);

      // Add data rows
      for (final inspection in inspections) {
        sheet.appendRow([
          TextCellValue(inspection.itemNumber),
          TextCellValue(inspection.location),
          TextCellValue(inspection.defectType),
          TextCellValue(inspection.defectCode),
          TextCellValue(inspection.impactCategory),
          TextCellValue(inspection.inspectorComments),
          TextCellValue(inspection.timestamp.toString().split('.')[0]),
        ]);
      }

      final output = await getApplicationDocumentsDirectory();
      final fileName =
          'DilapidationReport_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File('${output.path}/$fileName');

      await file.writeAsBytes(excel.encode()!);

      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel file saved to: ${file.path}'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => _shareFile(file),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting Excel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareFile(File file) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Dilapidation Survey Report',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final inspectionProvider = Provider.of<InspectionProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Report'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Report Summary',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryRow(
                        'Total Inspections',
                        inspectionProvider.inspectionCount.toString(),
                      ),
                      _buildSummaryRow(
                        'Report Format',
                        'PDF or Excel',
                      ),
                      _buildSummaryRow(
                        'Status',
                        inspectionProvider.inspectionCount > 0
                            ? 'Ready to export'
                            : 'No data to export',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Export Options
              Text(
                'Export Format',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),

              if (inspectionProvider.inspectionCount == 0)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.info,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No inspections to export',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // PDF Export
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.picture_as_pdf,
                              size: 32,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'PDF Report',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Professional formatted report',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isExporting ? null : _exportToPDF,
                            icon: _isExporting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.download),
                            label: Text(
                              _isExporting ? 'Exporting...' : 'Export as PDF',
                            ),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Excel Export
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.table_chart,
                              size: 32,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Excel Spreadsheet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Standard spreadsheet format for data analysis',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isExporting ? null : _exportToExcel,
                            icon: _isExporting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.download),
                            label: Text(
                              _isExporting
                                  ? 'Exporting...'
                                  : 'Export as Excel',
                            ),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Info Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Export Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Reports are saved to your device Documents folder\n'
                        '• You can share reports via email, messaging, or cloud storage\n'
                        '• All data is stored locally for offline access\n'
                        '• No internet connection required',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
