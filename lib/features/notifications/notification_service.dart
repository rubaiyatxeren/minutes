import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/notification_model.dart';

/// In-app realtime notifications, backed entirely by Firestore listeners —
/// no FCM/push, no Cloud Functions required. Each user has their own
/// `notifications/{uid}/items` subcollection; writers (chat/meeting
/// services) push a doc there for every *other* participant whenever
/// something notification-worthy happens, and this screen's StreamBuilder
/// picks it up instantly over the same socket already used for chat.
class NotificationService {
  final _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> _items(String uid) =>
      _db.collection('notifications').doc(uid).collection('items');

  /// Live feed for the current user, newest first. Sorted client-side for
  /// the same reason chat lists are (see ChatService.myChats) — avoids
  /// needing a composite index before the query will return data.
  Stream<List<NotificationModel>> myNotifications() {
    return _items(_uid).snapshots().map((snap) {
      final items = snap.docs
          .map((d) => NotificationModel.fromMap(d.data(), d.id))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  /// Live unread count only — cheap to keep mounted everywhere (nav badge,
  /// bell icon) without pulling full notification bodies.
  Stream<int> unreadCount() {
    return _items(_uid).where('isRead', isEqualTo: false).snapshots().map(
          (snap) => snap.docs.length,
        );
  }

  Future<void> markAsRead(String notificationId) {
    return _items(_uid).doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllAsRead() async {
    final unread =
        await _items(_uid).where('isRead', isEqualTo: false).get();
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> delete(String notificationId) {
    return _items(_uid).doc(notificationId).delete();
  }

  Future<void> clearAll() async {
    final all = await _items(_uid).get();
    final batch = _db.batch();
    for (final doc in all.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Writes a notification into [recipientUid]'s feed. Used by other
  /// services (chat, meetings) — never called for the acting user
  /// themselves, so people don't get notified about their own actions.
  Future<void> notify({
    required String recipientUid,
    required NotificationType type,
    required String title,
    required String body,
    String? chatId,
    String? meetingId,
    String? senderId,
    String? senderName,
    String? senderPhotoUrl,
  }) {
    final notification = NotificationModel(
      id: '',
      type: type,
      title: title,
      body: body,
      chatId: chatId,
      meetingId: meetingId,
      senderId: senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      createdAt: DateTime.now(),
    );
    return _items(recipientUid).add(notification.toMap()).then((_) {});
  }

  /// Fan-out helper: notify everyone in [recipientUids] except the acting
  /// user, in parallel.
  Future<void> notifyMany({
    required List<String> recipientUids,
    required NotificationType type,
    required String title,
    required String body,
    String? chatId,
    String? meetingId,
    String? senderId,
    String? senderName,
    String? senderPhotoUrl,
  }) async {
    final targets = recipientUids.where((id) => id != _uid).toSet();
    await Future.wait(targets.map((uid) => notify(
          recipientUid: uid,
          type: type,
          title: title,
          body: body,
          chatId: chatId,
          meetingId: meetingId,
          senderId: senderId,
          senderName: senderName,
          senderPhotoUrl: senderPhotoUrl,
        )));
  }
}
