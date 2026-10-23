import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Dark tile with a play glyph. Used for local picks and remote clips so a
/// video URL is never passed to [Image.network].
class AmanaVideoMark extends StatelessWidget {
  const AmanaVideoMark({
    this.onTap,
    this.compact = false,
    this.label = 'فيديو',
    super.key,
  });

  final VoidCallback? onTap;
  final bool compact;
  final String label;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFF1C1C1C)),
        child: Center(
          child: compact
              ? const Icon(Icons.play_circle_fill, color: Colors.white, size: 22)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 36,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
        ),
      ),
    );

    if (onTap == null) return mark;

    return Material(
      color: const Color(0xFF1C1C1C),
      child: InkWell(
        onTap: onTap,
        child: Semantics(button: true, label: label, child: mark),
      ),
    );
  }
}

/// Inline network player. Tap toggles play. Scrub with the progress bar.
class AmanaNetworkVideo extends StatefulWidget {
  const AmanaNetworkVideo({required this.url, super.key});

  final String url;

  @override
  State<AmanaNetworkVideo> createState() => _AmanaNetworkVideoState();
}

class _AmanaNetworkVideoState extends State<AmanaNetworkVideo> {
  VideoPlayerController? _controller;
  var _failed = false;
  var _playing = false;

  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.url.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      _failed = true;
      return;
    }
    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    controller.addListener(_onTick);
    controller.initialize().then((_) {
      if (mounted) setState(() {});
    }, onError: (Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  void _onTick() {
    final playing = _controller?.value.isPlaying ?? false;
    if (playing == _playing || !mounted) return;
    setState(() => _playing = playing);
  }

  @override
  void deactivate() {
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onTick);
      if (controller.value.isInitialized) {
        controller.pause();
      }
    }
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _controller?.addListener(_onTick);
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onTick);
      controller.dispose();
    }
    super.dispose();
  }

  void _toggle() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed || controller == null) {
      return const Center(
        child: Text(
          'تعذّر تشغيل الفيديو',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
    if (!controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final size = controller.value.size;
    final width = size.width > 0 ? size.width : 16.0;
    final height = size.height > 0 ? size.height : 9.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: width,
              height: height,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        IconButton(
          iconSize: 56,
          color: Colors.white,
          onPressed: _toggle,
          icon: Icon(
            _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 8,
          child: VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Colors.white,
              bufferedColor: Colors.white38,
              backgroundColor: Colors.white24,
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> showAmanaVideoPlayer(
  BuildContext context,
  String url, {
  String title = 'فيديو',
}) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return Future.value();
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              SizedBox(
                height: 320,
                width: double.infinity,
                child: AmanaNetworkVideo(url: trimmed),
              ),
            ],
          ),
        ),
      );
    },
  );
}
