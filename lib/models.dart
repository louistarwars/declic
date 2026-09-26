import 'package:flutter/material.dart';

const avatarColors = <Color>[
  Color(0xFFFF4D8D),
  Color(0xFFFF8A3D),
  Color(0xFFFFC53D),
  Color(0xFF3DDC97),
  Color(0xFF3DB8FF),
  Color(0xFF7B61FF),
  Color(0xFFB45CFF),
  Color(0xFFFF5C5C),
];

Color avatarColor(int index) => avatarColors[index.abs() % avatarColors.length];

int _int(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

enum Phase { submission, voting, closed, upcoming }

Phase parsePhase(String? s) => switch (s) {
  'voting' => Phase.voting,
  'closed' => Phase.closed,
  'upcoming' => Phase.upcoming,
  _ => Phase.submission,
};

enum VoteCategory {
  funny('funny', 'La plus drôle', '😂'),
  beautiful('beautiful', 'La plus belle', '😍'),
  original('original', 'La plus originale', '🤯');

  const VoteCategory(this.key, this.label, this.emoji);
  final String key;
  final String label;
  final String emoji;

  static VoteCategory fromKey(String k) => values.firstWhere((c) => c.key == k);
}

class Profile {
  Profile({required this.id, required this.username, required this.avatarEmoji, required this.avatarColor});

  final String id;
  final String username;
  final String avatarEmoji;
  final int avatarColor;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: j['id'] as String,
    username: j['username'] as String? ?? '?',
    avatarEmoji: j['avatar_emoji'] as String? ?? '😎',
    avatarColor: _int(j['avatar_color']),
  );
}

class Group {
  Group({required this.id, required this.name, required this.emoji, required this.inviteCode, required this.voteHour});

  final String id;
  final String name;
  final String emoji;
  final String inviteCode;
  final int voteHour;

  factory Group.fromJson(Map<String, dynamic> j) => Group(
    id: j['id'] as String,
    name: j['name'] as String,
    emoji: j['emoji'] as String? ?? '📸',
    inviteCode: j['invite_code'] as String? ?? '',
    voteHour: _int(j['vote_hour']),
  );
}

class Challenge {
  Challenge({required this.id, required this.groupId, required this.day, required this.text, required this.emoji});

  final String id;
  final String groupId;
  final DateTime day;
  final String text;
  final String emoji;

  factory Challenge.fromJson(Map<String, dynamic> j) => Challenge(
    id: j['id'] as String,
    groupId: j['group_id'] as String,
    day: DateTime.parse(j['day'] as String),
    text: j['text'] as String,
    emoji: j['emoji'] as String? ?? '📸',
  );
}

class GroupSummary {
  GroupSummary({
    required this.group,
    required this.isAdmin,
    required this.memberCount,
    required this.challenge,
    required this.phase,
    required this.submissionCount,
    required this.hasSubmitted,
    required this.myVoteCount,
    required this.streak,
  });

  final Group group;
  final bool isAdmin;
  final int memberCount;
  final Challenge challenge;
  final Phase phase;
  final int submissionCount;
  final bool hasSubmitted;
  final int myVoteCount;
  final int streak;

  factory GroupSummary.fromJson(Map<String, dynamic> j) => GroupSummary(
    group: Group.fromJson(j['group'] as Map<String, dynamic>),
    isAdmin: j['role'] == 'admin',
    memberCount: _int(j['member_count']),
    challenge: Challenge.fromJson(j['challenge'] as Map<String, dynamic>),
    phase: parsePhase(j['phase'] as String?),
    submissionCount: _int(j['submission_count']),
    hasSubmitted: j['has_submitted'] == true,
    myVoteCount: _int(j['my_vote_count']),
    streak: _int(j['streak']),
  );

  /// Action attendue de l'utilisateur, pour mettre un badge sur la carte du groupe.
  bool get needsAction => (phase == Phase.submission && !hasSubmitted) || (phase == Phase.voting && myVoteCount < 3);
}

class TodayState {
  TodayState({
    required this.challenge,
    required this.phase,
    required this.voteHour,
    required this.memberCount,
    required this.submissionCount,
    required this.mySubmission,
    required this.myVoteCount,
    required this.votersDone,
    required this.streak,
  });

  final Challenge challenge;
  final Phase phase;
  final int voteHour;
  final int memberCount;
  final int submissionCount;
  final Submission? mySubmission;
  final int myVoteCount;
  final int votersDone;
  final int streak;

