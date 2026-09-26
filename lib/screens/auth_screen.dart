import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  bool _signUp = true;
  bool _loading = false;
  bool _obscure = true;
  late String _emoji = pickableEmojis[Random().nextInt(16)];
  late int _color = Random().nextInt(avatarColors.length);

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_signUp) {
        await Api.signUp(
          email: _email.text,
          password: _password.text,
          username: _username.text,
          avatarEmoji: _emoji,
          avatarColor: _color,
        );
      } else {
        await Api.signIn(_email.text, _password.text);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
        if (friendlyError(e).startsWith('Compte créé')) setState(() => _signUp = false);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgot() async {
    if (!_email.text.contains('@')) {
      showMessage(context, 'Entre ton e-mail ci-dessus d\'abord.');
      return;
    }
    try {
      await Api.resetPassword(_email.text);
      if (mounted) showMessage(context, 'E-mail de réinitialisation envoyé 📬');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: Stack(
        children: [
          const _Blobs(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            gradient: AppColors.brandGradient,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.pink.withValues(alpha: 0.5),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 46, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: GradientText(
                          'Déclic',
                          style: t.displayMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1.5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Un thème par jour. Une photo.\nTes potes votent. 📸',
                        textAlign: TextAlign.center,
                        style: t.titleMedium?.copyWith(color: AppColors.textDim, height: 1.35),
                      ),
                      const SizedBox(height: 32),
                      _ModeSwitch(signUp: _signUp, onChanged: (v) => setState(() => _signUp = v)),
                      const SizedBox(height: 20),
                      if (_signUp) ...[
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final e = await pickEmoji(context);
                                if (e != null) setState(() => _emoji = e);
                              },
                              child: Avatar(emoji: _emoji, color: _color, size: 64),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextFormField(
                                controller: _username,
                                textCapitalization: TextCapitalization.words,
                                maxLength: 24,
                                decoration: const InputDecoration(labelText: 'Pseudo', counterText: ''),
                                validator: (v) => (v == null || v.trim().length < 2) ? 'Au moins 2 caractères' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 32,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: avatarColors.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 10),
                            itemBuilder: (_, i) => GestureDetector(
                              onTap: () => setState(() => _color = i),
                              child: Container(
                                width: 32,
                                decoration: BoxDecoration(
                                  color: avatarColors[i],
                                  shape: BoxShape.circle,
                                  border: Border.all(color: i == _color ? Colors.white : Colors.transparent, width: 3),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.alternate_email)),
                        validator: (v) => (v == null || !v.contains('@')) ? 'E-mail invalide' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6) ? '6 caractères minimum' : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (!_signUp)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(onPressed: _forgot, child: const Text('Mot de passe oublié ?')),
                        ),
                      const SizedBox(height: 20),
                      GradientButton(
                        label: _signUp ? 'Créer mon compte' : 'Se connecter',
                        loading: _loading,
                        onPressed: _submit,
                      ),
                      if (kIsWeb) ...[const SizedBox(height: 24), const _InstallTip()],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.signUp, required this.onChanged});

  final bool signUp;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool value) {
      final selected = signUp == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: selected ? AppColors.brandGradient : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, color: selected ? Colors.white : AppColors.textDim),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [tab('Inscription', true), tab('Connexion', false)]),
    );
  }
}

class _Blobs extends StatelessWidget {
  const _Blobs();

  @override
  Widget build(BuildContext context) {
    Widget blob(Color c, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [c.withValues(alpha: 0.35), c.withValues(alpha: 0)]),
      ),
    );
    return Stack(
      children: [
        Positioned(top: -80, left: -60, child: blob(AppColors.pink, 300)),
        Positioned(top: 120, right: -100, child: blob(AppColors.violet, 320)),
        Positioned(bottom: -120, left: 20, child: blob(AppColors.orange, 300)),
      ],
    );
  }
}

/// Affiché après un clic sur le lien « mot de passe oublié ».
class NewPasswordDialog extends StatefulWidget {
  const NewPasswordDialog({super.key});

  @override
  State<NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<NewPasswordDialog> {
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_password.text.length < 6) {
      showMessage(context, '6 caractères minimum');
      return;
    }
    setState(() => _loading = true);
    try {
      await Api.updatePassword(_password.text);
      if (!mounted) return;
      Navigator.pop(context);
      showMessage(context, 'Mot de passe mis à jour 🔐');
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau mot de passe', style: TextStyle(fontWeight: FontWeight.w900)),
      content: TextField(
        controller: _password,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Mot de passe'),
        onSubmitted: (_) => _save(),
      ),
      actions: [TextButton(onPressed: _loading ? null : _save, child: const Text('Enregistrer'))],
    );
  }
}

/// Version web : explique comment installer Déclic sur l'écran d'accueil d'un iPhone.
class _InstallTip extends StatelessWidget {
  const _InstallTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📲', style: TextStyle(fontSize: 22)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sur iPhone : dans Safari, touche Partager puis « Sur l\'écran d\'accueil » '
              'pour installer Déclic comme une vraie app.',
              style: TextStyle(color: AppColors.textDim, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
