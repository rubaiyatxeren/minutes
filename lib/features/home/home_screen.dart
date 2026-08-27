import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/localization/app_localizations.dart';
import '../../models/chat_model.dart';
import '../../models/meeting_model.dart';
import '../chat/chat_service.dart';
import '../chat/new_chat_screen.dart';
import '../meeting/create_meeting_screen.dart';
import '../meeting/join_meeting_screen.dart';
import '../meeting/meeting_history_screen.dart';
import '../meeting/meeting_service.dart';
import '../meeting/widgets/call_summary_sheet.dart';
import '../presence/presence_service.dart';
import '../settings/settings_screen.dart';
import 'chats_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  final _presenceService = PresenceService();
  final _chatService = ChatService();

  late final List<Widget> _tabs = const [
    ChatsTab(),
    _MeetingsTab(),
    SettingsScreen(),
  ];

  List<({IconData icon, IconData selected, String label})> _destinations(
      AppLocalizations t) =>
      [
        (
          icon: Icons.chat_bubble_outline_rounded,
          selected: Icons.chat_bubble_rounded,
          label: t.navChats
        ),
        (
          icon: Icons.video_camera_front_outlined,
          selected: Icons.video_camera_front_rounded,
          label: t.navMeetings
        ),
        (
          icon: Icons.settings_outlined,
          selected: Icons.settings_rounded,
          label: t.navSettings
        ),
      ];

  @override
  void initState() {
    super.initState();
    // Starts tracking real app-foreground/background state so `isOnline`
    // reflects whether the person is actually using the app right now, not
    // just whether they're still signed in (see PresenceService docs).
    _presenceService.attach();
  }

  @override
  void dispose() {
    _presenceService.detach();
    super.dispose();
  }

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  void _quickAction(int i) {
    // Long-press shortcuts: jump straight to the most common action for
    // that tab instead of making the person tap in, then tap again.
    HapticFeedback.mediumImpact();
    switch (i) {
      case 0:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NewChatScreen()),
        );
        break;
      case 1:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateMeetingScreen()),
        );
        break;
      default:
        // No quick action for Settings — nothing to do.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Lets the chat/meetings/settings content scroll UNDER the floating
      // glass bar — that's what makes the blur behind it actually show
      // page content rather than just the plain scaffold background.
      extendBody: true,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: _GlassNavBar(
        selectedIndex: _index,
        onSelected: _select,
        onLongPress: _quickAction,
        chatService: _chatService,
        destinations: _destinations(AppLocalizations.of(context)),
      ),
    );
  }
}

