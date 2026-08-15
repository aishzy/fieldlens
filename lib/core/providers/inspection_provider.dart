import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/inspection_report_model.dart';
import '../models/report_model.dart';

class InspectionProvider extends ChangeNotifier {
  String _currentUserId = '';
  List<InspectionReportModel> _inspections = [];
  List<ReportModel> _reports = [];
  String? _activeReportId;
  bool _isLoading = false;
  String? _error;

  String get currentUserId => _currentUserId;
  List<InspectionReportModel> get inspections => _inspections;
  List<ReportModel> get reports => _reports;
  String? get activeReportId => _activeReportId;
  ReportModel? get activeReport {
    if (_activeReportId == null) return null;
    for (final report in _reports) {
      if (report.id == _activeReportId) return report;
    }
    return null;
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  int get inspectionCount => _inspections.length;

  Future<void> setCurrentUserId(String userId) async {
    final changed = _currentUserId != userId;
    _currentUserId = userId;
    if (!changed) return;

    if (_currentUserId.isEmpty) {
      _reports = [];
      _activeReportId = null;
      _inspections = [];
      _error = null;
      notifyListeners();
      return;
    }

    await _loadReports();
    await loadInspections();
  }

  Future<void> loadInspections() async {
    if (_currentUserId.isEmpty) {
      _inspections = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    try {
      if (_activeReportId == null && _reports.isEmpty) {
        await _loadReports();
      }

      final reportId = _activeReportId ?? (_reports.isNotEmpty ? _reports.first.id : null);
      if (reportId != null) {
        _inspections = await DatabaseHelper.getInspectionsByUserIdAndReport(
          _currentUserId,
          reportId,
        );
      } else {
        _inspections = await DatabaseHelper.getInspectionsByUserId(_currentUserId);
      }
      _error = null;
    } catch (e) {
      _error = 'Failed to load inspections: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> saveInspection({
    required String itemNumber,
    required List<String> photoPaths,
    required String defectType,
    required String defectCode,
    required String location,
    required String inspectorComments,
    required String impactCategory,
    required String status,
    DateTime? timestamp,
    String refNo = '',
    String section = '',
    String? reportId,
    bool scopeInternal = false,
    bool scopeExternal = false,
    bool scopeME = false,
    bool scopePublicFacilities = false,
    List<String> selectedDefectCodes = const [],
    String inspectionMode = 'defect',
  }) async {
    if (_currentUserId.isEmpty) {
      _error = 'No user logged in';
      notifyListeners();
      return false;
    }

    try {
      await _ensureActiveReportExists();
      final activeReportId = reportId ?? _activeReportId;
      if (activeReportId == null || activeReportId.isEmpty) {
        _error = 'No active report available';
        notifyListeners();
        return false;
      }

      final inspection = InspectionReportModel(
        id: const Uuid().v4(),
        userId: _currentUserId,
        reportId: activeReportId,
        itemNumber: itemNumber,
        photoPaths: photoPaths,
        defectType: defectType,
        defectCode: defectCode,
        location: location,
        inspectorComments: inspectorComments,
        impactCategory: impactCategory,
        status: status,
        refNo: refNo,
        section: section,
        scopeInternal: scopeInternal,
        scopeExternal: scopeExternal,
        scopeME: scopeME,
        scopePublicFacilities: scopePublicFacilities,
        selectedDefectCodes: selectedDefectCodes,
        timestamp: timestamp ?? DateTime.now(),
        inspectionMode: inspectionMode,
      );

      final success = await DatabaseHelper.saveInspectionReport(inspection);

      if (success) {
        _inspections.insert(0, inspection);
        _error = null;
        notifyListeners();
        return true;
      } else {
        _error = 'Failed to save inspection';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error saving inspection: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateInspection(InspectionReportModel inspection) async {
    try {
      final success = await DatabaseHelper.updateInspectionReport(inspection);

      if (success) {
        final index = _inspections.indexWhere((i) => i.id == inspection.id);
        if (index >= 0) {
          _inspections[index] = inspection;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Error updating inspection: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteInspection(String id) async {
    try {
      final index = _inspections.indexWhere((item) => item.id == id);
      final inspection = index >= 0 ? _inspections[index] : null;
      final success = await DatabaseHelper.deleteInspectionReport(id);

      if (success) {
        if (inspection != null) {
          await _deleteInspectionImages(inspection);
        }
        _inspections.removeWhere((i) => i.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Error deleting inspection: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> setActiveReportId(String reportId) async {
    if (_reports.any((report) => report.id == reportId)) {
      _activeReportId = reportId;
      notifyListeners();
      await loadInspections();
      return true;
    }
    return false;
  }

  Future<bool> createReport({
    required String reportName,
    required String site,
    required String sector,
    required String siteLocation,
    required String inspector,
  }) async {
    if (_currentUserId.isEmpty) {
      _error = 'No user logged in';
      notifyListeners();
      return false;
    }

    final newReport = ReportModel(
      id: const Uuid().v4(),
      userId: _currentUserId,
      reportName: reportName,
      site: site,
      sector: sector,
      siteLocation: siteLocation,
      inspector: inspector,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await DatabaseHelper.saveReport(newReport);
    if (!success) {
      _error = 'Failed to create report';
      notifyListeners();
      return false;
    }

    _reports.insert(0, newReport);
    _activeReportId = newReport.id;
    notifyListeners();
    await loadInspections();
    return true;
  }

  Future<void> _loadReports() async {
    if (_currentUserId.isEmpty) {
      _reports = [];
      _activeReportId = null;
      return;
    }

    try {
      _reports = await DatabaseHelper.getReportsByUserId(_currentUserId);
      if (_reports.isEmpty) {
        final defaultReport = ReportModel(
          id: const Uuid().v4(),
          userId: _currentUserId,
          reportName: 'Default Report',
          site: '',
          sector: '',
          siteLocation: '',
          inspector: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final created = await DatabaseHelper.saveReport(defaultReport);
        if (created) {
          _reports = [defaultReport];
          _activeReportId = defaultReport.id;
          notifyListeners();
        }
      } else {
        _activeReportId ??= _reports.first.id;
      }
    } catch (e) {
      _error = 'Failed to load reports: ${e.toString()}';
    }
  }

  Future<void> _ensureActiveReportExists() async {
    if (_activeReportId != null) return;
    await _loadReports();
    if (_activeReportId == null && _reports.isNotEmpty) {
      _activeReportId = _reports.first.id;
    }
  }

  Future<void> _deleteInspectionImages(InspectionReportModel inspection) async {
    final seen = <String>{};
    for (final path in inspection.photoPaths) {
      if (path.isEmpty || seen.contains(path)) continue;
      seen.add(path);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
