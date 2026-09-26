import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

/// Réglages d'un groupe. Renvoie `true` si l'utilisateur a quitté le groupe.
class GroupSettingsScreen extends StatefulWidget {
  const GroupSettingsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  Group? _group;
  List<Member> _members = [];
  List<CustomPrompt> _prompts = [];
  bool get _isAdmin => _members.any((m) => m.profile.id == Api.myId && m.isAdmin);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        Api.group(widget.groupId),
        Api.members(widget.groupId),
        Api.customPrompts(widget.groupId),
      ]);
      if (!mounted) return;
      setState(() {
        _group = r[0] as Group;
        _members = r[1] as List<Member>;
        _prompts = r[2] as List<CustomPrompt>;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    try {
      await action();
      if (mounted && success != null) showMessage(context, success);
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _rename() async {
    final g = _group!;
    final ctrl = TextEditingController(text: g.name);
    var emoji = g.emoji;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Modifier le groupe', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final e = await pickEmoji(ctx, emojis: groupEmojis);
                  if (e != null) setLocal(() => emoji = e);
                },
                child: Text(emoji, style: const TextStyle(fontSize: 36)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  maxLength: 40,
                  decoration: const InputDecoration(counterText: ''),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await _run(() => Api.updateGroup(g.id, name: ctrl.text, emoji: emoji));
    }
    ctrl.dispose();
  }

  Future<void> _addPrompt() async {
    final ctrl = TextEditingController();
    var emoji = '💡';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Proposer un défi', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Les idées du groupe passent en priorité sur le catalogue. Elles restent secrètes jusqu\'au jour J !',
                style: TextStyle(color: AppColors.textDim),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final e = await pickEmoji(ctx);
                      if (e != null) setLocal(() => emoji = e);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 32)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      autofocus: true,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Ex : Ton pire pull', counterText: ''),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ajouter')),
          ],
        ),
      ),
    );
    if (ok == true && ctrl.text.trim().length >= 3) {
      await _run(() => Api.addPrompt(widget.groupId, ctrl.text, emoji), success: 'Idée ajoutée 💡');
    }
    ctrl.dispose();
  }

  Future<void> _leave() async {
    final ok = await confirm(
      context,
      title: 'Quitter le groupe ?',
      message: 'Tu ne verras plus les défis ni les photos de ce groupe.',
      confirmLabel: 'Quitter',
      destructive: true,
    );
    if (!ok) return;
    try {
      await Api.leaveGroup(widget.groupId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = _group;
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: g == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              children: [
                _Section(
                  title: 'Inviter des potes',
                  child: Column(
                    children: [
                      InviteCodeBox(group: g),
                      if (_isAdmin)
                        TextButton(
                          onPressed: () async {
                            final ok = await confirm(
                              context,
                              title: 'Nouveau code ?',
                              message: 'L\'ancien code ne fonctionnera plus.',
                            );
                            if (ok) await _run(() => Api.regenerateInviteCode(g.id), success: 'Nouveau code généré');
                          },
                          child: const Text('Générer un nouveau code'),
                        ),
                    ],
                  ),
                ),
                if (_isAdmin)
                  _Section(
                    title: 'Groupe',
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Text(g.emoji, style: const TextStyle(fontSize: 28)),
                          title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          trailing: const Icon(Icons.edit_outlined),
                          onTap: _rename,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Text('🗳️', style: TextStyle(fontSize: 28)),
                          title: const Text('Ouverture des votes', style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: const Text('Si tout le monde a posté avant, le vote s\'ouvre plus tôt.'),
                          trailing: DropdownButton<int>(
                            value: g.voteHour,
                            underline: const SizedBox(),
                            borderRadius: BorderRadius.circular(14),
                            items: [for (var h = 8; h <= 23; h++) DropdownMenuItem(value: h, child: Text('${h}h'))],
                            onChanged: (h) => _run(() => Api.updateGroup(g.id, voteHour: h)),
                          ),
                        ),
                      ],
                    ),
                  ),
                _Section(
                  title: 'Idées de défis (${_prompts.length})',
                  trailing: IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _addPrompt),
                  child: _prompts.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Propose tes propres thèmes : ils passeront avant ceux du catalogue.',
                            style: TextStyle(color: AppColors.textDim),
                          ),
                        )
                      : Column(
                          children: [
                            for (final p in _prompts)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Text(p.emoji, style: const TextStyle(fontSize: 24)),
                                title: Text(p.createdBy == Api.myId || _isAdmin ? p.text : '🤫 Idée secrète'),
                                trailing: p.createdBy == Api.myId || _isAdmin
                                    ? IconButton(
                                        icon: const Icon(Icons.delete_outline, color: AppColors.textDim),
                                        onPressed: () => _run(() => Api.deletePrompt(p.id)),
                                      )
                                    : null,
                              ),
                          ],
                        ),
                ),
                _Section(
                  title: 'Membres (${_members.length})',
                  child: Column(
                    children: [
                      for (final m in _members)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Avatar.profile(m.profile, size: 40),
                          title: Text(
                            m.profile.id == Api.myId ? '${m.profile.username} (toi)' : m.profile.username,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: m.isAdmin ? const Text('Admin') : null,
                          trailing: _isAdmin && m.profile.id != Api.myId
                              ? IconButton(
                                  icon: const Icon(Icons.person_remove_outlined, color: AppColors.textDim),
                                  onPressed: () async {
                                    final ok = await confirm(
                                      context,
                                      title: 'Retirer ${m.profile.username} ?',
                                      message: 'Il ou elle pourra revenir avec le code d\'invitation.',
                                      confirmLabel: 'Retirer',
                                      destructive: true,
                                    );
                                    if (ok) await _run(() => Api.kick(g.id, m.profile.id));
                                  },
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: _leave,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Quitter le groupe'),
                ),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
