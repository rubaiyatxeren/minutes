import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/call_preferences.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/meeting_model.dart';
import 'meeting_service.dart';
import 'widgets/call_summary_sheet.dart';

class JoinMeetingScreen extends StatefulWidget {
  const JoinMeetingScreen({super.key});

  @override
  State<JoinMeetingScreen> createState() => _JoinMeetingScreenState();
}

class _JoinMeetingScreenState extends State<JoinMeetingScreen> {
  final _meetingService = MeetingService();
  final _roomCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _joining = false;
  CallQuality _quality = CallQuality.auto;
  bool _joinMuted = false;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    final quality = await CallPreferences.getQuality();
    final joinMuted = await CallPreferences.getJoinMuted();
    if (!mounted) return;
    setState(() {
      _quality = quality;
      _joinMuted = joinMuted;
    });
  }

  String _extractRoomName(String input) {
    // Accepts either a bare room ID or a full https://meet.jit.si/xxxx link.
    final trimmed = input.trim();
    if (trimmed.startsWith('http')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.last;
      }
    }
    return trimmed;
  }

  Future<void> _join() async {
    if (_roomCtrl.text.trim().isEmpty) return;
    setState(() => _joining = true);

    final roomToCheck = _extractRoomName(_roomCtrl.text);
    final status = await _meetingService.getMeetingStatus(roomToCheck);
    if (status == MeetingStatus.ended) {
      if (mounted) {
        final t = AppLocalizations.of(context);
        setState(() => _joining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.locale.languageCode == 'zh'
                ? '该通话已结束'
                : 'This call has already ended'),
          ),
        );
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final isAnon = user?.isAnonymous ?? true;
    final displayName = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : (user?.displayName ?? 'Guest');
    final roomName = _extractRoomName(_roomCtrl.text);
    final joinedParticipants = <String>{displayName};

    // Same double-fire guard as create_meeting_screen.dart.
    var terminationHandled = false;

    try {
      await _meetingService.joinMeeting(
        roomName: roomName,
        displayName: displayName,
        email: user?.email,
        isAnonymous: isAnon,
        isAudioMuted: _joinMuted,
        quality: _quality,
        roomPassword: _passwordCtrl.text.trim().isEmpty
            ? null
            : _passwordCtrl.text.trim(),
        listener: JitsiMeetEventListener(
          conferenceJoined: (url) {
            debugPrint('Joined meeting: $url');
            // Not the host — attaches to the existing history doc (or
            // creates one if this room was never logged, e.g. joined via a
            // link from outside the app).
            _meetingService.logJoined(
              roomName: roomName,
              displayName: displayName,
              isGroupCall: true,
            );
          },
          participantJoined: (email, name, role, participantId) {
            if (name != null && name.isNotEmpty) joinedParticipants.add(name);
          },
          conferenceTerminated: (url, error) async {
            if (terminationHandled) return;
            terminationHandled = true;

            debugPrint('Left meeting: $url');
            final duration = await _meetingService.logEnded(roomName);
            if (!mounted || duration == null) return;
            showCallSummarySheet(
              context,
              topic: roomName,
              duration: duration,
              participantNames: joinedParticipants.toList(),
            );
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final zh = t.locale.languageCode == 'zh';
    return Scaffold(
      appBar: AppBar(title: Text(t.joinMeeting)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(zh
                  ? '输入房间号或粘贴会议链接以加入。'
                  : 'Enter a room ID or paste a meeting link to join.'),
              const SizedBox(height: 20),
              TextField(
                controller: _roomCtrl,
                decoration: InputDecoration(
                  labelText: zh ? '房间号或链接' : 'Room ID or link',
                  prefixIcon: const Icon(Icons.meeting_room_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: zh ? '您的显示名称' : 'Your display name',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: zh ? '密码（如需要）' : 'Password (if required)',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: zh ? '立即加入' : 'Join Now',
                icon: Icons.login_rounded,
                loading: _joining,
                onPressed: _join,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
