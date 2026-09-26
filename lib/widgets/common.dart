import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../services/api.dart';
import '../theme.dart';

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void showError(BuildContext context, Object error) => showMessage(context, friendlyError(error));

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.emoji, required this.color, this.size = 44, this.ring});

  Avatar.profile(Profile p, {super.key, this.size = 44, this.ring}) : emoji = p.avatarEmoji, color = p.avatarColor;

  final String emoji;
  final int color;
  final double size;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final c = avatarColor(color);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [c, Color.lerp(c, Colors.black, 0.35)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: ring != null ? Border.all(color: ring!, width: size / 16) : null,
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient = AppColors.brandGradient,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient gradient;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: gradient.colors.first.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: 56,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[Icon(icon, color: Colors.white), const SizedBox(width: 10)],
                          Text(
                            label,
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    required this.style,
    this.gradient = AppColors.brandGradient,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final Gradient gradient;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => gradient.createShader(Rect.fromLTWH(0, 0, r.width, r.height)),
      child: Text(text, style: style, textAlign: textAlign),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, this.color = AppColors.surfaceHigh, this.textColor, this.icon});

  final String label;
  final Color color;
  final Color? textColor;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Text(icon!, style: const TextStyle(fontSize: 13)), const SizedBox(width: 5)],
          Text(
            label,
            style: TextStyle(color: textColor ?? AppColors.text, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.emoji, required this.title, this.subtitle, this.action});

  final String emoji;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textDim, fontSize: 15),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    );
  }
}

/// Photo stockée dans Supabase, mise en cache par chemin (les URL signées changent).
class SubmissionPhoto extends StatelessWidget {
  const SubmissionPhoto({super.key, required this.submission, this.fit = BoxFit.cover});

  final Submission submission;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = submission.photoUrl;
    if (url == null) {
      return const ColoredBox(
        color: AppColors.surfaceHigh,
        child: Center(child: Icon(Icons.broken_image_outlined)),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: submission.photoPath,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => const ColoredBox(
        color: AppColors.surfaceHigh,
        child: Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5))),
      ),
      errorWidget: (_, _, _) => const ColoredBox(
        color: AppColors.surfaceHigh,
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

const pickableEmojis = [
  '😎',
  '🤪',
  '🥳',
  '🤠',
  '👻',
  '🤖',
  '👽',
  '🦊',
  '🐸',
  '🐼',
  '🐯',
  '🦁',
  '🐙',
  '🦄',
  '🐝',
  '🐧',
  '🍕',
  '🌮',
  '🍩',
  '🍉',
  '🥑',
  '🌶️',
  '🔥',
  '⚡',
  '🌈',
  '⭐',
  '🌙',
  '🌸',
  '🍀',
  '🎸',
  '🎮',
  '⚽',
  '🏀',
  '🎯',
  '🎲',
  '🚀',
  '🛸',
  '💎',
  '👑',
  '🎩',
  '📸',
  '🎨',
  '🎧',
  '🍿',
  '🧃',
  '🦖',
  '🐢',
  '🦩',
];

Future<String?> pickEmoji(BuildContext context, {List<String> emojis = pickableEmojis}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: GridView.count(
        crossAxisCount: 8,
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final e in emojis)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.pop(ctx, e),
              child: Center(child: Text(e, style: const TextStyle(fontSize: 28))),
            ),
        ],
      ),
    ),
  );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  bool destructive = false,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler', style: TextStyle(color: AppColors.textDim)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel, style: TextStyle(color: destructive ? AppColors.danger : AppColors.pink)),
        ),
      ],
    ),
  );
  return res ?? false;
}

Future<void> shareInvite(Group group, String code) => SharePlus.instance.share(
  ShareParams(
    text:
        'Rejoins mon groupe ${group.emoji} ${group.name} sur Déclic, le défi photo du jour entre potes ! '
        'Code d\'invitation : $code',
    subject: 'Rejoins-moi sur Déclic 📸',
  ),
);
