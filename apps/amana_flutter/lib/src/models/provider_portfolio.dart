import '../utils/media_kind.dart';

/// One image or short video in a provider's public «معرض الأعمال».
class ProviderPortfolioItem {
  const ProviderPortfolioItem({
    required this.id,
    required this.providerId,
    required this.title,
    required this.url,
    this.serviceId,
    this.caption,
    this.storagePath,
    this.mediaType,
    this.sortOrder = 0,
    this.isHidden = false,
    this.createdAt,
  });

  static const maxPerProvider = 12;

  final String id;
  final String providerId;
  final String? serviceId;
  final String title;
  final String? caption;
  final String? storagePath;

  /// `image`, `video`, or null when the row did not say (sniff [url]).
  final String? mediaType;
  final String url;
  final int sortOrder;
  final bool isHidden;
  final DateTime? createdAt;

  bool get hasUrl => url.trim().isNotEmpty;

  bool get isVideo =>
      mediaKindFrom(
        mediaType: mediaType,
        url: url,
        storagePath: storagePath,
      ) ==
      PortfolioMediaKind.video;

  factory ProviderPortfolioItem.fromJson(Map<String, dynamic> json) {
    final raw = json['media_type']?.toString().trim().toLowerCase();
    final known = (raw == 'image' || raw == 'video') ? raw : null;
    return ProviderPortfolioItem(
      id: json['id']?.toString().trim() ?? '',
      providerId: json['provider_id']?.toString().trim() ?? '',
      serviceId: json['service_id']?.toString().trim(),
      title: (json['title'] as String?)?.trim() ?? '',
      caption: (json['caption'] as String?)?.trim(),
      storagePath: (json['storage_path'] as String?)?.trim(),
      mediaType: known,
      url: (json['url'] as String?)?.trim() ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isHidden: json['is_hidden'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}
