import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/user_model.dart';
import '../utils/password_hasher.dart';

class AuthProvider extends ChangeNotifier {
  static const _sessionUserIdKey = 'session_user_id';
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  Future<void> initializeSession() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_sessionUserIdKey);
    if (userId != null) {
      _currentUser = await DatabaseHelper.getUserById(userId);
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> signup({
    required String name,
    required String username,
    required String password,
    required String inspectorId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check if username already exists
      final existingUser = await DatabaseHelper.getUserByUsername(username);
      if (existingUser != null) {
        _error = 'Username already exists';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Validate password
      if (password.length < 6) {
        _error = 'Password must be at least 6 characters';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Create user
      final userId = const Uuid().v4();
      final hashedPassword = PasswordHasher.hashPassword(password);
      
      final newUser = UserModel(
        id: userId,
        name: name,
        username: username,
        inspectorId: inspectorId,
        passwordHash: hashedPassword,
        createdAt: DateTime.now(),
      );

      final success = await DatabaseHelper.createUser(newUser);
      
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_sessionUserIdKey, newUser.id);
        _currentUser = newUser;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Failed to create user';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error during signup: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await DatabaseHelper.getUserByUsername(username);
      
      if (user == null) {
        _error = 'User not found';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final isPasswordValid = PasswordHasher.verifyPassword(
        password,
        user.passwordHash,
      );

      if (!isPasswordValid) {
        _error = 'Invalid password';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentUser = user;
      _isLoading = false;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionUserIdKey, user.id);
      return true;
    } catch (e) {
      _error = 'Error during login: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _error = null;
    _isLoading = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionUserIdKey);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
