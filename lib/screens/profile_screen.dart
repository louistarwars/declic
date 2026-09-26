import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/api.dart';
import '../services/notifications.dart';
import '../theme.dart';
import '../widgets/common.dart';

const privacyPolicyUrl = 'https://github.com/louistarwars/declic/blob/main/PRIVACY.md';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Profile? _me;
  NotificationSettings? _notif;
  final _username = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final me = await Api.myProfile();
      final n = await NotificationService.instance.settings();
      if (!mounted) return;
      setState(() {
        _me = me;
        _notif = n;
        _username.text = me.username;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _update({String? username, String? emoji, int? color}) async {
    try {
      await Api.updateProfile(username: username, avatarEmoji: emoji, avatarColor: color);
      await _load();
      if (username != null && mounted) showMessage(context, 'Pseudo mis à jour ✅');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _saveNotif(NotificationSettings s) async {
    setState(() => _notif = s);
    if (s.enabled || s.voteReminder) await NotificationService.instance.requestPermission();
    await NotificationService.instance.save(s);
  }

  Future<void> _pickTime() async {
    final n = _notif!;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: n.hour, minute: n.minute),
    );
    if (t != null) await _saveNotif(n.copyWith(hour: t.hour, minute: t.minute));
  }

  Future<void> _deleteAccount() async {
    final ok = await confirm(
      context,
      title: 'Supprimer ton compte ?',
      message:
          'Ton profil, tes photos, tes votes et tes points seront définitivement supprimés. '
          'Cette action est irréversible.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok) return;
    try {
      await NotificationService.instance.cancelAll();
      await Api.deleteAccount();
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    final n = _notif;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: me == null || n == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final e = await pickEmoji(context);
                      if (e != null) _update(emoji: e);
                    },
                    child: Stack(
                      children: [
                        Avatar.profile(me, size: 104),
                        const Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.surfaceHigh,
                            child: Icon(Icons.edit, size: 16, color: AppColors.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 32,
                  child: Center(
                    child: ListView.separated(
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      itemCount: avatarColors.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => _update(color: i),
                        child: Container(
                          width: 32,
                          decoration: BoxDecoration(
                            color: avatarColors[i],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: i == me.avatarColor ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _username,
                  maxLength: 24,
                  decoration: InputDecoration(
                    labelText: 'Pseudo',
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check_rounded),
                      onPressed: () {
                        if (_username.text.trim().length >= 2) _update(username: _username.text);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _Card(
                  children: [
                    const _CardTitle('🔔 Notifications'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: n.enabled,
                      title: const Text('Défi du jour'),
                      subtitle: const Text('Le thème du jour chaque matin'),
                      onChanged: (v) => _saveNotif(n.copyWith(enabled: v)),
                    ),
                    if (n.enabled)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Heure du rappel'),
                        trailing: Pill(
                          label: '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}',
                          icon: '⏰',
                        ),
                        onTap: _pickTime,
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: n.voteReminder,
                      title: const Text('Rappel de vote'),
                      subtitle: const Text('Quand les votes s\'ouvrent'),
                      onChanged: (v) => _saveNotif(n.copyWith(voteReminder: v)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const _Card(
                  children: [
                    _CardTitle('📖 Comment ça marche'),
                    _Step('1', 'Chaque jour, un nouveau thème photo pour ton groupe.'),
                    _Step(
                      '2',
                      'Poste ta photo avant l\'heure du vote. Tu découvres celles des autres une fois la tienne postée.',
                    ),
                    _Step('3', 'Vote pour la plus drôle 😂, la plus belle 😍 et la plus originale 🤯.'),
                    _Step('4', 'Les points s\'accumulent. Chaque mois, une nouvelle saison et un nouveau champion 👑.'),
                  ],
                ),
                const SizedBox(height: 14),
                _Card(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Politique de confidentialité'),
                      onTap: () => launchUrl(Uri.parse(privacyPolicyUrl), mode: LaunchMode.externalApplication),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.logout_rounded),
                      title: const Text('Se déconnecter'),
                      onTap: () async {
                        await NotificationService.instance.cancelAll();
                        await Api.signOut();
                        if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
                      title: const Text('Supprimer mon compte', style: TextStyle(color: AppColors.danger)),
                      onTap: _deleteAccount,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
  );
}

class _Step extends StatelessWidget {
  const _Step(this.n, this.text);

  final String n;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
          child: Text(n, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(height: 1.3))),
      ],
    ),
  );
}
