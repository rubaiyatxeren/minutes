import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/services/call_preferences.dart';
import '../../models/meeting_model.dart';
import '../../models/notification_model.dart';
import '../notifications/notification_service.dart';

class MeetingService {
  final JitsiMeet _jitsiMeet = JitsiMeet();
  final _db = FirebaseFirestore.instance;
  final _notificationService = NotificationService();

  // Primary public server (or replace with your self-hosted Jitsi instance)
  static const String serverUrl = 'https://meet.element.io';

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _meetings =>
      _db.collection('meetings');

  Future<void> joinMeeting({
    required String roomName,
    required String displayName,
    String? email,
    String? avatarUrl,
    String? roomPassword,
    bool isAudioMuted = false,
    bool isVideoMuted = false,
    bool isAnonymous = false,
    // Kept for backwards compatibility with any older call sites — maps
    // straight to CallQuality.dataSaver when true and is overridden by
    // [quality] if both are supplied.
    bool lowBandwidthMode = false,
    CallQuality quality = CallQuality.auto,
    JitsiMeetEventListener? listener,
  }) async {
    final effectiveQuality =
        lowBandwidthMode && quality == CallQuality.auto
            ? CallQuality.dataSaver
            : quality;

    // 1. Sanitize room name (remove spaces/special characters to prevent 404 URL errors)
    final String sanitizedRoom = roomName.replaceAll(RegExp(r'[^\w\=-]'), '');

    final options = JitsiMeetConferenceOptions(
      serverURL: serverUrl,
      room: sanitizedRoom,
      token: null,
      configOverrides: {
        'toolbarButtons': [],
        'startWithAudioMuted': isAudioMuted,
        'startWithVideoMuted': isVideoMuted,
        'subject': roomName,
        'enableWelcomePage': false,
        'prejoinPageEnabled': false, // Disables the native pre-join screen to jump straight in
        'requireDisplayName': true,
        'disableInviteFunctions': false,
        'enableLobbyChat': false,

        // "Set Meeting Password" was previously a dead feature — the host
        // could type a password in create_meeting_screen.dart and it was
        // collected all the way down to this method, then silently
        // dropped. This actually applies it to the room's config, which
        // is what the mobile SDK reads when a moderator sets/enforces a
        // conference password.
        if (roomPassword != null && roomPassword.isNotEmpty)
          'password': roomPassword,

        // ---- Performance / latency tuning ----------------------------
        // Suspends the video decode/encode pipeline for tiles that aren't
        // currently visible (e.g. off-screen thumbnails in a big grid)
        // instead of decoding every stream all the time. Cuts CPU/battery
        // and, indirectly, jank/lag in group calls with several
        // participants. Real Jitsi config flag, safe on/off for any tier.
        'enableLayerSuspension': true,

        ...switch (effectiveQuality) {
          // Auto: don't fight WebRTC's own bandwidth estimation. Simulcast
          // stays on (default — not disabled here) so every viewer gets
          // whichever resolution layer their own connection can sustain,
          // and no resolution/channel cap is imposed. This is the
          // combination that in practice tracks closest to "no lag" across
          // a mix of connection speeds, because the weakest participant no
          // longer determines everyone else's video quality.
          CallQuality.auto => const {},

          // High: prioritize visual quality on connections known to be
          // good; still leaves simulcast on so this device doesn't force
          // a high bitrate onto participants who can't sustain it.
          CallQuality.high => const {
              'resolution': 720,
              'constraints': {
                'video': {
                  'height': {'ideal': 720, 'max': 720, 'min': 240},
                },
              },
            },

          // Data saver (same mechanism the old "Low bandwidth mode" toggle
          // used): hard-cap resolution, drop simulcast layers, limit how
          // many participants' video is even received, and route through
          // the JVB instead of P2P so the bandwidth cap is actually
          // enforced consistently for everyone.
          CallQuality.dataSaver => const {
              'channelLastN': 4,
              'resolution': 180,
              'disableSimulcast': true,
              'p2p': {'enabled': false},
              'constraints': {
                'video': {
                  'height': {'ideal': 180, 'max': 180, 'min': 120},
                },
              },
            },
        },
      },
      featureFlags: {
        'chat.enabled': true,
        'polls.enabled': true, 
        'reactions.enabled': true, 
        'invite.enabled': true,
        'raise-hand.enabled': true,
        'meeting-password.enabled': true,
        'live-streaming.enabled': false, 
        'recording.enabled': false,      
        'screen-sharing.enabled': true,
        'pip.enabled': true,
        'toolbox.alwaysVisible': true,
        'add-people.enabled': true,
        'calendar.enabled': true,
        'call-integration.enabled': false, // Set to false to avoid native Android ConnectionService crashes
        'close-captions.enabled': true,
        'filmstrip.enabled': true,
        'kick-out.enabled': true,
        'lobby-mode.enabled': false,       
        'security-options.enabled': false, 
      },

      userInfo: JitsiMeetUserInfo(
        displayName: isAnonymous ? '$displayName (Guest)' : displayName,
        email: email,
        avatar: avatarUrl,
      ),
    );

    await _jitsiMeet.join(options, listener);
  }

  Future<void> hangUp() => _jitsiMeet.hangUp();

  Future<void> setAudioMuted(bool muted) => _jitsiMeet.setAudioMuted(muted);

