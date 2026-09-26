import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../services/api.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/results_view.dart';
import 'photo_viewer.dart';
import 'vote_screen.dart';

class TodayTab extends StatefulWidget {
  const TodayTab({super.key, required this.groupId});

  final String groupId;

  @override
  State<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<TodayTab> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  TodayState? _state;
  List<Submission> _subs = [];
  ChallengeResults? _results;
  Object? _error;
  Timer? _ticker;
  bool _uploading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final st = await Api.today(widget.groupId);
      List<Submission> subs = [];
      ChallengeResults? results;
      if (st.phase == Phase.closed) {
        results = await Api.results(st.challenge.id);
        subs = results.submissions;
      } else if (st.mySubmission != null || st.phase == Phase.voting) {
        subs = await Api.submissions(st.challenge.id);
      }
      if (!mounted) return;
      setState(() {
        _state = st;
        _subs = subs;
        _results = results;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _takePhoto(ImageSource source) async {
    final st = _state;
    if (st == null) return;
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (e) {
      if (mounted) showMessage(context, 'Impossible d\'accéder à l\'appareil photo.');
      return;
    }
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final caption = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoPreview(bytes: bytes, challenge: st.challenge),
      ),
    );
    if (caption == null) return;
    setState(() => _uploading = true);
    try {
      await Api.submitPhoto(challenge: st.challenge, bytes: bytes, caption: caption, replacing: st.mySubmission);
      if (mounted) showMessage(context, 'Photo envoyée ! 🎉');
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _chooseSource() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(ctx);
                _takePhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () {
                Navigator.pop(ctx);
                _takePhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _vote() async {
    final st = _state!;
    final others = _subs.where((s) => s.userId != Api.myId).toList();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoteScreen(challenge: st.challenge, submissions: others),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final st = _state;
    if (st == null) {
      if (_error != null) {
        return ListView(
          children: [
            const SizedBox(height: 60),
            EmptyState(
              emoji: '📡',
              title: 'Chargement impossible',
              subtitle: friendlyError(_error!),
              action: OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
            ),
          ],
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      color: AppColors.pink,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _ChallengeHeader(state: st),
          const SizedBox(height: 16),
          ..._phaseContent(st),
        ],
      ),
    );
  }

  List<Widget> _phaseContent(TodayState st) {
    final mine = st.mySubmission == null ? null : _subs.where((s) => s.id == st.mySubmission!.id).firstOrNull;
    final others = _subs.where((s) => s.userId != Api.myId).toList();

    switch (st.phase) {
      case Phase.submission:
      case Phase.upcoming:
        if (st.mySubmission == null) {
          return [
            _BigCameraButton(loading: _uploading, onTap: _chooseSource),
            const SizedBox(height: 16),
            _LockedGallery(count: st.submissionCount),
          ];
        }
        return [
          _SectionTitle('Ta photo'),
          if (mine != null) _MyPhotoCard(submission: mine, onRetake: _uploading ? null : _chooseSource),
          const SizedBox(height: 20),
          _SectionTitle(others.isEmpty ? 'Les autres' : 'Les autres (${others.length})'),
          if (others.isEmpty)
            const _Hint(emoji: '⏳', text: 'Personne d\'autre n\'a encore posté. Relance tes potes !')
          else
            PhotoGrid(submissions: others),
          const SizedBox(height: 12),
          _Hint(
            emoji: '🗳️',
            text: st.submissionCount < 2
                ? 'Le vote s\'ouvre dès qu\'il y a au moins 2 photos, à ${st.voteHour}h ou quand tout le monde a posté.'
                : 'Le vote s\'ouvre à ${st.voteHour}h, ou dès que tout le monde a posté.',
          ),
        ];

      case Phase.voting:
        final canVote = others.isNotEmpty;
        final done = st.myVoteCount >= 3;
        return [
          if (canVote)
            GradientButton(
              label: done ? 'Modifier mes votes' : 'Voter maintenant',
              icon: Icons.how_to_vote_rounded,
              gradient: done ? AppColors.violetGradient : AppColors.brandGradient,
              onPressed: _vote,
            ),
          if (done) ...[
            const SizedBox(height: 10),
            const _Hint(
              emoji: '✅',
              text: 'Tes 3 votes sont enregistrés. Résultats quand tout le monde aura voté, ou à minuit.',
            ),
          ],
          if (st.mySubmission == null) ...[
            const SizedBox(height: 10),
            const _Hint(emoji: '😬', text: 'Trop tard pour poster aujourd\'hui… mais tu peux quand même voter !'),
          ],
          const SizedBox(height: 20),
          _SectionTitle('Les photos du jour (${_subs.length})'),
          PhotoGrid(submissions: _subs),
        ];

      case Phase.closed:
        final r = _results;
        if (r == null) return [];
        return [ResultsView(results: r)];
    }
  }
}

class _ChallengeHeader extends StatelessWidget {
  const _ChallengeHeader({required this.state});

  final TodayState state;

  @override
  Widget build(BuildContext context) {
    final st = state;
    final (String status, String detail) = switch (st.phase) {
      Phase.submission || Phase.upcoming => (
        '📸 Photos · ${st.submissionCount}/${st.memberCount}',
        untilGameHour(st.voteHour).isNegative
            ? 'Vote dès 2 photos'
            : 'Vote dans ${formatDuration(untilGameHour(st.voteHour))}',
      ),
      Phase.voting => ('🗳️ Votes · ${st.votersDone}/${st.memberCount}', 'Fin dans ${formatDuration(untilMidnight())}'),
      Phase.closed => ('🏆 Résultats', 'Nouveau défi dans ${formatDuration(untilMidnight())}'),
    };
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: AppColors.pink.withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'DÉFI DU JOUR',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12),
              ),
              const Spacer(),
              if (st.streak > 0)
                Pill(label: '${st.streak} jour${st.streak > 1 ? 's' : ''}', icon: '🔥', color: Colors.black26),
            ],
          ),
          const SizedBox(height: 12),
          Text(st.challenge.emoji, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 6),
          Text(
            st.challenge.text,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.1),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Flexible(
                child: Pill(label: status, color: Colors.black26, textColor: Colors.white),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Pill(label: detail, color: Colors.black26, textColor: Colors.white, icon: '⏱️'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigCameraButton extends StatelessWidget {
  const _BigCameraButton({required this.onTap, required this.loading});

  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: loading ? null : onTap,
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.pink.withValues(alpha: 0.6), width: 2),
          ),
          child: Center(
            child: loading
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 14),
                      Text('Envoi en cours…', style: TextStyle(color: AppColors.textDim)),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 38),
                      ),
                      const SizedBox(height: 14),
                      const Text('Prendre ma photo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const Text('Sois créatif, sois drôle, sois toi 😎', style: TextStyle(color: AppColors.textDim)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _LockedGallery extends StatelessWidget {
  const _LockedGallery({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          const Text('🔒', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 0
                      ? 'Sois le premier à poster !'
                      : '$count photo${count > 1 ? 's' : ''} déjà postée${count > 1 ? 's' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Poste la tienne pour découvrir celles des autres.',
                  style: TextStyle(color: AppColors.textDim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyPhotoCard extends StatelessWidget {
  const _MyPhotoCard({required this.submission, required this.onRetake});

  final Submission submission;
  final VoidCallback? onRetake;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => openPhotoViewer(context, [submission], 0),
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: SubmissionPhoto(submission: submission),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 40, 12, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      submission.caption ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: onRetake,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reprendre'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PhotoGrid extends StatelessWidget {
  const PhotoGrid({super.key, required this.submissions});

  final List<Submission> submissions;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 4 / 5,
      ),
      itemCount: submissions.length,
      itemBuilder: (context, i) {
        final s = submissions[i];
        return GestureDetector(
          onTap: () => openPhotoViewer(context, submissions, i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'photo-${s.id}',
                  child: SubmissionPhoto(submission: s),
                ),
                if (s.author != null)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    right: 8,
                    child: Row(
                      children: [
                        Avatar.profile(s.author!, size: 26),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.author!.username,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.emoji, required this.text});

  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.textDim, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

class _PhotoPreview extends StatefulWidget {
  const _PhotoPreview({required this.bytes, required this.challenge});

  final Uint8List bytes;
  final Challenge challenge;

  @override
  State<_PhotoPreview> createState() => _PhotoPreviewState();
}

class _PhotoPreviewState extends State<_PhotoPreview> {
  final _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.challenge.emoji} ${widget.challenge.text}', maxLines: 1)),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom * 0),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.memory(widget.bytes, fit: BoxFit.cover, width: double.infinity),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _caption,
                maxLength: 140,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Ajoute une légende (optionnel)', counterText: ''),
              ),
              const SizedBox(height: 14),
              GradientButton(
                label: 'Envoyer au groupe',
                icon: Icons.send_rounded,
                onPressed: () => Navigator.pop(context, _caption.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
