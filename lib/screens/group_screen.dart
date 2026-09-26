import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'group_settings_screen.dart';
import 'history_tab.dart';
import 'leaderboard_tab.dart';
import 'today_tab.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  Group? _group;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    try {
      final g = await Api.group(widget.groupId);
      if (mounted) setState(() => _group = g);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _openSettings() async {
    final left = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => GroupSettingsScreen(groupId: widget.groupId)),
    );
    if (left == true) {
      if (mounted) Navigator.pop(context);
      return;
    }
    _loadGroup();
  }

  @override
  Widget build(BuildContext context) {
    final g = _group;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: g == null
              ? const SizedBox.shrink()
              : Row(
                  children: [
                    Text(g.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(g.name, overflow: TextOverflow.ellipsis)),
                  ],
                ),
          actions: [
            IconButton(
              tooltip: 'Réglages du groupe',
              icon: const Icon(Icons.settings_outlined),
              onPressed: _openSettings,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(58),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
              child: const TabBar(
                tabs: [
                  Tab(height: 40, text: '📸 Défi'),
                  Tab(height: 40, text: '🏆 Classement'),
                  Tab(height: 40, text: '🗓️ Historique'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            TodayTab(groupId: widget.groupId),
            LeaderboardTab(groupId: widget.groupId),
            HistoryTab(groupId: widget.groupId),
          ],
        ),
      ),
    );
  }
}
