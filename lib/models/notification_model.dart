enum NotificationType {
  message,
  meetingInvite,
  meetingEnded,
  reaction,
  groupAdded,
  messageRequest,
  requestAccepted,
}

class NotificationModel {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String? chatId;
  final String? meetingId;
  final String? senderId;
  final String? senderName;
  final String? senderPhotoUrl;
  final DateTime createdAt;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.chatId,
    this.meetingId,
    this.senderId,
    this.senderName,
    this.senderPhotoUrl,
    required this.createdAt,
    this.isRead = false,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      type: NotificationType.values.firstWhere(
        (t) => t.name == (map['type'] ?? 'message'),
        orElse: () => NotificationType.message,
      ),
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      chatId: map['chatId'],
      meetingId: map['meetingId'],
      senderId: map['senderId'],
      senderName: map['senderName'],
      senderPhotoUrl: map['senderPhotoUrl'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'title': title,
      'body': body,
      'chatId': chatId,
      'meetingId': meetingId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }
}
