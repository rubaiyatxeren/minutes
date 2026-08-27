import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/chat_model.dart';
import 'add_participants_screen.dart';
import 'chat_service.dart';

/// Full member list for a group chat — reached from ChatInfoScreen's
/// "See all" row. Lets the creator add or remove members; any member
/// can leave the group from here.
class GroupParticipantsScreen extends StatelessWidget {
  final ChatModel chat;
  const GroupParticipantsScreen({super.key, required this.chat});

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _confirmRemove(
    BuildContext context,
    ChatService chatService,
    String chatId,
    String uid,
    String name,
  ) async {
    final t = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.removeMemberQuestion),
        content: Text('$name ${t.willBeRemovedFromGroup}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.remove, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await chatService.removeParticipant(chatId, uid);
  }

  Future<void> _confirmLeave(
    BuildContext context,
    ChatService chatService,
    String chatId,
  ) async {
    final t = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.leaveGroupQuestion),
        content: Text(t.wontSeeNewMessages),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.leave, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await chatService.leaveChat(chatId);
    if (context.mounted) {
      // Pop back past ChatInfoScreen AND ChatScreen — the chat no longer
      // belongs to this user.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.participantsScreenTitle)),
      body: StreamBuilder<ChatModel>(
        stream: chatService.chatStream(chat.id),
        builder: (context, snapshot) {
          final liveChat = snapshot.data ?? chat;
          final isCreator = liveChat.createdBy == _myUid;
          final ids = liveChat.participantIds;

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).primaryColor.withOpacity(0.12),
                  child: Icon(Icons.person_add_alt_1_rounded,
                      color: Theme.of(context).primaryColor),
                ),
                title: Text(t.addParticipants,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddParticipantsScreen(chat: liveChat),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  '${ids.length} ${t.participantsCountLabel}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ),
              for (final uid in ids)
                ListTile(
                  leading: UserAvatar(
                    name: liveChat.participantNames[uid] ?? '?',
                    photoUrl: liveChat.participantPhotos[uid],
                    radius: 22,
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          liveChat.participantNames[uid] ??
                              AppLocalizations.of(context).unknownUser,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (uid == _myUid) ...[
                        const SizedBox(width: 6),
                        Text('(${t.you})',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                  subtitle: uid == liveChat.createdBy
                      ? Text(t.groupCreator)
                      : null,
                  trailing: (isCreator &&
                          uid != _myUid &&
                          uid != liveChat.createdBy)
                      ? IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded,
                              color: Colors.red),
                          tooltip: t.remove,
                          onPressed: () => _confirmRemove(
                            context,
                            chatService,
                            liveChat.id,
                            uid,
                            liveChat.participantNames[uid] ?? 'this member',
                          ),
                        )
                      : null,
                ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: Text(t.leaveGroup,
                    style: const TextStyle(color: Colors.red)),
                onTap: () => _confirmLeave(context, chatService, liveChat.id),
              ),
            ],
          );
        },
      ),
    );
  }
}
