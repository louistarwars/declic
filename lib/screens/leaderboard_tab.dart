import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

/// Classement par saison (une saison = un mois calendaire).
class LeaderboardTab extends StatefulWidget {
  const LeaderboardTab({super.key, required this.groupId});

  final String groupId;

  @override
  State<LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<LeaderboardTab> with AutomaticKeepAliveClientMixin {
  late DateTime _season;
  DateTime? _firstSeason;
  List<LeaderboardEntry>? _entries;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final now = gameNow();
    _season = DateTime(now.year, now.month);
    _init();
  }

  Future<void> _init() async {
    try {
      final created = await Api.groupCreatedAt(widget.groupId);
      _firstSeason = DateTime(created.year, created.month);
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final from = _season;
      final to = DateTime(_season.year, _season.month + 1, 0);
      final entries = await Api.leaderboard(widget.groupId, from, to);
      if (mounted) setState(() => _entries = entries);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  bool get _isCurrent {
    final now = gameNow();
    return _season.year == now.year && _season.month == now.month;
  }

  bool get _canGoBack => _firstSeason == null || _season.isAfter(_firstSeason!);

  void _shift(int months) {
    setState(() {
      _season = DateTime(_season.year, _season.month + months);
      _entries = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final entries = _entries;
    return RefreshIndicator(
      color: AppColors.pink,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _canGoBack ? () => _shift(-1) : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 30),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      seasonName(_season),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      _isCurrent
                          ? 'En cours · se termine dans ${DateTime(_season.year, _season.month + 1).difference(gameNow()).inDays + 1} j'
                          : 'Saison terminée',
                      style: const TextStyle(color: AppColors.textDim),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isCurrent ? null : () => _shift(1),
                icon: const Icon(Icons.chevron_right_rounded, size: 30),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null)
            EmptyState(emoji: '📡', title: 'Chargement impossible', subtitle: friendlyError(_error!))
          else if (entries == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (entries.every((e) => e.points == 0))
            EmptyState(
              emoji: '🏁',
              title: _isCurrent ? 'La saison commence !' : 'Aucun point cette saison',
              subtitle: 'Les points arrivent dès que les résultats d\'un défi sont tombés.',
            )
          else ...[
            _Podium(entries: entries.take(3).toList(), finished: !_isCurrent),
            const SizedBox(height: 20),
            for (var i = 0; i < entries.length; i++) ...[
              _Row(rank: i + 1, entry: entries[i], isMe: entries[i].profile.id == Api.myId),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 20),
          const _Rules(),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.entries, required this.finished});

  final List<LeaderboardEntry> entries;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    Widget column(int rank, double height) {
      if (entries.length < rank) return const Expanded(child: SizedBox());
      final e = entries[rank - 1];
      final colors = [AppColors.yellow, const Color(0xFFCFD8E6), const Color(0xFFE59A5C)];
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (rank == 1) Text(finished ? '👑' : '✨', style: const TextStyle(fontSize: 26)),
            Avatar.profile(e.profile, size: rank == 1 ? 72 : 58, ring: colors[rank - 1]),
            const SizedBox(height: 6),
            Text(
              e.profile.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              '${e.points} pts',
              style: TextStyle(color: colors[rank - 1], fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Container(
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [colors[rank - 1].withValues(alpha: 0.55), colors[rank - 1].withValues(alpha: 0.08)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 8),
              child: Text('$rank', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
    }

    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [column(2, 80), column(1, 110), column(3, 60)]);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.entry, required this.isMe});

  final int rank;
  final LeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isMe ? AppColors.pink : Colors.transparent, width: 1.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDim),
            ),
          ),
          Avatar.profile(e.profile, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${e.profile.username} (toi)' : e.profile.username,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                Text(
                  '📸 ${e.participations}  ·  🗳️ ${e.votesReceived}  ·  🏅 ${e.wins}',
                  style: const TextStyle(color: AppColors.textDim, fontSize: 13),
                ),
              ],
            ),
          ),
          Text('${e.points}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const Text(' pts', style: TextStyle(color: AppColors.textDim)),
        ],
      ),
    );
  }
}

class _Rules extends StatelessWidget {
  const _Rules();

  @override
  Widget build(BuildContext context) {
    Widget line(String emoji, String text, String pts) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
          Text(
            pts,
            style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.mint),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Comment gagner des points', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          line('📸', 'Poster ta photo du jour', '+1'),
          line('🗳️', 'Chaque vote reçu', '+2'),
          line('🏅', 'Remporter une catégorie (drôle, belle, originale)', '+3'),
          const SizedBox(height: 8),
          const Text(
            'Une saison dure un mois. Le compteur repart à zéro le 1er !',
            style: TextStyle(color: AppColors.textDim, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
