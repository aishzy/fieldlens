import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/inspection_report_model.dart';

class InspectionProvider extends ChangeNotifier {
  String _currentUserId = '';
  String _currentSessionId = '';
  List<InspectionReportModel> _inspections = [];
  bool _isLoading = false;
  String? _error;

  String get currentUserId => _currentUserId;
  String get currentSessionId => _currentSessionId;
  List<InspectionReportModel> get inspections => _inspections;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get inspectionCount => _inspections.length;

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  void setCurrentSession(String sessionId) {
    _currentSessionId = sessionId;
    if (sessionId.isNotEmpty) {
      loadInspections();
    }
  }

  Future<void> loadInspections() async {
    if (_currentSessionId.isEmpty) {
      _inspections = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _inspections =
          await DatabaseHelper.getInspectionsBySessionId(_currentSessionId);
      _error = null;
    } catch (e) {
      _error = 'Failed to load inspections: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> saveInspection({
    required String sessionId,
    required String itemNumber,
    required List<String> photoPaths,
    required String defectType,
    required String defectCode,
    required String location,
    required String inspectorComments,
    required String impactCategory,
    required String status,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    String? address,
    String refNo = '',
    String section = '',
    bool scopeInternal = false,
    bool scopeExternal = false,
    bool scopeME = false,
    bool scopePublicFacilities = false,
    List<String> selectedDefectCodes = const [],
  }) async {
    if (_currentUserId.isEmpty) {
      _error = 'No user logged in';
      notifyListeners();
      return false;
    }

    if (sessionId.isEmpty) {
      _error = 'No session selected';
      notifyListeners();
      return false;
    }

    try {
      final inspection = InspectionReportModel(
        id: const Uuid().v4(),
        userId: _currentUserId,
        sessionId: sessionId,
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
        latitude: latitude,
        longitude: longitude,
        address: address,
        timestamp: timestamp ?? DateTime.now(),
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

  int getInspectionCountBySessionId(String sessionId) {
    try {
      return _inspections.where((i) => i.sessionId == sessionId).length;
    } catch (e) {
      return 0;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
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
