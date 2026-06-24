import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/inspection_report_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/inspection_provider.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  static const _exportPathPref = 'fieldlens_export_path';
  bool _isExporting = false;
  String? _customExportPath;

  @override
  void initState() {
    super.initState();
    _loadExportPath();
  }

  Future<void> _loadExportPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _customExportPath = prefs.getString(_exportPathPref));
  }

  Future<void> _chooseExportDirectory() async {
    final controller = TextEditingController(text: _customExportPath ?? '');
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Set export folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Folder path',
            hintText: '/storage/emulated/0/Documents/FieldLens Reports',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (selected == null) return;
    if (selected.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_exportPathPref, selected);
    if (!mounted) return;
    setState(() => _customExportPath = selected);
  }

  Future<Directory> _resolveExportDirectory() async {
    if (_customExportPath != null && _customExportPath!.isNotEmpty) {
      final selected = Directory(_customExportPath!);
      if (!await selected.exists()) {
        await selected.create(recursive: true);
      }
      return selected;
    }

    if (Platform.isAndroid) {
      final preferred =
          Directory('/storage/emulated/0/Documents/FieldLens Reports');
      try {
        if (!await preferred.exists()) {
          await preferred.create(recursive: true);
        }
        return preferred;
      } catch (_) {}
    }

    final appDir = await getApplicationDocumentsDirectory();
    final fallback = Directory('${appDir.path}/FieldLens Reports');
    if (!await fallback.exists()) {
      await fallback.create(recursive: true);
    }
    return fallback;
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
          final imagePath = entry.primaryPhotoPath;
          Uint8List? imageBytes;
          if (imagePath.isNotEmpty) {
            final file = File(imagePath);
            if (await file.exists()) {
              imageBytes = await file.readAsBytes();
            }
          }
          return _PreparedInspection(entry, imageBytes);
        }),
      );

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => [
            pw.Text(
              'FieldLens Inspection Report',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Inspector: ${user?.name ?? 'N/A'}'),
            pw.Text('Inspector ID: ${user?.inspectorId ?? 'N/A'}'),
            pw.Text(
                'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
            pw.Text('Total Records: ${inspections.length}'),
            pw.SizedBox(height: 16),
            ...prepared.map((item) => _buildInspectionBlock(item)),
          ],
        ),
      );

      final output = await _resolveExportDirectory();
      final file = File(
        p.join(
          output.path,
          'FieldLens_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
        ),
      );
      await file.writeAsBytes(await pdf.save());
      _showSuccess('PDF saved to: ${file.path}', file);
    } catch (e) {
      _showFailure('Error exporting PDF: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  pw.Widget _buildInspectionBlock(_PreparedInspection prepared) {
    final inspection = prepared.inspection;
    final imageWidget = prepared.imageBytes == null
        ? pw.Container(
            width: 90,
            height: 90,
            alignment: pw.Alignment.center,
            color: PdfColors.grey300,
            child: pw.Text('No Image'),
          )
        : pw.Image(
            pw.MemoryImage(prepared.imageBytes!),
            width: 90,
            height: 90,
            fit: pw.BoxFit.cover,
          );

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey200),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          imageWidget,
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Report ${inspection.reportNumber.isEmpty ? inspection.itemNumber : inspection.reportNumber}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                    'Project: ${inspection.projectName} (${inspection.projectCode})'),
                pw.Text('Site: ${inspection.projectSiteLocation}'),
                pw.Text('Status: ${inspection.status}'),
                pw.Text(
                    'Defect: ${inspection.defectCode} (${inspection.defectType})'),
                pw.Text('Impact: ${inspection.impactCategory}'),
                pw.Text('Location: ${inspection.location}'),
                pw.Text('Comment: ${inspection.inspectorComments}'),
                pw.Text(
                  'Date/Time: ${DateFormat('yyyy-MM-dd HH:mm').format(inspection.timestamp)}',
                ),
                if (inspection.address != null &&
                    inspection.address!.isNotEmpty)
                  pw.Text('Address: ${inspection.address}'),
                if (inspection.latitude != null && inspection.longitude != null)
                  pw.Text(
                    'GPS: ${inspection.latitude!.toStringAsFixed(6)}, ${inspection.longitude!.toStringAsFixed(6)}',
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

      final excel = Excel.createExcel();
      final sheet = excel['Inspection Report'];
      sheet.appendRow([
        TextCellValue('Report Number'),
        TextCellValue('Project Name'),
        TextCellValue('Project Code'),
        TextCellValue('Site Location'),
        TextCellValue('Item Number'),
        TextCellValue('Status'),
        TextCellValue('Defect Type'),
        TextCellValue('Defect Code'),
        TextCellValue('Impact Category'),
        TextCellValue('Location'),
        TextCellValue('Inspector Comment'),
        TextCellValue('Date Time'),
        TextCellValue('Inspector Address'),
        TextCellValue('Latitude'),
        TextCellValue('Longitude'),
        TextCellValue('Image Reference'),
      ]);

      for (final inspection in rows) {
        final imageRef = inspection.primaryPhotoPath.isEmpty
            ? ''
            : 'file://${inspection.primaryPhotoPath}';
        sheet.appendRow([
          TextCellValue(inspection.reportNumber),
          TextCellValue(inspection.projectName),
          TextCellValue(inspection.projectCode),
          TextCellValue(inspection.projectSiteLocation),
          TextCellValue(inspection.itemNumber),
          TextCellValue(inspection.status),
          TextCellValue(inspection.defectType),
          TextCellValue(inspection.defectCode),
          TextCellValue(inspection.impactCategory),
          TextCellValue(inspection.location),
          TextCellValue(inspection.inspectorComments),
          TextCellValue(
              DateFormat('yyyy-MM-dd HH:mm').format(inspection.timestamp)),
          TextCellValue(inspection.address ?? ''),
          TextCellValue(inspection.latitude?.toStringAsFixed(6) ?? ''),
          TextCellValue(inspection.longitude?.toStringAsFixed(6) ?? ''),
          TextCellValue(imageRef),
        ]);
      }

      final output = await _resolveExportDirectory();
      final file = File(
        p.join(
          output.path,
          'FieldLens_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        ),
      );
      await file.writeAsBytes(excel.encode()!);
      _showSuccess('Excel saved to: ${file.path}', file);
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
    final exportPathHint =
        _customExportPath ?? 'Documents/FieldLens Reports (default)';

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
                    Text('Export folder: $exportPathHint'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isExporting ? null : _chooseExportDirectory,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Choose Export Folder'),
                    ),
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
                label: Text(
                  _isExporting
                      ? 'Exporting...'
                      : 'Export Excel (with image file references)',
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Reports include photo, comments, description, timestamp, inspector and status.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PreparedInspection {
  final InspectionReportModel inspection;
  final Uint8List? imageBytes;

  _PreparedInspection(this.inspection, this.imageBytes);
}
