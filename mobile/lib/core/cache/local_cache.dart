import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// A simple key-value cache backed by Hive.
///
/// Values are stored as JSON strings with an optional TTL.
/// Usage:
///   await LocalCache.init();                       // call once at app start
///   await LocalCache.put('workouts', myList);      // store
///   final data = LocalCache.get<List>('workouts'); // read (null if missing/expired)
class LocalCache {
  static const _boxName = 'app_cache';
  static const _ttlBoxName = 'app_cache_ttl';

  static late Box<String> _box;
  static late Box<int> _ttlBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    _ttlBox = await Hive.openBox<int>(_ttlBoxName);
  }

  /// Store [value] under [key]. If [ttlSeconds] is provided the entry
  /// expires after that many seconds. Pass null for no expiry.
  static Future<void> put(String key, dynamic value, {int? ttlSeconds}) async {
    await _box.put(key, jsonEncode(value));
    if (ttlSeconds != null) {
      final expiresAt = DateTime.now().millisecondsSinceEpoch + ttlSeconds * 1000;
      await _ttlBox.put(key, expiresAt);
    } else {
      await _ttlBox.delete(key);
    }
  }

  /// Returns the cached value for [key], or null if missing / expired.
  static T? get<T>(String key) {
    final expiresAt = _ttlBox.get(key);
    if (expiresAt != null && DateTime.now().millisecondsSinceEpoch > expiresAt) {
      _box.delete(key);
      _ttlBox.delete(key);
      return null;
    }
    final raw = _box.get(key);
    if (raw == null) return null;
    return jsonDecode(raw) as T?;
  }

  /// Returns true if a non-expired entry exists for [key].
  static bool has(String key) => get<dynamic>(key) != null;

  /// Delete a specific key.
  static Future<void> delete(String key) async {
    await _box.delete(key);
    await _ttlBox.delete(key);
  }

  /// Clear the entire cache (call on logout).
  static Future<void> clear() async {
    await _box.clear();
    await _ttlBox.clear();
  }
}
