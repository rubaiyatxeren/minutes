import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/services/call_preferences.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/user_avatar.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _soundPrefsKey = 'sound_enabled';
  static const _notificationsPrefsKey = 'notifications_enabled';

  bool _soundEnabled = true;
  bool _notificationsEnabled = true;
  bool _sendingReset = false;
  CallQuality _callQuality = CallQuality.auto;
  bool _joinCallsMuted = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final quality = await CallPreferences.getQuality();
    final joinMuted = await CallPreferences.getJoinMuted();
    if (!mounted) return;
    setState(() {
      _soundEnabled = prefs.getBool(_soundPrefsKey) ?? true;
      _notificationsEnabled = prefs.getBool(_notificationsPrefsKey) ?? true;
      _callQuality = quality;
      _joinCallsMuted = joinMuted;
    });
  }

  Future<void> _setSoundPref(bool v) async {
    setState(() => _soundEnabled = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundPrefsKey, v);
  }

  Future<void> _setNotificationsPref(bool v) async {
    setState(() => _notificationsEnabled = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsPrefsKey, v);
  }

  Future<void> _setCallQuality(CallQuality q) async {
    setState(() => _callQuality = q);
    await CallPreferences.setQuality(q);
  }

  Future<void> _setJoinCallsMuted(bool v) async {
    setState(() => _joinCallsMuted = v);
    await CallPreferences.setJoinMuted(v);
  }

  Future<void> _sendResetEmail(BuildContext context, String email) async {
    final t = AppLocalizations.of(context);
    setState(() => _sendingReset = true);
    try {
      await context.read<AuthService>().sendPasswordReset(email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.resetEmailSent} $email')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.resetEmailFailed}: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final localeProvider = context.read<LocaleProvider>();
    final current = localeProvider.resolvedLanguageCode(context);

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        Widget option(String code, String label) {
          return RadioListTile<String>(
            title: Text(label),
            value: code,
            groupValue: current,
            onChanged: (v) => Navigator.pop(ctx, v),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(t.chooseLanguage,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
                option('en', 'English'),
                option('zh', '中文（简体）'),
              ],
            ),
          ),
        );
      },
    );

    if (choice != null && choice != current) {
      await localeProvider.setLanguage(choice);
    }
  }

  Future<void> _pickCallQuality(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<CallQuality>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        Widget option(CallQuality q, String label, String subtitle) {
          return RadioListTile<CallQuality>(
            title: Text(label),
            subtitle: Text(subtitle),
            value: q,
            groupValue: _callQuality,
            onChanged: (v) => Navigator.pop(ctx, v),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(t.defaultCallQuality,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
                option(
                  CallQuality.auto,
                  t.qualityAuto,
                  t.locale.languageCode == 'zh'
                      ? '根据网络状况自动调整，延迟最低'
                      : 'Adapts to your connection automatically — lowest latency',
                ),
                option(
                  CallQuality.high,
                  t.qualityHigh,
                  t.locale.languageCode == 'zh'
                      ? '优先保证清晰度，消耗更多流量'
                      : 'Prioritizes sharpness — uses more data',
                ),
                option(
                  CallQuality.dataSaver,
                  t.qualityDataSaver,
                  t.locale.languageCode == 'zh'
                      ? '限制画质以适应较弱的网络'
                      : 'Caps quality for weak connections',
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice != null) await _setCallQuality(choice);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // Was reading FirebaseAuth.instance.currentUser directly — that only
    // reflects the very first build. AuthService.updateProfile() already
    // calls notifyListeners() after saving, so watching it here is what
    // makes this screen's avatar/name actually refresh the moment you
    // come back from Edit Profile, instead of needing an app restart.
    final user = context.watch<AuthService>().currentUser;
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final languageLabel = localeProvider.resolvedLanguageCode(context) == 'zh'
        ? '中文'
        : 'English';

    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _ProfileCard(user: user, t: t),
            const SizedBox(height: 24),
            _SectionLabel(t.appearance),
            _SettingsCard(
              children: [
                RadioListTile<ThemeMode>(
                  title: Text(t.light),
                  secondary: const Icon(Icons.light_mode_outlined),
                  value: ThemeMode.light,
                  groupValue: themeProvider.mode,
                  onChanged: (m) => themeProvider.setMode(m!),
                ),
                RadioListTile<ThemeMode>(
                  title: Text(t.dark),
                  secondary: const Icon(Icons.dark_mode_outlined),
                  value: ThemeMode.dark,
                  groupValue: themeProvider.mode,
                  onChanged: (m) => themeProvider.setMode(m!),
                ),
                RadioListTile<ThemeMode>(
                  title: Text(t.systemDefault),
                  secondary: const Icon(Icons.settings_suggest_outlined),
                  value: ThemeMode.system,
                  groupValue: themeProvider.mode,
                  onChanged: (m) => themeProvider.setMode(m!),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionLabel(t.language),
            _SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.translate_rounded),
                  title: Text(t.language),
                  subtitle: Text(languageLabel),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickLanguage(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionLabel(t.callSettings),
            _SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.high_quality_outlined),
                  title: Text(t.defaultCallQuality),
                  subtitle: Text(switch (_callQuality) {
                    CallQuality.auto => t.qualityAuto,
                    CallQuality.high => t.qualityHigh,
                    CallQuality.dataSaver => t.qualityDataSaver,
                  }),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickCallQuality(context),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.mic_off_outlined),
                  title: Text(t.joinCallsMuted),
                  subtitle: Text(t.joinCallsMutedSubtitle),
                  value: _joinCallsMuted,
                  onChanged: _setJoinCallsMuted,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionLabel(t.preferences),
            _SettingsCard(
              children: [
                SwitchListTile(
                  title: Text(t.messageSound),
                  subtitle: Text(t.messageSoundSubtitle),
                  secondary: const Icon(Icons.volume_up_outlined),
                  value: _soundEnabled,
                  onChanged: _setSoundPref,
                ),
                SwitchListTile(
                  title: Text(t.pushNotifications),
                  subtitle: Text(t.pushNotificationsSubtitle),
                  secondary: const Icon(Icons.notifications_outlined),
                  value: _notificationsEnabled,
                  onChanged: _setNotificationsPref,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionLabel(t.account),
            _SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(t.editProfile),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                  ),
                ),
                if (user != null &&
                    !user.isAnonymous &&
                    (user.email?.isNotEmpty ?? false))
                  ListTile(
                    leading: const Icon(Icons.lock_reset_rounded),
                    title: Text(t.resetPassword),
                    subtitle: Text('${t.sendResetLinkTo} ${user.email}'),
                    trailing: _sendingReset
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: _sendingReset
                        ? null
                        : () => _sendResetEmail(context, user.email!),
                  ),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.red),
                  title: Text(t.signOut, style: const TextStyle(color: Colors.red)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(t.signOutConfirmTitle),
                        content: Text(t.signOutConfirmBody),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(t.cancel)),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(t.signOut,
                                  style: const TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    await context.read<AuthService>().signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionLabel(t.about),
            _SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded),
                  title: Text(t.helpAndSupport),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(t.privacyPolicy),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Center(child: AppLogo(size: 40)),
            const SizedBox(height: 10),
            Center(
              child: Text('${t.appName} · v1.0.0',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final User? user;
  final AppLocalizations t;
  const _ProfileCard({required this.user, required this.t});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EditProfileScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              UserAvatar(
                name: user?.displayName ?? t.guest,
                photoUrl: user?.photoURL,
                radius: 30,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.displayName ?? t.guest,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(user?.email ?? t.anonymousSession,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined,
                  size: 20, color: Theme.of(context).primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}
