import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models.dart';
import '../util.dart';

/// Point d'accès unique au backend Supabase.
class Api {
  static SupabaseClient get _db => Supabase.instance.client;

  static String? get myId => _db.auth.currentUser?.id;

  // ---------------------------------------------------------------- Auth

  static Future<void> signUp({
    required String email,
    required String password,
    required String username,
    required String avatarEmoji,
    required int avatarColor,
  }) async {
    final res = await _db.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: AppConfig.authRedirectUrl,
      data: {'username': username.trim(), 'avatar_emoji': avatarEmoji, 'avatar_color': avatarColor},
    );
    if (res.session == null) {
      throw const AuthException('confirm_email');
    }
  }

  static Future<void> signIn(String email, String password) =>
      _db.auth.signInWithPassword(email: email.trim(), password: password);

  static Future<void> resetPassword(String email) =>
      _db.auth.resetPasswordForEmail(email.trim(), redirectTo: AppConfig.authRedirectUrl);

  static Future<void> updatePassword(String password) => _db.auth.updateUser(UserAttributes(password: password));

  static Future<void> signOut() => _db.auth.signOut();

  static Future<void> deleteAccount() async {
    final rows = await _db.from('submissions').select('photo_path').eq('user_id', myId!);
    final paths = rows.map((r) => r['photo_path'] as String).toList();
    for (var i = 0; i < paths.length; i += 100) {
      await _db.storage.from('photos').remove(paths.sublist(i, min(i + 100, paths.length)));
    }
    await _db.rpc('delete_my_account');
    await _db.auth.signOut();
  }

  // ------------------------------------------------------------- Profile

  static Future<Profile> myProfile() async {
    final row = await _db.from('profiles').select().eq('id', myId!).single();
    return Profile.fromJson(row);
  }

  static Future<void> updateProfile({String? username, String? avatarEmoji, int? avatarColor}) async {
    await _db
        .from('profiles')
        .update({
          if (username != null) 'username': username.trim(),
          'avatar_emoji': ?avatarEmoji,
          'avatar_color': ?avatarColor,
        })
        .eq('id', myId!);
  }

  // -------------------------------------------------------------- Groups

  static Future<List<GroupSummary>> myGroups() async {
    final res = await _db.rpc('get_my_groups') as List<dynamic>;
    return res.map((e) => GroupSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Group> createGroup(String name, String emoji) async {
    final res = await _db.rpc('create_group', params: {'p_name': name.trim(), 'p_emoji': emoji});
    return Group.fromJson(res as Map<String, dynamic>);
  }

  static Future<Group> joinGroup(String code) async {
    final res = await _db.rpc('join_group', params: {'p_code': code.trim().toUpperCase()});
    return Group.fromJson(res as Map<String, dynamic>);
  }

  static Future<Group> group(String id) async {
    final row = await _db.from('groups').select().eq('id', id).single();
    return Group.fromJson(row);
  }

  static Future<void> updateGroup(String id, {String? name, String? emoji, int? voteHour}) async {
    await _db
        .from('groups')
        .update({if (name != null) 'name': name.trim(), 'emoji': ?emoji, 'vote_hour': ?voteHour})
        .eq('id', id);
  }

  static Future<String> regenerateInviteCode(String groupId) async =>
      await _db.rpc('regenerate_invite_code', params: {'gid': groupId}) as String;

  static Future<void> leaveGroup(String groupId) => _db.rpc('leave_group', params: {'gid': groupId});

  static Future<List<Member>> members(String groupId) async {
    final rows = await _db
        .from('group_members')
        .select('role, joined_at, profiles(*)')
        .eq('group_id', groupId)
        .order('joined_at');
    return rows.map(Member.fromJson).toList();
  }

  static Future<void> kick(String groupId, String userId) =>
      _db.from('group_members').delete().eq('group_id', groupId).eq('user_id', userId);

  // ---------------------------------------------------------- Challenges

  static Future<TodayState> today(String groupId) async {
    final res = await _db.rpc('get_group_today', params: {'gid': groupId});
    return TodayState.fromJson(res as Map<String, dynamic>);
  }

  static Future<List<Map<String, dynamic>>> upcomingChallenges() async {
    final res = await _db.rpc('get_upcoming_challenges') as List<dynamic>;
    return res.cast<Map<String, dynamic>>();
  }

  static Future<List<Challenge>> pastChallenges(String groupId, {int limit = 60}) async {
    final rows = await _db
        .from('challenges')
        .select()
        .eq('group_id', groupId)
        .lt('day', isoDay(gameNow()))
        .order('day', ascending: false)
        .limit(limit);
    return rows.map(Challenge.fromJson).toList();
  }

  static Future<List<Submission>> submissions(String challengeId) async {
    final rows = await _db
        .from('submissions')
        .select('*, profiles(*)')
        .eq('challenge_id', challengeId)
        .order('created_at');
    final subs = rows.map(Submission.fromJson).toList();
    await _attachUrls(subs);
    return subs;
  }

  static Future<List<Vote>> votes(String challengeId) async {
    final rows = await _db.from('votes').select().eq('challenge_id', challengeId);
    return rows.map(Vote.fromJson).toList();
  }

  static Future<ChallengeResults> results(String challengeId) async {
    final subs = await submissions(challengeId);
    final v = await votes(challengeId);
    return ChallengeResults(subs, v);
  }

  static Future<void> _attachUrls(List<Submission> subs) async {
    if (subs.isEmpty) return;
    final signed = await _db.storage
        .from('photos')
        .createSignedUrlsResult(subs.map((s) => s.photoPath).toList(), 60 * 60 * 24);
    final byPath = {for (final s in signed.whereType<SignedUrlSuccess>()) s.path: s.signedUrl};
    for (final s in subs) {
      s.photoUrl = byPath[s.photoPath];
    }
  }

  static Future<void> submitPhoto({
    required Challenge challenge,
    required Uint8List bytes,
    String? caption,
    Submission? replacing,
  }) async {
    final rand =
        '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1 << 30).toRadixString(36)}';
    final path = '${challenge.groupId}/${challenge.id}/${myId}_$rand.jpg';
    await _db.storage
        .from('photos')
        .uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    if (replacing != null) {
      await _db.from('submissions').delete().eq('id', replacing.id);
      try {
        await _db.storage.from('photos').remove([replacing.photoPath]);
      } catch (_) {}
    }
    await _db.from('submissions').insert({
      'challenge_id': challenge.id,
      'user_id': myId,
      'photo_path': path,
      if (caption != null && caption.trim().isNotEmpty) 'caption': caption.trim(),
    });
  }

  static Future<void> updateCaption(String submissionId, String caption) async {
    await _db
        .from('submissions')
        .update({'caption': caption.trim().isEmpty ? null : caption.trim()})
        .eq('id', submissionId);
  }

  static Future<void> vote({
    required String challengeId,
    required String submissionId,
    required VoteCategory category,
  }) async {
    await _db.from('votes').delete().eq('challenge_id', challengeId).eq('voter_id', myId!).eq('category', category.key);
    await _db.from('votes').insert({
      'challenge_id': challengeId,
      'voter_id': myId,
      'submission_id': submissionId,
      'category': category.key,
    });
  }

  // --------------------------------------------------------- Leaderboard

  static Future<List<LeaderboardEntry>> leaderboard(String groupId, DateTime from, DateTime to) async {
    final res = await _db.rpc(
      'get_leaderboard',
      params: {'gid': groupId, 'from_day': isoDay(from), 'to_day': isoDay(to)},
    ) as List<dynamic>;
    return res.map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<DateTime> groupCreatedAt(String groupId) async {
    final row = await _db.from('groups').select('created_at').eq('id', groupId).single();
    return DateTime.parse(row['created_at'] as String).toLocal();
  }

  // ------------------------------------------------------ Custom prompts

  static Future<List<CustomPrompt>> customPrompts(String groupId) async {
    final rows = await _db.from('prompts').select().eq('group_id', groupId).order('created_at', ascending: false);
    return rows.map(CustomPrompt.fromJson).toList();
  }

  static Future<void> addPrompt(String groupId, String text, String emoji) async {
    await _db.from('prompts').insert({'group_id': groupId, 'text': text.trim(), 'emoji': emoji, 'created_by': myId});
  }

  static Future<void> deletePrompt(int id) => _db.from('prompts').delete().eq('id', id);
}

/// Traduit les erreurs du backend en messages lisibles.
String friendlyError(Object e) {
  final msg = switch (e) {
    AuthException(:final message) => message,
    PostgrestException(:final message) => message,
    StorageException(:final message) => message,
    _ => e.toString(),
  };
  final m = msg.toLowerCase();
  if (m.contains('confirm_email')) {
    return 'Compte créé ! Confirme ton adresse e-mail puis connecte-toi.';
  }
  if (m.contains('invalid login credentials')) return 'E-mail ou mot de passe incorrect.';
  if (m.contains('user already registered')) return 'Un compte existe déjà avec cet e-mail.';
  if (m.contains('password should be at least')) return 'Le mot de passe doit faire au moins 6 caractères.';
  if (m.contains('email not confirmed')) return 'Confirme ton adresse e-mail avant de te connecter.';
  if (m.contains('invalid_code')) return 'Code d\'invitation introuvable.';
  if (m.contains('group_full')) return 'Ce groupe est complet.';
  if (m.contains('row-level security') || m.contains('violates row-level')) {
    return 'Action impossible pour le moment (la phase du défi a peut-être changé).';
  }
  if (m.contains('socketexception') || m.contains('failed host lookup') || m.contains('clientexception')) {
    return 'Pas de connexion internet.';
  }
  if (m.contains('duplicate key') && m.contains('prompts')) return 'Cette idée existe déjà.';
  return 'Oups, une erreur est survenue. ($msg)';
}
