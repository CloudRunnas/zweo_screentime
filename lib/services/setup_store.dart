import 'package:shared_preferences/shared_preferences.dart';

/// Flutter-side state of the first-run setup.
class SetupStore {
  static const _keySetupCompleted = 'setupCompleted';
  static const _keyAutostartAcknowledged = 'autostartAcknowledged';
  static const _keyOtherPermissionsAcknowledged = 'otherPermissionsAcknowledged';

  static final _prefs = SharedPreferencesAsync();

  static Future<bool> isSetupCompleted() async =>
      await _prefs.getBool(_keySetupCompleted) ?? false;

  static Future<void> setSetupCompleted(bool value) =>
      _prefs.setBool(_keySetupCompleted, value);

  static Future<bool> isAutostartAcknowledged() async =>
      await _prefs.getBool(_keyAutostartAcknowledged) ?? false;

  static Future<void> setAutostartAcknowledged(bool value) =>
      _prefs.setBool(_keyAutostartAcknowledged, value);

  static Future<bool> isOtherPermissionsAcknowledged() async =>
      await _prefs.getBool(_keyOtherPermissionsAcknowledged) ?? false;

  static Future<void> setOtherPermissionsAcknowledged(bool value) =>
      _prefs.setBool(_keyOtherPermissionsAcknowledged, value);
}
