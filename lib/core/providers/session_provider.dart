import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/session_model.dart';

class SessionProvider extends ChangeNotifier {
  String _currentUserId = '';
  String _currentSessionId = '';
  List<SessionModel> _sessions = [];
  bool _isLoading = false;
  String? _error;

  String get currentUserId => _currentUserId;
  String get currentSessionId => _currentSessionId;
  List<SessionModel> get sessions => _sessions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    if (userId.isNotEmpty) {
      loadSessions();
    }
  }

  Future<void> loadSessions() async {
    if (_currentUserId.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      final sessionMaps =
          await DatabaseHelper.getSessionsByUserId(_currentUserId);
      _sessions = sessionMaps
          .map((map) => SessionModel.fromMap(map))
          .toList();
      _error = null;
      
      // Reset current session if it's not in the list anymore
      if (_currentSessionId.isNotEmpty &&
          !_sessions.any((s) => s.id == _currentSessionId)) {
        _currentSessionId = '';
      }
    } catch (e) {
      _error = 'Failed to load sessions: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<SessionModel?> createSession({
    required String name,
    required String projectName,
    required String siteLocation,
    required DateTime inspectionDate,
  }) async {
    if (_currentUserId.isEmpty) {
      _error = 'No user logged in';
      notifyListeners();
      return null;
    }

    try {
      final sessionId = const Uuid().v4();
      final now = DateTime.now();

      final session = SessionModel(
        id: sessionId,
        userId: _currentUserId,
        sessionName: name,
        projectName: projectName,
        siteLocation: siteLocation,
        inspectionDate: inspectionDate,
        createdAt: now,
      );

      final success = await DatabaseHelper.createSession(session.toMap());

      if (success) {
        _sessions.insert(0, session);
        _currentSessionId = sessionId;
        _error = null;
        notifyListeners();
        return session;
      } else {
        _error = 'Failed to create session';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = 'Error creating session: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteSession(String sessionId) async {
    try {
      final success = await DatabaseHelper.deleteSession(sessionId);

      if (success) {
        _sessions.removeWhere((s) => s.id == sessionId);
        if (_currentSessionId == sessionId) {
          _currentSessionId = '';
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Error deleting session: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  SessionModel? getSessionById(String sessionId) {
    try {
      return _sessions.firstWhere((s) => s.id == sessionId);
    } catch (e) {
      return null;
    }
  }

  void setCurrentSession(String sessionId) {
    _currentSessionId = sessionId;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
