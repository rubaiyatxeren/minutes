import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/chat_model.dart';
import 'chat_screen.dart';
import 'chat_service.dart';

/// Messenger/Instagram-style "Message requests" inbox. New direct chats
/// from people the user hasn't accepted yet land here instead of the main
/// chat list, so anyone can start a conversation but it can't reach the
/// user's inbox proper without an explicit accept.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final _chatService = ChatService();
  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  final Set<String> _busyIds = {};

  Future<void> _accept(ChatModel chat) async {
    setState(() => _busyIds.add(chat.id));
    try {
      await _chatService.respondToRequest(chat.id, accept: true);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(chat.id));
    }
  }

  Future<void> _decline(ChatModel chat) async {
    setState(() => _busyIds.add(chat.id));
    try {
      await _chatService.respondToRequest(chat.id, accept: false);
    } finally {
      if (mounted) setState(() => _busyIds.remove(chat.id));
    }
  }

  Future<void> _declineAndBlock(ChatModel chat) async {
    final otherUid = chat.otherUidFor(_myUid);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(t.blockThisPersonQuestion),
          content: Text(
            "${chat.titleFor(_myUid)} won't be able to message you again, "
            "and this request will be deleted.",
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t.cancel)),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.block, style: const TextStyle(color: AppColors.danger)),
            ),
          ],
        );
      },
    );
    if (confirmed != true || otherUid.isEmpty) return;

    setState(() => _busyIds.add(chat.id));
    try {
      await _chatService.declineAndBlock(chat.id, otherUid);
    } finally {
      if (mounted) setState(() => _busyIds.remove(chat.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.messageRequests)),
      body: StreamBuilder<List<ChatModel>>(
        stream: _chatService.myChatRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_rounded,
                        size: 48, color: Theme.of(context).disabledColor),
                    const SizedBox(height: 16),
                    Text(t.noPendingRequests,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      t.noPendingRequestsSubtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 84),
            itemBuilder: (context, i) {
              final chat = requests[i];
              final title = chat.titleFor(_myUid);
              final photo = chat.photoFor(_myUid);
              final busy = _busyIds.contains(chat.id);

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserAvatar(name: title, photoUrl: photo, radius: 26),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(
                            chat.lastMessage.isEmpty
                                ? t.wantsToMessageYou
                                : chat.lastMessage,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeago.format(chat.lastMessageTime),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: 11),
                          ),
                          const SizedBox(height: 10),
                          if (busy)
                            const SizedBox(
                              height: 32,
                              width: 32,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _accept(chat),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 8),
                                  ),
                                  child: Text(t.accept),
                                ),
                                OutlinedButton(
                                  onPressed: () => _decline(chat),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 8),
                                  ),
                                  child: Text(t.delete),
                                ),
                                TextButton(
                                  onPressed: () => _declineAndBlock(chat),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.danger,
                                  ),
                                  child: Text(t.block),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
