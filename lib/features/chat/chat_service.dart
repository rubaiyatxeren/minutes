import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../models/chat_model.dart';
import '../../models/message_model.dart';
import '../../models/notification_model.dart';
import '../notifications/notification_service.dart';

/// All chat/message reads & writes go through here. Firestore was chosen
/// because it needs zero backend code, has generous free-tier limits,
/// and gives realtime listeners out of the box (`snapshots()`).
class ChatService {
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();
  final _notifications = NotificationService();

  /// How long a "typing" flag is considered fresh. Cleared client-side by
  /// [typingUsers] rather than relying on the sender's app to always send
  /// an explicit "stopped typing" (e.g. if it crashes or loses signal).
  static const _typingTtl = Duration(seconds: 6);

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _chats.doc(chatId).collection('messages');

  DocumentReference<Map<String, dynamic>> get _myUserDoc =>
      _db.collection('users').doc(_uid);

  /// Live list of chats the current user participates in, newest first.
  /// Excludes incoming message requests the user hasn't accepted yet —
  /// those live in [myChatRequests] instead, so a stranger's opening
  /// message can't just land in the main inbox unfiltered.
  ///
  /// IMPORTANT: this deliberately does NOT chain `.orderBy()` onto the
  /// `.where('participantIds', arrayContains: ...)` query. Combining an
  /// array-contains filter with an orderBy on a different field requires a
  /// Firestore *composite index* — until that index is created in the
  /// Firebase console, the query throws `failed-precondition` and the
  /// stream silently produces no data, which is exactly why the chat list
  /// looked stuck on the "start a chat" empty state even after chats were
  /// created. Sorting client-side avoids that dependency entirely.
  Stream<List<ChatModel>> myChats() {
    return _chats
        .where('participantIds', arrayContains: _uid)
        .snapshots()
        .map((snap) {
      final chats = snap.docs
          .map((d) => ChatModel.fromMap(d.data(), d.id))
          .where((c) => !c.isRequestFor(_uid))
          .toList();
      // Pinned chats float to the top; everything else stays newest-first.
      chats.sort((a, b) {
        final aPinned = a.isPinnedFor(_uid) ? 1 : 0;
        final bPinned = b.isPinnedFor(_uid) ? 1 : 0;
        if (aPinned != bPinned) return bPinned - aPinned;
        return b.lastMessageTime.compareTo(a.lastMessageTime);
      });
      return chats;
    });
  }

  /// Live list of pending message requests sent *to* the current user —
  /// direct chats a stranger started that haven't been accepted yet.
  Stream<List<ChatModel>> myChatRequests() {
    return _chats
        .where('participantIds', arrayContains: _uid)
        .where('status', isEqualTo: ChatStatus.pending)
        .snapshots()
        .map((snap) {
      final requests = snap.docs
          .map((d) => ChatModel.fromMap(d.data(), d.id))
          .where((c) => c.isRequestFor(_uid))
          .toList();
      requests.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return requests;
    });
  }

  /// Cheap badge count for [myChatRequests] — same filtering, just a length.
  Stream<int> pendingRequestCount() =>
      myChatRequests().map((list) => list.length);