/// An iOS-style floating "liquid glass" tab bar: a frosted, translucent
/// pill that floats above the content (real blur via BackdropFilter, not
/// just a tinted rectangle), with a soft moving highlight behind the
/// selected item and a light haptic tick on switch.
///
/// Fully responsive: it adapts padding, icon size, label size and bar
/// height to the available width, clamps runaway system text scaling so
/// labels never force an overflow, and caps its own width on large
/// screens (tablets/foldables/desktop) so it doesn't stretch edge to edge.
class _GlassNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<int> onLongPress;
  final ChatService chatService;
  final List<({IconData icon, IconData selected, String label})> destinations;

  static const double _maxBarWidth = 480;

  const _GlassNavBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.onLongPress,
    required this.chatService,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = media.padding.bottom;
    final screenWidth = media.size.width;
    final isLandscape = media.orientation == Orientation.landscape;

    // Clamp text scaling for just this bar: a floating pill nav has to
    // stay legible and tappable even when the person has cranked up
    // system font size in Accessibility settings — it should never grow
    // tall/wide enough to overflow or eat the content behind it.
    final clampedScaler = media.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.25);
    final textScale = clampedScaler.scale(14) / 14;

    // Compact mode kicks in on narrow phones (small/folded devices) or
    // once text scaling is pushed up — this is what actually prevents the
    // label + icon + padding from ever exceeding the space each item has.
    final compact = screenWidth < 360 || textScale > 1.12;

    final barHeight = isLandscape && media.size.height < 420
        ? 54.0
        : (compact ? 60.0 : 66.0);

    // On wide screens (tablets, foldables unfolded, desktop) don't let the
    // pill stretch full width — cap it and center it instead.
    final horizontalMargin = screenWidth > _maxBarWidth + 32
        ? (screenWidth - _maxBarWidth) / 2
        : 16.0;

    return MediaQuery(
      data: media.copyWith(textScaler: clampedScaler),
      child: RepaintBoundary(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalMargin,
            0,
            horizontalMargin,
            bottomInset > 0 ? bottomInset - 4 : 12,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                height: barHeight,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.white.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.14)
                        : Colors.white.withOpacity(0.75),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.35 : 0.10),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      Expanded(
                        child: _GlassNavItem(
                          icon: destinations[i].icon,
                          selectedIcon: destinations[i].selected,
                          label: destinations[i].label,
                          selected: selectedIndex == i,
                          compact: compact,
                          showChatsBadge: i == 0,
                          chatService: chatService,
                          onTap: () => onSelected(i),
                          onLongPress: () => onLongPress(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassNavItem extends StatefulWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool compact;
  final bool showChatsBadge;
  final ChatService chatService;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GlassNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.compact,
    required this.showChatsBadge,
    required this.chatService,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_GlassNavItem> createState() => _GlassNavItemState();
}

class _GlassNavItemState extends State<_GlassNavItem> {
  // Tiny press-down scale gives tactile feedback without the cost of a
  // full AnimationController — GestureDetector's callbacks are enough.
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final mutedColor = Theme.of(context).textTheme.bodySmall?.color;
    final iconSize = widget.compact ? 21.0 : 23.0;
    final labelSize = widget.compact ? 12.0 : 13.0;
    final selectedPad = widget.compact ? 10.0 : 16.0;

    final iconWidget = Icon(
      widget.selected ? widget.selectedIcon : widget.icon,
      size: iconSize,
      color: widget.selected ? Colors.white : mutedColor,
    );

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: Tooltip(
        message: widget.label,
        waitDuration: const Duration(milliseconds: 500),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          child: AnimatedScale(
            scale: _pressed ? 0.94 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: EdgeInsets.symmetric(
                horizontal: widget.selected ? selectedPad : 0,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: widget.selected ? primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: widget.selected
                    ? [
                        BoxShadow(
                          color: primary.withOpacity(0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              // Row sizes itself to the available column width (tight,
              // via the parent Expanded) — wrapping the label in Flexible
              // is what stops a long label + icon from ever overflowing
              // on narrow screens or with bumped-up system text size; it
              // shrinks/ellipsizes gracefully instead of spilling into
              // the neighbouring tab.
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  widget.showChatsBadge
                      ? _BadgedIcon(chatService: widget.chatService, child: iconWidget)
                      : iconWidget,
                  if (widget.selected)
                    Flexible(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: labelSize,
                            ),
                          ),
                        ),
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

/// Unread-count badge on the Chats tab icon. Shows a plain dot up to a
/// handful of unread chats, then switches to a compact "N" / "9+" pill
/// once there's an actual number worth surfacing — still small enough to
/// not fight the glass bar's compact height.
class _BadgedIcon extends StatelessWidget {
  final ChatService chatService;
  final Widget child;
  const _BadgedIcon({required this.chatService, required this.child});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<List<ChatModel>>(
      stream: chatService.myChats(),
      builder: (context, snapshot) {
        final total = (snapshot.data ?? const <ChatModel>[])
            .fold<int>(0, (sum, c) => sum + (c.unreadCount[myUid] ?? 0));
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (total > 0)
              Positioned(
                top: -4,
                right: -8,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: total <= 2
                      ? Container(
                          key: const ValueKey('dot'),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        )
                      : Container(
                          key: const ValueKey('count'),
                          constraints: const BoxConstraints(minWidth: 15),
                          height: 15,
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          child: Text(
                            total > 9 ? '9+' : '$total',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MeetingsTab extends StatelessWidget {
  const _MeetingsTab();

  @override
  Widget build(BuildContext context) {
    final meetingService = MeetingService();
    final t = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          children: [
            Text(t.navMeetings,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(t.startOrJoinSubtitle,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 22),
            _MeetingActionCard(
              icon: Icons.video_call_rounded,
              title: t.newMeeting,
              subtitle: t.newMeetingSubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateMeetingScreen()),
              ),
            ),
            const SizedBox(height: 14),
            _MeetingActionCard(
              icon: Icons.login_rounded,
              title: t.joinMeeting,
              subtitle: t.joinMeetingSubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const JoinMeetingScreen()),
              ),
            ),
            const SizedBox(height: 14),
            _MeetingActionCard(
              icon: Icons.history_rounded,
              title: t.meetingHistory,
              subtitle: t.meetingHistorySubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const MeetingHistoryScreen()),
              ),
            ),
            const SizedBox(height: 28),
            StreamBuilder<List<MeetingModel>>(
              stream: meetingService.myMeetingHistory(),
              builder: (context, snapshot) {
                final recent = (snapshot.data ?? const <MeetingModel>[])
                    .take(3)
                    .toList();
                if (recent.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.recentLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        )),
                    const SizedBox(height: 10),
                    for (final m in recent)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RecentMeetingTile(meeting: m),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentMeetingTile extends StatefulWidget {
  final MeetingModel meeting;
  const _RecentMeetingTile({required this.meeting});

  @override
  State<_RecentMeetingTile> createState() => _RecentMeetingTileState();
}

class _RecentMeetingTileState extends State<_RecentMeetingTile> {
  final _meetingService = MeetingService();
  bool _joining = false;

  Future<void> _rejoin() async {
    setState(() => _joining = true);
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        user?.displayName?.isNotEmpty == true ? user!.displayName! : 'Guest';
    final joinedParticipants = <String>{displayName};

    // Same double-fire guard used everywhere else conferenceTerminated
    // is handled — see chat_screen.dart / meeting_history_screen.dart.
    var terminationHandled = false;

    try {
      await _meetingService.joinMeeting(
        roomName: widget.meeting.roomName,
        displayName: displayName,
        email: user?.email,
        listener: JitsiMeetEventListener(
          conferenceJoined: (url) {
            _meetingService.logJoined(
              roomName: widget.meeting.roomName,
              displayName: displayName,
              topic: widget.meeting.topic,
              chatId: widget.meeting.chatId,
              isGroupCall: true,
            );
          },
          participantJoined: (email, name, role, participantId) {
            if (name != null && name.isNotEmpty) joinedParticipants.add(name);
          },
          conferenceTerminated: (url, error) async {
            if (terminationHandled) return;
            terminationHandled = true;
            final duration =
                await _meetingService.logEnded(widget.meeting.roomName);
            if (!mounted || duration == null) return;
            showCallSummarySheet(
              context,
              topic: widget.meeting.topic.isNotEmpty
                  ? widget.meeting.topic
                  : widget.meeting.roomName,
              duration: duration,
              participantNames: joinedParticipants.toList(),
            );
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.meeting.topic.isNotEmpty
        ? widget.meeting.topic
        : widget.meeting.roomName;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.12),
          child: Icon(Icons.videocam_rounded,
              color: Theme.of(context).primaryColor, size: 20),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          AppLocalizations.of(context).participantsTimeLabel(
              widget.meeting.participantIds.length,
              timeago.format(widget.meeting.startedAt)),
        ),
        trailing: _joining
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: _rejoin,
                child: Text(AppLocalizations.of(context).rejoin),
              ),
      ),
    );
  }
}

class _MeetingActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MeetingActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}