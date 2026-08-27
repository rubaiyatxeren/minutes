import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/chat_model.dart';
import '../chat/chat_screen.dart';
import '../chat/chat_service.dart';
import '../chat/new_chat_screen.dart';
import '../chat/requests_screen.dart';
import '../notifications/notification_service.dart';
import '../notifications/notifications_screen.dart';

class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  final _chatService = ChatService();
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _searching = false;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openNewChat() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NewChatScreen()),
      );

  void _showChatOptions(BuildContext context, ChatModel chat) {
    final isPinned = chat.isPinnedFor(_myUid);
    final isMuted = chat.isMutedFor(_myUid);
    final t = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined),
              title: Text(isPinned ? t.unpinChatOption : t.pinChatOption),
              onTap: () {
                Navigator.pop(ctx);
                _chatService.setPinned(chat.id, !isPinned);
              },
            ),
            ListTile(
              leading: Icon(isMuted
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined),
              title: Text(isMuted ? t.unmuteNotifOption : t.muteNotifOption),
              onTap: () {
                Navigator.pop(ctx);
                _chatService.setMuted(chat.id, !isMuted);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final myName = FirebaseAuth.instance.currentUser?.displayName ?? 'there';
    final firstName = myName.split(' ').first;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.greeting(firstName),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color)),
                          const SizedBox(height: 2),
                          Text(t.navChats,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    StreamBuilder<int>(
                      stream: NotificationService().unreadCount(),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return IconButton.filledTonal(
                          tooltip: t.notificationsTooltip,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const NotificationsScreen()),
                          ),
                          icon: Badge(
                            isLabelVisible: count > 0,
                            label: Text(count > 99 ? '99+' : '$count'),
                            child: const Icon(Icons.notifications_outlined),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () => setState(() => _searching = !_searching),
                      icon: Icon(_searching
                          ? Icons.close_rounded
                          : Icons.search_rounded),
                    ),
                  ],
                ),
              ),
            ),
            if (_searching)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: t.searchChats,
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v.toLowerCase()),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: StreamBuilder<int>(
                stream: _chatService.pendingRequestCount(),
                builder: (context, snap) {
                  final count = snap.data ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const RequestsScreen()),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    Theme.of(context).primaryColor,
                                child: const Icon(Icons.mail_outline_rounded,
                                    color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  t.messageRequests,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$count',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right_rounded,
                                  size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            StreamBuilder<List<ChatModel>>(
              stream: _chatService.myChats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: _ErrorState(error: snapshot.error.toString()),
                  );
                }
                var chats = snapshot.data ?? [];
                if (_query.isNotEmpty) {
                  chats = chats
                      .where((c) =>
                          c.titleFor(_myUid).toLowerCase().contains(_query) ||
                          c.lastMessage.toLowerCase().contains(_query))
                      .toList();
                }
                if (chats.isEmpty) {
                  return SliverFillRemaining(
                    child: _EmptyState(onNewChat: _openNewChat),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final chat = chats[i];
                      return _ChatTile(
                        chat: chat,
                        myUid: _myUid,
                        onLeave: () => _chatService.leaveChat(chat.id),
                        onTap: () async {
                          await _chatService.markAsRead(chat.id);
                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => ChatScreen(chat: chat)),
                          );
                        },
                        onLongPress: () => _showChatOptions(context, chat),
                      );
                    },
                    childCount: chats.length,
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
      // This tab is nested inside HomeScreen's own Scaffold, which has a
      // floating "glass" bottomNavigationBar. A nested Scaffold's FAB has
      // no awareness of that outer nav bar's height, so without this
      // bottom padding the FAB anchors to the very bottom of the screen
      // and ends up sitting under/behind the floating nav pill instead of
      // floating above it.
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 78),
        child: FloatingActionButton.extended(
          onPressed: _openNewChat,
          icon: const Icon(Icons.edit_rounded),
          label: Text(t.newChat),
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatModel chat;
  final String myUid;
  final VoidCallback onTap;
  final VoidCallback onLeave;
  final VoidCallback onLongPress;

  const _ChatTile({
    required this.chat,
    required this.myUid,
    required this.onTap,
    required this.onLeave,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final unread = chat.unreadCount[myUid] ?? 0;
    final title = chat.titleFor(myUid);
    final photo = chat.photoFor(myUid);
    final otherUid = chat.otherUidFor(myUid);
    final isMine = chat.lastMessageSenderId == myUid;

    return Dismissible(
      key: ValueKey(chat.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(chat.isGroup
              ? AppLocalizations.of(context).leaveGroupQuestion
              : AppLocalizations.of(context).deleteChatQuestion),
          content: Text(chat.isGroup
              ? AppLocalizations.of(context).leaveGroupWarning(title)
              : AppLocalizations.of(context).deleteChatWarning(title)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(context).cancel)),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                    chat.isGroup
                        ? AppLocalizations.of(context).leave
                        : AppLocalizations.of(context).delete,
                    style: const TextStyle(color: AppColors.danger))),
          ],
        ),
      ),
      onDismissed: (_) => onLeave(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: unread > 0
                  ? Theme.of(context).primaryColor.withOpacity(0.06)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                if (chat.isGroup || otherUid.isEmpty)
                  UserAvatar(name: title, photoUrl: photo, isGroup: true)
                else
                  _OnlineAwareAvatar(uid: otherUid, name: title, photoUrl: photo),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontWeight: unread > 0
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    fontSize: 15.5)),
                          ),
                          if (chat.isPinnedFor(myUid)) ...[
                            const SizedBox(width: 5),
                            Icon(Icons.push_pin_rounded,
                                size: 13,
                                color: Theme.of(context).primaryColor),
                          ],
                          if (chat.isMutedFor(myUid)) ...[
                            const SizedBox(width: 5),
                            Icon(Icons.notifications_off_rounded,
                                size: 13,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (chat.isRequestSentBy(myUid))
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.schedule_rounded,
                                  size: 13,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color),
                            ),
                          Expanded(
                            child: Text(
                              chat.isRequestSentBy(myUid)
                                  ? AppLocalizations.of(context).requestSent
                                  : (chat.lastMessage.isEmpty
                                      ? AppLocalizations.of(context).sayHello
                                      : (isMine
                                          ? AppLocalizations.of(context)
                                              .youMessagePrefix(
                                                  chat.lastMessage)
                                          : chat.lastMessage)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontStyle: chat.isRequestSentBy(myUid)
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                                color: unread > 0
                                    ? Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color
                                    : Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                fontWeight: unread > 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeago.format(chat.lastMessageTime, locale: 'en_short'),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: unread > 0
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).textTheme.bodySmall?.color,
                        fontWeight:
                            unread > 0 ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (unread > 0)
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      )
                    else
                      const SizedBox(height: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps [UserAvatar] with a light stream on the other user's doc so 1:1
/// chats show a live online dot without every list rebuild needing it.
class _OnlineAwareAvatar extends StatelessWidget {
  final String uid;
  final String name;
  final String? photoUrl;

  const _OnlineAwareAvatar(
      {required this.uid, required this.name, required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return UserAvatar(name: name, photoUrl: photoUrl);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final online = snap.data?.data()?['isOnline'] as bool? ?? false;
        return UserAvatar(name: name, photoUrl: photoUrl, online: online);
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onNewChat;
  const _EmptyState({required this.onNewChat});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);   // <-- ADD THIS LINE
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.18),
                    Theme.of(context).primaryColor.withOpacity(0.05),
                  ],
                ),
              ),
              child: Icon(Icons.chat_bubble_outline_rounded,
                  size: 40, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 20),
            Text(t.noChatsYet,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              t.noChatsYetSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onNewChat,
              icon: const Icon(Icons.add_rounded),
              label: Text(t.startAChat),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 40, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context).couldntLoadChats,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
