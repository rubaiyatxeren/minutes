import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/meeting_model.dart';
import 'meeting_service.dart';

class MeetingHistoryScreen extends StatefulWidget {
  const MeetingHistoryScreen({super.key});

  @override
  State<MeetingHistoryScreen> createState() => _MeetingHistoryScreenState();
}

class _MeetingHistoryScreenState extends State<MeetingHistoryScreen> {
  final _meetingService = MeetingService();
  String? _rejoiningRoom;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }

  Future<void> _rejoin(MeetingModel meeting) async {
    setState(() => _rejoiningRoom = meeting.roomName);
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        user?.displayName?.isNotEmpty == true ? user!.displayName! : 'Guest';
    var terminationHandled = false;
    try {
      await _meetingService.joinMeeting(
        roomName: meeting.roomName,
        displayName: displayName,
        email: user?.email,
        listener: JitsiMeetEventListener(
          conferenceJoined: (url) {
            _meetingService.logJoined(
              roomName: meeting.roomName,
              displayName: displayName,
              topic: meeting.topic,
              chatId: meeting.chatId,
              isGroupCall: true,
            );
          },
          conferenceTerminated: (url, error) {
            if (terminationHandled) return;
            terminationHandled = true;
            _meetingService.logEnded(meeting.roomName);
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _rejoiningRoom = null);
    }
  }

  void _showMeetingDetailsSheet(BuildContext context, MeetingModel meeting) {
    final isOngoing = meeting.status == MeetingStatus.ongoing;
    final wasHost = meeting.hostId == _myUid;
    final t = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: (isOngoing
                            ? AppColors.success
                            : Theme.of(context).primaryColor)
                        .withOpacity(0.12),
                    child: Icon(
                      meeting.isGroupCall
                          ? Icons.groups_rounded
                          : Icons.videocam_rounded,
                      color: isOngoing
                          ? AppColors.success
                          : Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meeting.topic.isNotEmpty
                              ? meeting.topic
                              : meeting.roomName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isOngoing ? t.callInProgress : t.endedCallStatus,
                          style: TextStyle(
                            color: isOngoing
                                ? AppColors.success
                                : Theme.of(context).textTheme.bodySmall?.color,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                icon: Icons.meeting_room_outlined,
                label: t.roomId,
                value: meeting.roomName,
              ),
              _buildDetailRow(
                context,
                icon: Icons.person_outline_rounded,
                label: t.host,
                value: wasHost
                    ? t.youSuffix(meeting.hostName)
                    : meeting.hostName,
              ),
              _buildDetailRow(
                context,
                icon: Icons.access_time_rounded,
                label: t.startedAt,
                value: meeting.startedAt.toLocal().toString().split('.').first,
              ),
              if (meeting.endedAt != null)
                _buildDetailRow(
                  context,
                  icon: Icons.event_available_rounded,
                  label: t.endedAt,
                  value: meeting.endedAt!.toLocal().toString().split('.').first,
                ),
              _buildDetailRow(
                context,
                icon: Icons.timer_outlined,
                label: t.duration,
                value:
                    isOngoing ? t.ongoing : _formatDuration(meeting.duration),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                t.participantsCountParen(meeting.participantNames.length),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: meeting.participantNames.entries.map((entry) {
                      final uid = entry.key;
                      final name = entry.value;
                      final isMe = uid == _myUid;
                      final isMeetingHost = uid == meeting.hostId;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        title: Text(
                          isMe ? t.youSuffix(name) : name,
                          style: TextStyle(
                            fontWeight:
                                isMe ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: isMeetingHost
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  t.host,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : null,
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!isOngoing)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _rejoiningRoom == null
                        ? () {
                            Navigator.pop(context);
                            _rejoin(meeting);
                          }
                        : null,
                    icon: const Icon(Icons.call_rounded),
                    label: Text(AppLocalizations.of(context).rejoin),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).hintColor),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
          ),
          const Spacer(),
          SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.meetingHistory)),
      body: SafeArea(
        child: StreamBuilder<List<MeetingModel>>(
          stream: _meetingService.myMeetingHistory(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    t.couldntLoadMeetingHistory('${snapshot.error}'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            }
            final meetings = snapshot.data ?? [];
            if (meetings.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [
                            Theme.of(context).primaryColor.withOpacity(0.18),
                            Theme.of(context).primaryColor.withOpacity(0.05),
                          ]),
                        ),
                        child: Icon(Icons.history_rounded,
                            size: 38, color: Theme.of(context).primaryColor),
                      ),
                      const SizedBox(height: 18),
                      Text(t.noCallsYet,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        t.noCallsYetSubtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: meetings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final m = meetings[i];
                final isOngoing = m.status == MeetingStatus.ongoing;
                final wasHost = m.hostId == _myUid;
                final otherNames = m.participantNames.entries
                    .where((e) => e.key != _myUid)
                    .map((e) => e.value)
                    .toList();

                return Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _showMeetingDetailsSheet(context, m),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (isOngoing
                                      ? AppColors.success
                                      : Theme.of(context).primaryColor)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              m.isGroupCall
                                  ? Icons.groups_rounded
                                  : Icons.videocam_rounded,
                              color: isOngoing
                                  ? AppColors.success
                                  : Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.topic.isNotEmpty ? m.topic : m.roomName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  otherNames.isEmpty
                                      ? (wasHost
                                          ? t.youHosted
                                          : t.soloCall)
                                      : t.withNames(
                                          otherNames.join(', ')),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      isOngoing
                                          ? Icons.fiber_manual_record_rounded
                                          : Icons.timer_outlined,
                                      size: 13,
                                      color: isOngoing
                                          ? AppColors.success
                                          : Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isOngoing
                                          ? t.inProgress
                                          : _formatDuration(m.duration),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isOngoing
                                            ? AppColors.success
                                            : Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.color,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('·',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                    const SizedBox(width: 8),
                                    Text(
                                      timeago.format(m.startedAt,
                                          locale: 'en_short'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (!isOngoing)
                            IconButton(
                              tooltip: t.callAgainTooltip,
                              icon: _rejoiningRoom == m.roomName
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Icon(Icons.call_rounded,
                                      color: Theme.of(context).primaryColor),
                              onPressed: _rejoiningRoom == null
                                  ? () => _rejoin(m)
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}