import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/media_kind.dart';
import '../utils/video_duration_stub.dart'
    if (dart.library.io) '../utils/video_duration_io.dart';
import 'supabase_service.dart';

/// Upload result for storage + optional DB metadata.
class StorageUploadResult {
  const StorageUploadResult({
    required this.url,
    required this.path,
  });

  final String url;
  final String path;
}

/// Supabase Storage helpers for avatars, verification docs, order images,
/// optional short order videos, and provider portfolio
/// (same avatars bucket, `{userId}/portfolio/...`).
class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  static const bucketAvatars = 'avatars';
  static const bucketVerification = 'verification';
  static const bucketOrderAttachments = 'order-attachments';
  static const bucketServiceProofs = 'service-proofs';

  SupabaseClient get _client {
    if (!SupabaseService.isInitialized) {
      throw StateError('Supabase غير مهيأ — تحقق من إعدادات الاتصال');
    }
    return SupabaseService.client;
  }

  String? get _userId => SupabaseService.instance.currentUserId;

  /// Picks an image from gallery or camera. Returns null if cancelled.
  Future<XFile?> pickImage({
    ImageSource source = ImageSource.gallery,
    int imageQuality = 85,
    double? maxWidth,
  }) async {
    final picker = ImagePicker();
    try {
      return await picker.pickImage(
        source: source,
        imageQuality: imageQuality,
        maxWidth: maxWidth ?? 1600,
      );
    } on Object catch (error) {
      debugPrint('[Storage] pickImage failed: $error');
      throw StateError(_pickError(error));
    }
  }

  /// Gallery or camera clip. Rejects anything over [shortVideoMaxSeconds]
  /// or [shortVideoMaxBytes], and any type other than mp4/mov/webm/m4v.
  /// [ImagePicker.maxDuration] is only a hint for the camera; duration is
  /// checked again from the file.
  Future<XFile?> pickVideo({
    ImageSource source = ImageSource.gallery,
    Duration? maxDuration,
  }) async {
    final picker = ImagePicker();
    try {
      final file = await picker.pickVideo(
        source: source,
        maxDuration:
            maxDuration ?? const Duration(seconds: shortVideoMaxSeconds),
      );
      if (file == null) return null;
      await _assertShortVideo(file);
      return file;
    } on StateError {
      rethrow;
    } on Object catch (error) {
      debugPrint('[Storage] pickVideo failed: $error');
      throw StateError(_pickError(error, video: true));
    }
  }

  Future<StorageUploadResult> uploadAvatar(String userId, XFile file) async {
    final uid = userId.trim();
    if (uid.isEmpty) {
      throw StateError('معرّف المستخدم غير متوفر لرفع الصورة الشخصية');
    }
    _requireSession(uid);

    final ext = _extensionOf(file);
    final path = '$uid/avatar.$ext';
    final bytes = await file.readAsBytes();
    _ensureNotEmpty(bytes);

    try {
      await _client.storage.from(bucketAvatars).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentType(ext),
              upsert: true,
            ),
          );
      final url = _client.storage.from(bucketAvatars).getPublicUrl(path);
      // Cache-bust so UI refreshes after replace.
      final stamped = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
      return StorageUploadResult(url: stamped, path: path);
    } on Object catch (error) {
      debugPrint('[Storage] uploadAvatar failed: $error');
      throw StateError(_storageError(error, action: 'رفع الصورة الشخصية'));
    }
  }

  /// Same as [uploadAvatar] but from in-memory bytes (signup draft rehydrate).
  Future<StorageUploadResult> uploadAvatarBytes(
    String userId,
    Uint8List bytes, {
    String ext = 'jpg',
  }) async {
    final uid = userId.trim();
    if (uid.isEmpty) {
      throw StateError('معرّف المستخدم غير متوفر لرفع الصورة الشخصية');
    }
    _requireSession(uid);
    _ensureNotEmpty(bytes);

    final safeExt = ext.trim().isEmpty ? 'jpg' : ext.trim().toLowerCase();
    final path = '$uid/avatar.$safeExt';

    try {
      await _client.storage.from(bucketAvatars).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentType(safeExt),
              upsert: true,
            ),
          );
      final url = _client.storage.from(bucketAvatars).getPublicUrl(path);
      final stamped = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
      return StorageUploadResult(url: stamped, path: path);
    } on Object catch (error) {
      debugPrint('[Storage] uploadAvatarBytes failed: $error');
      throw StateError(_storageError(error, action: 'رفع الصورة الشخصية'));
    }
  }

  /// Identity photos plus courier vehicle documents.
  Future<StorageUploadResult> uploadVerificationDoc(
    String userId,
    String type,
    XFile file,
  ) async {
    final uid = userId.trim();
    final docType = type.trim().toLowerCase();
    if (uid.isEmpty) {
      throw StateError('معرّف المستخدم غير متوفر لرفع مستند التحقق');
    }
    if (!const {
      'id_front',
      'id_back',
      'selfie',
      'driving_license_front',
      'driving_license_back',
      'vehicle_card_front',
      'vehicle_card_back',
      'plate_photo',
      'plate_front',
      'plate_back',
      'bicycle_photo',
    }.contains(docType)) {
      throw StateError('نوع المستند غير صالح');
    }
    _requireSession(uid);

    final ext = _extensionOf(file);
    final path = '$uid/$docType.$ext';
    final bytes = await file.readAsBytes();
    _ensureNotEmpty(bytes);

    try {
      await _client.storage.from(bucketVerification).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentType(ext),
              upsert: true,
            ),
          );

      // Private bucket — signed URL for preview (7 days).
      final signed = await _client.storage
          .from(bucketVerification)
          .createSignedUrl(path, 60 * 60 * 24 * 7);

      await _client.from('verification_documents').upsert(
        {
          'user_id': uid,
          'doc_type': docType,
          'storage_path': path,
          'url': signed,
        },
        onConflict: 'user_id,doc_type',
      );

      return StorageUploadResult(url: signed, path: path);
    } on Object catch (error) {
      debugPrint('[Storage] uploadVerificationDoc failed: $error');
      throw StateError(_storageError(error, action: 'رفع مستند التحقق'));
    }
  }

  Future<StorageUploadResult> uploadOrderAttachment(
    String orderId,
    XFile file,
  ) async {
    final oid = orderId.trim();
    final uid = _userId;
    if (uid == null) {
      throw StateError('يجب تسجيل الدخول لرفع مرفق الطلب');
    }
    if (oid.isEmpty || !SupabaseService.isLikelyUuid(oid)) {
      throw StateError('معرّف الطلب غير صالح لرفع المرفق');
    }

    final ext = _extensionOf(file);
    final video = isVideoExtension(ext);
    if (video) {
      await _assertShortVideo(file);
    }
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${_shortId()}.$ext';
    final path = '$oid/$fileName';
    final bytes = await file.readAsBytes();
    _ensureNotEmpty(
      bytes,
      maxBytes: video ? shortVideoMaxBytes : 10 * 1024 * 1024,
      emptyMessage: video ? 'ملف الفيديو فارغ' : 'الملف فارغ — اختر صورة صالحة',
      tooLargeMessage: video
          ? 'حجم الفيديو كبير جداً (الحد ${shortVideoMaxBytes ~/ (1024 * 1024)} ميجابايت)'
          : 'حجم الصورة كبير جداً (الحد 10 ميجابايت)',
    );

    try {
      await _client.storage.from(bucketOrderAttachments).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentType(ext),
              upsert: false,
            ),
          );
      final url =
          _client.storage.from(bucketOrderAttachments).getPublicUrl(path);

      try {
        await _client.from('order_attachments').insert({
          'order_id': oid,
          'uploader_id': uid,
          'url': url,
          'storage_path': path,
        });
      } on Object catch (dbError) {
        // Storage succeeded — surface table/RLS issues clearly.
        debugPrint('[Storage] order_attachments insert failed: $dbError');
        throw StateError(
          _storageError(dbError, action: 'حفظ سجل مرفق الطلب'),
        );
      }

      return StorageUploadResult(url: url, path: path);
    } on StateError {
      rethrow;
    } on Object catch (error) {
      debugPrint('[Storage] uploadOrderAttachment failed: $error');
      throw StateError(_storageError(error, action: 'رفع مرفق الطلب'));
    }
  }

  /// Public gallery photo in the existing avatars bucket (5MB).
  /// Path: `{userId}/portfolio/{file}` — not service-proofs or order attachments.
  Future<StorageUploadResult> uploadPortfolioImage(XFile file) async {
    final uid = _userId;
    if (uid == null) {
      throw StateError('يجب تسجيل الدخول لرفع صورة المعرض');
    }

    final ext = _extensionOf(file);
    if (isVideoExtension(ext)) {
      throw StateError('لرفع فيديو المعرض استخدم رفع الوسائط، لا رفع الصورة');
    }
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${_shortId()}.$ext';
    final path = '$uid/portfolio/$fileName';
    final bytes = await file.readAsBytes();
    _ensureNotEmpty(bytes);
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      throw StateError('حجم الصورة كبير جداً (الحد 5 ميجابايت)');
    }

    try {
      await _client.storage.from(bucketAvatars).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentType(ext),
              upsert: false,
            ),
          );
      final url = _client.storage.from(bucketAvatars).getPublicUrl(path);
      return StorageUploadResult(url: url, path: path);
    } on Object catch (error) {
      debugPrint('[Storage] uploadPortfolioImage failed: $error');
      throw StateError(_storageError(error, action: 'رفع صورة المعرض'));
    }
  }

  /// Gallery image (5MB, same as [uploadPortfolioImage]) or one short video
  /// (mp4/mov/webm, [shortVideoMaxSeconds] / [shortVideoMaxBytes]) in
  /// `{userId}/portfolio/`.
  Future<StorageUploadResult> uploadPortfolioMedia(XFile file) async {
    final ext = _extensionOf(file);
    if (!isVideoExtension(ext)) {
      return uploadPortfolioImage(file);
    }

    final uid = _userId;
    if (uid == null) {
      throw StateError('يجب تسجيل الدخول لرفع فيديو المعرض');
    }
    await _assertShortVideo(file);

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${_shortId()}.$ext';
    final path = '$uid/portfolio/$fileName';
    final bytes = await file.readAsBytes();
    _ensureNotEmpty(
      bytes,
      maxBytes: shortVideoMaxBytes,
      emptyMessage: 'ملف الفيديو فارغ',
      tooLargeMessage:
          'حجم الفيديو كبير جداً (الحد ${shortVideoMaxBytes ~/ (1024 * 1024)} ميجابايت)',
    );

    try {
      await _client.storage.from(bucketAvatars).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentType(ext),
              upsert: false,
            ),
          );
      final url = _client.storage.from(bucketAvatars).getPublicUrl(path);
      return StorageUploadResult(url: url, path: path);
    } on Object catch (error) {
      debugPrint('[Storage] uploadPortfolioMedia failed: $error');
      throw StateError(_storageError(error, action: 'رفع فيديو المعرض'));
    }
  }

  Future<void> deletePortfolioFile(String storagePath) async {
    final uid = _userId;
    final path = storagePath.trim();
    if (uid == null || path.isEmpty) return;
    if (!path.startsWith('$uid/portfolio/')) return;
    try {
      await _client.storage.from(bucketAvatars).remove([path]);
    } on Object catch (error) {
      debugPrint('[Storage] deletePortfolioFile failed: $error');
    }
  }

  /// Work-completion proof. Path: `{uid}/order-proofs/{orderId}/{file}`
  /// in the existing private `service-proofs` bucket.
  Future<StorageUploadResult> uploadOrderWorkProof({
    required String orderId,
    required XFile file,
  }) async {
    final uid = _userId;
    final oid = orderId.trim();
    if (uid == null) {
      throw StateError('يجب تسجيل الدخول لرفع إثبات العمل');
    }
    if (oid.isEmpty) {
      throw StateError('معرّف الطلب غير صالح لرفع الإثبات');
    }

    final ext = _extensionOf(file);
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${_shortId()}.$ext';
    final path = '$uid/order-proofs/$oid/$fileName';
    final bytes = await file.readAsBytes();
    _ensureNotEmpty(bytes);

    try {
      await _client.storage.from(bucketServiceProofs).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentType(ext),
              upsert: false,
            ),
          );
      final signed = await _client.storage
          .from(bucketServiceProofs)
          .createSignedUrl(path, 60 * 60 * 24 * 7);
      return StorageUploadResult(url: signed, path: path);
    } on Object catch (error) {
      debugPrint('[Storage] uploadOrderWorkProof failed: $error');
      throw StateError(_storageError(error, action: 'رفع إثبات العمل'));
    }
  }

  Future<StorageUploadResult> uploadServiceProof({
    required String serviceId,
    required XFile file,
  }) async {
    final uid = _userId;
    final sid = serviceId.trim();
    if (uid == null) {
      throw StateError('يجب تسجيل الدخول لرفع إثبات الخدمة');
    }
    if (sid.isEmpty) {
      throw StateError('معرّف الخدمة غير صالح لرفع الإثبات');
    }

    final ext = _extensionOf(file);
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${_shortId()}.$ext';
    final path = '$uid/$sid/$fileName';
    final bytes = await file.readAsBytes();
    _ensureNotEmpty(bytes);

    try {
      await _client.storage.from(bucketServiceProofs).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentType(ext),
              upsert: false,
            ),
          );
      final signed = await _client.storage
          .from(bucketServiceProofs)
          .createSignedUrl(path, 60 * 60 * 24 * 7);
      return StorageUploadResult(url: signed, path: path);
    } on Object catch (error) {
      debugPrint('[Storage] uploadServiceProof failed: $error');
      throw StateError(_storageError(error, action: 'رفع إثبات الخدمة'));
    }
  }

  Future<List<String>> signServiceProofPaths(List<String> paths) async {
    final out = <String>[];
    for (final path in paths) {
      final p = path.trim();
      if (p.isEmpty) continue;
      try {
        final url = await _client.storage
            .from(bucketServiceProofs)
            .createSignedUrl(p, 60 * 60 * 24 * 7);
        if (url.isNotEmpty) out.add(url);
      } on Object catch (error) {
        debugPrint('[Storage] sign service proof failed: $error');
      }
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> fetchOrderAttachments(
    String orderId,
  ) async {
    final oid = orderId.trim();
    if (oid.isEmpty || !SupabaseService.isLikelyUuid(oid)) {
      return const [];
    }
    try {
      final rows = await _client
          .from('order_attachments')
          .select()
          .eq('order_id', oid)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } on Object catch (error) {
      debugPrint('[Storage] fetchOrderAttachments failed: $error');
      return const [];
    }
  }

  Future<Map<String, String>> fetchVerificationUrls(String userId) async {
    try {
      final rows = await _client
          .from('verification_documents')
          .select('doc_type, url, storage_path')
          .eq('user_id', userId);
      final out = <String, String>{};
      for (final row in rows as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final type = (map['doc_type'] as String?)?.trim() ?? '';
        var url = (map['url'] as String?)?.trim() ?? '';
        final path = (map['storage_path'] as String?)?.trim() ?? '';
        if (type.isEmpty) continue;
        if (url.isEmpty && path.isNotEmpty) {
          try {
            url = await _client.storage
                .from(bucketVerification)
                .createSignedUrl(path, 60 * 60 * 24 * 7);
          } on Object {
            continue;
          }
        }
        if (url.isNotEmpty) out[type] = url;
      }
      return out;
    } on Object catch (error) {
      debugPrint('[Storage] fetchVerificationUrls failed: $error');
      return const {};
    }
  }

  void _requireSession(String userId) {
    final current = _userId;
    if (current == null) {
      throw StateError('يجب تسجيل الدخول أولاً');
    }
    if (current != userId) {
      throw StateError('لا يمكنك رفع ملفات لحساب آخر');
    }
  }

  void _ensureNotEmpty(
    Uint8List bytes, {
    int maxBytes = 10 * 1024 * 1024,
    String emptyMessage = 'الملف فارغ — اختر صورة صالحة',
    String tooLargeMessage = 'حجم الصورة كبير جداً (الحد 10 ميجابايت)',
  }) {
    if (bytes.isEmpty) {
      throw StateError(emptyMessage);
    }
    if (bytes.lengthInBytes > maxBytes) {
      throw StateError(tooLargeMessage);
    }
  }

  Future<void> _assertShortVideo(XFile file) async {
    final ext = _extensionOf(file);
    if (!isVideoExtension(ext)) {
      throw StateError('صيغة الفيديو غير مدعومة. استخدم MP4 أو MOV أو WEBM.');
    }
    final length = await file.length();
    if (length <= 0) {
      throw StateError('ملف الفيديو فارغ');
    }
    if (length > shortVideoMaxBytes) {
      throw StateError(
        'حجم الفيديو كبير جداً (الحد ${shortVideoMaxBytes ~/ (1024 * 1024)} ميجابايت)',
      );
    }

    Duration? duration;
    try {
      duration = await probeVideoDuration(file.path);
    } on StateError {
      rethrow;
    } on Object catch (error) {
      throw StateError(
        'تعذّر قراءة مدة الفيديو. جرّب حفظه بصيغة MP4.\n$error',
      );
    }
    if (duration == null) {
      // Probe is unavailable (web). The size cap still applies.
      return;
    }
    if (duration <= Duration.zero) {
      throw StateError('تعذّر قراءة مدة الفيديو. جرّب حفظه بصيغة MP4.');
    }
    if (!isAllowedShortVideoDuration(duration)) {
      throw StateError(
        'الفيديو أطول من $shortVideoMaxSeconds ثانية. اختر مقطعاً أقصر.',
      );
    }
  }

  static String _extensionOf(XFile file) {
    final named = mediaExtensionOfName(file.name) ??
        mediaExtensionOfName(file.path);
    if (named != null) return named;
    final mime = file.mimeType?.toLowerCase() ?? '';
    if (mime.contains('png')) return 'png';
    if (mime.contains('webp')) return 'webp';
    if (mime.contains('gif')) return 'gif';
    if (mime.contains('webm')) return 'webm';
    if (mime.contains('quicktime')) return 'mov';
    if (mime.contains('mp4')) return 'mp4';
    return 'jpg';
  }

  static String _contentType(String ext) => contentTypeForExtension(ext);

  static String _shortId() {
    final n = DateTime.now().microsecondsSinceEpoch;
    return n.toRadixString(36);
  }

  static String _pickError(Object error, {bool video = false}) {
    final text = error.toString().toLowerCase();
    final noun = video ? 'الفيديو' : 'الصورة';
    if (text.contains('permission') || text.contains('denied')) {
      return 'تم رفض إذن الوصول للكاميرا أو المعرض.\n'
          'فعّل الإذن من إعدادات الجهاز ثم أعد المحاولة.';
    }
    if (text.contains('camera')) {
      return video
          ? 'تعذّر فتح الكاميرا. جرّب اختيار فيديو من المعرض.'
          : 'تعذّر فتح الكاميرا. جرّب اختيار صورة من المعرض.';
    }
    return 'تعذّر اختيار $noun.\nالتفاصيل: $error';
  }

  static String _storageError(Object error, {required String action}) {
    final detail = error is StorageException
        ? '${error.message} (status=${error.statusCode ?? '?'})'
        : error is PostgrestException
            ? [
                error.message,
                if ((error.details ?? '').toString().trim().isNotEmpty)
                  error.details.toString(),
                'رمز=${error.code ?? '?'}',
              ].join(' | ')
            : error.toString();
    final lower = detail.toLowerCase();

    if (lower.contains('bucket') &&
        (lower.contains('not found') || lower.contains('does not exist'))) {
      return 'فشل $action: حاوية التخزين غير موجودة.\n'
          'شغّل supabase/15_storage_images_patch.sql '
          'أو 57_provider_service_verification.sql في Supabase.\n'
          'التفاصيل: $detail';
    }
    if (lower.contains('verification_documents') ||
        lower.contains('order_attachments')) {
      return 'فشل $action: جدول المرفقات غير موجود.\n'
          'شغّل supabase/15_storage_images_patch.sql.\n'
          'التفاصيل: $detail';
    }
    if (lower.contains('row-level security') ||
        lower.contains('42501') ||
        lower.contains('unauthorized') ||
        lower.contains('permission') ||
        lower.contains('not allowed')) {
      return 'فشل $action: سياسة الأمان تمنع الرفع.\n'
          'تأكد من تسجيل الدخول وشغّل 15_storage_images_patch.sql.\n'
          'التفاصيل: $detail';
    }
    if (lower.contains('payload too large') ||
        lower.contains('entity too large') ||
        lower.contains('413')) {
      return 'فشل $action: حجم الملف كبير جداً.';
    }
    if ((lower.contains('mime') ||
            lower.contains('content type') ||
            lower.contains('content-type')) &&
        (lower.contains('not allowed') ||
            lower.contains('invalid') ||
            lower.contains('unsupported') ||
            lower.contains('not supported'))) {
      return 'فشل $action: نوع الملف غير مسموح في حاوية التخزين.\n'
          'شغّل supabase/150_short_video_media.sql في محرر SQL.\n'
          'التفاصيل: $detail';
    }
    return 'تعذّر $action.\nالتفاصيل: $detail';
  }
}
