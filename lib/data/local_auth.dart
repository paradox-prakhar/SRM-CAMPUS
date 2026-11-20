import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A signed-in demo account stored on this device.
class LocalUser {
  final String name, email;
  final DateTime createdAt;
  const LocalUser(this.name, this.email, this.createdAt);
}

class LocalAuthException implements Exception {
  final String message;
  const LocalAuthException(this.message);
  @override
  String toString() => message;
}

/// Demo-only account store kept on the device with shared_preferences
/// (localStorage on web). Nothing is sent to a server. Passwords are stored
/// as salted SHA-256 hashes, never as plain text. Not production security.
class LocalAuth {
  static const _usersKey = 'local_auth_users_v1';
  static const _sessionKey = 'local_auth_session_v1';

  /// The signed-in user, or null. Listen to rebuild UI on sign in/out.
  static final current = ValueNotifier<LocalUser?>(null);

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Restores the saved session on app start.
  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_sessionKey);
      if (email == null) return;
      final record = _users(prefs)[email];
      if (record == null) {
        await prefs.remove(_sessionKey);
        return;
      }
      current.value = _toUser(email, record);
    } catch (_) {
      // Storage unavailable: start signed out.
    }
  }

  static Future<LocalUser> signUp(
    String name,
    String email,
    String password,
  ) async {
    name = name.trim();
    email = email.trim().toLowerCase();
    if (name.isEmpty) throw const LocalAuthException('Enter your name.');
    if (!_emailPattern.hasMatch(email)) {
      throw const LocalAuthException('Enter a valid email address.');
    }
    if (password.length < 6) {
      throw const LocalAuthException('Password must be at least 6 characters.');
    }
    final prefs = await SharedPreferences.getInstance();
    final users = _users(prefs);
    if (users.containsKey(email)) {
      throw const LocalAuthException(
        'An account with this email already exists on this device. Sign in instead.',
      );
    }
    final salt = _salt();
    users[email] = {
      'name': name,
      'salt': salt,
      'hash': _hash(password, salt),
      'createdAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_usersKey, jsonEncode(users));
    await prefs.setString(_sessionKey, email);
    return current.value = _toUser(email, users[email]!);
  }

  static Future<LocalUser> signIn(String email, String password) async {
    email = email.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final record = _users(prefs)[email];
    if (record == null ||
        record['hash'] != _hash(password, record['salt'] as String)) {
      throw const LocalAuthException('Incorrect email or password.');
    }
    await prefs.setString(_sessionKey, email);
    return current.value = _toUser(email, record);
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    current.value = null;
  }

  /// Removes the signed-in account from this device.
  static Future<void> deleteAccount() async {
    final user = current.value;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final users = _users(prefs)..remove(user.email);
    await prefs.setString(_usersKey, jsonEncode(users));
    await signOut();
  }

  static Map<String, Map<String, dynamic>> _users(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_usersKey);
      if (raw == null) return {};
      return (jsonDecode(raw) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
      );
    } catch (_) {
      return {};
    }
  }

  static LocalUser _toUser(String email, Map<String, dynamic> r) => LocalUser(
    r['name'] as String? ?? email,
    email,
    DateTime.tryParse(r['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  static String _salt() {
    final rnd = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
  }

  static String _hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();
}
