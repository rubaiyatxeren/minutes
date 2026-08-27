import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../models/message_model.dart';
import '../../../models/meeting_model.dart';
import '../../meeting/meeting_service.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;

  final VoidCallback onLongPress;
  final VoidCallback onReactTap;
  final VoidCallback? onTap;
  final void Function(String roomId)? onJoinCall;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.onLongPress,
    required this.onReactTap,
    this.onTap,
    this.onJoinCall,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    final bubbleColor = isMine
        ? (isDark
            ? AppColors.darkBubbleMine
            : AppColors.lightBubbleMine)
        : (isDark
            ? AppColors.darkBubbleOther
            : AppColors.lightBubbleOther);

    final textColor = isMine
        ? Colors.white
        : (isDark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary);

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTap,
      child: Align(
        alignment: isMine
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Container(
          margin:
              const EdgeInsets.symmetric(
            vertical: 3,
            horizontal: 12,
          ),
          constraints:
              BoxConstraints(
            maxWidth:
                MediaQuery.of(context)
                        .size
                        .width *
                    0.76,
          ),
          child: Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (message.isPinned)
                Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 3,
                    left: 4,
                    right: 4,
                  ),
                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.push_pin_rounded,
                        size: 12,
                        color:
                            Theme.of(context)
                                .primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context).pinnedLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              Theme.of(context)
                                  .primaryColor,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius:
                      BorderRadius.only(
                    topLeft:
                        const Radius.circular(18),
                    topRight:
                        const Radius.circular(18),
                    bottomLeft:
                        Radius.circular(
                      isMine ? 18 : 5,
                    ),
                    bottomRight:
                        Radius.circular(
                      isMine ? 5 : 18,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    if (message
                            .replyToMessageId !=
                        null)
                      _buildReplyPreview(
                        context,
                        textColor,
                      ),

                    if (!isMine &&
                        message
                            .senderName
                            .isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 3,
                        ),
                        child: Text(
                          message.senderName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w700,
                            color:
                                Theme.of(
                              context,
                            ).primaryColor,
                          ),
                        ),
                      ),

                    _buildContent(
                      context,
                      textColor,
                    ),

                    const SizedBox(height: 5),

                    Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat(
                            'h:mm a',
                          ).format(
                            message.timestamp,
                          ),
                          style: TextStyle(
                            fontSize: 10,
                            color: textColor
                                .withOpacity(
                              0.65,
                            ),
                          ),
                        ),
                        if (message.isEdited) ...[
                          const SizedBox(
                            width: 4,
                          ),
                          Text(
                            AppLocalizations.of(context).editedLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: textColor
                                  .withOpacity(
                                0.65,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              if (message.reactions.isNotEmpty)
                _buildReactions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview(
    BuildContext context,
    Color textColor,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: 7),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color:
            textColor.withOpacity(0.08),
        borderRadius:
            BorderRadius.circular(9),
        border: Border(
          left: BorderSide(
            color:
                Theme.of(context)
                    .primaryColor,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            message.replyToSender ?? '',
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message.replyToText ?? '',
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color:
                  textColor.withOpacity(
                0.75,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Color textColor,
  ) {
    if (message.isDeleted) {
      return Text(
        AppLocalizations.of(context).messageWasDeleted,
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color:
              textColor.withOpacity(0.6),
        ),
      );
    }

    switch (message.type) {
      case MessageType.image:
      case MessageType.gif:
        return ClipRRect(
          borderRadius:
              BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl:
                message.mediaUrl ?? '',
            width: 230,
            fit: BoxFit.cover,
            placeholder:
                (_, __) => const SizedBox(
              width: 230,
              height: 150,
              child: Center(
                child:
                    CircularProgressIndicator(),
              ),
            ),
            errorWidget:
                (_, __, ___) =>
                    const SizedBox(
              width: 230,
              height: 150,
              child: Center(
                child: Icon(
                  Icons
                      .broken_image_outlined,
                ),
              ),
            ),
          ),
        );

      case MessageType.video:
        return Container(
          width: 230,
          height: 150,
          decoration:
              BoxDecoration(
            color: Colors.black26,
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons
                .play_circle_fill_rounded,
            size: 50,
            color: Colors.white,
          ),
        );

      case MessageType.audio:
        return Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .play_circle_fill_rounded,
              color: textColor,
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context).voiceMessage,
              style: TextStyle(
                color: textColor,
              ),
            ),
          ],
        );

      case MessageType.file:
        return Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration:
                  BoxDecoration(
                color: textColor
                    .withOpacity(0.1),
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),
              child: Icon(
                Icons
                    .insert_drive_file_rounded,
                color: textColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                message.text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                ),
                overflow:
                    TextOverflow.ellipsis,
              ),
            ),
          ],
        );

      case MessageType.callInvite:
        final roomId = message.mediaUrl ?? '';
        return _CallInviteContent(
          roomId: roomId,
          isMine: isMine,
          textColor: textColor,
          onJoinCall: onJoinCall,
        );

      case MessageType.text:
        return Text(
          message.text,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            height: 1.35,
          ),
        );
    }
  }

  Widget _buildReactions(
    BuildContext context,
  ) {
    final counts =
        <String, int>{};

    for (final emoji
        in message.reactions.values) {
      counts[emoji] =
          (counts[emoji] ?? 0) + 1;
    }

    return GestureDetector(
      onTap: onReactTap,
      child: Container(
        margin:
            const EdgeInsets.only(top: 3),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 4,
        ),
        decoration:
            BoxDecoration(
          color: Theme.of(context)
              .cardColor,
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color:
                Theme.of(context)
                    .dividerColor
                    .withOpacity(0.7),
          ),
        ),
        child: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: counts.entries
              .map(
                (entry) => Padding(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 2,
                  ),
                  child: Text(
                    '${entry.key} ${entry.value}',
                    style:
                        const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

/// The "Video call" bubble content, split out into its own widget so it can
/// hold a live Firestore subscription on the meeting doc. Without this the
/// bubble was a dumb, static "Join Call" button forever — even minutes
/// after the host hung up and the room was gone, tapping it would still
/// try to open Jitsi to a dead room. Now it listens for `status: 'ended'`
/// and flips itself into a disabled "Call ended" state the instant that
/// happens, for every participant, in real time.
class _CallInviteContent extends StatefulWidget {
  final String roomId;
  final bool isMine;
  final Color textColor;
  final void Function(String roomId)? onJoinCall;

  const _CallInviteContent({
    required this.roomId,
    required this.isMine,
    required this.textColor,
    required this.onJoinCall,
  });

  @override
  State<_CallInviteContent> createState() => _CallInviteContentState();
}

class _CallInviteContentState extends State<_CallInviteContent> {
  final _meetingService = MeetingService();

  @override
  Widget build(BuildContext context) {
    final textColor = widget.textColor;
    final roomId = widget.roomId;
    final t = AppLocalizations.of(context);

    return StreamBuilder<MeetingModel?>(
      stream: roomId.isEmpty
          ? null
          : _meetingService.meetingDocStream(roomId),
      builder: (context, snapshot) {
        final meeting = snapshot.data;
        final hasEnded = meeting?.status == MeetingStatus.ended;

        return Container(
          constraints: const BoxConstraints(minWidth: 190),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    hasEnded
                        ? Icons.call_end_rounded
                        : Icons.videocam_rounded,
                    color: textColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasEnded ? t.videoCallEndedLabel : t.videoCall,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                hasEnded
                    ? (meeting?.durationSeconds != null
                        ? t.lastedFor(_formatDuration(meeting!.duration))
                        : t.thisCallHasEnded)
                    : t.roomIdInline(roomId),
                style: TextStyle(
                  color: textColor.withOpacity(0.75),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (roomId.isEmpty ||
                          widget.onJoinCall == null ||
                          hasEnded)
                      ? null
                      : () => widget.onJoinCall!(roomId),
                  icon: Icon(
                    hasEnded ? Icons.block_rounded : Icons.call_rounded,
                    size: 16,
                  ),
                  label: Text(hasEnded ? t.callEndedShort : t.joinCallButton),
                  style: FilledButton.styleFrom(
                    backgroundColor: hasEnded
                        ? Theme.of(context).disabledColor.withOpacity(0.25)
                        : (widget.isMine
                            ? Colors.white
                            : Theme.of(context).primaryColor),
                    foregroundColor: hasEnded
                        ? textColor.withOpacity(0.6)
                        : (widget.isMine
                            ? Theme.of(context).primaryColor
                            : Colors.white),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m}m';
    }
    if (m > 0) {
      return '${m}m ${s}s';
    }
    return '${s}s';
  }
}