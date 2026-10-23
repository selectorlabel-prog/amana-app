/// Image vs short-video classification shared by storage, portfolio, and order UI.
///
/// Existing photo rows have no `media_type`. Those stay images unless the
/// file URL/path itself is a video extension.
enum PortfolioMediaKind { image, video }

/// One problem-description or portfolio clip.
const shortVideoMaxSeconds = 60;

/// Phone clips of about a minute stay under this client cap (20 MB).
const shortVideoMaxBytes = 20 * 1024 * 1024;

const videoExtensions = {'mp4', 'mov', 'webm', 'm4v'};

/// True when [duration] is a real clip no longer than [shortVideoMaxSeconds]
/// (half a second of container slack).
bool isAllowedShortVideoDuration(Duration duration) {
  if (duration <= Duration.zero) return false;
  return duration <=
      const Duration(seconds: shortVideoMaxSeconds, milliseconds: 500);
}

/// Extension from a file name or URL path, without the query string.
/// `jpeg` is normalized to `jpg` so photo uploads keep `image/jpeg`.
String? mediaExtensionOfName(String name) {
  final base = name.split('?').first.split('#').first;
  final slash = base.lastIndexOf('/');
  final file = slash >= 0 ? base.substring(slash + 1) : base;
  final dot = file.lastIndexOf('.');
  if (dot <= 0 || dot == file.length - 1) return null;
  final ext = file.substring(dot + 1).toLowerCase();
  if (ext == 'jpeg') return 'jpg';
  const known = {
    'png',
    'webp',
    'gif',
    'jpg',
    'mp4',
    'mov',
    'webm',
    'm4v',
  };
  if (!known.contains(ext)) return null;
  return ext;
}

bool isVideoExtension(String ext) =>
    videoExtensions.contains(ext.trim().toLowerCase());

bool looksLikeVideo(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return false;
  final uri = Uri.tryParse(text);
  final path = (uri == null || uri.path.isEmpty) ? text.split('?').first : uri.path;
  final ext = mediaExtensionOfName(path);
  return ext != null && isVideoExtension(ext);
}

/// MIME for storage uploads. Unknown extensions stay `image/jpeg` (photo path).
String contentTypeForExtension(String ext) {
  return switch (ext.trim().toLowerCase()) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'mp4' || 'm4v' => 'video/mp4',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    _ => 'image/jpeg',
  };
}

/// Explicit `image` / `video` wins. Missing or unknown values fall back to the URL.
PortfolioMediaKind mediaKindFrom({
  String? mediaType,
  String? url,
  String? storagePath,
}) {
  final raw = mediaType?.trim().toLowerCase() ?? '';
  if (raw == 'video') return PortfolioMediaKind.video;
  if (raw == 'image') return PortfolioMediaKind.image;
  if (looksLikeVideo(url) || looksLikeVideo(storagePath)) {
    return PortfolioMediaKind.video;
  }
  return PortfolioMediaKind.image;
}
