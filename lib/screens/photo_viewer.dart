import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/common.dart';

void openPhotoViewer(BuildContext context, List<Submission> submissions, int index) {
  Navigator.push(
    context,
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) => PhotoViewer(submissions: submissions, initialIndex: index),
      transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
    ),
  );
}

class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.submissions, required this.initialIndex});

  final List<Submission> submissions;
  final int initialIndex;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submissions[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.submissions.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: Hero(
                  tag: 'photo-${widget.submissions[i].id}',
                  child: SubmissionPhoto(submission: widget.submissions[i], fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          if (s.author != null || (s.caption?.isNotEmpty ?? false))
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 40, 20, 20 + MediaQuery.paddingOf(context).bottom),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Row(
                  children: [
                    if (s.author != null) ...[Avatar.profile(s.author!, size: 40), const SizedBox(width: 12)],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (s.author != null)
                            Text(s.author!.username, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          if (s.caption?.isNotEmpty ?? false)
                            Text(s.caption!, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                        ],
                      ),
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