  Future<void> setVideoMuted(bool muted) => _jitsiMeet.setVideoMuted(muted);

  // ---- Meeting history -----------------------------------------------
  //
  // The room name doubles as the Firestore doc id: everyone who joins the
  // same Jitsi room therefore reads/writes the same history entry, so a
  // group call shows up once in history (with everyone listed as a
  // participant) rather than once per person who joined.

  /// Call right after `joinMeeting` succeeds (i.e. in `conferenceJoined`).
  /// Creates the history doc on first join, or just adds the caller as a
  /// participant if someone else already started it.
  Future<void> logJoined({
    required String roomName,
    required String displayName,
    String? topic,
    String? chatId,
    bool isGroupCall = false,
  }) async {
    if (_uid.isEmpty) return;
    final ref = _meetings.doc(roomName);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {
          'roomName': roomName,
          'topic': topic ?? '',
          'hostId': _uid,
          'hostName': displayName,
          'chatId': chatId,
          'isGroupCall': isGroupCall,
          'participantIds': [_uid],
          'participantNames': {_uid: displayName},
          'startedAt': DateTime.now().toIso8601String(),
          'endedAt': null,
          'durationSeconds': null,
          'status': 'ongoing',
        });
      } else {
        tx.update(ref, {
          'participantIds': FieldValue.arrayUnion([_uid]),
          'participantNames.$_uid': displayName,
          'isGroupCall': true, // a second joiner makes it a group call
          'status': 'ongoing',
        });
      }
    });
  }

  /// Call from `conferenceTerminated`. Only actually closes out the history
  /// entry (sets `endedAt`/duration) — it never deletes it, so the call
  /// still appears in history even if Firestore write races with app exit.
  /// Returns the final duration for a "call ended" summary, or null if the
  /// meeting was never logged (e.g. offline).
  ///
  /// Marking `status: 'ended'` here is also what everyone else's UI relies
  /// on to know the room is dead: the "Join Call" chat bubble listens to
  /// [meetingDocStream] and flips itself to a disabled "Call ended" state
  /// the instant this write lands, and [getMeetingStatus] is checked by
  /// [ChatService]-side joiners before they ever try to open Jitsi, so
  /// nobody can walk into a room that's already been torn down.
  Future<Duration?> logEnded(String roomName) async {
    if (_uid.isEmpty) return null;
    final ref = _meetings.doc(roomName);
    try {
      final snap = await ref.get();
      if (!snap.exists) return null;
      final data = snap.data()!;
      // Already closed out by someone else (e.g. another participant's
      // conferenceTerminated fired first) — don't double-write/notify.
      if (data['status'] == 'ended') {
        final durationSeconds = data['durationSeconds'];
        return durationSeconds != null
            ? Duration(seconds: durationSeconds as int)
            : null;
      }
      final startedAt =
          DateTime.tryParse(data['startedAt']?.toString() ?? '') ??
              DateTime.now();
      final duration = DateTime.now().difference(startedAt);
      await ref.update({
        'endedAt': DateTime.now().toIso8601String(),
        'durationSeconds': duration.inSeconds,
        'status': 'ended',
      });

      // Let anyone who was invited but never joined know the room is gone,
      // so a stale "Join Call" bubble doesn't sit there looking live.
      final participantIds = List<String>.from(data['participantIds'] ?? []);
      final hostName = data['hostName']?.toString() ?? 'Someone';
      if (participantIds.isNotEmpty) {
        await _notificationService.notifyMany(
          recipientUids: participantIds,
          type: NotificationType.meetingEnded,
          title: AppLocalizations.tGlobal('callEndedShort'),
          body: AppLocalizations.hostCallEndedGlobal(hostName),
          chatId: data['chatId'],
          meetingId: roomName,
        );
      }

      return duration;
    } catch (_) {
      return null;
    }
  }

  /// One-shot status check — call this right before opening Jitsi (e.g.
  /// tapping "Join Call" on an old chat bubble) so a room that was already
  /// terminated never gets re-opened as a blank/dead call.
  /// Returns null if the room was never logged at all (e.g. a brand-new
  /// room about to be created, or one started outside the app).
  Future<MeetingStatus?> getMeetingStatus(String roomName) async {
    try {
      final snap = await _meetings.doc(roomName).get();
      if (!snap.exists) return null;
      return MeetingModel.fromMap(snap.data()!, snap.id).status;
    } catch (_) {
      return null;
    }
  }

  /// Live status stream for a single room — drives the "Join Call" chat
  /// bubble so it automatically flips to a disabled "Call ended" state for
  /// every participant the moment the host (or last person) hangs up,
  /// without anyone needing to reopen the chat.
  Stream<MeetingModel?> meetingDocStream(String roomName) {
    return _meetings.doc(roomName).snapshots().map(
          (snap) => snap.exists ? MeetingModel.fromMap(snap.data()!, snap.id) : null,
        );
  }

  /// Live "call history" list for the current user, most recent first.
  /// Sorted client-side (same reasoning as ChatService.myChats) so it works
  /// without needing a composite Firestore index set up in the console.
  Stream<List<MeetingModel>> myMeetingHistory() {
    return _meetings
        .where('participantIds', arrayContains: _uid)
        .snapshots()
        .map((snap) {
      final meetings =
          snap.docs.map((d) => MeetingModel.fromMap(d.data(), d.id)).toList();
      meetings.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return meetings;
    });
  }
}
