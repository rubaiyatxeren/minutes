import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:giphy_get/giphy_get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/chat_model.dart';
import '../../models/meeting_model.dart';
import '../../models/message_model.dart';
import '../../models/notification_model.dart';
import '../meeting/meeting_service.dart';
import '../meeting/widgets/call_summary_sheet.dart';
import '../notifications/notification_service.dart';
import 'chat_info_screen.dart';
import 'chat_service.dart';
import 'widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final ChatModel chat;

  const ChatScreen({
    super.key,
    required this.chat,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _meetingService = MeetingService();
  final _notificationService = NotificationService();

  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _composerFocus = FocusNode();

  final _uuid = const Uuid();

  final _cloudinary = CloudinaryService.instance;

  bool _sending = false;
  bool _hasText = false;
  bool _iAmTyping = false;

  Timer? _typingStopTimer;

  MessageModel? _replyTo;
  MessageModel? _editing;

  String get _myUid =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  String get _myName =>
      FirebaseAuth.instance.currentUser?.displayName ?? 'Me';

  // ---------------------------------------------------------------------------
  // MESSAGE REQUESTS
  // ---------------------------------------------------------------------------
  //
  // widget.chat is a snapshot taken when this screen was opened, so these
  // getters are only used for the initial guard in `_send`. The actual
  // request banner/action-bar in `build` reads live status off a
  // StreamBuilder so it updates in real time (e.g. it disappears the
  // instant the other side accepts, without needing to reopen the chat).

  bool get _isIncomingRequest => widget.chat.isRequestFor(_myUid);

  bool _requestBusy = false;

  Future<void> _acceptRequest() async {
    if (_requestBusy) return;
    setState(() => _requestBusy = true);
    try {
      await _chatService.respondToRequest(widget.chat.id, accept: true);
    } finally {
      if (mounted) setState(() => _requestBusy = false);
    }
  }

  Future<void> _declineRequest() async {
    if (_requestBusy) return;
    setState(() => _requestBusy = true);
    try {
      await _chatService.respondToRequest(widget.chat.id, accept: false);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _requestBusy = false);
    }
  }

  Future<void> _declineAndBlockRequest() async {
    final otherUid = widget.chat.otherUidFor(_myUid);
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.blockThisPersonQuestion),
        content: Text(
          "${widget.chat.titleFor(_myUid)} won't be able to message you "
          "again, and this request will be deleted.",
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
      ),
    );
    if (confirmed != true || otherUid.isEmpty || _requestBusy) return;

    setState(() => _requestBusy = true);
    try {
      await _chatService.declineAndBlock(widget.chat.id, otherUid);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _requestBusy = false);
    }
  }

  @override
  void initState() {
    super.initState();

    _chatService.markAsRead(widget.chat.id);

    _textCtrl.addListener(() {
      final hasText = _textCtrl.text.trim().isNotEmpty;

      if (hasText != _hasText && mounted) {
        setState(() => _hasText = hasText);
      }

      _handleTypingChanged(hasText);
    });

    _composerFocus.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _handleTypingChanged(bool hasText) {
    _typingStopTimer?.cancel();

    if (hasText) {
      if (!_iAmTyping) {
        _iAmTyping = true;
        _chatService.setTyping(widget.chat.id, true);
      }

      _typingStopTimer = Timer(
        const Duration(seconds: 3),
        () {
          _iAmTyping = false;
          _chatService.setTyping(widget.chat.id, false);
        },
      );
    } else if (_iAmTyping) {
      _iAmTyping = false;
      _chatService.setTyping(widget.chat.id, false);
    }
  }

  @override
  void dispose() {
    _typingStopTimer?.cancel();

    if (_iAmTyping) {
      _chatService.setTyping(widget.chat.id, false);
    }

    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _composerFocus.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // SEND TEXT
  // ---------------------------------------------------------------------------

  Future<void> _send() async {
    final text = _textCtrl.text.trim();

    if (text.isEmpty || _sending) return;
    if (_isIncomingRequest) return; // composer is hidden for this case anyway

    final replyTo = _replyTo;
    final editing = _editing;

    _textCtrl.clear();

    _typingStopTimer?.cancel();

    if (_iAmTyping) {
      _iAmTyping = false;
      _chatService.setTyping(widget.chat.id, false);
    }

    setState(() {
      _replyTo = null;
      _editing = null;
      _sending = true;
    });

    try {
      if (editing != null) {
        await _chatService.editMessage(
          widget.chat.id,
          editing.id,
          text,
        );
      } else {
        await _chatService.sendMessage(
          chatId: widget.chat.id,
          text: text,
          senderName: _myName,
          senderPhotoUrl:
              FirebaseAuth.instance.currentUser?.photoURL,
          replyToMessageId: replyTo?.id,
          replyToText: replyTo?.text,
          replyToSender: replyTo?.senderName,
        );
      }
    } catch (_) {
      if (!mounted) return;

      _textCtrl.text = text;

      setState(() {
        _replyTo = replyTo;
        _editing = editing;
      });

      final t = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.messageFailedRetry),
          action: SnackBarAction(
            label: t.retry,
            onPressed: _send,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // IMAGE PICKER
  // ---------------------------------------------------------------------------

  Future<void> _pickMultipleImages() async {
    final picker = ImagePicker();

    final List<XFile> images = await picker.pickMultiImage(
      imageQuality: 75,
    );

    if (images.isEmpty) return;

    setState(() => _sending = true);

    try {
      final uploadFutures = images.map((image) async {
        final bytes = await image.readAsBytes();

        return _cloudinary.uploadImage(
          bytes,
          folder: 'chat_media/${widget.chat.id}',
          fileName: _uuid.v4(),
        );
      });

      final List<String?> urls =
          await Future.wait(uploadFutures);

      final validUrls =
          urls.whereType<String>().toList();

      for (final url in validUrls) {
        await _chatService.sendMessage(
          chatId: widget.chat.id,
          text: '',
          type: MessageType.image,
          mediaUrl: url,
          senderName: _myName,
          senderPhotoUrl:
              FirebaseAuth.instance.currentUser?.photoURL,
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context).failedUploadImages('$e')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // DOCUMENT
  // ---------------------------------------------------------------------------

  Future<void> _pickAndSendDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'txt',
        'zip',
        'xlsx',
        'pptx',
      ],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;

    if (file.bytes == null) return;

    setState(() => _sending = true);

    try {
      final secureUrl = await _cloudinary.uploadRawFile(
        file.bytes!,
        folder: 'chat_docs/${widget.chat.id}',
        fileName: '${_uuid.v4()}_${file.name}',
      );

      if (secureUrl != null) {
        await _chatService.sendMessage(
          chatId: widget.chat.id,
          text: file.name,
          type: MessageType.file,
          mediaUrl: secureUrl,
          senderName: _myName,
          senderPhotoUrl:
              FirebaseAuth.instance.currentUser?.photoURL,
        );
      } else {
        throw Exception('Upload failed');
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).failedUploadFile('$e')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // DOWNLOAD
  // ---------------------------------------------------------------------------

  Future<void> _downloadAndOpenFile(
    String url,
    String fileName,
  ) async {
    try {
      final dir =
          await getApplicationDocumentsDirectory();

      // Prefix with a short hash of the URL — otherwise two different
      // messages that happen to share a display name (e.g. two photos
      // both named "image.jpg") would wrongly reuse each other's cached
      // file and open the wrong content.
      final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
      final urlHash = url.hashCode.toUnsigned(20).toRadixString(16);
      final filePath = '${dir.path}/${urlHash}_$safeName';
      final file = File(filePath);

      if (!await file.exists()) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).downloadingFile),
          ),
        );

        await Dio().download(
          url,
          filePath,
        );
      }

      final openResult = await OpenFile.open(filePath);

      if (openResult.type != ResultType.done &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)
                  .couldNotOpenFile('${openResult.message}'),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).errorDownloadingFile('$e'),
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // IMAGE PREVIEW
  // ---------------------------------------------------------------------------

  void _openImagePreview(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.download_rounded,
                ),
                onPressed: () {
                  _downloadAndOpenFile(
                    url,
                    'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
                  );
                },
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GIF
  // ---------------------------------------------------------------------------

  Future<void> _pickGif() async {
    final gif = await GiphyGet.getGif(
      context: context,
      apiKey:
          'mcJEZBcbivPtHlzBBjgP6idySLYh95mH',
    );

    if (gif == null) return;

    final url =
        gif.images?.original?.url ?? '';

    if (url.isEmpty) return;

    await _chatService.sendMessage(
      chatId: widget.chat.id,
      text: '',
      type: MessageType.gif,
      mediaUrl: url,
      senderName: _myName,
      senderPhotoUrl:
          FirebaseAuth.instance.currentUser?.photoURL,
    );
  }

  // ---------------------------------------------------------------------------
  // VIDEO CALL
  // ---------------------------------------------------------------------------

  Future<void> _startVideoCallInChat() async {
    final roomName =
        _chatService.newMeetingRoomId();
    final t = AppLocalizations.of(context);

    // Sent as a dedicated callInvite type (not plain text) so the bubble
    // can render a proper "Join Call" button instead of just the raw
    // room-id text.
    await _chatService.sendMessage(
      chatId: widget.chat.id,
      text: t.videoCallStartedText,
      type: MessageType.callInvite,
      mediaUrl: roomName,
      senderName: _myName,
      senderPhotoUrl: FirebaseAuth.instance.currentUser?.photoURL,
    );

    await _notificationService.notifyMany(
      recipientUids: widget.chat.participantIds,
      type: NotificationType.meetingInvite,
      title: t.startedCallNotifTitle(_myName),
      body: t.tapToJoinBody(roomName),
      chatId: widget.chat.id,
      senderId: _myUid,
      senderName: _myName,
    );

    await _joinCall(roomName, isHost: true);
  }

  /// Joins a call — either the one just started (`isHost: true`, used by
  /// [_startVideoCallInChat]) or an existing one via the "Join Call"
  /// button on a callInvite bubble ([_joinCallFromInvite]).
  Future<void> _joinCall(String roomName, {required bool isHost}) async {
    final joinedParticipants = <String>{_myName};

    // Guards against jitsi_meet_flutter_sdk's known quirk where
    // conferenceTerminated can fire more than once for a single call —
    // without this, logEnded() runs twice (recomputing a slightly
    // different duration each time) and the summary sheet pops up twice.
    var terminationHandled = false;

    await _meetingService.joinMeeting(
      roomName: roomName,
      displayName: _myName,
      listener: JitsiMeetEventListener(
        conferenceJoined: (url) {
          _meetingService.logJoined(
            roomName: roomName,
            displayName: _myName,
            chatId: widget.chat.id,
            isGroupCall: widget.chat.isGroup,
          );
        },
        participantJoined:
            (email, name, role, participantId) {
          if (name != null && name.isNotEmpty) {
            joinedParticipants.add(name);
          }
        },
        conferenceTerminated:
            (url, error) async {
          if (terminationHandled) return;
          terminationHandled = true;

          final duration =
              await _meetingService.logEnded(
            roomName,
          );

          if (!mounted || duration == null) {
            return;
          }

          showCallSummarySheet(
            context,
            topic: widget.chat.titleFor(_myUid),
            duration: duration,
            participantNames:
                joinedParticipants.toList(),
          );
        },
      ),
    );
  }

  /// Called when someone taps "Join Call" on a callInvite bubble. The
  /// bubble itself already disables the button once it sees the room is
  /// ended, but that's a live UI reflection, not a guarantee — a stale
  /// build, a race between two taps, or a cached frame could still let one
  /// through. This is the real gate: check Firestore for the room's
  /// current status right before ever opening Jitsi, so nobody can walk
  /// into a room that's already been torn down by the host.
  Future<void> _joinCallFromInvite(String roomName) async {
    if (roomName.isEmpty) return;
    final status = await _meetingService.getMeetingStatus(roomName);
    if (status == MeetingStatus.ended) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context).thisCallHasEnded)),
      );
      return;
    }
    await _joinCall(roomName, isHost: false);
  }

  // ---------------------------------------------------------------------------
  // MESSAGE ACTIONS
  // ---------------------------------------------------------------------------

  void _showMessageActions(
    MessageModel message,
  ) {
    final isMine =
        message.senderId == _myUid;
    final t = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12,
              ),
              child: Wrap(
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .dividerColor,
                        borderRadius:
                            BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _ActionTile(
                    icon: Icons.reply_rounded,
                    label: t.reply,
                    onTap: () {
                      Navigator.pop(context);

                      setState(() {
                        _replyTo = message;
                        _editing = null;
                      });

                      _composerFocus.requestFocus();
                    },
                  ),

                  _ActionTile(
                    icon:
                        Icons.emoji_emotions_outlined,
                    label: t.react,
                    onTap: () {
                      Navigator.pop(context);
                      _showReactionPicker(message);
                    },
                  ),

                  _ActionTile(
                    icon: message.isPinned
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                    label:
                        message.isPinned
                            ? t.unpin
                            : t.pin,
                    onTap: () {
                      Navigator.pop(context);

                      _chatService.togglePin(
                        widget.chat.id,
                        message.id,
                        !message.isPinned,
                      );
                    },
                  ),

                  if (message.mediaUrl != null &&
                      message.mediaUrl!.isNotEmpty)
                    _ActionTile(
                      icon:
                          Icons.download_rounded,
                      label: t.download,
                      onTap: () {
                        Navigator.pop(context);

                        final filename =
                            message.text.isNotEmpty
                                ? message.text
                                : 'file_${message.id}';

                        _downloadAndOpenFile(
                          message.mediaUrl!,
                          filename,
                        );
                      },
                    ),

                  if (isMine &&
                      !message.isDeleted) ...[
                    _ActionTile(
                      icon:
                          Icons.edit_outlined,
                      label: t.editAction,
                      onTap: () {
                        Navigator.pop(context);

                        setState(() {
                          _editing = message;
                          _replyTo = null;
                          _textCtrl.text =
                              message.text;

                          _textCtrl.selection =
                              TextSelection.fromPosition(
                            TextPosition(
                              offset:
                                  _textCtrl.text.length,
                            ),
                          );
                        });

                        _composerFocus.requestFocus();
                      },
                    ),
                    _ActionTile(
                      icon:
                          Icons.delete_outline_rounded,
                      label: AppLocalizations.of(context).delete,
                      color: AppColors.danger,
                      onTap: () {
                        Navigator.pop(context);

                        _chatService.deleteMessage(
                          widget.chat.id,
                          message.id,
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // REACTIONS
  // ---------------------------------------------------------------------------

  void _showReactionPicker(
    MessageModel message,
  ) {
    const quickEmojis = [
      '👍',
      '❤️',
      '😂',
      '😮',
      '😢',
      '🙏',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(24),
          ),
          child: Padding(
            padding:
                const EdgeInsets.all(20),
            child: Wrap(
              spacing: 14,
              runSpacing: 10,
              children: quickEmojis.map((emoji) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);

                    _chatService.toggleReaction(
                      widget.chat.id,
                      message.id,
                      emoji,
                    );
                  },
                  child: Text(
                    emoji,
                    style:
                        const TextStyle(
                      fontSize: 30,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // MESSAGE TAP
  // ---------------------------------------------------------------------------

  void _handleMessageTap(
    MessageModel message,
  ) {
    if (message.type == MessageType.image &&
        message.mediaUrl != null) {
      _openImagePreview(
        message.mediaUrl!,
      );
    } else if (message.type ==
            MessageType.file &&
        message.mediaUrl != null) {
      final fileName =
          message.text.isNotEmpty
              ? message.text
              : 'attachment.pdf';

      _downloadAndOpenFile(
        message.mediaUrl!,
        fileName,
      );
    } else if (message.type ==
            MessageType.callInvite &&
        message.mediaUrl != null) {
      _joinCallFromInvite(message.mediaUrl!);
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final title =
        widget.chat.titleFor(_myUid);

    final photo =
        widget.chat.photoFor(_myUid);

    final otherUid =
        widget.chat.otherUidFor(_myUid);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          borderRadius:
              BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  ChatInfoScreen(chat: widget.chat),
            ),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(
              vertical: 6,
            ),
            child: Row(
              children: [
                if (widget.chat.isGroup ||
                    otherUid.isEmpty)
                  UserAvatar(
                    name: title,
                    photoUrl: photo,
                    radius: 18,
                    isGroup:
                        widget.chat.isGroup,
                  )
                else
                  StreamBuilder<
                      DocumentSnapshot<
                          Map<String, dynamic>>>(
                    stream:
                        FirebaseFirestore
                            .instance
                            .collection(
                                'users')
                            .doc(otherUid)
                            .snapshots(),
                    builder:
                        (context, snap) {
                      final online =
                          snap.data
                                  ?.data()?[
                              'isOnline'] as bool? ??
                              false;

                      return UserAvatar(
                        name: title,
                        photoUrl: photo,
                        radius: 18,
                        online: online,
                      );
                    },
                  ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),

                      StreamBuilder<
                          List<String>>(
                        stream:
                            _chatService
                                .typingUsers(
                          widget.chat.id,
                        ),
                        builder:
                            (context,
                                typingSnap) {
                          final typingUids =
                              typingSnap.data ??
                                  const [];

                          if (typingUids
                              .isNotEmpty) {
                            final t =
                                AppLocalizations.of(
                                    context);
                            final names =
                                typingUids
                                    .map(
                                      (uid) =>
                                          widget.chat.participantNames[
                                                  uid] ??
                                              t.someone,
                                    )
                                    .toList();

                            final label = t.typingLabel(
                                names,
                                widget.chat.isGroup);

                            return Text(
                              label,
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle:
                                    FontStyle
                                        .italic,
                                color:
                                    Theme.of(
                                  context,
                                ).primaryColor,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            );
                          }

                          if (widget.chat.isGroup) {
                            return Text(
                              AppLocalizations.of(context)
                                  .membersCount(widget
                                      .chat
                                      .participantIds
                                      .length),
                              style:
                                  Theme.of(
                                context,
                              )
                                      .textTheme
                                      .bodySmall,
                            );
                          }

                          if (otherUid.isEmpty) {
                            return const SizedBox
                                .shrink();
                          }

                          return StreamBuilder<
                              DocumentSnapshot<
                                  Map<String,
                                      dynamic>>>(
                            stream:
                                FirebaseFirestore
                                    .instance
                                    .collection(
                                        'users')
                                    .doc(otherUid)
                                    .snapshots(),
                            builder:
                                (context,
                                    snap) {
                              final data =
                                  snap.data
                                      ?.data();

                              final online =
                                  data?[
                                          'isOnline']
                                      as bool? ??
                                      false;

                              if (online) {
                                return Text(
                                  AppLocalizations.of(
                                          context)
                                      .onlineStatus,
                                  style:
                                      TextStyle(
                                    fontSize: 12,
                                    color:
                                        AppColors
                                            .success,
                                  ),
                                );
                              }

                              final lastSeenStr =
                                  data?[
                                      'lastSeen'];

                              final lastSeen =
                                  lastSeenStr
                                          is String
                                      ? DateTime.tryParse(
                                          lastSeenStr)
                                      : null;

                              return Text(
                                lastSeen !=
                                        null
                                    ? AppLocalizations.of(
                                            context)
                                        .lastSeenLabel(
                                            timeago.format(
                                                lastSeen,
                                                locale:
                                                    'en_short'))
                                    : '',
                                style:
                                    Theme.of(
                                  context,
                                )
                                        .textTheme
                                        .bodySmall,
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.videocam_rounded,
            ),
            tooltip: AppLocalizations.of(context).startVideoCallTooltip,
            onPressed:
                _startVideoCallInChat,
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color:
                    Theme.of(context)
                                .brightness ==
                            Brightness.dark
                        ? Colors.black
                            .withOpacity(0.12)
                        : Theme.of(context)
                            .primaryColor
                            .withOpacity(0.025),
              ),
              child:
                  StreamBuilder<
                      List<MessageModel>>(
                stream:
                    _chatService.messagesFor(
                  widget.chat.id,
                ),
                builder:
                    (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child:
                          CircularProgressIndicator(),
                    );
                  }

                  final messages =
                      snapshot.data!;

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration:
                                BoxDecoration(
                              shape:
                                  BoxShape.circle,
                              gradient:
                                  LinearGradient(
                                colors: [
                                  Theme.of(
                                    context,
                                  )
                                      .primaryColor
                                      .withOpacity(
                                          0.18),
                                  Theme.of(
                                    context,
                                  )
                                      .primaryColor
                                      .withOpacity(
                                          0.05),
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons
                                  .waving_hand_rounded,
                              size: 36,
                              color:
                                  Theme.of(
                                context,
                              ).primaryColor,
                            ),
                          ),
                          const SizedBox(
                            height: 16,
                          ),
                          Text(
                            AppLocalizations.of(context)
                                .noMessagesYet,
                            style:
                                Theme.of(
                              context,
                            )
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight:
                                          FontWeight
                                              .w700,
                                    ),
                          ),
                          const SizedBox(
                            height: 6,
                          ),
                          Text(
                            AppLocalizations.of(context)
                                .sayHiTo(title),
                            style:
                                Theme.of(
                              context,
                            )
                                    .textTheme
                                    .bodySmall,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller:
                        _scrollCtrl,
                    reverse: true,
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 12,
                    ),
                    itemCount:
                        messages.length,
                    itemBuilder:
                        (context, i) {
                      final message =
                          messages[i];

                      return MessageBubble(
                        message: message,
                        isMine:
                            message.senderId ==
                                _myUid,
                        onLongPress: () =>
                            _showMessageActions(
                          message,
                        ),
                        onReactTap: () =>
                            _showReactionPicker(
                          message,
                        ),
                        onTap: () =>
                            _handleMessageTap(
                          message,
                        ),
                        onJoinCall: (roomId) =>
                            _joinCallFromInvite(
                          roomId,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // -------------------------------------------------------------------
          // REPLY / EDIT BANNER + COMPOSER
          // -------------------------------------------------------------------
          //
          // Wrapped in a live StreamBuilder (not widget.chat, which is a
          // snapshot from when this screen opened) so the request UI reacts
          // in real time — e.g. if the other person accepts while this
          // screen is still open, the accept/decline bar swaps to the
          // normal composer immediately.

          StreamBuilder<ChatModel>(
            stream: _chatService.chatStream(widget.chat.id),
            initialData: widget.chat,
            builder: (context, chatSnap) {
              final liveChat = chatSnap.data ?? widget.chat;
              final isIncomingRequest = liveChat.isRequestFor(_myUid);
              final isSentRequest = liveChat.isRequestSentBy(_myUid);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSentRequest) _buildSentRequestBanner(),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: (_replyTo != null || _editing != null)
                        ? _buildComposerBanner()
                        : const SizedBox(width: double.infinity),
                  ),
                  isIncomingRequest
                      ? _buildRequestActionBar()
                      : _buildComposer(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MESSAGE REQUEST UI
  // ---------------------------------------------------------------------------

  /// Shown above the composer for the *requester*, on their own outgoing
  /// request — they can still keep messaging, but it's clear the other
  /// side hasn't accepted yet.
  Widget _buildSentRequestBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).primaryColor.withOpacity(0.06),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded,
              size: 15, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context).requestSentBanner,
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Replaces the composer entirely for the *recipient* of a pending
  /// request — they can read what's been sent, but can't reply until they
  /// explicitly accept, so a stranger can't be messaged into a full
  /// conversation without the recipient opting in.
  Widget _buildRequestActionBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        14 + MediaQuery.of(context).padding.bottom,
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
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)
                  .wantsToSendMessage(widget.chat.titleFor(_myUid)),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (_requestBusy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _declineRequest,
                      child: Text(AppLocalizations.of(context).delete),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _acceptRequest,
                      child: Text(AppLocalizations.of(context).accept),
                    ),
                  ),
                ],
              ),
            if (!_requestBusy)
              TextButton(
                onPressed: _declineAndBlockRequest,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(AppLocalizations.of(context).block),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REPLY / EDIT BANNER
  // ---------------------------------------------------------------------------

  Widget _buildComposerBanner() {
    final isEditing =
        _editing != null;
    final t = AppLocalizations.of(context);

    final label = isEditing
        ? t.editingMessage
        : t.replyingTo(_replyTo!.senderName);

    final preview =
        isEditing
            ? _editing!.text
            : _replyTo!.text;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        18,
        10,
        10,
        8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context)
                .dividerColor
                .withOpacity(0.45),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 38,
            decoration: BoxDecoration(
              color:
                  Theme.of(context)
                      .primaryColor,
              borderRadius:
                  BorderRadius.circular(4),
            ),
          ),

          const SizedBox(width: 10),

          Icon(
            isEditing
                ? Icons.edit_rounded
                : Icons.reply_rounded,
            size: 17,
            color:
                Theme.of(context)
                    .primaryColor,
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Theme.of(context)
                            .primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preview.isEmpty
                      ? t.mediaPlaceholder
                      : preview,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            splashRadius: 20,
            icon: const Icon(
              Icons.close_rounded,
              size: 19,
            ),
            onPressed: () {
              setState(() {
                _replyTo = null;
                _editing = null;
                _textCtrl.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MODERN MESSAGE COMPOSER
  // ---------------------------------------------------------------------------

 Widget _buildComposer() {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final surfaceColor = isDark ? const Color(0xFF17181C) : const Color(0xFFF4F5F7);
  final t = AppLocalizations.of(context);

  return SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Attachment icons row (top row)
          Row(
            children: [
              _ModernComposerButton(
                icon: Icons.add_rounded,
                tooltip: t.attachTooltip,
                onTap: _pickAndSendDocument,
              ),
              const SizedBox(width: 4),
              _InlineComposerButton(
                icon: Icons.photo_outlined,
                tooltip: t.choosePhotosTooltip,
                onTap: _pickMultipleImages,
              ),
              const SizedBox(width: 4),
              _InlineComposerButton(
                icon: Icons.gif_box_outlined,
                tooltip: 'GIF',
                onTap: _pickGif,
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Message input + Send button (bottom row)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  focusNode: _composerFocus,
                  minLines: 1,
                  maxLines: 8,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).writeAMessage,
                    hintStyle: TextStyle(
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              // Send button - now in the same row as text input
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    ),
                    child: child,
                  );
                },
                child: _hasText || _sending
                    ? _buildSendButton()
                    : _buildInactiveSendButton(),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildSendButton() {
    return Container(
      key: const ValueKey('active-send'),
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color:
            Theme.of(context)
                .primaryColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context)
                .primaryColor
                .withOpacity(0.22),
            blurRadius: 12,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: _sending
            ? const SizedBox(
                width: 19,
                height: 19,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 22,
              ),
        onPressed:
            _sending ? null : _send,
      ),
    );
  }

  Widget _buildInactiveSendButton() {
    return Container(
      key: const ValueKey('inactive-send'),
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color:
            Theme.of(context)
                .dividerColor
                .withOpacity(0.35),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.arrow_upward_rounded,
        size: 21,
        color: Theme.of(context)
            .textTheme
            .bodySmall
            ?.color
            ?.withOpacity(0.45),
      ),
    );
  }
}

// =============================================================================
// MODERN COMPOSER BUTTON
// =============================================================================

class _ModernComposerButton
    extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ModernComposerButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.7),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder:
              const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 50,
            height: 50,
            child: Icon(
              Icons.add_rounded,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// INLINE COMPOSER BUTTON
// =============================================================================

class _InlineComposerButton
    extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _InlineComposerButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        splashRadius: 21,
        icon: Icon(
          icon,
          size: 22,
        ),
        color: Theme.of(context)
            .textTheme
            .bodySmall
            ?.color
            ?.withOpacity(0.7),
        onPressed: onTap,
      ),
    );
  }
}

// =============================================================================
// ACTION TILE
// =============================================================================

class _ActionTile
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(14),
      ),
      leading: Icon(
        icon,
        color: color,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}