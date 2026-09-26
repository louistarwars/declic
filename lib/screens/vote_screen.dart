import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';

class VoteScreen extends StatefulWidget {
  const VoteScreen({super.key, required this.challenge, required this.submissions});

  final Challenge challenge;

  /// Photos pour lesquelles on peut voter (sans la sienne).
  final List<Submission> submissions;

  @override
  State<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends State<VoteScreen> {
  final _pages = PageController(viewportFraction: 0.86);
  final Map<VoteCategory, String> _choices = {};
  VoteCategory _category = VoteCategory.funny;
  int _page = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadMine();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _loadMine() async {
    try {
      final votes = await Api.votes(widget.challenge.id);
      if (!mounted) return;
      setState(() {
        for (final v in votes.where((v) => v.voterId == Api.myId)) {
          _choices[v.category] = v.submissionId;
        }
        _category = VoteCategory.values.firstWhere((c) => !_choices.containsKey(c), orElse: () => VoteCategory.funny);
      });
      _jumpToChoice();
    } catch (_) {}
  }

  void _jumpToChoice() {
    final chosen = _choices[_category];
    if (chosen == null || !_pages.hasClients) return;
    final i = widget.submissions.indexWhere((s) => s.id == chosen);
    if (i >= 0) _pages.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _cast() async {
    final sub = widget.submissions[_page];
    setState(() => _saving = true);
    try {
      await Api.vote(challengeId: widget.challenge.id, submissionId: sub.id, category: _category);
      if (!mounted) return;
      setState(() => _choices[_category] = sub.id);
      final next = VoteCategory.values.where((c) => !_choices.containsKey(c)).firstOrNull;
      if (next != null) {
        setState(() => _category = next);
        showMessage(context, 'Vote enregistré ✅ · au tour de « ${next.label.toLowerCase()} » ${next.emoji}');
      } else {
        await _finished();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finished() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('A voté ! 🎉', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          'Tes 3 votes sont enregistrés. Les résultats tombent quand tout le monde a voté, ou à minuit.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Super'))],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final subs = widget.submissions;
    final current = subs.isEmpty ? null : subs[_page.clamp(0, subs.length - 1)];
    final isChosen = current != null && _choices[_category] == current.id;
    final catColor = AppColors.category(_category.key);

    return Scaffold(
      appBar: AppBar(title: const Text('Vote')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final c in VoteCategory.values) ...[
                    Expanded(
                      child: _CategoryChip(
                        category: c,
                        selected: c == _category,
                        done: _choices.containsKey(c),
                        onTap: () {
                          setState(() => _category = c);
                          _jumpToChoice();
                        },
                      ),
                    ),
                    if (c != VoteCategory.values.last) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Quelle est ${_category.label.toLowerCase()} ?',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: subs.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final s = subs[i];
                  final chosenCats = VoteCategory.values.where((c) => _choices[c] == s.id).toList();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          SubmissionPhoto(submission: s),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Row(
                              children: [
                                for (final c in chosenCats)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.category(c.key),
                                      child: Text(c.emoji, style: const TextStyle(fontSize: 18)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black87],
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (s.author != null) ...[
                                    Avatar.profile(s.author!, size: 34),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          s.author?.username ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                        ),
                                        if (s.caption?.isNotEmpty ?? false)
                                          Text(s.caption!, style: const TextStyle(color: Colors.white70)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < subs.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _page ? catColor : AppColors.border,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: GradientButton(
                label: isChosen ? 'Ton choix ${_category.emoji}' : '${_category.emoji}  Je vote pour celle-ci',
                loading: _saving,
                gradient: LinearGradient(colors: [catColor, Color.lerp(catColor, AppColors.violet, 0.5)!]),
                onPressed: current == null || isChosen ? null : _cast,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.selected, required this.done, required this.onTap});

  final VoteCategory category;
  final bool selected;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.category(category.key);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : AppColors.border, width: 2),
        ),
        child: Column(
          children: [
            Text(category.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  category.label.replaceFirst('La plus ', ''),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: selected ? color : AppColors.text),
                ),
                if (done) ...[const SizedBox(width: 4), Icon(Icons.check_circle_rounded, size: 14, color: color)],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
