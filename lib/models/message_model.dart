enum MessageType { text, image, video, audio, file, gif, callInvite }

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String text;
  final MessageType type;
  final String? mediaUrl;
  final DateTime timestamp;
  final bool isEdited;
  final bool isDeleted;
  final bool isPinned;
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSender;
  final Map<String, String> reactions; // userId -> emoji

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.text,
    this.type = MessageType.text,
    this.mediaUrl,
    required this.timestamp,
    this.isEdited = false,
    this.isDeleted = false,
    this.isPinned = false,
    this.replyToMessageId,
    this.replyToText,
    this.replyToSender,
    this.reactions = const {},
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderPhotoUrl: map['senderPhotoUrl'],
      text: map['text'] ?? '',
      type: MessageType.values.firstWhere(
        (t) => t.name == (map['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      mediaUrl: map['mediaUrl'],
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isEdited: map['isEdited'] ?? false,
      isDeleted: map['isDeleted'] ?? false,
      isPinned: map['isPinned'] ?? false,
      replyToMessageId: map['replyToMessageId'],
      replyToText: map['replyToText'],
      replyToSender: map['replyToSender'],
      reactions: Map<String, String>.from(map['reactions'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'type': type.name,
      'mediaUrl': mediaUrl,
      'timestamp': timestamp.toIso8601String(),
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      'isPinned': isPinned,
      'replyToMessageId': replyToMessageId,
      'replyToText': replyToText,
      'replyToSender': replyToSender,
      'reactions': reactions,
    };
  }
}
