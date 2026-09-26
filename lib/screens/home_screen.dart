import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../services/api.dart';
import '../services/notifications.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'group_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<GroupSummary>? _groups;
  Profile? _me;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _askNotificationsOnce();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _askNotificationsOnce() async {
    final p = await SharedPreferences.getInstance();
    if (p.getBool('asked_notif') == true) return;
    await p.setBool('asked_notif', true);
    await NotificationService.instance.requestPermission();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([Api.myGroups(), Api.myProfile()]);
      if (!mounted) return;
      setState(() {
        _groups = results[0] as List<GroupSummary>;
        _me = results[1] as Profile;
        _error = null;
      });
      NotificationService.instance.reschedule();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _openGroup(GroupSummary g) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => GroupScreen(groupId: g.group.id)));
    _load();
  }

  Future<void> _create() async {
    final group = await showModalBottomSheet<Group>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateGroupSheet(),
    );
    if (group != null && mounted) {
      await _load();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => InviteDialog(group: group),
      );
      _load();
    }
  }

  Future<void> _join() async {
    final group = await showModalBottomSheet<Group>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _JoinGroupSheet(),
    );
    if (group != null && mounted) {
      showMessage(context, 'Bienvenue dans ${group.emoji} ${group.name} !');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: GradientText('Déclic', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        actions: [
          if (_me != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                  _load();
                },
                child: Avatar.profile(_me!, size: 40),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(color: AppColors.pink, onRefresh: _load, child: _buildBody()),
      bottomNavigationBar: _groups == null || _groups!.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _join,
                        icon: const Icon(Icons.group_add_outlined),
                        label: const Text('Rejoindre'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GradientButton(label: 'Créer', icon: Icons.add_rounded, onPressed: _create),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_groups == null && _error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          EmptyState(
            emoji: '📡',
            title: 'Connexion impossible',
            subtitle: friendlyError(_error!),
            action: OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
          ),
        ],
      );
    }
    if (_groups == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_groups!.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          const EmptyState(
            emoji: '👯',
            title: 'Crée ton premier groupe',
            subtitle:
                'Chaque jour, un nouveau thème photo pour toute la bande. '
                'Postez, votez, grimpez au classement !',
          ),
          GradientButton(label: 'Créer un groupe', icon: Icons.add_rounded, onPressed: _create),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _join,
            icon: const Icon(Icons.vpn_key_outlined),
            label: const Text("J'ai un code d'invitation"),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _groups!.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        if (i == 0) {
          final todo = _groups!.where((g) => g.needsAction).length;
          return Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 2),
            child: Text(
              todo == 0
                  ? 'Tout est à jour, bien joué ✨'
                  : 'Tu as $todo défi${todo > 1 ? 's' : ''} qui t\'attend${todo > 1 ? 'ent' : ''} 👀',
              style: const TextStyle(color: AppColors.textDim, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          );
        }
        final g = _groups![i - 1];
        return _GroupCard(summary: g, onTap: () => _openGroup(g));
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.summary, required this.onTap});

  final GroupSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final (label, icon, color) = switch (s.phase) {
      Phase.submission when !s.hasSubmitted => ('À toi de jouer', '📸', AppColors.pink),
      Phase.submission => ('${s.submissionCount}/${s.memberCount} photos', '✅', AppColors.mint),
      Phase.voting when s.myVoteCount < 3 => ('Vote ouvert', '🗳️', AppColors.orange),
      Phase.voting => ('A voté', '✅', AppColors.mint),
      _ => ('Résultats', '🏆', AppColors.yellow),
    };
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: s.needsAction ? color.withValues(alpha: 0.7) : AppColors.border, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(s.group.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${s.memberCount} membre${s.memberCount > 1 ? 's' : ''}',
                          style: const TextStyle(color: AppColors.textDim, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (s.streak > 0) Pill(label: '${s.streak}', icon: '🔥'),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(18)),
                child: Row(
                  children: [
                    Text(s.challenge.emoji, style: const TextStyle(fontSize: 34)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DÉFI DU JOUR',
                            style: TextStyle(
                              color: AppColors.textDim,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.challenge.text,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Pill(label: label, icon: icon, color: color.withValues(alpha: 0.18), textColor: color),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_rounded, color: AppColors.textDim),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const groupEmojis = [
  '📸',
  '🔥',
  '🎉',
  '🍻',
  '🏖️',
  '🎓',
  '💼',
  '🏠',
  '⚽',
  '🎮',
  '🎸',
  '🍕',
  '🌍',
  '🚀',
  '👯',
  '💖',
  '🦄',
  '🐸',
  '🌈',
  '👑',
  '🎨',
  '🍿',
  '☕',
  '🌮',
];

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet();

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _name = TextEditingController();
  String _emoji = '📸';
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final g = await Api.createGroup(_name.text, _emoji);
      if (mounted) Navigator.pop(context, g);
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Nouveau groupe', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final e = await pickEmoji(context, emojis: groupEmojis);
                  if (e != null) setState(() => _emoji = e);
                },
                child: Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(_emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _name,
                  autofocus: true,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nom du groupe', counterText: ''),
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GradientButton(label: 'Créer le groupe', loading: _loading, onPressed: _submit),
        ],
      ),
    );
  }
}

class _JoinGroupSheet extends StatefulWidget {
  const _JoinGroupSheet();

  @override
  State<_JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends State<_JoinGroupSheet> {
  final _code = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.text.trim().length < 6) return;
    setState(() => _loading = true);
    try {
      final g = await Api.joinGroup(_code.text);
      if (mounted) Navigator.pop(context, g);
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Rejoindre un groupe', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
            'Demande le code à 6 caractères à un membre du groupe.',
            style: TextStyle(color: AppColors.textDim),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            autofocus: true,
            maxLength: 6,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
              TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase())),
            ],
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 10),
            decoration: const InputDecoration(hintText: 'ABC123', counterText: ''),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          GradientButton(label: 'Rejoindre', loading: _loading, onPressed: _submit),
        ],
      ),
    );
  }
}

class InviteDialog extends StatelessWidget {
  const InviteDialog({super.key, required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${group.emoji} ${group.name}', style: const TextStyle(fontWeight: FontWeight.w900)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Invite tes potes avec ce code :', style: TextStyle(color: AppColors.textDim)),
          const SizedBox(height: 16),
          InviteCodeBox(group: group),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("C'est parti !"))],
    );
  }
}

class InviteCodeBox extends StatelessWidget {
  const InviteCodeBox({super.key, required this.group, this.code});

  final Group group;
  final String? code;

  @override
  Widget build(BuildContext context) {
    final c = code ?? group.inviteCode;
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: c));
            showMessage(context, 'Code copié 📋');
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: GradientText(
              c,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 8),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => shareInvite(group, c),
          icon: const Icon(Icons.ios_share_rounded),
          label: const Text('Partager'),
        ),
      ],
    );
  }
}
