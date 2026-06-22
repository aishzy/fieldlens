import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/inspection_report_model.dart';

class InspectionProvider extends ChangeNotifier {
  String _currentUserId = '';
  List<InspectionReportModel> _inspections = [];
  bool _isLoading = false;
  String? _error;

  String get currentUserId => _currentUserId;
  List<InspectionReportModel> get inspections => _inspections;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get inspectionCount => _inspections.length;

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    if (userId.isNotEmpty) {
      loadInspections();
    }
  }

  Future<void> loadInspections() async {
    if (_currentUserId.isEmpty) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      _inspections = await DatabaseHelper.getInspectionsByUserId(_currentUserId);
      _error = null;
    } catch (e) {
      _error = 'Failed to load inspections: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> saveInspection({
    required String itemNumber,
    required String photoPath,
    required String defectType,
    required String defectCode,
    required String location,
    required String inspectorComments,
    required String impactCategory,
  }) async {
    if (_currentUserId.isEmpty) {
      _error = 'No user logged in';
      notifyListeners();
      return false;
    }

    try {
      final inspection = InspectionReportModel(
        id: const Uuid().v4(),
        userId: _currentUserId,
        itemNumber: itemNumber,
        photoPath: photoPath,
        defectType: defectType,
        defectCode: defectCode,
        location: location,
        inspectorComments: inspectorComments,
        impactCategory: impactCategory,
        timestamp: DateTime.now(),
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
      final success = await DatabaseHelper.deleteInspectionReport(id);
      
      if (success) {
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
}
