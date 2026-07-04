class AdminPeerProfile {
  const AdminPeerProfile({
    required this.uid,
    required this.displayName,
    this.email,
    this.photoUrl,
  });

  final String uid;
  final String displayName;
  final String? email;
  final String? photoUrl;

  Map<String, dynamic> toCallPayload() {
    return <String, dynamic>{
      'uid': uid,
      'displayName': displayName,
      if (email != null && email!.isNotEmpty) 'email': email,
      if (photoUrl != null && photoUrl!.isNotEmpty) 'photoUrl': photoUrl,
    };
  }
}
