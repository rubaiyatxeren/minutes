import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/utils/file_download.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/chat_model.dart';
import '../../models/message_model.dart';
import 'chat_service.dart';
import 'group_participants_screen.dart';

/// Reached by tapping a chat's header. For groups: shows a participant
/// preview + link to the full member list. For 1:1 chats: shows the
/// other person's basic profile info. Both share Media/Links/Files tabs
/// built from that chat's actual message history.
class ChatInfoScreen extends StatelessWidget {
  final ChatModel chat;
  const ChatInfoScreen({super.key, required this.chat});

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();

    return Scaffold(
      appBar: AppBar(
        title: Text(chat.isGroup
            ? AppLocalizations.of(context).groupInfo
            : AppLocalizations.of(context).contactInfo),
      ),
      body: StreamBuilder<ChatModel>(
        // Live, not the possibly-stale `chat` passed in — so a newly
        // added participant shows up immediately without leaving here.
        stream: chatService.chatStream(chat.id),
        builder: (context, snapshot) {
          final liveChat = snapshot.data ?? chat;

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                _Header(chat: liveChat, myUid: _myUid),
                if (liveChat.isGroup)
                  _ParticipantsPreview(chat: liveChat, myUid: _myUid)
                else
                  _ContactDetails(chat: liveChat, myUid: _myUid),
                _ChatActionsRow(chat: liveChat, myUid: _myUid),
                const Divider(height: 1),
                const TabBar(
                  tabs: [
                    Tab(text: 'Media'),
                    Tab(text: 'Links'),
                    Tab(text: 'Files'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _MediaTab(chatId: liveChat.id),
                      _LinksTab(chatId: liveChat.id),
                      _FilesTab(chatId: liveChat.id),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatefulWidget {
  final ChatModel chat;
  final String myUid;
  const _Header({required this.chat, required this.myUid});

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  final _chatService = ChatService();
  bool _uploadingPhoto = false;

  bool get _canEditGroupPhoto =>
      widget.chat.isGroup && widget.chat.createdBy == widget.myUid;

  Future<void> _changeGroupPhoto() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final Uint8List bytes = await file.readAsBytes();
      final url = await CloudinaryService.instance.uploadImage(
        bytes,
        folder: 'group_photos/${widget.chat.id}',
        fileName: widget.chat.id,
      );
      if (url == null) throw Exception('Upload failed');
      await _chatService.updateGroupPhoto(widget.chat.id, url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)
                .couldntUpdateGroupPhoto('$e'))),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final title = chat.titleFor(widget.myUid);
    final photo = chat.photoFor(widget.myUid);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        children: [
          GestureDetector(
            // Only the creator can tap through to change it — everyone
            // else just sees a plain (non-interactive) avatar, same as
            // it always was, so this never looks like a dead button to
            // regular members.
            onTap: _canEditGroupPhoto && !_uploadingPhoto
                ? _changeGroupPhoto
                : null,
            child: Stack(
              children: [
                UserAvatar(
                  name: title,
                  photoUrl: photo,
                  radius: 44,
                  isGroup: chat.isGroup,
                ),
                if (_uploadingPhoto)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.4),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    ),
                  )
                else if (_canEditGroupPhoto)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 3,
                        ),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 14, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          if (chat.isGroup) ...[
            const SizedBox(height: 4),
            Text(
              '${chat.participantIds.length} members',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown for 1:1 chats — the other person's email + online/last-seen,
/// resolved live from their `users/{uid}` doc.
class _ContactDetails extends StatelessWidget {
  final ChatModel chat;
  final String myUid;
  const _ContactDetails({required this.chat, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final otherUid = chat.otherUidFor(myUid);
    if (otherUid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(otherUid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final email = data?['email'] as String? ?? '';
        final online = data?['isOnline'] as bool? ?? false;
        final lastSeenStr = data?['lastSeen'] as String?;
        final lastSeen =
            lastSeenStr != null ? DateTime.tryParse(lastSeenStr) : null;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              if (email.isNotEmpty)
                _InfoRow(icon: Icons.mail_outline_rounded, label: email),
              const SizedBox(height: 6),
              _InfoRow(
                icon: Icons.circle,
                iconSize: 10,
                iconColor: online ? AppColors.success : Colors.grey,
                label: online
                    ? AppLocalizations.of(context).onlineStatus
                    : lastSeen != null
                        ? AppLocalizations.of(context)
                            .lastSeenLabel(timeago.format(lastSeen))
                        : AppLocalizations.of(context).offline,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Mute/unmute + (for 1:1 chats) block/unblock, in one compact row. Muting
/// only silences notifications for this chat; blocking prevents the other
/// person from starting new message requests at all.
class _ChatActionsRow extends StatelessWidget {
  final ChatModel chat;
  final String myUid;
  const _ChatActionsRow({required this.chat, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();
    final otherUid = chat.otherUidFor(myUid);
    final isMuted = chat.isMutedFor(myUid);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          _ActionChip(
            icon: isMuted
                ? Icons.notifications_off_rounded
                : Icons.notifications_outlined,
            label: isMuted
                ? AppLocalizations.of(context).mutedState
                : AppLocalizations.of(context).mute,
            active: isMuted,
            onTap: () => chatService.setMuted(chat.id, !isMuted),
          ),
          if (!chat.isGroup && otherUid.isNotEmpty)
            StreamBuilder<List<String>>(
              stream: chatService.blockedUids(),
              builder: (context, snap) {
                final blocked = (snap.data ?? const <String>[]).contains(otherUid);
                return _ActionChip(
                  icon: blocked
                      ? Icons.block_rounded
                      : Icons.block_flipped,
                  label: blocked ? AppLocalizations.of(context).blocked : AppLocalizations.of(context).blockQuestion,
                  active: blocked,
                  danger: !blocked,
                  onTap: () async {
                    if (blocked) {
                      await chatService.unblockUser(otherUid);
                      return;
                    }
                    final t = AppLocalizations.of(context);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('${t.blockQuestion} ${chat.titleFor(myUid)}?'),
                        content: Text(t.blockExplain),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(t.cancel)),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(t.blockQuestion,
                                style: const TextStyle(color: AppColors.danger)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await chatService.blockUser(otherUid);
                    }
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool danger;
  final VoidCallback onTap;
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppColors.danger
        : (active
            ? Theme.of(context).primaryColor
            : Theme.of(context).textTheme.bodyMedium?.color);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? Theme.of(context).primaryColor
                : Theme.of(context).dividerColor,
          ),
          color: active
              ? Theme.of(context).primaryColor.withOpacity(0.08)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double iconSize;
  final Color? iconColor;
  const _InfoRow({
    required this.icon,
    required this.label,
    this.iconSize = 16,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: iconSize, color: iconColor ?? Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Shown for group chats — a horizontal preview of up to 6 avatars plus
/// a "See all" row that opens the full participant list/management
/// screen (add/remove members lives there, not here).
class _ParticipantsPreview extends StatelessWidget {
  final ChatModel chat;
  final String myUid;
  const _ParticipantsPreview({required this.chat, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final ids = chat.participantIds;
    final preview = ids.take(6).toList();

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GroupParticipantsScreen(chat: chat),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Row(
          children: [
            SizedBox(
              // A SizedBox with only a height, inside a Row, has no width
              // constraint of its own — Flutter falls back to the Row's
              // incoming constraints, which can be unbounded (infinite)
              // depending on ancestors. The Stack below has ONLY Positioned
              // children, so with unbounded width it can never size itself,
              // which throws a "RenderBox was not laid out" cascade the
              // instant this screen renders. Giving it an explicit width
              // (avatar diameter + the overlap offset of every extra
              // avatar) fixes that for good.
              width: preview.isEmpty
                  ? 0
                  : 40.0 + (preview.length - 1) * 26.0,
              height: 40,
              child: Stack(
                children: [
                  for (var i = 0; i < preview.length; i++)
                    Positioned(
                      left: i * 26.0,
                      child: UserAvatar(
                        name: chat.participantNames[preview[i]] ?? '?',
                        photoUrl: chat.participantPhotos[preview[i]],
                        radius: 20,
                      ),
                    ),
                ],
              ),
            ),
            const Spacer(),
            Text(AppLocalizations.of(context).seeAll,
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                )),
            Icon(Icons.chevron_right_rounded,
                color: Theme.of(context).primaryColor),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TABS
// ---------------------------------------------------------------------------

class _MediaTab extends StatelessWidget {
  final String chatId;
  const _MediaTab({required this.chatId});

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();
    return StreamBuilder<List<MessageModel>>(
      stream: chatService.messagesFor(chatId),
      builder: (context, snapshot) {
        final media = (snapshot.data ?? [])
            .where((m) =>
                !m.isDeleted &&
                (m.type == MessageType.image ||
                    m.type == MessageType.video ||
                    m.type == MessageType.gif) &&
                (m.mediaUrl?.isNotEmpty ?? false))
            .toList();

        if (media.isEmpty) {
          return _EmptyTab(
            icon: Icons.photo_library_outlined,
            label: AppLocalizations.of(context).noPhotosVideosYet,
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: media.length,
          itemBuilder: (context, i) {
            final m = media[i];
            return GestureDetector(
              onTap: () {
                if (m.type == MessageType.video) {
                  downloadAndOpenFile(
                    context,
                    url: m.mediaUrl!,
                    fileName: 'video_${m.id}.mp4',
                  );
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _FullscreenImage(url: m.mediaUrl!),
                    ),
                  );
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: m.mediaUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: Colors.grey.withOpacity(0.15)),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey.withOpacity(0.15),
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                    if (m.type == MessageType.video)
                      Container(
                        color: Colors.black26,
                        child: const Icon(Icons.play_circle_fill_rounded,
                            color: Colors.white, size: 28),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FullscreenImage extends StatelessWidget {
  final String url;
  const _FullscreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () => downloadAndOpenFile(
              context,
              url: url,
              fileName: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          ),
        ],
      ),
      body: Center(child: InteractiveViewer(child: Image.network(url))),
    );
  }
}

class _LinksTab extends StatelessWidget {
  final String chatId;
  const _LinksTab({required this.chatId});

  static final _urlPattern = RegExp(r'(https?:\/\/[^\s]+)');

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();
    return StreamBuilder<List<MessageModel>>(
      stream: chatService.messagesFor(chatId),
      builder: (context, snapshot) {
        final links = <MapEntry<String, MessageModel>>[];
        for (final m in snapshot.data ?? <MessageModel>[]) {
          if (m.isDeleted || m.type != MessageType.text) continue;
          for (final match in _urlPattern.allMatches(m.text)) {
            links.add(MapEntry(match.group(0)!, m));
          }
        }

        if (links.isEmpty) {
          return _EmptyTab(
            icon: Icons.link_rounded,
            label: AppLocalizations.of(context).noLinksSharedYet,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: links.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
          itemBuilder: (context, i) {
            final link = links[i].key;
            final sender = links[i].value.senderName;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    Theme.of(context).primaryColor.withOpacity(0.12),
                child: Icon(Icons.link_rounded,
                    color: Theme.of(context).primaryColor),
              ),
              title: Text(link,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(AppLocalizations.of(context).sharedBy(sender)),
              trailing: IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: AppLocalizations.of(context).copyLinkTooltip,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            AppLocalizations.of(context).linkCopied)),
                  );
                },
              ),
              onTap: () async {
                final uri = Uri.tryParse(link);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            AppLocalizations.of(context).couldntOpenLink)),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}

class _FilesTab extends StatelessWidget {
  final String chatId;
  const _FilesTab({required this.chatId});

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();
    return StreamBuilder<List<MessageModel>>(
      stream: chatService.messagesFor(chatId),
      builder: (context, snapshot) {
        final files = (snapshot.data ?? [])
            .where((m) =>
                !m.isDeleted &&
                m.type == MessageType.file &&
                (m.mediaUrl?.isNotEmpty ?? false))
            .toList();

        if (files.isEmpty) {
          return _EmptyTab(
            icon: Icons.insert_drive_file_outlined,
            label: AppLocalizations.of(context).noFilesSharedYet,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: files.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
          itemBuilder: (context, i) {
            final f = files[i];
            final name = f.text.isNotEmpty ? f.text : 'file_${f.id}';
            return ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    Theme.of(context).primaryColor.withOpacity(0.12),
                child: Icon(Icons.insert_drive_file_rounded,
                    color: Theme.of(context).primaryColor),
              ),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(AppLocalizations.of(context).sharedBy(f.senderName)),
              trailing: IconButton(
                icon: const Icon(Icons.download_rounded),
                onPressed: () => downloadAndOpenFile(
                  context,
                  url: f.mediaUrl!,
                  fileName: name,
                ),
              ),
              onTap: () => downloadAndOpenFile(
                context,
                url: f.mediaUrl!,
                fileName: name,
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).disabledColor),
          const SizedBox(height: 12),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
