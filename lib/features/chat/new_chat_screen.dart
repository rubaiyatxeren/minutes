import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import 'chat_screen.dart';
import 'chat_service.dart';

/// Lets the user pick from the `users` collection to start a direct chat,
/// or select multiple people to create a group.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _chatService = ChatService();
  final _groupNameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final Map<String, AppUser> _selected = {};
  bool _groupMode = false;
  String _search = '';
  bool _busy = false;

  @override
  void dispose() {
    _groupNameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleUser(AppUser user) {
    setState(() {
      _selected.containsKey(user.uid)
          ? _selected.remove(user.uid)
          : _selected[user.uid] = user;
    });
  }

  Future<void> _startDirect(AppUser user) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final chatId = await _chatService.getOrCreateDirectChat(
        user.uid,
        user.name,
        otherPhotoUrl: user.photoUrl,
      );
      // Fetch the real chat back rather than assuming — it may have been
      // an existing (already-accepted) chat that just got reused, or a
      // brand new one that's now a pending message request.
      final chat = await _chatService.getChat(chatId);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('StateError: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createGroup() async {
    if (_groupNameCtrl.text.trim().isEmpty || _selected.length < 2 || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final title = _groupNameCtrl.text.trim();
      final names = {for (final u in _selected.values) u.uid: u.name};
      final photos = {for (final u in _selected.values) u.uid: u.photoUrl};
      final groupCreatedText = AppLocalizations.of(context).groupCreatedText;

      final chatId = await _chatService.createGroupChat(
        title: title,
        participantIds: _selected.keys.toList(),
        participantNames: names,
        participantPhotos: photos,
        lastMessageText: groupCreatedText,
      );
      if (!mounted) return;
      final myUid = FirebaseAuth.instance.currentUser!.uid;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chat: ChatModel(
              id: chatId,
              title: title,
              isGroup: true,
              participantIds: [..._selected.keys, myUid],
              participantNames: names,
              participantPhotos: photos,
              lastMessage: groupCreatedText,
              lastMessageTime: DateTime.now(),
              lastMessageSenderId: '',
              createdBy: myUid,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_groupMode ? t.newGroup : t.newChatTitle),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _ModeChip(
                    label: t.directMessage,
                    icon: Icons.person_outline_rounded,
                    selected: !_groupMode,
                    onTap: () => setState(() => _groupMode = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModeChip(
                    label: t.newGroup,
                    icon: Icons.groups_outlined,
                    selected: _groupMode,
                    onTap: () => setState(() => _groupMode = true),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: t.searchPeople,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _groupMode ? _buildGroupHeader(context) : const SizedBox(),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: StreamBuilder<List<String>>(
              stream: _chatService.blockedUids(),
              builder: (context, blockedSnap) {
                final blocked = blockedSnap.data ?? const <String>[];
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final users = snapshot.data!.docs
                        .map((d) => AppUser.fromMap(d.data(), d.id))
                        .where((u) => u.uid != myUid)
                        .where((u) => !blocked.contains(u.uid))
                        .where((u) => u.name.toLowerCase().contains(_search))
                        .toList();
                    return _buildUserList(context, users);
                  },
                );
              },
            ),
          ),
          if (_groupMode)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selected.length >= 2 && !_busy
                      ? _createGroup
                      : null,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.groups_rounded),
                  label: Text(_selected.length < 2
                      ? t.selectAtLeast2
                      : '${t.createGroup} (${_selected.length})'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserList(BuildContext context, List<AppUser> users) {
    final t = AppLocalizations.of(context);
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 40, color: Theme.of(context).disabledColor),
            const SizedBox(height: 10),
            Text(t.noOneFound,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: users.length,
      itemBuilder: (context, i) {
        final user = users[i];
        final isSelected = _selected.containsKey(user.uid);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.06)
              : Colors.transparent,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: UserAvatar(
              name: user.name,
              photoUrl: user.photoUrl,
              radius: 24,
              online: user.isOnline,
            ),
            title: Text(user.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              _groupMode ? user.email : '${user.email} · ${AppLocalizations.of(context).tapToMessage}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _groupMode
                ? AnimatedScale(
                    scale: isSelected ? 1 : 0.9,
                    duration: const Duration(milliseconds: 120),
                    child: Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).disabledColor,
                    ),
                  )
                : null,
            onTap: _busy
                ? null
                : () => _groupMode ? _toggleUser(user) : _startDirect(user),
          ),
        );
      },
    );
  }

  Widget _buildGroupHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _groupNameCtrl,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).groupName,
              prefixIcon: const Icon(Icons.edit_outlined),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_selected.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 82,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _selected.values
                    .map((u) => Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Column(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  UserAvatar(
                                      name: u.name,
                                      photoUrl: u.photoUrl,
                                      radius: 24),
                                  Positioned(
                                    right: -4,
                                    top: -4,
                                    child: GestureDetector(
                                      onTap: () => _toggleUser(u),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .scaffoldBackgroundColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                            Icons.cancel_rounded,
                                            size: 18,
                                            color: Colors.black54),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  u.name.split(' ').first,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? primary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? primary : Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18, color: selected ? Colors.white : primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}