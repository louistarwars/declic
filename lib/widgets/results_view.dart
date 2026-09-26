import 'package:flutter/material.dart';

import '../models.dart';
import '../screens/photo_viewer.dart';
import '../theme.dart';
import 'common.dart';

/// Résultats d'un défi terminé : gagnants par catégorie puis classement du jour.
class ResultsView extends StatelessWidget {
  const ResultsView({super.key, required this.results});

  final ChallengeResults results;

  @override
  Widget build(BuildContext context) {
    final r = results;
    if (r.submissions.isEmpty) {
      return const EmptyState(emoji: '🦗', title: 'Aucune photo ce jour-là', subtitle: 'Pas de points pour personne…');
    }
    final ranked = r.ranked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text('Les gagnants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        for (final cat in VoteCategory.values) ...[
          _WinnerCard(category: cat, winners: r.winners(cat), results: r),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text('Toutes les photos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        for (var i = 0; i < ranked.length; i++) ...[
          _RankedTile(rank: i + 1, submission: ranked[i], results: r, all: ranked, index: i),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _WinnerCard extends StatelessWidget {
  const _WinnerCard({required this.category, required this.winners, required this.results});

  final VoteCategory category;
  final List<Submission> winners;
  final ChallengeResults results;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.category(category.key);
    final w = winners.firstOrNull;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 110,
            child: w == null
                ? Center(child: Text(category.emoji, style: const TextStyle(fontSize: 40)))
                : GestureDetector(
                    onTap: () => openPhotoViewer(context, winners, 0),
                    child: SubmissionPhoto(submission: w),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${category.emoji} ${category.label.toUpperCase()}',
                    style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                  ),
                  const SizedBox(height: 6),
                  if (w == null)
                    const Text('Aucun vote', style: TextStyle(color: AppColors.textDim))
                  else
                    Text(
                      winners.map((s) => s.author?.username ?? '?').join(' & '),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  if (w != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${results.count(w.id, category)} vote${results.count(w.id, category) > 1 ? 's' : ''}'
                      '${winners.length > 1 ? ' · ex æquo' : ''} · +3 pts',
                      style: const TextStyle(color: AppColors.textDim),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (w?.author != null)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Avatar.profile(w!.author!, size: 40, ring: color),
            ),
        ],
      ),
    );
  }
}

class _RankedTile extends StatelessWidget {
  const _RankedTile({
    required this.rank,
    required this.submission,
    required this.results,
    required this.all,
    required this.index,
  });

  final int rank;
  final Submission submission;
  final ChallengeResults results;
  final List<Submission> all;
  final int index;

  @override
  Widget build(BuildContext context) {
    final s = submission;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => openPhotoViewer(context, all, index),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(width: 64, height: 64, child: SubmissionPhoto(submission: s)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.author?.username ?? '?', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    if (s.caption?.isNotEmpty ?? false)
                      Text(
                        s.caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textDim),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        for (final c in VoteCategory.values) ...[
                          Text(
                            '${c.emoji} ${results.count(s.id, c)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '#$rank',
                style: TextStyle(fontSize: rank <= 3 ? 28 : 18, fontWeight: FontWeight.w900, color: AppColors.textDim),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}
