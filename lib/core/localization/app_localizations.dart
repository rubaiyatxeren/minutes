import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Central localization store for the app. Supports English (`en`) and
/// Simplified Chinese (`zh`).
///
/// Usage in widgets:
/// ```dart
/// final t = AppLocalizations.of(context);
/// Text(t.settings)
/// ```
///
/// To add a new string:
///   1. Add a getter below (e.g. `String get foo => _t('foo');`)
///   2. Add the English value to `_en` and the Chinese value to `_zh`.
/// Any screen not yet migrated to this system simply keeps its existing
/// hardcoded English text — nothing else breaks if a key is missing,
/// `_t()` falls back to the English string (or the key itself).
class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const supportedLocales = [Locale('en'), Locale('zh')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String get _lang => locale.languageCode == 'zh' ? 'zh' : 'en';

  /// Mirrors the active language for code that has no [BuildContext] to
  /// call [of] with (e.g. background services building notification
  /// text). [LocaleProvider] keeps this in sync whenever the user's
  /// language preference loads or changes.
  static String currentLanguageCode = 'en';

  /// Static-context equivalent of the instance getters below, for the
  /// same non-widget callers described above.
  static String tGlobal(String key) {
    final map = currentLanguageCode == 'zh' ? _zh : _en;
    return map[key] ?? _en[key] ?? key;
  }

  static String hostCallEndedGlobal(String hostName) => currentLanguageCode == 'zh'
      ? '$hostName的通话已结束'
      : "$hostName's call has ended";

  String _t(String key) {
    final map = _lang == 'zh' ? _zh : _en;
    return map[key] ?? _en[key] ?? key;
  }

  // ---- App ----
  String get appName => _t('appName');

  // ---- Onboarding ----
  String get onboardTitle1 => _t('onboardTitle1');
  String get onboardBody1 => _t('onboardBody1');
  String get onboardTitle2 => _t('onboardTitle2');
  String get onboardBody2 => _t('onboardBody2');
  String get onboardTitle3 => _t('onboardTitle3');
  String get onboardBody3 => _t('onboardBody3');
  String get getStarted => _t('getStarted');
  String get skip => _t('skip');
  String get next => _t('next');

  // ---- Auth ----
  String get welcomeBack => _t('welcomeBack');
  String get signInToContinue => _t('signInToContinue');
  String get createAccount => _t('createAccount');
  String get email => _t('email');
  String get password => _t('password');
  String get fullName => _t('fullName');
  String get signIn => _t('signIn');
  String get signUp => _t('signUp');
  String get continueWithGoogle => _t('continueWithGoogle');
  String get joinAnonymously => _t('joinAnonymously');
  String get noAccount => _t('noAccount');
  String get haveAccount => _t('haveAccount');
  String get orDivider => _t('orDivider');
  String get enterValidEmail => _t('enterValidEmail');
  String get minSixChars => _t('minSixChars');
  String get incorrectCredentials => _t('incorrectCredentials');
  String get networkError => _t('networkError');
  String get somethingWentWrong => _t('somethingWentWrong');

  // ---- Home / navigation ----
  String get navChats => _t('navChats');
  String get navMeetings => _t('navMeetings');
  String get navSettings => _t('navSettings');

  // ---- Settings screen ----
  String get settings => _t('settings');
  String get appearance => _t('appearance');
  String get light => _t('light');
  String get dark => _t('dark');
  String get systemDefault => _t('systemDefault');
  String get preferences => _t('preferences');
  String get messageSound => _t('messageSound');
  String get messageSoundSubtitle => _t('messageSoundSubtitle');
  String get language => _t('language');
  String get languageSubtitle => _t('languageSubtitle');
  String get callSettings => _t('callSettings');
  String get defaultCallQuality => _t('defaultCallQuality');
  String get defaultCallQualitySubtitle => _t('defaultCallQualitySubtitle');
  String get qualityAuto => _t('qualityAuto');
  String get qualityHigh => _t('qualityHigh');
  String get qualityDataSaver => _t('qualityDataSaver');
  String get joinCallsMuted => _t('joinCallsMuted');
  String get joinCallsMutedSubtitle => _t('joinCallsMutedSubtitle');
  String get notifications => _t('notifications');
  String get pushNotifications => _t('pushNotifications');
  String get pushNotificationsSubtitle => _t('pushNotificationsSubtitle');
  String get account => _t('account');
  String get editProfile => _t('editProfile');
  String get resetPassword => _t('resetPassword');
  String get sendResetLinkTo => _t('sendResetLinkTo');
  String get signOut => _t('signOut');
  String get signOutConfirmTitle => _t('signOutConfirmTitle');
  String get signOutConfirmBody => _t('signOutConfirmBody');
  String get cancel => _t('cancel');
  String get about => _t('about');
  String get helpAndSupport => _t('helpAndSupport');
  String get privacyPolicy => _t('privacyPolicy');
  String get resetEmailSent => _t('resetEmailSent');
  String get resetEmailFailed => _t('resetEmailFailed');
  String get guest => _t('guest');
  String get anonymousSession => _t('anonymousSession');
  String get chooseLanguage => _t('chooseLanguage');

  // ---- Meetings ----
  String get newMeeting => _t('newMeeting');
  String get joinMeeting => _t('joinMeeting');
  String get roomId => _t('roomId');
  String get startWithVideoOff => _t('startWithVideoOff');
  String get startWithAudioMuted => _t('startWithAudioMuted');
  String get lowBandwidthMode => _t('lowBandwidthMode');
  String get lowBandwidthModeSubtitle => _t('lowBandwidthModeSubtitle');

  // ---- Call summary sheet ----
  String get callEnded => _t('callEnded');
  String get duration => _t('duration');
  String get participants => _t('participants');
  String get done => _t('done');

  // ---- Meeting history ----
  String get meetingHistory => _t('meetingHistory');
  String get noCallsYet => _t('noCallsYet');
  String get noCallsYetSubtitle => _t('noCallsYetSubtitle');
  String get ongoing => _t('ongoing');
  String get ended => _t('ended');
  String get rejoin => _t('rejoin');
  String get groupCall => _t('groupCall');

  // ---- Chats tab / list ----
  String get noChatsYet => _t('noChatsYet');
  String get noChatsYetSubtitle => _t('noChatsYetSubtitle');
  String get newChat => _t('newChat');
  String get searchChats => _t('searchChats');
  String get typing => _t('typing');
  String get chatRequests => _t('chatRequests');
  String get delete => _t('delete');
  String get mute => _t('mute');
  String get unmute => _t('unmute');
  String get pin => _t('pin');
  String get unpin => _t('unpin');

  // ---- Notifications ----
  String get noNotificationsYet => _t('noNotificationsYet');
  String get noNotificationsYetSubtitle => _t('noNotificationsYetSubtitle');
  String get markAllAsRead => _t('markAllAsRead');

  // ---- Edit profile ----
  String get saveChanges => _t('saveChanges');
  String get displayName => _t('displayName');
  String get profilePhoto => _t('profilePhoto');
  String get changePhoto => _t('changePhoto');
  String get profileUpdated => _t('profileUpdated');

  // ---- Requests / add participants ----
  String get accept => _t('accept');
  String get decline => _t('decline');
  String get addParticipants => _t('addParticipants');
  String get searchPeople => _t('searchPeople');
  String get add => _t('add');
  String get noResultsFound => _t('noResultsFound');
  String get startAChat => _t('startAChat');
  String get leave => _t('leave');
  String get leaveGroupQuestion => _t('leaveGroupQuestion');
  String get deleteChatQuestion => _t('deleteChatQuestion');
  String get couldntLoadChats => _t('couldntLoadChats');
  String get notificationsTooltip => _t('notificationsTooltip');
  String get clearAll => _t('clearAll');
  String get clearAllNotificationsQuestion => _t('clearAllNotificationsQuestion');
  String get cantBeUndone => _t('cantBeUndone');
  String get clear => _t('clear');
  String get messageRequests => _t('messageRequests');
  String get noPendingRequests => _t('noPendingRequests');
  String get noPendingRequestsSubtitle => _t('noPendingRequestsSubtitle');
  String get wantsToMessageYou => _t('wantsToMessageYou');
  String get block => _t('block');
  String get blockThisPersonQuestion => _t('blockThisPersonQuestion');
  String get everyoneAlreadyInGroup => _t('everyoneAlreadyInGroup');
  String get noOneFound => _t('noOneFound');
  String get selectPeopleToAdd => _t('selectPeopleToAdd');
  String get participantsScreenTitle => _t('participantsScreenTitle');
  String get removeMemberQuestion => _t('removeMemberQuestion');
  String get remove => _t('remove');
  String get willBeRemovedFromGroup => _t('willBeRemovedFromGroup');
  String get leaveGroup => _t('leaveGroup');
  String get wontSeeNewMessages => _t('wontSeeNewMessages');
  String get groupCreator => _t('groupCreator');
  String get you => _t('you');
  String get participantsCountLabel => _t('participantsCountLabel');
  String get nameCantBeEmpty => _t('nameCantBeEmpty');
  String get save => _t('save');
  String get yourName => _t('yourName');
  String get emailCantBeChanged => _t('emailCantBeChanged');
  String get sendPasswordResetEmail => _t('sendPasswordResetEmail');
  String get passwordResetEmailSent => _t('passwordResetEmailSent');
  String get newGroup => _t('newGroup');
  String get newChatTitle => _t('newChatTitle');
  String get directMessage => _t('directMessage');
  String get tapToMessage => _t('tapToMessage');
  String get groupName => _t('groupName');
  String get selectAtLeast2 => _t('selectAtLeast2');
  String get createGroup => _t('createGroup');
  String get writeAMessage => _t('writeAMessage');
  String get groupInfo => _t('groupInfo');
  String get contactInfo => _t('contactInfo');
  String get blocked => _t('blocked');
  String get blockQuestion => _t('blockQuestion');
  String get blockExplain => _t('blockExplain');

  // ---- Message bubble ----
  String get pinnedLabel => _t('pinnedLabel');
  String get editedLabel => _t('editedLabel');
  String get voiceMessage => _t('voiceMessage');
  String get videoCall => _t('videoCall');
  String get videoCallEndedLabel => _t('videoCallEndedLabel');
  String get thisCallHasEnded => _t('thisCallHasEnded');
  String get callEndedShort => _t('callEndedShort');
  String get joinCallButton => _t('joinCallButton');
  String get videoCallStartedText => _t('videoCallStartedText');
  String get messageWasDeleted => _t('messageWasDeleted');

  // ---- Chats tab ----
  String get unpinChatOption => _t('unpinChatOption');
  String get pinChatOption => _t('pinChatOption');
  String get unmuteNotifOption => _t('unmuteNotifOption');
  String get muteNotifOption => _t('muteNotifOption');
  String get requestSent => _t('requestSent');
  String get sayHello => _t('sayHello');
  String get requestSentBanner => _t('requestSentBanner');

  // ---- Chat screen ----
  String get messageFailedRetry => _t('messageFailedRetry');
  String get retry => _t('retry');
  String get downloadingFile => _t('downloadingFile');
  String get reply => _t('reply');
  String get react => _t('react');
  String get download => _t('download');
  String get editAction => _t('editAction');
  String get someone => _t('someone');
  String get onlineStatus => _t('onlineStatus');
  String get offline => _t('offline');
  String get startVideoCallTooltip => _t('startVideoCallTooltip');
  String get noMessagesYet => _t('noMessagesYet');
  String get editingMessage => _t('editingMessage');
  String get mediaPlaceholder => _t('mediaPlaceholder');
  String get attachTooltip => _t('attachTooltip');
  String get choosePhotosTooltip => _t('choosePhotosTooltip');

  // ---- Chat info screen ----
  String get seeAll => _t('seeAll');
  String get noPhotosVideosYet => _t('noPhotosVideosYet');
  String get noLinksSharedYet => _t('noLinksSharedYet');
  String get copyLinkTooltip => _t('copyLinkTooltip');
  String get linkCopied => _t('linkCopied');
  String get couldntOpenLink => _t('couldntOpenLink');
  String get noFilesSharedYet => _t('noFilesSharedYet');
  String get mutedState => _t('mutedState');

  // ---- Meeting history ----
  String get callInProgress => _t('callInProgress');
  String get endedCallStatus => _t('endedCallStatus');
  String get host => _t('host');
  String get startedAt => _t('startedAt');
  String get endedAt => _t('endedAt');
  String get youHosted => _t('youHosted');
  String get soloCall => _t('soloCall');
  String get inProgress => _t('inProgress');
  String get callAgainTooltip => _t('callAgainTooltip');

  // ---- Meetings tab ----
  String get recentLabel => _t('recentLabel');
  String get startOrJoinSubtitle => _t('startOrJoinSubtitle');
  String get newMeetingSubtitle => _t('newMeetingSubtitle');
  String get joinMeetingSubtitle => _t('joinMeetingSubtitle');
  String get meetingHistorySubtitle => _t('meetingHistorySubtitle');

  // ---- Misc ----
  String get groupCreatedText => _t('groupCreatedText');
  String get unknownUser => _t('unknownUser');
  String get today => _t('today');
  String get yesterday => _t('yesterday');
  String get filterAll => _t('filterAll');
  String get filterCalls => _t('filterCalls');
  String get filterMessages => _t('filterMessages');
  String get filterOther => _t('filterOther');
  String get noNotificationsHere => _t('noNotificationsHere');
  String get tryDifferentFilter => _t('tryDifferentFilter');

  // ---- Templated strings (parameterized) ----
  String greeting(String name) =>
      _lang == 'zh' ? '你好，$name 👋' : 'Hi, $name 👋';

  String youMessagePrefix(String msg) =>
      _lang == 'zh' ? '你：$msg' : 'You: $msg';

  String leaveGroupWarning(String title) => _lang == 'zh'
      ? '您将不再收到来自"$title"的消息。'
      : 'You will stop receiving messages from "$title".';

  String deleteChatWarning(String title) => _lang == 'zh'
      ? '这将从您的列表中移除与 $title 的对话。'
      : 'This removes the conversation with $title from your list.';

  String failedUploadImages(String err) =>
      _lang == 'zh' ? '图片上传失败：$err' : 'Failed to upload image(s): $err';

  String failedUploadFile(String err) =>
      _lang == 'zh' ? '文件上传失败：$err' : 'Failed to upload file: $err';

  String couldNotOpenFile(String msg) =>
      _lang == 'zh' ? '无法打开文件：$msg' : 'Could not open file: $msg';

  String errorDownloadingFile(String err) =>
      _lang == 'zh' ? '下载/打开文件时出错：$err' : 'Error downloading/opening file: $err';

  String startedCallNotifTitle(String name) =>
      _lang == 'zh' ? '$name 发起了一通通话' : '$name started a call';

  String tapToJoinBody(String roomName) =>
      _lang == 'zh' ? '点击加入 · 房间 $roomName' : 'Tap to join · room $roomName';

  String typingLabel(List<String> names, bool isGroup) {
    if (!isGroup) return typing;
    final joined = names.join('、');
    if (_lang == 'zh') return '$joined 正在输入…';
    final joinedEn = names.join(', ');
    return '$joinedEn ${names.length > 1 ? 'are' : 'is'} typing…';
  }

  String membersCount(int count) =>
      _lang == 'zh' ? '$count 位成员' : '$count members';

  String lastSeenLabel(String time) =>
      _lang == 'zh' ? '最后活跃于 $time' : 'Last seen $time';

  String sayHiTo(String title) =>
      _lang == 'zh' ? '跟 $title 打个招呼吧 👋' : 'Say hi to $title 👋';

  String replyingTo(String name) =>
      _lang == 'zh' ? '回复 $name' : 'Replying to $name';

  String roomIdInline(String id) =>
      _lang == 'zh' ? '房间号：$id' : 'Room ID: $id';

  String lastedFor(String duration) =>
      _lang == 'zh' ? '通话时长 $duration' : 'Lasted $duration';

  String couldntUpdateGroupPhoto(String err) =>
      _lang == 'zh' ? '无法更新群组头像：$err' : "Couldn't update group photo: $err";

  String couldntSave(String err) =>
      _lang == 'zh' ? '无法保存：$err' : "Couldn't save: $err";

  String downloadFailed(String err) =>
      _lang == 'zh' ? '下载失败：$err' : 'Download failed: $err';

  String sharedBy(String name) =>
      _lang == 'zh' ? '由 $name 分享' : 'Shared by $name';

  String couldntLoadMeetingHistory(String err) => _lang == 'zh'
      ? '无法加载会议记录\n$err'
      : "Couldn't load meeting history\n$err";

  String withNames(String names) =>
      _lang == 'zh' ? '与 $names' : 'With $names';

  String participantsCountParen(int count) =>
      _lang == 'zh' ? '参与者（$count）' : 'Participants ($count)';

  String youSuffix(String name) => _lang == 'zh' ? '$name（你）' : '$name (You)';

  String participantsTimeLabel(int count, String time) {
    if (_lang == 'zh') return '$count 位参与者 · $time';
    return '$count participant${count == 1 ? '' : 's'} · $time';
  }

  String wantsToSendMessage(String name) =>
      _lang == 'zh' ? '$name 想给您发送消息' : '$name wants to send you a message';

  String weekdayName(int weekday) {
    const en = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const zh = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final list = _lang == 'zh' ? zh : en;
    return list[weekday - 1];
  }

  static const Map<String, String> _en = {
    'appName': 'Minutes',
    'onboardTitle1': 'Meet without limits',
    'onboardBody1':
        'Crystal-clear video & audio conferencing for teams of any size.',
    'onboardTitle2': 'Chat that keeps up',
    'onboardBody2':
        'Group & personal chats, threads, reactions and file sharing — all in one place.',
    'onboardTitle3': 'Built for real teams',
    'onboardBody3':
        'Screen share, raise hand, recordings and more — right when you need them.',
    'getStarted': 'Get Started',
    'skip': 'Skip',
    'next': 'Next',
    'welcomeBack': 'Welcome back',
    'signInToContinue': 'Sign in to continue',
    'createAccount': 'Create your account',
    'email': 'Email',
    'password': 'Password',
    'fullName': 'Full name',
    'signIn': 'Sign In',
    'signUp': 'Sign Up',
    'continueWithGoogle': 'Continue with Google',
    'joinAnonymously': 'Join a meeting as guest',
    'noAccount': "Don't have an account? ",
    'haveAccount': 'Already have an account? ',
    'orDivider': 'or',
    'enterValidEmail': 'Enter a valid email',
    'minSixChars': 'Minimum 6 characters',
    'incorrectCredentials': 'Incorrect email or password.',
    'networkError': 'Network error. Check your connection.',
    'somethingWentWrong': 'Something went wrong. Please try again.',
    'navChats': 'Chats',
    'navMeetings': 'Meetings',
    'navSettings': 'Settings',
    'settings': 'Settings',
    'appearance': 'Appearance',
    'light': 'Light',
    'dark': 'Dark',
    'systemDefault': 'System default',
    'preferences': 'Preferences',
    'messageSound': 'Message sound',
    'messageSoundSubtitle': 'Play a sound for new messages',
    'language': 'Language',
    'languageSubtitle': 'English',
    'callSettings': 'Video & audio calls',
    'defaultCallQuality': 'Default call quality',
    'defaultCallQualitySubtitle':
        'Applied automatically to new calls on this device',
    'qualityAuto': 'Auto (recommended)',
    'qualityHigh': 'High quality',
    'qualityDataSaver': 'Data saver',
    'joinCallsMuted': 'Join calls with mic muted',
    'joinCallsMutedSubtitle': 'Avoid noise when entering a busy meeting',
    'notifications': 'Notifications',
    'pushNotifications': 'Push notifications',
    'pushNotificationsSubtitle': 'Get notified about messages and calls',
    'account': 'Account',
    'editProfile': 'Edit profile',
    'resetPassword': 'Reset password',
    'sendResetLinkTo': 'Send a reset link to',
    'signOut': 'Sign out',
    'signOutConfirmTitle': 'Sign out?',
    'signOutConfirmBody': 'You can sign back in anytime.',
    'cancel': 'Cancel',
    'about': 'About',
    'helpAndSupport': 'Help & support',
    'privacyPolicy': 'Privacy policy',
    'resetEmailSent': 'Password reset email sent to',
    'resetEmailFailed': "Couldn't send reset email",
    'guest': 'Guest',
    'anonymousSession': 'Anonymous session',
    'chooseLanguage': 'Choose language',
    'newMeeting': 'New Meeting',
    'joinMeeting': 'Join Meeting',
    'roomId': 'Room ID',
    'startWithVideoOff': 'Start with video off',
    'startWithAudioMuted': 'Start with audio muted',
    'lowBandwidthMode': 'Low bandwidth mode',
    'lowBandwidthModeSubtitle': 'Caps video quality for weak connections',
    'callEnded': 'Call ended',
    'duration': 'Duration',
    'participants': 'Participants',
    'done': 'Done',
    'meetingHistory': 'Meeting history',
    'noCallsYet': 'No calls yet',
    'noCallsYetSubtitle': 'Your call history will show up here',
    'ongoing': 'Ongoing',
    'ended': 'Ended',
    'rejoin': 'Rejoin',
    'groupCall': 'Group call',
    'noChatsYet': 'No chats yet',
    'noChatsYetSubtitle': 'Start a new conversation to see it here',
    'newChat': 'New chat',
    'searchChats': 'Search chats',
    'typing': 'typing…',
    'chatRequests': 'Chat requests',
    'delete': 'Delete',
    'mute': 'Mute',
    'unmute': 'Unmute',
    'pin': 'Pin',
    'unpin': 'Unpin',
    'noNotificationsYet': 'No notifications yet',
    'noNotificationsYetSubtitle': "We'll let you know when something happens",
    'markAllAsRead': 'Mark all as read',
    'saveChanges': 'Save changes',
    'displayName': 'Display name',
    'profilePhoto': 'Profile photo',
    'changePhoto': 'Change photo',
    'profileUpdated': 'Profile updated',
    'accept': 'Accept',
    'decline': 'Decline',
    'addParticipants': 'Add participants',
    'searchPeople': 'Search people',
    'add': 'Add',
    'noResultsFound': 'No results found',
    'startAChat': 'Start a chat',
    'leave': 'Leave',
    'leaveGroupQuestion': 'Leave group?',
    'deleteChatQuestion': 'Delete chat?',
    'couldntLoadChats': "Couldn't load chats",
    'notificationsTooltip': 'Notifications',
    'clearAll': 'Clear all',
    'clearAllNotificationsQuestion': 'Clear all notifications?',
    'cantBeUndone': "This can't be undone.",
    'clear': 'Clear',
    'messageRequests': 'Message requests',
    'noPendingRequests': 'No pending requests',
    'noPendingRequestsSubtitle':
        "When someone new messages you for the first time, it'll show up here until you accept it.",
    'wantsToMessageYou': 'Wants to send you a message',
    'block': 'Block',
    'blockThisPersonQuestion': 'Block this person?',
    'everyoneAlreadyInGroup': 'Everyone is already in this group',
    'noOneFound': 'No one found',
    'selectPeopleToAdd': 'Select people to add',
    'participantsScreenTitle': 'Participants',
    'removeMemberQuestion': 'Remove member?',
    'remove': 'Remove',
    'willBeRemovedFromGroup': 'will be removed from this group.',
    'leaveGroup': 'Leave group',
    'wontSeeNewMessages': "You won't be able to see new messages here.",
    'groupCreator': 'Group creator',
    'you': 'You',
    'participantsCountLabel': 'PARTICIPANTS',
    'nameCantBeEmpty': "Name can't be empty",
    'save': 'Save',
    'yourName': 'Your name',
    'emailCantBeChanged': "Email can't be changed here.",
    'sendPasswordResetEmail': 'Send password reset email',
    'passwordResetEmailSent': 'Password reset email sent',
    'newGroup': 'New group',
    'newChatTitle': 'New Chat',
    'directMessage': 'Direct message',
    'tapToMessage': 'Tap to message',
    'groupName': 'Group name',
    'selectAtLeast2': 'Select at least 2 people',
    'createGroup': 'Create group',
    'writeAMessage': 'Write a message...',
    'groupInfo': 'Group info',
    'contactInfo': 'Contact info',
    'blocked': 'Blocked',
    'blockQuestion': 'Block',
    'blockExplain':
        "They won't be able to send you new messages. This won't delete your existing conversation.",
    'pinnedLabel': 'Pinned',
    'editedLabel': 'edited',
    'voiceMessage': 'Voice message',
    'videoCall': 'Video call',
    'videoCallEndedLabel': 'Video call ended',
    'thisCallHasEnded': 'This call has ended',
    'callEndedShort': 'Call ended',
    'joinCallButton': 'Join Call',
    'videoCallStartedText': 'Video call started',
    'messageWasDeleted': 'This message was deleted',
    'unpinChatOption': 'Unpin chat',
    'pinChatOption': 'Pin chat',
    'unmuteNotifOption': 'Unmute notifications',
    'muteNotifOption': 'Mute notifications',
    'requestSent': 'Request sent',
    'sayHello': 'Say hello 👋',
    'requestSentBanner':
        'Message request sent — they can reply once they accept it.',
    'messageFailedRetry': 'Message failed to send — tap send to retry',
    'retry': 'Retry',
    'downloadingFile': 'Downloading file...',
    'reply': 'Reply',
    'react': 'React',
    'download': 'Download',
    'editAction': 'Edit',
    'someone': 'Someone',
    'onlineStatus': 'Online',
    'offline': 'Offline',
    'startVideoCallTooltip': 'Start video call',
    'noMessagesYet': 'No messages yet',
    'editingMessage': 'Editing message',
    'mediaPlaceholder': '📷 Media',
    'attachTooltip': 'Attach',
    'choosePhotosTooltip': 'Choose photos',
    'seeAll': 'See all',
    'noPhotosVideosYet': 'No photos or videos yet',
    'noLinksSharedYet': 'No links shared yet',
    'copyLinkTooltip': 'Copy link',
    'linkCopied': 'Link copied',
    'couldntOpenLink': "Couldn't open link",
    'noFilesSharedYet': 'No files shared yet',
    'mutedState': 'Muted',
    'callInProgress': 'Call in progress',
    'endedCallStatus': 'Ended call',
    'host': 'Host',
    'startedAt': 'Started At',
    'endedAt': 'Ended At',
    'youHosted': 'You hosted',
    'soloCall': 'Solo call',
    'inProgress': 'In progress',
    'callAgainTooltip': 'Call again',
    'recentLabel': 'RECENT',
    'startOrJoinSubtitle': 'Start or join a video call in seconds',
    'newMeetingSubtitle': 'Start an instant meeting with password & controls',
    'joinMeetingSubtitle': 'Enter a room ID or link — guests welcome',
    'meetingHistorySubtitle': 'See past calls, duration & participants',
    'groupCreatedText': 'Group created',
    'unknownUser': 'Unknown',
    'today': 'Today',
    'yesterday': 'Yesterday',
    'filterAll': 'All',
    'filterCalls': 'Calls',
    'filterMessages': 'Messages',
    'filterOther': 'Other',
    'noNotificationsHere': 'No notifications here',
    'tryDifferentFilter': 'Try a different filter above.',
  };

  static const Map<String, String> _zh = {
    'appName': 'Minutes',
    'onboardTitle1': '畅享无限视频通话',
    'onboardBody1': '为任意规模的团队提供清晰流畅的音视频会议体验。',
    'onboardTitle2': '聊天永不掉线',
    'onboardBody2': '群聊、私聊、话题讨论、表情回应与文件分享，一应俱全。',
    'onboardTitle3': '为真实团队而生',
    'onboardBody3': '屏幕共享、举手发言、会议录制等功能，随时为你待命。',
    'getStarted': '开始使用',
    'skip': '跳过',
    'next': '下一步',
    'welcomeBack': '欢迎回来',
    'signInToContinue': '登录以继续',
    'createAccount': '创建账户',
    'email': '邮箱',
    'password': '密码',
    'fullName': '姓名',
    'signIn': '登录',
    'signUp': '注册',
    'continueWithGoogle': '使用 Google 继续',
    'joinAnonymously': '以访客身份加入会议',
    'noAccount': '还没有账户？',
    'haveAccount': '已有账户？',
    'orDivider': '或',
    'enterValidEmail': '请输入有效的邮箱地址',
    'minSixChars': '密码至少需要 6 位',
    'incorrectCredentials': '邮箱或密码不正确。',
    'networkError': '网络错误，请检查您的网络连接。',
    'somethingWentWrong': '出现问题，请重试。',
    'navChats': '聊天',
    'navMeetings': '会议',
    'navSettings': '设置',
    'settings': '设置',
    'appearance': '外观',
    'light': '浅色',
    'dark': '深色',
    'systemDefault': '跟随系统',
    'preferences': '偏好设置',
    'messageSound': '消息提示音',
    'messageSoundSubtitle': '收到新消息时播放提示音',
    'language': '语言',
    'languageSubtitle': '中文',
    'callSettings': '音视频通话',
    'defaultCallQuality': '默认通话画质',
    'defaultCallQualitySubtitle': '将自动应用于此设备上发起的新通话',
    'qualityAuto': '自动（推荐）',
    'qualityHigh': '高清',
    'qualityDataSaver': '省流量模式',
    'joinCallsMuted': '加入通话时静音麦克风',
    'joinCallsMutedSubtitle': '进入热闹的会议时避免噪音干扰',
    'notifications': '通知',
    'pushNotifications': '推送通知',
    'pushNotificationsSubtitle': '接收消息与通话的通知提醒',
    'account': '账户',
    'editProfile': '编辑资料',
    'resetPassword': '重置密码',
    'sendResetLinkTo': '发送重置链接至',
    'signOut': '退出登录',
    'signOutConfirmTitle': '退出登录？',
    'signOutConfirmBody': '您可以随时重新登录。',
    'cancel': '取消',
    'about': '关于',
    'helpAndSupport': '帮助与支持',
    'privacyPolicy': '隐私政策',
    'resetEmailSent': '密码重置邮件已发送至',
    'resetEmailFailed': '重置邮件发送失败',
    'guest': '访客',
    'anonymousSession': '匿名会话',
    'chooseLanguage': '选择语言',
    'newMeeting': '新建会议',
    'joinMeeting': '加入会议',
    'roomId': '房间号',
    'startWithVideoOff': '开始时关闭摄像头',
    'startWithAudioMuted': '开始时静音麦克风',
    'lowBandwidthMode': '低带宽模式',
    'lowBandwidthModeSubtitle': '在网络较弱时限制视频画质',
    'callEnded': '通话已结束',
    'duration': '通话时长',
    'participants': '参与人数',
    'done': '完成',
    'meetingHistory': '会议记录',
    'noCallsYet': '暂无通话记录',
    'noCallsYetSubtitle': '您的通话记录将显示在这里',
    'ongoing': '进行中',
    'ended': '已结束',
    'rejoin': '重新加入',
    'groupCall': '群组通话',
    'noChatsYet': '暂无聊天',
    'noChatsYetSubtitle': '开始新的对话后将显示在这里',
    'newChat': '新建聊天',
    'searchChats': '搜索聊天',
    'typing': '正在输入…',
    'chatRequests': '聊天请求',
    'delete': '删除',
    'mute': '静音',
    'unmute': '取消静音',
    'pin': '置顶',
    'unpin': '取消置顶',
    'noNotificationsYet': '暂无通知',
    'noNotificationsYetSubtitle': '有新动态时会在这里通知您',
    'markAllAsRead': '全部标记为已读',
    'saveChanges': '保存更改',
    'displayName': '显示名称',
    'profilePhoto': '头像',
    'changePhoto': '更换头像',
    'profileUpdated': '资料已更新',
    'accept': '接受',
    'decline': '拒绝',
    'addParticipants': '添加参与者',
    'searchPeople': '搜索联系人',
    'add': '添加',
    'noResultsFound': '未找到结果',
    'startAChat': '开始聊天',
    'leave': '退出',
    'leaveGroupQuestion': '退出群组？',
    'deleteChatQuestion': '删除聊天？',
    'couldntLoadChats': '无法加载聊天',
    'notificationsTooltip': '通知',
    'clearAll': '清空全部',
    'clearAllNotificationsQuestion': '清空所有通知？',
    'cantBeUndone': '此操作无法撤销。',
    'clear': '清空',
    'messageRequests': '消息请求',
    'noPendingRequests': '暂无待处理请求',
    'noPendingRequestsSubtitle': '当有新用户第一次给您发消息时，会显示在这里，直到您接受为止。',
    'wantsToMessageYou': '想给您发送消息',
    'block': '屏蔽',
    'blockThisPersonQuestion': '屏蔽此人？',
    'everyoneAlreadyInGroup': '大家都已在此群组中',
    'noOneFound': '未找到相关用户',
    'selectPeopleToAdd': '选择要添加的联系人',
    'participantsScreenTitle': '参与者',
    'removeMemberQuestion': '移除该成员？',
    'remove': '移除',
    'willBeRemovedFromGroup': '将被移出此群组。',
    'leaveGroup': '退出群组',
    'wontSeeNewMessages': '您将无法再看到这里的新消息。',
    'groupCreator': '群主',
    'you': '你',
    'participantsCountLabel': '位参与者',
    'nameCantBeEmpty': '姓名不能为空',
    'save': '保存',
    'yourName': '您的姓名',
    'emailCantBeChanged': '邮箱地址在此处无法更改。',
    'sendPasswordResetEmail': '发送密码重置邮件',
    'passwordResetEmailSent': '密码重置邮件已发送',
    'newGroup': '新建群组',
    'newChatTitle': '新建聊天',
    'directMessage': '私聊',
    'tapToMessage': '点击发送消息',
    'groupName': '群组名称',
    'selectAtLeast2': '请至少选择 2 位联系人',
    'createGroup': '创建群组',
    'writeAMessage': '输入消息…',
    'groupInfo': '群组信息',
    'contactInfo': '联系人信息',
    'blocked': '已屏蔽',
    'blockQuestion': '屏蔽',
    'blockExplain': '对方将无法再给您发送新消息，但不会删除现有的聊天记录。',
    'pinnedLabel': '置顶',
    'editedLabel': '已编辑',
    'voiceMessage': '语音消息',
    'videoCall': '视频通话',
    'videoCallEndedLabel': '视频通话已结束',
    'thisCallHasEnded': '此通话已结束',
    'callEndedShort': '通话已结束',
    'joinCallButton': '加入通话',
    'videoCallStartedText': '发起了视频通话',
    'messageWasDeleted': '此消息已被删除',
    'unpinChatOption': '取消置顶聊天',
    'pinChatOption': '置顶聊天',
    'unmuteNotifOption': '取消通知静音',
    'muteNotifOption': '通知静音',
    'requestSent': '请求已发送',
    'sayHello': '打个招呼吧 👋',
    'requestSentBanner': '消息请求已发送 — 对方接受后即可回复。',
    'messageFailedRetry': '消息发送失败 — 点击发送重试',
    'retry': '重试',
    'downloadingFile': '正在下载文件…',
    'reply': '回复',
    'react': '表情回应',
    'download': '下载',
    'editAction': '编辑',
    'someone': '某人',
    'onlineStatus': '在线',
    'offline': '离线',
    'startVideoCallTooltip': '发起视频通话',
    'noMessagesYet': '暂无消息',
    'editingMessage': '正在编辑消息',
    'mediaPlaceholder': '📷 媒体文件',
    'attachTooltip': '附件',
    'choosePhotosTooltip': '选择照片',
    'seeAll': '查看全部',
    'noPhotosVideosYet': '暂无照片或视频',
    'noLinksSharedYet': '暂无分享的链接',
    'copyLinkTooltip': '复制链接',
    'linkCopied': '链接已复制',
    'couldntOpenLink': '无法打开链接',
    'noFilesSharedYet': '暂无分享的文件',
    'mutedState': '已静音',
    'callInProgress': '通话进行中',
    'endedCallStatus': '通话已结束',
    'host': '主持人',
    'startedAt': '开始时间',
    'endedAt': '结束时间',
    'youHosted': '您是主持人',
    'soloCall': '单人通话',
    'inProgress': '进行中',
    'callAgainTooltip': '再次拨打',
    'recentLabel': '最近',
    'startOrJoinSubtitle': '几秒钟内即可开始或加入视频通话',
    'newMeetingSubtitle': '发起一个带密码和控制权限的即时会议',
    'joinMeetingSubtitle': '输入房间号或链接 — 访客也可加入',
    'meetingHistorySubtitle': '查看历史通话、时长与参与者',
    'groupCreatedText': '群组已创建',
    'unknownUser': '未知用户',
    'today': '今天',
    'yesterday': '昨天',
    'filterAll': '全部',
    'filterCalls': '通话',
    'filterMessages': '消息',
    'filterOther': '其他',
    'noNotificationsHere': '这里没有通知',
    'tryDifferentFilter': '请尝试上方其他筛选条件。',
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    if (kDebugMode) {
      debugPrint('AppLocalizations: loading ${locale.languageCode}');
    }
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
