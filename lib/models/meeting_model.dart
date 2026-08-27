enum MeetingStatus { ongoing, ended }

/// A logged video call — created the moment someone starts/joins a room and
/// closed out (with a duration) when the last known participant leaves.
/// Backs the "Meeting history" screen and the post-call summary.
class MeetingModel {
  final String id;
  final String roomName;
  final String topic;
  final String hostId;
  final String hostName;
  final String? chatId; // set when the call was started from inside a chat
  final bool isGroupCall;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final MeetingStatus status;

  MeetingModel({
    required this.id,
    required this.roomName,
    this.topic = '',
    required this.hostId,
    required this.hostName,
    this.chatId,
    this.isGroupCall = false,
    this.participantIds = const [],
    this.participantNames = const {},
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.status = MeetingStatus.ongoing,
  });

  Duration get duration {
    if (durationSeconds != null) return Duration(seconds: durationSeconds!);
    if (endedAt != null) return endedAt!.difference(startedAt);
    return DateTime.now().difference(startedAt);
  }

  factory MeetingModel.fromMap(Map<String, dynamic> map, String id) {
    return MeetingModel(
      id: id,
      roomName: map['roomName'] ?? '',
      topic: map['topic'] ?? '',
      hostId: map['hostId'] ?? '',
      hostName: map['hostName'] ?? '',
      chatId: map['chatId'],
      isGroupCall: map['isGroupCall'] ?? false,
      participantIds: List<String>.from(map['participantIds'] ?? []),
      participantNames:
          Map<String, String>.from(map['participantNames'] ?? {}),
      startedAt: map['startedAt'] != null
          ? DateTime.tryParse(map['startedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endedAt: map['endedAt'] != null
          ? DateTime.tryParse(map['endedAt'].toString())
          : null,
      durationSeconds: map['durationSeconds'],
      status: MeetingStatus.values.firstWhere(
        (s) => s.name == (map['status'] ?? 'ongoing'),
        orElse: () => MeetingStatus.ongoing,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomName': roomName,
      'topic': topic,
      'hostId': hostId,
      'hostName': hostName,
      'chatId': chatId,
      'isGroupCall': isGroupCall,
      'participantIds': participantIds,
      'participantNames': participantNames,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'durationSeconds': durationSeconds,
      'status': status.name,
    };
  }
}
