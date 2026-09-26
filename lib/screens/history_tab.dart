import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/results_view.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key, required this.groupId});

  final String groupId;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> with AutomaticKeepAliveClientMixin {
  List<Challenge>? _challenges;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await Api.pastChallenges(widget.groupId);
      if (mounted) setState(() => _challenges = list);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final list = _challenges;
    Widget body;
    if (list == null && _error != null) {
      body = ListView(
        children: [EmptyState(emoji: '📡', title: 'Chargement impossible', subtitle: friendlyError(_error!))],
      );
    } else if (list == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (list.isEmpty) {
      body = ListView(
        children: const [
          SizedBox(height: 60),
          EmptyState(
            emoji: '🗓️',
            title: 'Pas encore d\'historique',
            subtitle: 'Les défis terminés et leurs résultats apparaîtront ici.',
          ),
        ],
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final c = list[i];
          return Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChallengeDetailScreen(challenge: c))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(16)),
                      child: Text(c.emoji, style: const TextStyle(fontSize: 26)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(prettyDay(c.day), style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
                          Text(c.text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
    return RefreshIndicator(color: AppColors.pink, onRefresh: _load, child: body);
  }
}

class ChallengeDetailScreen extends StatefulWidget {
  const ChallengeDetailScreen({super.key, required this.challenge});

  final Challenge challenge;

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  ChallengeResults? _results;
  Object? _error;

  @override
  void initState() {
    super.initState();
    Api.results(widget.challenge.id).then(
      (r) => mounted ? setState(() => _results = r) : null,
      onError: (Object e) => mounted ? setState(() => _error = e) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    return Scaffold(
      appBar: AppBar(title: Text(prettyDay(c.day))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: AppColors.violetGradient, borderRadius: BorderRadius.circular(24)),
            child: Row(
              children: [
                Text(c.emoji, style: const TextStyle(fontSize: 44)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    c.text,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            EmptyState(emoji: '📡', title: 'Chargement impossible', subtitle: friendlyError(_error!))
          else if (_results == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ResultsView(results: _results!),
        ],
      ),
    );
  }
}
