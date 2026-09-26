import 'package:declic/models.dart';
import 'package:flutter_test/flutter_test.dart';

Submission _sub(String id) =>
    Submission(id: id, challengeId: 'c', userId: 'u$id', photoPath: 'g/c/$id.jpg', createdAt: DateTime(2026));

Vote _vote(String voter, String sub, VoteCategory cat) => Vote(voterId: voter, submissionId: sub, category: cat);

void main() {
  test('ChallengeResults : gagnants, ex æquo et tri', () {
    final r = ChallengeResults(
      [_sub('a'), _sub('b'), _sub('c')],
      [
        _vote('1', 'a', VoteCategory.funny),
        _vote('2', 'a', VoteCategory.funny),
        _vote('3', 'b', VoteCategory.funny),
        _vote('1', 'b', VoteCategory.beautiful),
        _vote('2', 'c', VoteCategory.beautiful),
      ],
    );
    expect(r.winners(VoteCategory.funny).map((s) => s.id), ['a']);
    expect(r.winners(VoteCategory.beautiful).map((s) => s.id), ['b', 'c']);
    expect(r.winners(VoteCategory.original), isEmpty);
    expect(r.ranked.first.id, 'a');
    expect(r.total('b'), 2);
  });

  test('GroupSummary.needsAction', () {
    Map<String, dynamic> json(String phase, bool submitted, int votes) => {
          'group': {'id': 'g', 'name': 'G', 'emoji': '📸', 'invite_code': 'ABCDEF', 'vote_hour': 20},
          'role': 'member',
          'member_count': 3,
          'challenge': {'id': 'c', 'group_id': 'g', 'day': '2026-09-26', 'text': 'Bleu', 'emoji': '🔵'},
          'phase': phase,
          'submission_count': 1,
          'has_submitted': submitted,
          'my_vote_count': votes,
          'streak': 2,
        };
    expect(GroupSummary.fromJson(json('submission', false, 0)).needsAction, isTrue);
    expect(GroupSummary.fromJson(json('submission', true, 0)).needsAction, isFalse);
    expect(GroupSummary.fromJson(json('voting', true, 1)).needsAction, isTrue);
    expect(GroupSummary.fromJson(json('voting', false, 3)).needsAction, isFalse);
    expect(GroupSummary.fromJson(json('closed', false, 0)).needsAction, isFalse);
  });
}
