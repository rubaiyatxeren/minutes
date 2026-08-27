/// Lifecycle of a 1:1 chat. Group chats are always [accepted] — the
/// request flow only applies to direct messages between two people who
/// haven't talked before (see ChatService.getOrCreateDirectChat).
class ChatStatus {
  static const accepted = 'accepted';
  static const pending = 'pending';
}

class ChatModel {
  final String id;
  final String title; // group name, or (legacy) creator's label for 1:1
  final bool isGroup;
  final List<String> participantIds;
  final Map<String, String> participantNames; // uid -> display name
  final Map<String, String?> participantPhotos; // uid -> photo url
  final String? groupPhotoUrl;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastMessageSenderId;
  final Map<String, int> unreadCount; // per-user unread count
  final List<String> pinnedMessageIds;
  final String createdBy;

  /// 'accepted' | 'pending'. Missing on old docs -> treated as 'accepted'
  /// so existing conversations aren't retroactively turned into requests.
  final String status;

  /// Who started this direct chat — i.e. whose message request it is.
  /// Empty for groups and for chats created before this field existed.
  final String requestedBy;

  /// Uids who muted this chat's notifications.
  final List<String> mutedBy;

  /// Uids who pinned this chat to the top of their own chat list. Purely
  /// per-user — pinning is a personal organization choice, not something
  /// that should move the chat for everyone else too.
  final List<String> pinnedBy;

  ChatModel({
    required this.id,
    required this.title,
    required this.isGroup,
    required this.participantIds,
    this.participantNames = const {},
    this.participantPhotos = const {},
    this.groupPhotoUrl,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastMessageSenderId,
    this.unreadCount = const {},
    this.pinnedMessageIds = const [],
    required this.createdBy,
    this.status = ChatStatus.accepted,
    this.requestedBy = '',
    this.mutedBy = const [],
    this.pinnedBy = const [],
  });

  /// The uid of "the other person" in a 1:1 chat, or '' if not found/group.
  String otherUidFor(String myUid) => isGroup
      ? ''
      : participantIds.firstWhere((id) => id != myUid, orElse: () => '');

  /// Chat title as it should appear for [myUid]. For groups this is just
  /// [title]; for direct chats it resolves to the *other* participant's
  /// current name so both people never see their own name in the list.
  String titleFor(String myUid) {
    if (isGroup) return title;
    final otherId = otherUidFor(myUid);
    return participantNames[otherId] ?? title;
  }

  /// Avatar photo URL as it should appear for [myUid].
  String? photoFor(String myUid) {
    if (isGroup) return groupPhotoUrl;
    final otherId = otherUidFor(myUid);
    return participantPhotos[otherId];
  }

  bool get isPending => !isGroup && status == ChatStatus.pending;

  /// True if [myUid] is the one who needs to act (accept/decline) — i.e.
  /// someone else sent *them* a message request.
  bool isRequestFor(String myUid) => isPending && requestedBy != myUid;

  /// True if [myUid] is the one waiting on their own outgoing request.
  bool isRequestSentBy(String myUid) => isPending && requestedBy == myUid;

  bool isMutedFor(String myUid) => mutedBy.contains(myUid);

  bool isPinnedFor(String myUid) => pinnedBy.contains(myUid);

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    return ChatModel(
      id: id,
      title: map['title'] ?? '',
      isGroup: map['isGroup'] ?? false,
      participantIds: List<String>.from(map['participantIds'] ?? []),
      participantNames:
          Map<String, String>.from(map['participantNames'] ?? {}),
      participantPhotos:
          Map<String, String?>.from(map['participantPhotos'] ?? {}),
      groupPhotoUrl: map['groupPhotoUrl'],
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: map['lastMessageTime'] != null
          ? DateTime.tryParse(map['lastMessageTime'].toString()) ??
              DateTime.now()
          : DateTime.now(),
      lastMessageSenderId: map['lastMessageSenderId'] ?? '',
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
      pinnedMessageIds: List<String>.from(map['pinnedMessageIds'] ?? []),
      createdBy: map['createdBy'] ?? '',
      status: map['status'] ?? ChatStatus.accepted,
      requestedBy: map['requestedBy'] ?? '',
      mutedBy: List<String>.from(map['mutedBy'] ?? []),
      pinnedBy: List<String>.from(map['pinnedBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'isGroup': isGroup,
      'participantIds': participantIds,
      'participantNames': participantNames,
      'participantPhotos': participantPhotos,
      'groupPhotoUrl': groupPhotoUrl,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': unreadCount,
      'pinnedMessageIds': pinnedMessageIds,
      'createdBy': createdBy,
      'status': status,
      'requestedBy': requestedBy,
      'mutedBy': mutedBy,
      'pinnedBy': pinnedBy,
    };
  }

  ChatModel copyWith({
    String? title,
    Map<String, String>? participantNames,
    Map<String, String?>? participantPhotos,
    String? groupPhotoUrl,
    String? status,
    List<String>? mutedBy,
    List<String>? pinnedBy,
  }) {
    return ChatModel(
      id: id,
      title: title ?? this.title,
      isGroup: isGroup,
      participantIds: participantIds,
      participantNames: participantNames ?? this.participantNames,
      participantPhotos: participantPhotos ?? this.participantPhotos,
      groupPhotoUrl: groupPhotoUrl ?? this.groupPhotoUrl,
      lastMessage: lastMessage,
      lastMessageTime: lastMessageTime,
      lastMessageSenderId: lastMessageSenderId,
      unreadCount: unreadCount,
      pinnedMessageIds: pinnedMessageIds,
      createdBy: createdBy,
      status: status ?? this.status,
      requestedBy: requestedBy,
      mutedBy: mutedBy ?? this.mutedBy,
      pinnedBy: pinnedBy ?? this.pinnedBy,
    );
  }
}
