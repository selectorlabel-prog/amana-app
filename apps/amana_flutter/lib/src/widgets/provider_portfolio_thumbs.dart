import 'package:flutter/material.dart';

import '../models/provider_portfolio.dart';
import '../theme/amana_theme.dart';
import 'amana_playable_video.dart';

/// Up to 3 real portfolio thumbnails. Renders nothing when [items] is empty
/// (no gray placeholders, no fake images).
class ProviderPortfolioThumbs extends StatelessWidget {
  const ProviderPortfolioThumbs({
    required this.items,
    this.height = 56,
    super.key,
  });

  static const stripKey = Key('provider-portfolio-thumbs');

  final List<ProviderPortfolioItem> items;
  final double height;

  List<ProviderPortfolioItem> get _visible {
    return items.where((e) => e.hasUrl).take(3).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final thumbs = _visible;
    if (thumbs.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      key: stripKey,
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < thumbs.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              child: Material(
                color: AmanaTheme.surfaceContainerLow,
                child: InkWell(
                  onTap: () => showProviderPortfolioLightbox(
                    context,
                    items: thumbs,
                    initialIndex: i,
                  ),
                  child: thumbs[i].isVideo
                      ? const AmanaVideoMark(compact: true, label: 'فيديو')
                      : Image.network(
                          thumbs[i].url,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showProviderPortfolioLightbox(
  BuildContext context, {
  required List<ProviderPortfolioItem> items,
  int initialIndex = 0,
}) {
  final photos = items.where((e) => e.hasUrl).toList(growable: false);
  if (photos.isEmpty) return Future.value();
  final start = initialIndex.clamp(0, photos.length - 1);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black,
    builder: (ctx) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: _PortfolioLightbox(items: photos, initialIndex: start),
      );
    },
  );
}

class _PortfolioLightbox extends StatefulWidget {
  const _PortfolioLightbox({
    required this.items,
    required this.initialIndex,
  });

  final List<ProviderPortfolioItem> items;
  final int initialIndex;

  @override
  State<_PortfolioLightbox> createState() => _PortfolioLightboxState();
}

class _PortfolioLightboxState extends State<_PortfolioLightbox> {
  late final PageController _pages;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pages = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_index];
    final caption = item.caption?.trim() ?? '';
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      item.title.trim().isEmpty ? 'معرض الأعمال' : item.title,
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
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: widget.items.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final current = widget.items[i];
                  if (current.isVideo) {
                    return AmanaNetworkVideo(url: current.url);
                  }
                  return InteractiveViewer(
                    child: Image.network(
                      current.url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                          size: 48,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              )
            else
              const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
