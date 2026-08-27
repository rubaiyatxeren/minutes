import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/notification_model.dart';
import '../chat/chat_screen.dart';
import '../chat/chat_service.dart';
import 'notification_service.dart';

enum _NotifFilter { all, calls, messages, other }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notificationService = NotificationService();
  final _chatService = ChatService();

  _NotifFilter _filter = _NotifFilter.all;

  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.message:
        return Icons.chat_bubble_rounded;
      case NotificationType.meetingInvite:
        return Icons.video_call_rounded;
      case NotificationType.meetingEnded:
        return Icons.call_end_rounded;
      case NotificationType.reaction:
        return Icons.emoji_emotions_rounded;
      case NotificationType.groupAdded:
        return Icons.group_add_rounded;
      case NotificationType.messageRequest:
        return Icons.mail_outline_rounded;
      case NotificationType.requestAccepted:
        return Icons.check_circle_rounded;
    }
  }

  // Every notification type gets its own tint so the feed is scannable at
  // a glance (calls read differently from reactions, etc.) instead of
  // everything sharing one flat accent color.
  Color _colorFor(NotificationType type, BuildContext context) {
    switch (type) {
      case NotificationType.message:
        return Theme.of(context).primaryColor;
      case NotificationType.meetingInvite:
        return AppColors.success;
      case NotificationType.meetingEnded:
        return AppColors.danger;
      case NotificationType.reaction:
        return AppColors.warning;
      case NotificationType.groupAdded:
        return const Color(0xFF9B6BFF);
      case NotificationType.messageRequest:
        return AppColors.warning;
      case NotificationType.requestAccepted:
        return AppColors.success;
    }
  }

  bool _matchesFilter(NotificationModel n) {
    switch (_filter) {
      case _NotifFilter.all:
        return true;
      case _NotifFilter.calls:
        return n.type == NotificationType.meetingInvite ||
            n.type == NotificationType.meetingEnded;
      case _NotifFilter.messages:
        return n.type == NotificationType.message ||
            n.type == NotificationType.reaction ||
            n.type == NotificationType.messageRequest ||
            n.type == NotificationType.requestAccepted;
      case _NotifFilter.other:
        return n.type == NotificationType.groupAdded;
    }
  }

  String _dayLabel(DateTime d) {
    final t = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return t.today;
    if (diff == 1) return t.yesterday;
    if (diff < 7) return t.weekdayName(d.weekday);
    return '${d.day}/${d.month}/${d.year}';
  }

  Future<void> _openNotification(NotificationModel n) async {
    await _notificationService.markAsRead(n.id);
    if (n.chatId == null || !mounted) return;

    // Fetch directly rather than searching myChats() — that stream
    // deliberately excludes pending incoming requests (see ChatService),
    // so a messageRequest/requestAccepted notification would never
    // resolve to a chat if we looked it up that way.
    final chat = await _chatService.getChat(n.chatId!);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.notifications),
        actions: [
          StreamBuilder<int>(
            stream: _notificationService.unreadCount(),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return PopupMenuButton<String>(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.more_vert_rounded),
                ),
                onSelected: (v) {
                  if (v == 'read_all') _notificationService.markAllAsRead();
                  if (v == 'clear') _showClearConfirm();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'read_all',
                    child: Row(
                      children: [
                        const Icon(Icons.done_all_rounded, size: 18),
                        const SizedBox(width: 10),
                        Text(t.markAllAsRead),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_sweep_outlined, size: 18),
                        const SizedBox(width: 10),
                        Text(t.clearAll),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _FilterBar(
              selected: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
            Expanded(
              child: StreamBuilder<List<NotificationModel>>(
                stream: _notificationService.myNotifications(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final all = snapshot.data ?? [];
                  final items = all.where(_matchesFilter).toList();

                  if (items.isEmpty) {
                    return _EmptyState(hasAny: all.isNotEmpty);
                  }

                  // Group into day buckets, in order, so headers only
                  // appear once per day instead of repeating per row.
                  final grouped = <String, List<NotificationModel>>{};
                  for (final n in items) {
                    final label = _dayLabel(n.createdAt);
                    grouped.putIfAbsent(label, () => []).add(n);
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
                          child: Text(
                            entry.key.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                        ),
                        for (final n in entry.value)
                          _NotificationCard(
                            key: ValueKey(n.id),
                            notification: n,
                            icon: _iconFor(n.type),
                            color: _colorFor(n.type, context),
                            isDark: isDark,
                            onTap: () => _openNotification(n),
                            onDismissed: () => _notificationService.delete(n.id),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearConfirm() {
    showDialog(
      context: context,
      builder: (ctx) {
        final t = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(t.clearAllNotificationsQuestion),
          content: Text(t.cantBeUndone),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t.cancel),
            ),
            TextButton(
              onPressed: () {
                _notificationService.clearAll();
                Navigator.pop(ctx);
              },
              child: Text(t.clear, style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

/// Horizontally scrollable pill filters — All / Calls / Messages / Other.
/// Keeps the feed easy to scan on a busy account without needing a
/// separate tabs screen.
class _FilterBar extends StatelessWidget {
  final _NotifFilter selected;
  final ValueChanged<_NotifFilter> onChanged;

  const _FilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final entries = [
      (_NotifFilter.all, t.filterAll, Icons.notifications_rounded),
      (_NotifFilter.calls, t.filterCalls, Icons.video_call_rounded),
      (_NotifFilter.messages, t.filterMessages, Icons.chat_bubble_rounded),
      (_NotifFilter.other, t.filterOther, Icons.more_horiz_rounded),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (f, label, icon) = entries[i];
          final isSelected = f == selected;
          final primary = Theme.of(context).primaryColor;
          return ChoiceChip(
            label: Text(label),
            avatar: Icon(icon,
                size: 16,
                color: isSelected ? Colors.white : Theme.of(context).textTheme.bodySmall?.color),
            selected: isSelected,
            onSelected: (_) => onChanged(f),
            selectedColor: primary,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : null,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? primary : Theme.of(context).dividerColor,
              ),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _NotificationCard({
    super.key,
    required this.notification,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;

    return Dismissible(
      key: ValueKey('dismiss_${n.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onDismissed(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: n.isRead
                ? Theme.of(context).dividerColor
                : color.withOpacity(0.35),
            width: n.isRead ? 1 : 1.4,
          ),
          boxShadow: n.isRead
              ? null
              : [
                  BoxShadow(
                    color: color.withOpacity(isDark ? 0.10 : 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Unread accent bar — a quieter, more modern signal than
                  // a full tinted-row background.
                  Container(
                    width: 3,
                    height: 40,
                    margin: const EdgeInsets.only(right: 10, top: 2),
                    decoration: BoxDecoration(
                      color: n.isRead ? Colors.transparent : color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Stack(
                    children: [
                      n.senderName != null
                          ? UserAvatar(
                              name: n.senderName!,
                              photoUrl: n.senderPhotoUrl,
                              radius: 22,
                            )
                          : Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.withOpacity(0.14),
                              ),
                              child: Icon(icon, color: color, size: 22),
                            ),
                      if (n.senderName != null)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              border: Border.all(
                                color: Theme.of(context).cardColor,
                                width: 2,
                              ),
                            ),
                            child: Icon(icon, color: Colors.white, size: 10),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                n.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight:
                                      n.isRead ? FontWeight.w600 : FontWeight.w800,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeago.format(n.createdAt, locale: 'en_short'),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 11.5,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          n.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                height: 1.3,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasAny;
  const _EmptyState({required this.hasAny});

  @override
  Widget build(BuildContext context) {
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
                    Theme.of(context).primaryColor.withOpacity(0.20),
                    Theme.of(context).primaryColor.withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                hasAny
                    ? Icons.filter_alt_off_rounded
                    : Icons.notifications_none_rounded,
                size: 42,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasAny
                  ? AppLocalizations.of(context).noNotificationsHere
                  : AppLocalizations.of(context).noNotificationsYet,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              hasAny
                  ? AppLocalizations.of(context).tryDifferentFilter
                  : AppLocalizations.of(context).noNotificationsYetSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
