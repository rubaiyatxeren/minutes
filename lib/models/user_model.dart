class AppUser {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final bool isAnonymous;
  final DateTime? lastSeen;
  final bool isOnline;

  /// Uids this user has blocked. Blocked users can't send them new message
  /// requests and disappear from their "New chat" people picker.
  final List<String> blockedUids;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.isAnonymous = false,
    this.lastSeen,
    this.isOnline = false,
    this.blockedUids = const [],
  });

  bool hasBlocked(String uid) => blockedUids.contains(uid);

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      name: map['name'] ?? 'Unknown',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'],
      isAnonymous: map['isAnonymous'] ?? false,
      lastSeen: map['lastSeen'] != null
          ? DateTime.tryParse(map['lastSeen'].toString())
          : null,
      isOnline: map['isOnline'] ?? false,
      blockedUids: List<String>.from(map['blockedUids'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'isAnonymous': isAnonymous,
      'lastSeen': DateTime.now().toIso8601String(),
      'isOnline': isOnline,
      'blockedUids': blockedUids,
    };
  }
}
