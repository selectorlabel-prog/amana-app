import 'package:amana_flutter/src/models/provider_portfolio.dart';
import 'package:amana_flutter/src/utils/media_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('photo extensions keep image MIME types', () {
    expect(contentTypeForExtension('jpg'), 'image/jpeg');
    expect(contentTypeForExtension('jpeg'), 'image/jpeg');
    expect(contentTypeForExtension('png'), 'image/png');
    expect(contentTypeForExtension('webp'), 'image/webp');
    expect(contentTypeForExtension('gif'), 'image/gif');
    expect(mediaExtensionOfName('photo.JPEG'), 'jpg');
    expect(looksLikeVideo('https://cdn.example/a.jpg'), isFalse);
    expect(
      mediaKindFrom(url: 'https://cdn.example/work.png'),
      PortfolioMediaKind.image,
    );
  });

  test('video extensions map to mp4 mov and webm', () {
    expect(contentTypeForExtension('mp4'), 'video/mp4');
    expect(contentTypeForExtension('m4v'), 'video/mp4');
    expect(contentTypeForExtension('mov'), 'video/quicktime');
    expect(contentTypeForExtension('webm'), 'video/webm');
    expect(looksLikeVideo('https://cdn.example/a.MOV?t=1'), isTrue);
    expect(
      looksLikeVideo(
        'https://proj.supabase.co/storage/v1/object/public/order-attachments/oid/1.webm',
      ),
      isTrue,
    );
    expect(isVideoExtension('mp4'), isTrue);
    expect(isVideoExtension('jpg'), isFalse);
  });

  test('explicit media_type wins over the file extension', () {
    expect(
      mediaKindFrom(
        mediaType: 'image',
        url: 'https://cdn.example/clip.mp4',
      ),
      PortfolioMediaKind.image,
    );
    expect(
      mediaKindFrom(
        mediaType: 'video',
        url: 'https://cdn.example/still.jpg',
      ),
      PortfolioMediaKind.video,
    );
  });

  test('duration cap allows one minute and rejects longer clips', () {
    expect(
      isAllowedShortVideoDuration(const Duration(seconds: 60)),
      isTrue,
    );
    expect(
      isAllowedShortVideoDuration(
        const Duration(seconds: 60, milliseconds: 500),
      ),
      isTrue,
    );
    expect(
      isAllowedShortVideoDuration(const Duration(seconds: 61)),
      isFalse,
    );
    expect(isAllowedShortVideoDuration(Duration.zero), isFalse);
    expect(shortVideoMaxBytes, 20 * 1024 * 1024);
  });

  test('portfolio rows without media_type sniff the url', () {
    final photo = ProviderPortfolioItem.fromJson({
      'id': '1',
      'provider_id': '2',
      'title': 'لوحة',
      'url': 'https://cdn.example/a.jpg',
    });
    final clip = ProviderPortfolioItem.fromJson({
      'id': '3',
      'provider_id': '2',
      'title': 'تسريب',
      'url': 'https://cdn.example/u/portfolio/clip.mp4',
      'media_type': 'video',
    });
    expect(photo.isVideo, isFalse);
    expect(photo.mediaType, isNull);
    expect(clip.isVideo, isTrue);
    expect(clip.mediaType, 'video');

    final legacyVideo = ProviderPortfolioItem(
      id: '4',
      providerId: '2',
      title: 'عمل',
      url: 'https://cdn.example/u/portfolio/old.mov',
    );
    expect(legacyVideo.isVideo, isTrue);
  });
}