  factory TodayState.fromJson(Map<String, dynamic> j) => TodayState(
    challenge: Challenge.fromJson(j['challenge'] as Map<String, dynamic>),
    phase: parsePhase(j['phase'] as String?),
    voteHour: _int(j['vote_hour']),
    memberCount: _int(j['member_count']),
    submissionCount: _int(j['submission_count']),
    mySubmission: j['my_submission'] == null ? null : Submission.fromJson(j['my_submission'] as Map<String, dynamic>),
    myVoteCount: _int(j['my_vote_count']),
    votersDone: _int(j['voters_done']),
    streak: _int(j['streak']),
  );
}

class Submission {
  Submission({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.photoPath,
    this.caption,
    this.author,
    required this.createdAt,
  });

  final String id;
  final String challengeId;
  final String userId;
  final String photoPath;
  final String? caption;
  final Profile? author;
  final DateTime createdAt;

  /// Rempli après chargement des URL signées.
  String? photoUrl;

  factory Submission.fromJson(Map<String, dynamic> j) => Submission(
    id: j['id'] as String,
    challengeId: j['challenge_id'] as String,
    userId: j['user_id'] as String,
    photoPath: j['photo_path'] as String,
    caption: j['caption'] as String?,
    author: j['profiles'] is Map<String, dynamic> ? Profile.fromJson(j['profiles'] as Map<String, dynamic>) : null,
    createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
  );
}

class Vote {
  Vote({required this.voterId, required this.submissionId, required this.category});

  final String voterId;
  final String submissionId;
  final VoteCategory category;

  factory Vote.fromJson(Map<String, dynamic> j) => Vote(
    voterId: j['voter_id'] as String,
    submissionId: j['submission_id'] as String,
    category: VoteCategory.fromKey(j['category'] as String),
  );
}

class Member {
  Member({required this.profile, required this.isAdmin, required this.joinedAt});

  final Profile profile;
  final bool isAdmin;
  final DateTime joinedAt;

  factory Member.fromJson(Map<String, dynamic> j) => Member(
    profile: Profile.fromJson(j['profiles'] as Map<String, dynamic>),
    isAdmin: j['role'] == 'admin',
    joinedAt: DateTime.tryParse(j['joined_at'] as String? ?? '') ?? DateTime.now(),
  );
}

class LeaderboardEntry {
  LeaderboardEntry({
    required this.profile,
    required this.points,
    required this.participations,
    required this.votesReceived,
    required this.wins,
  });

  final Profile profile;
  final int points;
  final int participations;
  final int votesReceived;
  final int wins;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
    profile: Profile(
      id: j['user_id'] as String,
      username: j['username'] as String? ?? '?',
      avatarEmoji: j['avatar_emoji'] as String? ?? '😎',
      avatarColor: _int(j['avatar_color']),
    ),
    points: _int(j['points']),
    participations: _int(j['participations']),
    votesReceived: _int(j['votes_received']),
    wins: _int(j['wins']),
  );
}

class CustomPrompt {
  CustomPrompt({required this.id, required this.text, required this.emoji, this.createdBy});

  final int id;
  final String text;
  final String emoji;
  final String? createdBy;

  factory CustomPrompt.fromJson(Map<String, dynamic> j) => CustomPrompt(
    id: _int(j['id']),
    text: j['text'] as String,
    emoji: j['emoji'] as String? ?? '📸',
    createdBy: j['created_by'] as String?,
  );
}

/// Résultats d'un défi terminé.
class ChallengeResults {
  ChallengeResults(this.submissions, this.votes);

  final List<Submission> submissions;
  final List<Vote> votes;

  int count(String submissionId, VoteCategory cat) =>
      votes.where((v) => v.submissionId == submissionId && v.category == cat).length;

  int total(String submissionId) => votes.where((v) => v.submissionId == submissionId).length;

  /// Gagnant(s) d'une catégorie (ex-aequo possibles). Vide si aucun vote.
  List<Submission> winners(VoteCategory cat) {
    var best = 0;
    for (final s in submissions) {
      final n = count(s.id, cat);
      if (n > best) best = n;
    }
    if (best == 0) return [];
    return submissions.where((s) => count(s.id, cat) == best).toList();
  }

  List<Submission> get ranked {
    final list = [...submissions];
    list.sort((a, b) => total(b.id).compareTo(total(a.id)));
    return list;
  }
}
