import 'package:shared_preferences/shared_preferences.dart';

import 'local_api.dart';
import 'local_attendance_state.dart';
import 'local_leave_state.dart';

/// Sesi masuk lokal (tanpa OAuth) untuk build Nexora standalone.
class LocalSession {
  LocalSession._();

  static const _loggedInKey = 'nexora_local_logged_in';
  static const _userNameKey = 'nexora_local_user_name';

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loggedInKey) ??
        prefs.getBool('demo_logged_in') ??
        false;
  }

  static Future<String?> userName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey) ??
        prefs.getString('demo_user_name');
  }

  static Future<void> signIn({String displayName = 'Andi Wijaya'}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, true);
    await prefs.setString(_userNameKey, displayName);
    await prefs.remove('demo_logged_in');
    await prefs.remove('demo_user_name');
    LocalApi.setProfileDisplayName(displayName);
  }

  static Future<void> signOut() async {
    LocalAttendanceState.instance.reset();
    LocalLeaveState.instance.reset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loggedInKey);
    await prefs.remove(_userNameKey);
    await prefs.remove('demo_logged_in');
    await prefs.remove('demo_user_name');
  }
}
