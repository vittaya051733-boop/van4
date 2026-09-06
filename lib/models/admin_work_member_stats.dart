class AdminWorkMemberStats {
  const AdminWorkMemberStats({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.successCount,
    required this.failCount,
    required this.inProgressCount,
    required this.inProgressTitles,
  });

  final String uid;
  final String email;
  final String displayName;
  final int successCount;
  final int failCount;
  final int inProgressCount;
  final List<String> inProgressTitles;

  int get totalHandled => successCount + failCount + inProgressCount;
}
