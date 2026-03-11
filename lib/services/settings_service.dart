import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class SettingsService {
  static const String _hapticsKey = 'haptics_enabled';
  static const String _soundEffectsKey = 'sound_effects_enabled';
  static const String _showButtonLabelsKey = 'show_button_labels';
  static const String _confirmBeforeDeleteKey = 'confirm_before_delete';
  static const String _buttonRepeatDelayKey = 'button_repeat_delay';
  static const String _buttonSizeKey = 'button_size';
  static const String _betaFeaturesKey = 'beta_features_enabled';
  static const String _customRemoteUrlsKey = 'custom_remote_urls';
  static const String _developerModeKey = 'developer_mode_enabled';
  static const String _parsedImportPolicyKey = 'parsed_import_policy';

  static bool _hapticsEnabled = true;
  static bool _soundEffectsEnabled = true;
  static bool _showButtonLabels = true;
  static bool _confirmBeforeDelete = true;
  static int _buttonRepeatDelay = 300;
  static double _buttonSize = 70.0;
  static bool _betaFeaturesEnabled = false;
  static Map<String, String> _customRemoteUrls = {};
  static bool _developerModeEnabled = false;
  // 'ask' | 'raw' | 'parsed'
  static String _parsedImportPolicy = 'ask';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _hapticsEnabled = prefs.getBool(_hapticsKey) ?? true;
    _soundEffectsEnabled = prefs.getBool(_soundEffectsKey) ?? true;
    _showButtonLabels = prefs.getBool(_showButtonLabelsKey) ?? true;
    _confirmBeforeDelete = prefs.getBool(_confirmBeforeDeleteKey) ?? true;
    _buttonRepeatDelay = prefs.getInt(_buttonRepeatDelayKey) ?? 300;
    _buttonSize = prefs.getDouble(_buttonSizeKey) ?? 70.0;
    _betaFeaturesEnabled = prefs.getBool(_betaFeaturesKey) ?? false;
    _developerModeEnabled = prefs.getBool(_developerModeKey) ?? false;
    _parsedImportPolicy = prefs.getString(_parsedImportPolicyKey) ?? 'ask';
    
    final urlsJson = prefs.getString(_customRemoteUrlsKey);
    if (urlsJson != null) {
      try {
        final decoded = jsonDecode(urlsJson) as Map<String, dynamic>;
        _customRemoteUrls = decoded.map((key, value) => MapEntry(key, value.toString()));
      } catch (e) {
        _customRemoteUrls = {};
      }
    }
  }

  static bool get hapticsEnabled => _hapticsEnabled;
  static bool get soundEffectsEnabled => _soundEffectsEnabled;
  static bool get showButtonLabels => _showButtonLabels;
  static bool get confirmBeforeDelete => _confirmBeforeDelete;
  static int get buttonRepeatDelay => _buttonRepeatDelay;
  static double get buttonSize => _buttonSize;
  static bool get betaFeaturesEnabled => _betaFeaturesEnabled;
  static Map<String, String> get customRemoteUrls => Map.unmodifiable(_customRemoteUrls);
  static bool get developerModeEnabled => _developerModeEnabled;
  static String get parsedImportPolicy => _parsedImportPolicy;

  static Future<void> setHapticsEnabled(bool enabled) async {
    _hapticsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticsKey, enabled);
  }

  static Future<void> setSoundEffectsEnabled(bool enabled) async {
    _soundEffectsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEffectsKey, enabled);
  }

  static Future<void> setShowButtonLabels(bool enabled) async {
    _showButtonLabels = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showButtonLabelsKey, enabled);
  }

  static Future<void> setConfirmBeforeDelete(bool enabled) async {
    _confirmBeforeDelete = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_confirmBeforeDeleteKey, enabled);
  }

  static Future<void> setButtonRepeatDelay(int delay) async {
    _buttonRepeatDelay = delay;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_buttonRepeatDelayKey, delay);
  }

  static Future<void> setButtonSize(double size) async {
    _buttonSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_buttonSizeKey, size);
  }

  static Future<void> setBetaFeaturesEnabled(bool enabled) async {
    _betaFeaturesEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_betaFeaturesKey, enabled);
  }

  static Future<void> setDeveloperModeEnabled(bool enabled) async {
    _developerModeEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_developerModeKey, enabled);
  }

  /// Set how parsed Flipper files should be handled on import.
  /// Allowed values: 'ask', 'raw', 'parsed'
  static Future<void> setParsedImportPolicy(String policy) async {
    if (policy != 'ask' && policy != 'raw' && policy != 'parsed') {
      return;
    }
    _parsedImportPolicy = policy;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_parsedImportPolicyKey, policy);
  }

  static Future<void> setCustomRemoteUrl(String deviceType, String url) async {
    _customRemoteUrls[deviceType] = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customRemoteUrlsKey, jsonEncode(_customRemoteUrls));
  }

  static Future<void> removeCustomRemoteUrl(String deviceType) async {
    _customRemoteUrls.remove(deviceType);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customRemoteUrlsKey, jsonEncode(_customRemoteUrls));
  }

  static String? getCustomRemoteUrl(String deviceType) {
    return _customRemoteUrls[deviceType];
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith('universal_library_'))
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  static void lightHaptic() {
    if (_hapticsEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  static void mediumHaptic() {
    if (_hapticsEnabled) {
      HapticFeedback.mediumImpact();
    }
  }

  static void heavyHaptic() {
    if (_hapticsEnabled) {
      HapticFeedback.heavyImpact();
    }
  }

  static void selectionHaptic() {
    if (_hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
  }
}
