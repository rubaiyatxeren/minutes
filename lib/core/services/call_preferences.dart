import 'package:shared_preferences/shared_preferences.dart';

/// Default video call quality, applied automatically to new calls.
///
/// - [auto]: let the SDK/network adapt (simulcast on, no resolution cap).
///   Best experience on decent connections — this is the "blazing fast"
///   default because it lets WebRTC's own bandwidth estimation pick the
///   best layer per-participant instead of a fixed cap.
/// - [high]: prioritize resolution/framerate; uses more bandwidth/battery.
/// - [dataSaver]: caps resolution and disables simulcast — same mechanism
///   as the existing "Low bandwidth mode" toggle, just as a standing
///   default instead of a per-call switch.
enum CallQuality { auto, high, dataSaver }

/// Centralizes the small set of call-related preferences that used to be
/// re-entered on every "New meeting" / "Join meeting" screen. Settings
/// writes these; the meeting screens read them as the starting defaults
/// (a user can still override per-call before joining).
class CallPreferences {
  CallPreferences._();

  static const _qualityKey = 'call_quality';
  static const _joinMutedKey = 'call_join_muted';

  static Future<CallQuality> getQuality() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_qualityKey)) {
      case 'high':
        return CallQuality.high;
      case 'dataSaver':
        return CallQuality.dataSaver;
      default:
        return CallQuality.auto;
    }
  }

  static Future<void> setQuality(CallQuality quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_qualityKey, quality.name);
  }

  static Future<bool> getJoinMuted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_joinMutedKey) ?? false;
  }

  static Future<void> setJoinMuted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_joinMutedKey, value);
  }
}
