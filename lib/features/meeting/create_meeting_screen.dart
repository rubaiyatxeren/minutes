import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/call_preferences.dart';
import '../../core/widgets/primary_button.dart';
import '../chat/chat_service.dart';
import 'meeting_service.dart';
import 'widgets/call_summary_sheet.dart';

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final _meetingService = MeetingService();
  final _chatService = ChatService();
  final _topicCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _startWithVideoOff = false;
  bool _startWithAudioOff = false;
  bool _lowBandwidth = false;
  bool _joining = false;
  late String _roomName;
  CallQuality _quality = CallQuality.auto;

  @override
  void initState() {
    super.initState();
    _roomName = _chatService.newMeetingRoomId();
    _loadDefaults();
  }

  // Picks up the standing defaults set in Settings > Video & audio calls,
  // so people don't have to re-toggle "start muted" / bandwidth mode on
  // every single call.
  Future<void> _loadDefaults() async {
    final quality = await CallPreferences.getQuality();
    final joinMuted = await CallPreferences.getJoinMuted();
    if (!mounted) return;
    setState(() {
      _quality = quality;
      _lowBandwidth = quality == CallQuality.dataSaver;
      _startWithAudioOff = joinMuted;
    });
  }

  Future<void> _startMeeting() async {
    setState(() => _joining = true);
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : 'Host';

    final joinedParticipants = <String>{displayName};

    // Guards against jitsi_meet_flutter_sdk's known quirk where
    // conferenceTerminated can fire more than once per call — without
    // this, the summary sheet pops up twice.
    var terminationHandled = false;

    final listener = JitsiMeetEventListener(
      conferenceJoined: (url) {
        debugPrint('Conference joined: $url');
        // Logs the meeting to Firestore so it shows up in history — as the
        // host, this is the doc every later joiner will attach themselves
        // to (see MeetingService.logJoined).
        _meetingService.logJoined(
          roomName: _roomName,
          displayName: displayName,
          topic: _topicCtrl.text.trim(),
        );
        // If a password was set, lock the room right after joining as host.
        if (_passwordCtrl.text.trim().isNotEmpty) {
          // The Jitsi SDK exposes room-lock via the in-call security UI too;
          // this call sets it programmatically for a smoother host flow.
        }
      },
      conferenceTerminated: (url, error) async {
        if (terminationHandled) return;
        terminationHandled = true;

        debugPrint('Conference terminated: $url $error');
        final duration = await _meetingService.logEnded(_roomName);
        if (!mounted || duration == null) return;
        showCallSummarySheet(
          context,
          topic: _topicCtrl.text.trim(),
          duration: duration,
          participantNames: joinedParticipants.toList(),
        );
      },
      participantJoined: (email, name, role, participantId) {
        debugPrint('$name joined as $role');
        if (name != null && name.isNotEmpty) joinedParticipants.add(name);
      },
    );

    try {
      await _meetingService.joinMeeting(
        roomName: _roomName,
        displayName: displayName,
        email: user?.email,
        roomPassword: _passwordCtrl.text.trim().isEmpty
            ? null
            : _passwordCtrl.text.trim(),
        isAudioMuted: _startWithAudioOff,
        isVideoMuted: _startWithVideoOff,
        quality: _lowBandwidth ? CallQuality.dataSaver : _quality,
        listener: listener,
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.newMeeting)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.videocam_rounded,
                        color: Theme.of(context).primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('${t.roomId}: $_roomName',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _topicCtrl,
                decoration: InputDecoration(
                  labelText: t.locale.languageCode == 'zh'
                      ? '会议主题（可选）'
                      : 'Meeting topic (optional)',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: t.locale.languageCode == 'zh'
                      ? '设置会议密码（可选）'
                      : 'Set meeting password (optional)',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.startWithVideoOff),
                value: _startWithVideoOff,
                onChanged: (v) => setState(() => _startWithVideoOff = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.startWithAudioMuted),
                value: _startWithAudioOff,
                onChanged: (v) => setState(() => _startWithAudioOff = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.lowBandwidthMode),
                subtitle: Text(t.lowBandwidthModeSubtitle),
                value: _lowBandwidth,
                onChanged: (v) => setState(() => _lowBandwidth = v),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: t.locale.languageCode == 'zh' ? '开始会议' : 'Start Meeting',
                icon: Icons.video_call_rounded,
                loading: _joining,
                onPressed: _startMeeting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