  Stream<List<MessageModel>> messagesFor(String chatId) {
    return _messages(chatId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => MessageModel.fromMap(d.data(), d.id)).toList());
  }

  /// Creates (or reuses) a 1:1 chat between the current user and [otherUid].
  /// Stores both participants' current name/photo so each side can resolve
  /// the *other* person's name as the chat title (see [ChatModel.titleFor]).
  ///
  /// Brand new chats are created with `status: pending` — like a message
  /// request on Instagram/Messenger, the recipient has to accept before
  /// it's a normal two-way conversation in their main inbox (see
  /// [myChats] / [myChatRequests] / [respondToRequest]). Reusing an
  /// existing chat just returns it as-is, whatever state it's already in.
  Future<String> getOrCreateDirectChat(
    String otherUid,
    String otherName, {
    String? otherPhotoUrl,
  }) async {
    if (otherUid == _uid) {
      throw StateError("You can't start a chat with yourself");
    }

    final myUserSnap = await _myUserDoc.get();
    final myBlocked =
        List<String>.from(myUserSnap.data()?['blockedUids'] ?? []);
    if (myBlocked.contains(otherUid)) {
      throw StateError('You have blocked this person. Unblock them first.');
    }
    final otherUserSnap =
        await _db.collection('users').doc(otherUid).get();
    final theirBlocked =
        List<String>.from(otherUserSnap.data()?['blockedUids'] ?? []);
    if (theirBlocked.contains(_uid)) {
      throw StateError("You can't message this person right now.");
    }

    final existing = await _chats
        .where('isGroup', isEqualTo: false)
        .where('participantIds', arrayContains: _uid)
        .get();

    for (final doc in existing.docs) {
      final ids = List<String>.from(doc.data()['participantIds'] ?? []);
      if (ids.contains(otherUid) && ids.length == 2) return doc.id;
    }

    final me = FirebaseAuth.instance.currentUser;
    final myName =
        (me?.displayName?.isNotEmpty ?? false) ? me!.displayName! : 'Me';

    final chat = ChatModel(
      id: '',
      title: otherName,
      isGroup: false,
      participantIds: [_uid, otherUid],
      participantNames: {_uid: myName, otherUid: otherName},
      participantPhotos: {_uid: me?.photoURL, otherUid: otherPhotoUrl},
      lastMessage: '',
      lastMessageTime: DateTime.now(),
      lastMessageSenderId: '',
      createdBy: _uid,
      status: ChatStatus.pending,
      requestedBy: _uid,
    );
    final ref = await _chats.add(chat.toMap());
    return ref.id;
  }

  /// Fetches a single chat once (not a stream) — used right after creating
  /// or reusing a chat so the caller knows its *real* status (pending vs.
  /// already-accepted) instead of guessing.
  Future<ChatModel> getChat(String chatId) async {
    final doc = await _chats.doc(chatId).get();
    return ChatModel.fromMap(doc.data() ?? {}, doc.id);
  }

  Future<String> createGroupChat({
    required String title,
    required List<String> participantIds,
    Map<String, String> participantNames = const {},
    Map<String, String?> participantPhotos = const {},
    // Callers pass the localized "Group created" string (via
    // AppLocalizations, which needs a BuildContext this service doesn't
    // have) so the initial chat-list preview respects the user's chosen
    // language instead of always showing English.
    String lastMessageText = 'Group created',
  }) async {
    // Defensive filter: even if a caller accidentally includes the
    // current user's own uid in the selected list, it never gets added
    // twice — {..., _uid} below is a Set so this is really belt-and-
    // suspenders, but it also means a self-uid can never sneak in via a
    // typo'd id since it's filtered before the Set union.
    final others = participantIds.where((id) => id != _uid);
    final all = {...others, _uid}.toList();
    final me = FirebaseAuth.instance.currentUser;
    final myName =
        (me?.displayName?.isNotEmpty ?? false) ? me!.displayName! : 'Me';

    final chat = ChatModel(
      id: '',
      title: title,
      isGroup: true,
      participantIds: all,
      participantNames: {...participantNames, _uid: myName},
      participantPhotos: {...participantPhotos, _uid: me?.photoURL},
      lastMessage: lastMessageText,
      lastMessageTime: DateTime.now(),
      lastMessageSenderId: _uid,
      createdBy: _uid,
    );
    final ref = await _chats.add(chat.toMap());

    // Notify everyone who was added at creation time — same as being
    // added to an existing group (see addParticipantsToGroup below), so
    // "you were added to a group" behaves consistently whether the group
    // is brand new or already existed.
    await _notifications.notifyMany(
      recipientUids: all,
      type: NotificationType.groupAdded,
      title: title,
      body: '$myName added you to "$title"',
      chatId: ref.id,
      senderId: _uid,
      senderName: myName,
      senderPhotoUrl: me?.photoURL,
    );

    return ref.id;
  }

  Future<void> sendMessage({
    required String chatId,
    required String text,
    MessageType type = MessageType.text,
    String? mediaUrl,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSender,
    required String senderName,
    String? senderPhotoUrl,
  }) async {
    final chatSnapBefore = await _chats.doc(chatId).get();
    final status =
        chatSnapBefore.data()?['status'] as String? ?? ChatStatus.accepted;
    final requestedBy = chatSnapBefore.data()?['requestedBy'] as String? ?? '';
    // A pending request's non-requester can't reply until they accept —
    // the UI already hides the composer for them, this is just a
    // defensive backstop.
    if (status == ChatStatus.pending && requestedBy.isNotEmpty && requestedBy != _uid) {
      throw StateError('Accept this message request before replying.');
    }

    final message = MessageModel(
      id: '',
      chatId: chatId,
      senderId: _uid,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      text: text,
      type: type,
      mediaUrl: mediaUrl,
      timestamp: DateTime.now(),
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
      replyToSender: replyToSender,
    );
    await _messages(chatId).add(message.toMap());

    final preview = type == MessageType.text ? text : _previewFor(type);
    final chatDoc = await _chats.doc(chatId).get();
    final chatData = chatDoc.data() ?? {};
    final participantIds = List<String>.from(chatData['participantIds'] ?? []);
    final mutedBy = List<String>.from(chatData['mutedBy'] ?? []);

    final updates = <String, dynamic>{
      'lastMessage': preview,
      'lastMessageTime': DateTime.now().toIso8601String(),
      'lastMessageSenderId': _uid,
    };
    // Bump unread count for everyone except the sender, and clear our own
    // typing flag now that the message actually landed.
    for (final id in participantIds) {
      if (id != _uid) {
        updates['unreadCount.$id'] = FieldValue.increment(1);
      }
    }
    updates['typingAt.$_uid'] = FieldValue.delete();
    await _chats.doc(chatId).update(updates);

    // Realtime in-app notification for everyone else in the chat, skipping
    // anyone who's muted this specific chat. A first message on a still-
    // pending request gets its own notification type so it's clearly
    // flagged as "someone new wants to chat" rather than a regular message.
    final chatTitle = (chatData['isGroup'] == true)
        ? (chatData['title'] as String? ?? senderName)
        : senderName;
    final isFirstRequestMessage =
        status == ChatStatus.pending && requestedBy == _uid;
    final notifyTargets =
        participantIds.where((id) => !mutedBy.contains(id)).toList();
    await _notifications.notifyMany(
      recipientUids: notifyTargets,
      type: isFirstRequestMessage
          ? NotificationType.messageRequest
          : NotificationType.message,
      title: chatTitle,
      senderName: senderName,
      body: isFirstRequestMessage
          ? '$senderName sent you a message request'
          : (preview.isEmpty ? '$senderName sent a message' : preview),
      chatId: chatId,
      senderId: _uid,
      senderPhotoUrl: senderPhotoUrl,
    );
  }

  String _previewFor(MessageType type) {
    switch (type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.audio:
        return '🎤 Audio';
      case MessageType.gif:
        return 'GIF';
      case MessageType.file:
        return '📎 File';
      case MessageType.callInvite:
        return '📹 Video call';
      case MessageType.text:
        return '';
    }
  }

  /// Resets the unread counter for the current user — call when a chat is
  /// opened so its badge clears.
  Future<void> markAsRead(String chatId) {
    return _chats.doc(chatId).update({'unreadCount.$_uid': 0});
  }

  /// Removes the current user from a chat's participant list. For 1:1 chats
  /// this hides the conversation from their list (the other person keeps
  /// their copy); for groups it's a "leave group".
  Future<void> leaveChat(String chatId) {
    return _chats.doc(chatId).update({
      'participantIds': FieldValue.arrayRemove([_uid]),
      'unreadCount.$_uid': FieldValue.delete(),
    });
  }

  // ---- Message requests ---------------------------------------------------

  /// Accepts or declines an incoming message request. Accepting flips the
  /// chat to a normal conversation and lets the requester know; declining
  /// deletes the chat and everything sent in it — same as never having
  /// replied, so a stranger's opening message can't linger once refused.
  Future<void> respondToRequest(String chatId, {required bool accept}) async {
    if (!accept) {
      await _deleteChatEntirely(chatId);
      return;
    }

    await _chats.doc(chatId).update({'status': ChatStatus.accepted});

    final chatDoc = await _chats.doc(chatId).get();
    final requesterId = chatDoc.data()?['requestedBy'] as String? ?? '';
    if (requesterId.isEmpty || requesterId == _uid) return;

    final me = FirebaseAuth.instance.currentUser;
    final myName =
        (me?.displayName?.isNotEmpty ?? false) ? me!.displayName! : 'Someone';
    await _notifications.notify(
      recipientUid: requesterId,
      type: NotificationType.requestAccepted,
      title: myName,
      body: '$myName accepted your message request',
      chatId: chatId,
      senderId: _uid,
      senderName: myName,
      senderPhotoUrl: me?.photoURL,
    );
  }

  /// Declines a request and blocks the sender in one step — the common
  /// "not interested, and don't let them try again" action.
  Future<void> declineAndBlock(String chatId, String otherUid) async {
    await _deleteChatEntirely(chatId);
    await blockUser(otherUid);
  }

  Future<void> _deleteChatEntirely(String chatId) async {
    final messages = await _messages(chatId).get();
    final batch = _db.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_chats.doc(chatId));
    await batch.commit();
  }

  // ---- Blocking -------------------------------------------------------------

  Future<void> blockUser(String otherUid) {
    return _myUserDoc.update({
      'blockedUids': FieldValue.arrayUnion([otherUid]),
    });
  }

  Future<void> unblockUser(String otherUid) {
    return _myUserDoc.update({
      'blockedUids': FieldValue.arrayRemove([otherUid]),
    });
  }

  Stream<List<String>> blockedUids() {
    return _myUserDoc.snapshots().map(
          (snap) => List<String>.from(snap.data()?['blockedUids'] ?? []),
        );
  }

  // ---- Muting ---------------------------------------------------------------

  /// Mutes/unmutes notifications for a chat. Muted chats still update the
  /// unread badge — this only silences the push/in-app ping (see the
  /// `mutedBy` check in [sendMessage]).
  Future<void> setMuted(String chatId, bool muted) {
    return _chats.doc(chatId).update({
      'mutedBy': muted
          ? FieldValue.arrayUnion([_uid])
          : FieldValue.arrayRemove([_uid]),
    });
  }

  // ---- Pinning ----------------------------------------------------------

  /// Pins/unpins a chat to the top of the current user's own chat list.
  /// Purely per-user — pinning never affects what other participants see.
  Future<void> setPinned(String chatId, bool pinned) {
    return _chats.doc(chatId).update({
      'pinnedBy': pinned
          ? FieldValue.arrayUnion([_uid])
          : FieldValue.arrayRemove([_uid]),
    });
  }

  Future<void> editMessage(String chatId, String messageId, String newText) {
    return _messages(chatId).doc(messageId).update({
      'text': newText,
      'isEdited': true,
    });
  }

  Future<void> deleteMessage(String chatId, String messageId) {
    return _messages(chatId).doc(messageId).update({
      'isDeleted': true,
      'text': '',
    });
  }

  Future<void> togglePin(String chatId, String messageId, bool pin) async {
    await _messages(chatId).doc(messageId).update({'isPinned': pin});
    final chatRef = _chats.doc(chatId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(chatRef);
      final pinned = List<String>.from(snap.data()?['pinnedMessageIds'] ?? []);
      if (pin && !pinned.contains(messageId)) {
        pinned.add(messageId);
      } else if (!pin) {
        pinned.remove(messageId);
      }
      tx.update(chatRef, {'pinnedMessageIds': pinned});
    });
  }

  Future<void> toggleReaction(
      String chatId, String messageId, String emoji) async {
    final ref = _messages(chatId).doc(messageId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final reactions =
          Map<String, String>.from(snap.data()?['reactions'] ?? {});
      if (reactions[_uid] == emoji) {
        reactions.remove(_uid); // tapping same emoji again removes it
      } else {
        reactions[_uid] = emoji;
      }
      tx.update(ref, {'reactions': reactions});
    });
  }

  String newMeetingRoomId() => 'room-${_uuid.v4().substring(0, 8)}';

  // ---- Chat info / participant management --------------------------------

  /// Live view of a single chat doc — used by ChatInfoScreen so an added
  /// or removed participant shows up instantly without leaving the screen.
  Stream<ChatModel> chatStream(String chatId) {
    return _chats
        .doc(chatId)
        .snapshots()
        .map((d) => ChatModel.fromMap(d.data() ?? {}, d.id));
  }

  /// Adds new members to a group. [newIds] is defensively filtered so the
  /// current user can never add themselves (they're already a participant
  /// by definition) and so anyone already in the group is skipped rather
  /// than double-added.
  Future<void> addParticipantsToGroup({
    required String chatId,
    required List<String> newIds,
    required Map<String, String> newNames,
    required Map<String, String?> newPhotos,
    required List<String> currentParticipantIds,
    String? groupTitle,
  }) async {
    final toAdd = newIds
        .where((id) => id != _uid && !currentParticipantIds.contains(id))
        .toList();
    if (toAdd.isEmpty) return;

    final updates = <String, dynamic>{
      'participantIds': FieldValue.arrayUnion(toAdd),
    };
    for (final id in toAdd) {
      updates['participantNames.$id'] = newNames[id] ?? '';
      updates['participantPhotos.$id'] = newPhotos[id];
    }
    await _chats.doc(chatId).update(updates);

    // This was previously silent — NotificationType.groupAdded existed in
    // the model and was already handled by the notifications screen's UI,
    // but nothing ever actually created one. Now the people just added
    // get a real notification, same as a call invite or a new message
    // would show up.
    final me = FirebaseAuth.instance.currentUser;
    final myName =
        (me?.displayName?.isNotEmpty ?? false) ? me!.displayName! : 'Someone';
    String title = groupTitle ?? '';
    if (title.isEmpty) {
      final chatDoc = await _chats.doc(chatId).get();
      title = chatDoc.data()?['title'] as String? ?? 'a group';
    }
    await _notifications.notifyMany(
      recipientUids: toAdd,
      type: NotificationType.groupAdded,
      title: title,
      body: '$myName added you to "$title"',
      chatId: chatId,
      senderId: _uid,
      senderName: myName,
      senderPhotoUrl: me?.photoURL,
    );
  }

  /// Removes a member from a group. Only meaningful for group chats — the
  /// UI only exposes this to the chat's creator, but it's enforced again
  /// here defensively (a member can never remove themselves this way;
  /// they should use [leaveChat] instead).
  Future<void> removeParticipant(String chatId, String uidToRemove) {
    if (uidToRemove == _uid) {
      throw StateError('Use leaveChat() to remove yourself');
    }
    return _chats.doc(chatId).update({
      'participantIds': FieldValue.arrayRemove([uidToRemove]),
    });
  }

  /// Only the group's creator can change the group photo — this is the
  /// only mutation here, so it's the only one worth guarding this
  /// explicitly (add/remove members already gate on `createdBy` too, in
  /// GroupParticipantsScreen).
  Future<void> updateGroupPhoto(String chatId, String photoUrl) {
    return _chats.doc(chatId).update({'groupPhotoUrl': photoUrl});
  }

  // ---- Typing indicators -------------------------------------------------
  //
  // Stored as a small map (`typingAt`) directly on the chat doc rather than
  // a subcollection, since it's tiny, always read alongside the chat, and
  // this way a single `chats/{id}` snapshot listener covers it. Each entry
  // is a timestamp, not a bool, so a stale flag (app killed mid-type)
  // silently expires instead of leaving "X is typing…" stuck forever.

  /// Call on every keystroke (already debounced by the UI). Setting
  /// [isTyping] to false removes the flag immediately (e.g. on send).
  Future<void> setTyping(String chatId, bool isTyping) {
    if (_uid.isEmpty) return Future.value();
    if (isTyping) {
      return _chats.doc(chatId).update({
        'typingAt.$_uid': DateTime.now().toIso8601String(),
      });
    }
    return _chats.doc(chatId).update({'typingAt.$_uid': FieldValue.delete()});
  }

  /// Live list of *other* participants currently typing in [chatId].
  Stream<List<String>> typingUsers(String chatId) {
    return _chats.doc(chatId).snapshots().map((snap) {
      final map = Map<String, dynamic>.from(snap.data()?['typingAt'] ?? {});
      final now = DateTime.now();
      final typing = <String>[];
      map.forEach((uid, value) {
        if (uid == _uid) return;
        final ts = DateTime.tryParse(value.toString());
        if (ts != null && now.difference(ts) < _typingTtl) {
          typing.add(uid);
        }
      });
      return typing;
    });
  }
}
