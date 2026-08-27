import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import 'chat_service.dart';

/// Picker for adding new members to an existing group. The user list is
/// filtered to exclude both the current user (can't add yourself — you're
/// already a participant) and anyone already in the group, so there's no
/// way to select someone who's already there.
class AddParticipantsScreen extends StatefulWidget {
  final ChatModel chat;
  const AddParticipantsScreen({super.key, required this.chat});

  @override
  State<AddParticipantsScreen> createState() => _AddParticipantsScreenState();
}

class _AddParticipantsScreenState extends State<AddParticipantsScreen> {
  final _chatService = ChatService();
  final _searchCtrl = TextEditingController();
  final Map<String, AppUser> _selected = {};
  String _search = '';
  bool _busy = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggle(AppUser user) {
    setState(() {
      _selected.containsKey(user.uid)
          ? _selected.remove(user.uid)
          : _selected[user.uid] = user;
    });
  }

  Future<void> _addSelected() async {
    if (_selected.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await _chatService.addParticipantsToGroup(
        chatId: widget.chat.id,
        newIds: _selected.keys.toList(),
        newNames: {for (final u in _selected.values) u.uid: u.name},
        newPhotos: {for (final u in _selected.values) u.uid: u.photoUrl},
        currentParticipantIds: widget.chat.participantIds,
        groupTitle: widget.chat.title,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final existingIds = widget.chat.participantIds;

    return Scaffold(
      appBar: AppBar(title: Text(t.addParticipants)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: t.searchPeople,
                prefixIcon: const Icon(Icons.search_rounded),
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
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = snapshot.data!.docs
                    .map((d) => AppUser.fromMap(d.data(), d.id))
                    // Excludes self AND everyone already in the group —
                    // this is the actual fix for "shouldn't be able to
                    // add someone (including yourself) who's already in
                    // the chat".
                    .where((u) => u.uid != myUid)
                    .where((u) => !existingIds.contains(u.uid))
                    .where((u) => u.name.toLowerCase().contains(_search))
                    .toList();

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_search_rounded,
                            size: 40,
                            color: Theme.of(context).disabledColor),
                        const SizedBox(height: 10),
                        Text(
                          existingIds.length > 1 && _search.isEmpty
                              ? t.everyoneAlreadyInGroup
                              : t.noOneFound,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
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
                    return Container(
                      color: isSelected
                          ? Theme.of(context).primaryColor.withOpacity(0.06)
                          : Colors.transparent,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        leading: UserAvatar(
                          name: user.name,
                          photoUrl: user.photoUrl,
                          radius: 24,
                        ),
                        title: Text(user.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(user.email),
                        trailing: Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).disabledColor,
                        ),
                        onTap: () => _toggle(user),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
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
                onPressed: _selected.isNotEmpty && !_busy ? _addSelected : null,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.person_add_alt_1_rounded),
                label: Text(_selected.isEmpty
                    ? t.selectPeopleToAdd
                    : '${t.add} (${_selected.length})'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
