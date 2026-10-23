import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order.dart';
import '../models/profile.dart';
import '../models/provider_service.dart';
import '../navigation/customer_flow.dart';
import '../services/places_service.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../utils/public_ref.dart';
import '../utils/self_booking.dart';
import '../utils/share_receipt.dart';
import '../utils/service_category_icons.dart';
import '../theme/amana_theme.dart';
import '../utils/image_source_sheet.dart';
import '../utils/media_kind.dart';
import '../widgets/amana_map_preview.dart';
import '../widgets/amana_playable_video.dart';
import '../widgets/amana_user_avatar.dart';
import '../widgets/customer_bottom_nav.dart';
import '../widgets/order_sla_banner.dart';
import 'live_order_tracking_screen.dart';

/// Customer order details — matches `شاشة تفاصيل الطلب/code.html` literally
/// (RTL, status hero, provider, rating, payment, actions) with live Supabase
/// binding + realtime on the order row.
class CustomerOrderDetailScreen extends StatefulWidget {
  const CustomerOrderDetailScreen({
    this.orderId,
    this.seedOrder,
    super.key,
  });

  /// When null (demo / widget tests), shows the static mock UI.
  final String? orderId;

  /// Demo / widget-test seed (applied when not in a live session).
  final AmanaOrder? seedOrder;

  @override
  State<CustomerOrderDetailScreen> createState() =>
      _CustomerOrderDetailScreenState();
}

class _CustomerOrderDetailScreenState extends State<CustomerOrderDetailScreen> {
  static const _monthsAr = <String>[
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  bool _loading = false;
  bool _accepting = false;
  bool _proposing = false;
  String? _error;
  AmanaOrder? _order;
  String? _resolvedAddress;
  Profile? _providerProfile;
  OrderReview? _review;
  double? _providerAvg;
  int _providerReviewCount = 0;
  RealtimeChannel? _orderChannel;
  final _attachmentUrls = <String>[];
  bool _uploadingAttachment = false;

  static const _myRole = 'customer';

  bool get _useLive =>
      widget.orderId != null &&
      widget.orderId!.isNotEmpty &&
      SupabaseService.isLikelyUuid(widget.orderId!) &&
      SupabaseService.isInitialized &&
      SupabaseService.instance.hasSession;

  @override
  void initState() {
    super.initState();
    if (_useLive) {
      _loadOrder();
      _subscribeOrder();
    } else if (widget.seedOrder != null) {
      _order = widget.seedOrder;
    } else {
      _order = const AmanaOrder(
        id: 'AMN-88294',
        customerId: 'demo',
        serviceName: 'سباكة',
        status: 'completed',
        price: 4500,
        notes: 'المزود: أحمد عثمان\nالعنوان: الخرطوم — الرياض',
        createdAt: null,
      );
      _review = null;
      _providerAvg = null;
      _providerReviewCount = 0;
    }
  }

  @override
  void dispose() {
    SupabaseService.instance.removeOrdersPeerListener(_onPeerOrdersChanged);
    _orderChannel?.unsubscribe();
    SupabaseService.instance.unsubscribeChannel(_orderChannel);
    super.dispose();
  }

  void _subscribeOrder() {
    final id = widget.orderId;
    if (id == null || !_useLive) return;
    _orderChannel = SupabaseService.instance.subscribeOrderChanges(
      id,
      onOrder: (order) {
        if (!mounted) return;
        setState(() => _order = order);
        unawaited(_adoptSpecialty(order));
        unawaited(_refreshPlaceLabel(order));
        _loadExtras(silent: true);
      },
    );
    SupabaseService.instance.removeOrdersPeerListener(_onPeerOrdersChanged);
    SupabaseService.instance.addOrdersPeerListener(_onPeerOrdersChanged);
  }

  Future<void> _adoptSpecialty(AmanaOrder order) async {
    if (!_useLive || !SupabaseService.isInitialized) return;
    final labeled =
        await SupabaseService.instance.attachLiveSpecialty(order);
    if (!mounted) return;
    final current = _order;
    if (current == null || current.id != labeled.id) return;
    final label = labeled.specialtyLabel.trim();
    if (label.isEmpty || label == 'خدمة' || current.specialtyLabel == label) {
      return;
    }
    setState(() => _order = current.withSpecialty(label));
  }

  void _onPeerOrdersChanged() {
    if (!mounted || !_useLive) return;
    _loadOrder(silent: true);
  }

  Future<void> _loadOrder({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final order =
          await SupabaseService.instance.fetchOrderById(widget.orderId!);
      if (!mounted) return;
      if (order == null) {
        setState(() {
          _error =
              'لم نجد تفاصيل الطلب. إن كان مكتملاً أو ملغى، شغّل '
              'supabase/23_orders_reviews_completed_restore.sql ثم أعد المحاولة.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _order = order;
        _loading = false;
        _error = null;
      });
      unawaited(_refreshPlaceLabel(order));
      await SupabaseService.instance.scanOrderSla();
      await _loadExtras(silent: true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل تفاصيل الطلب';
        _loading = false;
      });
      debugPrint('[OrderDetail] load failed: $error');
    }
  }

  Future<void> _loadExtras({bool silent = true}) async {
    final order = _order;
    if (order == null || !_useLive) return;

    Profile? profile;
    OrderReview? review;
    double? avg;
    var count = 0;

    final providerId = order.providerId?.trim();
    if (providerId != null && providerId.isNotEmpty) {
      try {
        profile = await SupabaseService.instance.fetchProfile(providerId);
      } on Object catch (e) {
        debugPrint('[OrderDetail] provider profile: $e');
      }
      try {
        final stats =
            await SupabaseService.instance.fetchProviderReviewStats(providerId);
        if (stats != null) {
          avg = stats.average;
          count = stats.count;
        }
      } on Object catch (e) {
        debugPrint('[OrderDetail] provider stats: $e');
      }
    }

    if (order.isCompleted) {
      try {
        review = await SupabaseService.instance.fetchOrderReview(order.id);
      } on Object catch (e) {
        debugPrint('[OrderDetail] review: $e');
      }
    }

    var photos = const <String>[];
    try {
      final rows =
          await StorageService.instance.fetchOrderAttachments(order.id);
      photos = rows
          .map((r) => (r['url'] as String?)?.trim() ?? '')
          .where((u) => u.isNotEmpty)
          .toList();
    } on Object catch (e) {
      debugPrint('[OrderDetail] attachments: $e');
    }

    if (!mounted) return;
    setState(() {
      _providerProfile = profile ?? _providerProfile;
      _review = review;
      _providerAvg = (count > 0) ? avg : null;
      _providerReviewCount = count;
      if (photos.isNotEmpty || _attachmentUrls.isEmpty) {
        _attachmentUrls
          ..clear()
          ..addAll(photos);
      }
      if (!silent) {
        _loading = false;
        _error = null;
      }
    });
  }

  Future<void> _onRefresh() async {
    if (_useLive) await _loadOrder();
  }

  bool get _canAddPhotos {
    final o = _order;
    if (o == null || _isLocallyCancelled || o.isCancelled || o.isCompleted) {
      return false;
    }
    return true;
  }

  Future<void> _addAttachment() async {
    if (_uploadingAttachment || !_canAddPhotos) return;
    if (!_useLive) {
      customerFlow.showMessage('افتح طلباً حقيقياً لإضافة صور');
      return;
    }
    final orderId = widget.orderId?.trim();
    if (orderId == null || !SupabaseService.isLikelyUuid(orderId)) {
      customerFlow.showMessage('معرّف الطلب غير صالح لإضافة صورة');
      return;
    }

    final source = await showImageSourceSheet(context);
    if (source == null || !mounted) return;

    setState(() => _uploadingAttachment = true);
    try {
      final file = await StorageService.instance.pickImage(source: source);
      if (file == null) {
        if (mounted) setState(() => _uploadingAttachment = false);
        return;
      }
      final uploaded =
          await StorageService.instance.uploadOrderAttachment(orderId, file);
      if (!mounted) return;
      setState(() {
        _attachmentUrls.insert(0, uploaded.url);
        _uploadingAttachment = false;
      });
      customerFlow.showMessage('تم رفع الصورة بنجاح');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _uploadingAttachment = false);
      final message = error is StateError && error.message.isNotEmpty
          ? error.message
          : 'تعذّر رفع الصورة.\nالتفاصيل: $error';
      customerFlow.showMessage(message);
    }
  }

  bool get _hasProblemVideo => _attachmentUrls.any(looksLikeVideo);

  Future<void> _addVideoAttachment() async {
    if (_uploadingAttachment || !_canAddPhotos || _hasProblemVideo) return;
    if (!_useLive) {
      customerFlow.showMessage('افتح طلباً حقيقياً لإضافة فيديو');
      return;
    }
    final orderId = widget.orderId?.trim();
    if (orderId == null || !SupabaseService.isLikelyUuid(orderId)) {
      customerFlow.showMessage('معرّف الطلب غير صالح لإضافة فيديو');
      return;
    }

    final source = await showImageSourceSheet(context);
    if (source == null || !mounted) return;

    setState(() => _uploadingAttachment = true);
    try {
      final file = await StorageService.instance.pickVideo(source: source);
      if (file == null) {
        if (mounted) setState(() => _uploadingAttachment = false);
        return;
      }
      final uploaded =
          await StorageService.instance.uploadOrderAttachment(orderId, file);
      if (!mounted) return;
      setState(() {
        _attachmentUrls.insert(0, uploaded.url);
        _uploadingAttachment = false;
      });
      customerFlow.showMessage('تم رفع الفيديو بنجاح');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _uploadingAttachment = false);
      final message = error is StateError && error.message.isNotEmpty
          ? error.message
          : 'تعذّر رفع الفيديو.\nالتفاصيل: $error';
      customerFlow.showMessage(message);
    }
  }

  bool get _isLocallyCancelled =>
      _order != null && customerFlow.isLocallyCancelled(_order!.id);

  String get _providerName {
    final fromProfile = _providerProfile?.fullName?.trim();
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    return _order?.providerNameFromNotes ?? 'مزود الخدمة';
  }

  String? get _providerAvatar {
    final url = _providerProfile?.avatarUrl?.trim();
    if (url != null && url.isNotEmpty) return url;
    return null;
  }

  bool get _providerVerified => false;

  String get _orderNumberLabel {
    final order = _order;
    if (order != null) return order.displayRef;
    final id = widget.orderId ?? '';
    if (id.isEmpty) return '—';
    if (!_useLive) return 'AMN-ORD-000000-0000';
    return displayPublicRef(null, id);
  }

  String get _dateLabel {
    final dt = _order?.createdAt?.toLocal();
    if (dt == null) {
      return !_useLive ? '14 أكتوبر 2023' : '—';
    }
    final month = _monthsAr[(dt.month - 1).clamp(0, 11)];
    return '${dt.day} $month ${dt.year}';
  }

  String get _serviceName => _order?.specialtyLabel ?? 'خدمة';

  String? get _address {
    final resolved = _resolvedAddress?.trim();
    if (resolved != null &&
        resolved.isNotEmpty &&
        !PlacesService.looksLikeCoordinateLabel(resolved)) {
      return resolved;
    }
    return _order?.serviceAddressLabel;
  }

  Future<void> _refreshPlaceLabel(AmanaOrder order) async {
    final coords = order.serviceCoordinates;
    if (coords == null) return;
    final existing = order.serviceAddressLabel;
    final (lat, lng) = coords;
    final label = await PlacesService.resolveHumanAddress(
      lat: lat,
      lng: lng,
      existing: existing,
    );
    if (!mounted || _order?.id != order.id) return;
    final text = label?.trim() ?? '';
    if (text.isEmpty || PlacesService.looksLikeCoordinateLabel(text)) return;
    setState(() => _resolvedAddress = text);
  }

  double get _serviceCost =>
      _order?.displayOfferAmount ?? _order?.price ?? (!_useLive ? 4500 : 0);

  /// Design shows optional promo line; no coupon column yet → hide when 0.
  double get _discount => !_useLive ? 450 : 0;

  double get _totalPaid {
    final total = _serviceCost - _discount;
    return total < 0 ? 0 : total;
  }

  IconData get _serviceIcon {
    return serviceCategoryIcon(null, nameHint: _serviceName);
  }

  ({IconData icon, Color bg, String title, String subtitle}) get _statusHero {
    final order = _order;
    if (order == null || _isLocallyCancelled || order.isCancelled) {
      return (
        icon: Icons.cancel,
        bg: AmanaTheme.errorRed,
        title: 'تم إلغاء الطلب',
        subtitle: order?.cancelledBadgeAr.isNotEmpty == true
            ? order!.cancelledBadgeAr
            : 'لن يتم تنفيذ هذا الطلب',
      );
    }
    if (order.isCompleted) {
      return (
        icon: Icons.check_circle,
        bg: AmanaTheme.successGreen,
        title: 'تم اكتمال الطلب بنجاح',
        subtitle: 'شكراً لاستخدامك منصة أمانة',
      );
    }
    if (order.isAwaitingCustomerConfirm) {
      return (
        icon: Icons.done_all,
        bg: AmanaTheme.warningAmber,
        title: 'بانتظار تأكيد الاستلام',
        subtitle: 'أنهى المزود العمل — أكّد الاستلام عندما تكون جاهزاً',
      );
    }
    if (order.needsCustomerArrivalConfirm) {
      return (
        icon: Icons.hail,
        bg: AmanaTheme.warningAmber,
        title: 'المزود يقول إنه وصل',
        subtitle: 'أكّد الوصول ليبدأ العمل، أو أبلغ إن لم يصل بعد',
      );
    }
    return (
      icon: Icons.hourglass_top,
      bg: AmanaTheme.primaryDark,
      title: order.statusHeadlineAr,
      subtitle: order.statusSubtitleAr,
    );
  }

  bool get _showCancel =>
      !_isLocallyCancelled &&
      (_order?.canCustomerCancel == true) &&
      !(_order?.isCancelled ?? false);

  bool get _showComplete =>
      _order != null &&
      !_order!.isCancelled &&
      !_order!.isCompleted &&
      !_isLocallyCancelled &&
      _order!.isAwaitingCustomerConfirm;

  bool get _showArrivalConfirm =>
      _order != null &&
      !_order!.isCancelled &&
      !_order!.isCompleted &&
      !_isLocallyCancelled &&
      _order!.needsCustomerArrivalConfirm;

  bool get _showRate =>
      _order?.isCompleted == true && _review == null && _useLive;

  bool get _canAccept =>
      _order != null &&
      !_isLocallyCancelled &&
      _order!.canAcceptProposal(_myRole);

  bool get _canPropose =>
      _order != null &&
      !_isLocallyCancelled &&
      !_order!.isCancelled &&
      !_order!.isCompleted &&
      !_order!.isPriceConfirmed &&
      _order!.isActive;

  /// Live map only after price confirmation (coords optional — provider GPS still useful).
  bool get _showLiveTracking {
    final o = _order;
    if (o == null || !_useLive) return false;
    if (!o.isPriceConfirmed ||
        o.isCancelled ||
        o.isCompleted ||
        o.isAwaitingCustomerConfirm) {
      return false;
    }
    return true;
  }

  void _openChat() {
    customerFlow.openProviderChat(
      context,
      providerName: _providerName,
      orderId: _order?.id ?? widget.orderId,
      avatarUrl: _providerAvatar,
    );
  }

  void _openCancel() {
    customerFlow.openCancelOrder(
      context,
      orderId: _order?.id ?? widget.orderId,
      serviceTitle: _serviceName,
      providerName: _providerName,
      publicRef: _order?.publicRef,
      statusLabel: _order?.offerStatusBadgeAr,
    );
  }

  Future<void> _confirmArrival() async {
    final id = _order?.id.trim() ?? widget.orderId?.trim() ?? '';
    if (id.isEmpty || !SupabaseService.isInitialized) return;
    try {
      final updated = await SupabaseService.instance.confirmArrival(id);
      if (!mounted) return;
      setState(() => _order = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تأكيد الوصول — يمكن للمزود بدء العمل')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      final msg = error is StateError && error.message.isNotEmpty
          ? error.message
          : 'تعذّر تأكيد الوصول';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _denyArrival() async {
    final id = _order?.id.trim() ?? widget.orderId?.trim() ?? '';
    if (id.isEmpty || !SupabaseService.isInitialized) return;
    try {
      final updated = await SupabaseService.instance.denyArrival(id);
      if (!mounted) return;
      setState(() => _order = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إبلاغ المزود أنك لم تجده في الموقع')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      final msg = error is StateError && error.message.isNotEmpty
          ? error.message
          : 'تعذّر إرسال البلاغ';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _openComplete() {
    customerFlow.openOrderCompletion(
      context,
      orderId: _order?.id ?? widget.orderId,
      serviceName: _serviceName,
      providerName: _providerName,
      providerId: _order?.providerId,
      price: _serviceCost,
      notes: _order?.notes,
    );
  }

  Future<void> _openRate() async {
    await customerFlow.openServiceRating(
      context,
      orderId: _order?.id ?? widget.orderId,
      providerName: _providerName,
      providerId: _order?.providerId,
    );
    if (mounted) await _loadExtras();
  }

  Future<void> _rebook() async {
    final pid = _order?.providerId?.trim();
    if (_useLive &&
        pid != null &&
        pid.isNotEmpty &&
        SupabaseService.isLikelyUuid(pid)) {
      final working = await SupabaseService.instance.isProviderWorking(pid);
      if (!working) {
        customerFlow.showMessage(kProviderNotWorkingMessage);
        return;
      }
    }
    if (!mounted) return;
    final published = await _publishedServiceForRebook();
    if (!mounted) return;

    final title = published?.title.trim().isNotEmpty == true
        ? published!.title.trim()
        : _serviceName;
    final fromService = published?.category?.trim() ?? '';
    final fromNotes = _order?.categoryFromNotes?.trim() ?? '';
    final category = fromService.isNotEmpty
        ? fromService
        : (fromNotes.isNotEmpty && fromNotes != title) ? fromNotes : null;
    final serviceDescription = published?.description?.trim() ?? '';
    final description = serviceDescription.isNotEmpty
        ? serviceDescription
        : _descriptionFromNotes(_order?.notes);
    final listed = published?.bookingPrice;
    final serviceId = published?.id.trim().isNotEmpty == true
        ? published!.id.trim()
        : _usableServiceId(_order?.providerServiceId);

    customerFlow.openBookingConfirmation(
      context,
      providerName: _providerName,
      providerId: _order?.providerId,
      serviceId: serviceId,
      serviceTitle: title,
      price: (listed != null && listed > 0)
          ? listed
          : (_order?.price ?? _serviceCost),
      category: category,
      description: description,
      providerAvatarUrl: _providerAvatar,
      trustLevel: published?.trustLevel ?? ProviderService.trustNone,
    );
  }

  /// Published row for this booking. Title match only — never another service.
  Future<ProviderService?> _publishedServiceForRebook() async {
    if (!_useLive || !SupabaseService.isInitialized) return null;
    try {
      final sid = _usableServiceId(_order?.providerServiceId);
      if (sid != null) {
        final one =
            await SupabaseService.instance.fetchProviderServiceById(sid);
        if (one != null) return one;
      }
      final pid = _order?.providerId?.trim() ?? '';
      if (pid.isEmpty || !SupabaseService.isLikelyUuid(pid)) return null;
      final list = await SupabaseService.instance
          .fetchProviderServices(pid)
          .timeout(const Duration(seconds: 8));
      final title = (_order?.serviceName ?? '').trim();
      if (title.isEmpty) return null;
      for (final service in list) {
        if (service.title.trim() == title) return service;
      }
    } on Object catch (error) {
      debugPrint('[Rebook] service lookup failed: $error');
    }
    return null;
  }

  String? _usableServiceId(String? raw) {
    final sid = raw?.trim() ?? '';
    if (sid.isEmpty || sid == 'featured') return null;
    return sid;
  }

  String? _descriptionFromNotes(String? notes) {
    final text = notes;
    if (text == null || text.isEmpty) return null;
    final match = RegExp(r'الوصف:\s*(.+)').firstMatch(text);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    return value.split('\n').first.trim();
  }

  Future<void> _shareReceipt() async {
    final text = (StringBuffer()
          ..writeln('إيصال أمانة')
          ..writeln('رقم الطلب: $_orderNumberLabel')
          ..writeln('الخدمة: $_serviceName')
          ..writeln('المزود: $_providerName')
          ..writeln('التاريخ: $_dateLabel')
          ..writeln('الإجمالي: ${AmanaOrder.formatAmount(_totalPaid)} ج.س')
          ..writeln('الحالة: ${_order?.statusHeadlineAr ?? '—'}'))
        .toString();
    final shared = await shareAmanaReceipt(text);
    if (shared || !mounted) return;
    customerFlow.showMessage('تم نسخ الإيصال — يمكنك مشاركته الآن');
  }

  Future<bool> _confirmPriceDialog() async {
    final amount = _order?.offerPriceLabel ?? '—';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد السعر'),
          content: Text(
            'هل تؤكد السعر $amount؟\nسيتم قفل الاتفاق مع المزود بعد التأكيد.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد السعر'),
            ),
          ],
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _acceptOffer() async {
    if (!_canAccept || _accepting) return;
    final confirmed = await _confirmPriceDialog();
    if (!confirmed || !mounted) return;
    if (!_useLive) {
      final amount = _order!.displayOfferAmount ?? _serviceCost;
      setState(() {
        _order = _order!.copyWith(
          price: amount,
          offerPrice: amount,
          proposedPrice: amount,
          priceConfirmedAt: DateTime.now(),
          status: 'price_agreed',
        );
      });
      customerFlow.showMessage('تم الاتفاق على السعر!');
      return;
    }
    setState(() => _accepting = true);
    try {
      final updated =
          await SupabaseService.instance.acceptOrderPrice(widget.orderId!);
      if (!mounted) return;
      setState(() {
        _order = updated;
        _accepting = false;
      });
      customerFlow.refreshOrders(focusTab: 'active');
      customerFlow.showMessage('تم الاتفاق على السعر!');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _accepting = false);
      customerFlow.showMessage(customerAcceptPriceErrorMessage(error));
    }
  }

  Future<void> _proposePrice() async {
    if (!_canPropose || _proposing) return;
    final isCounter = _canAccept;
    final controller = TextEditingController(
      text: _serviceCost > 0 ? _serviceCost.toStringAsFixed(0) : '',
    );
    final notesController = TextEditingController();
    final result = await showDialog<(double, String?)>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(isCounter ? 'إرسال عرض مضاد' : 'اقتراح سعر'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: isCounter
                      ? 'مبلغ العرض المضاد (ج.س)'
                      : 'المبلغ المقترح (ج.س)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(controller.text.trim());
                if (v == null || v <= 0) return;
                final n = notesController.text.trim();
                Navigator.pop(ctx, (v, n.isEmpty ? null : n));
              },
              child: Text(isCounter ? 'إرسال عرض مضاد' : 'إرسال عرض'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    notesController.dispose();
    if (result == null || !mounted || !_useLive) return;

    setState(() => _proposing = true);
    try {
      final updated = await SupabaseService.instance.proposeOrderPrice(
        widget.orderId!,
        result.$1,
        notes: result.$2,
      );
      if (!mounted) return;
      setState(() {
        _order = updated;
        _proposing = false;
      });
      customerFlow.refreshOrders(focusTab: 'active');
      customerFlow.showMessage('تم إرسال عرض السعر');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _proposing = false);
      final detail = error is StateError && error.message.isNotEmpty
          ? error.message
          : error.toString();
      customerFlow.showMessage(
        detail.contains('تعذّر') || detail.contains('فشل')
            ? detail
            : 'تعذّر إرسال العرض\nالتفاصيل: $detail',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AmanaTheme.surface,
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AmanaTheme.primary),
              )
            : _error != null
                ? _errorBody()
                : RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: AmanaTheme.primaryDark,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _topBar(context)),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              _statusHeader(),
                              if (_order != null) ...[
                                const SizedBox(height: 12),
                                OrderSlaBanner(order: _order!),
                              ],
                              const SizedBox(height: 16),
                              if (_showLiveTracking) ...[
                                _liveTrackingCard(),
                                const SizedBox(height: 16),
                              ],
                              _orderInfoAndProvider(),
                              if (_address != null &&
                                  _address!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _addressCard(),
                              ],
                              const SizedBox(height: 12),
                              if (_useLive ||
                                  _canAddPhotos ||
                                  _attachmentUrls.isNotEmpty)
                                _photosCard(),
                              if (_canAccept || _canPropose) ...[
                                const SizedBox(height: 12),
                                _negotiationCard(),
                              ],
                              if (_review != null || _showRate) ...[
                                const SizedBox(height: 12),
                                _ratingSection(),
                              ],
                              const SizedBox(height: 12),
                              _paymentSection(),
                              const SizedBox(height: 16),
                              _actionsSection(),
                              const SizedBox(height: 24),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
        bottomNavigationBar: CustomerBottomNav(
          selectedIndex: 1,
          onTap: (index) => customerFlow.goToTab(context, index),
        ),
      ),
    );
  }

  Widget _errorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AmanaTheme.error),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadOrder,
              child: const Text('إعادة المحاولة'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('رجوع'),
            ),
          ],
        ),
      ),
    );
  }

  /// Fixed top app bar — design: h-12, back + title + more_vert.
  Widget _topBar(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AmanaTheme.surface,
        border: const Border(
          bottom: BorderSide(color: AmanaTheme.outlineVariant),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: const Icon(Icons.arrow_forward, color: AmanaTheme.primaryDark),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'تفاصيل الطلب',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AmanaTheme.primaryDark,
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AmanaTheme.primaryDark),
            onSelected: (value) {
              if (value == 'refresh') _onRefresh();
              if (value == 'chat') _openChat();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'refresh', child: Text('تحديث')),
              PopupMenuItem(value: 'chat', child: Text('محادثة المزود')),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _statusHeader() {
    final hero = _statusHero;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: hero.bg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(hero.icon, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 12),
          Text(
            hero.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AmanaTheme.onSurface,
              height: 1.33,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hero.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AmanaTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bentoCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AmanaTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _orderInfoAndProvider() {
    return Column(
      children: [
        _bentoCard(
          child: Column(
            children: [
              _infoRow('رقم الطلب', _orderNumberLabel),
              const SizedBox(height: 8),
              _infoRow('التاريخ', _dateLabel),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'نوع الخدمة',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AmanaTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(_serviceIcon, size: 16, color: AmanaTheme.primaryDark),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _serviceName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AmanaTheme.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _bentoCard(
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AmanaUserAvatar(
                    url: _providerAvatar,
                    name: _providerName,
                    size: 56,
                    borderColor: AmanaTheme.primaryContainer,
                  ),
                  if (_providerVerified)
                    Positioned(
                      bottom: -2,
                      left: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AmanaTheme.primaryDark,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.verified,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _providerName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AmanaTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 16,
                          color: AmanaTheme.warningAmber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _providerAvg != null
                              ? '${_providerAvg!.toStringAsFixed(1)} ($_providerReviewCount تقييم)'
                              : 'لا تقييمات بعد',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AmanaTheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _providerVerified
                          ? 'مزود خدمة معتمد'
                          : 'مزود خدمة',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _providerVerified
                            ? AmanaTheme.successGreen
                            : AmanaTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: AmanaTheme.surfaceContainerHigh,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _openChat,
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.chat, color: AmanaTheme.primaryDark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AmanaTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AmanaTheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _addressCard() {
    return _bentoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_outlined, color: AmanaTheme.primaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'العنوان',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AmanaTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _address!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AmanaTheme.onSurface,
                  ),
                ),
                if (_order?.appointmentLabelAr != null &&
                    _order!.appointmentLabelAr!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'الموعد: ${_order!.appointmentLabelAr}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AmanaTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveTrackingCard() {
    final coords = _order?.serviceCoordinates;
    final orderId = _order?.id ?? widget.orderId ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AmanaMapPreview(
          lat: coords?.$1,
          lng: coords?.$2,
          height: 192,
          label: _address,
          navigationLabel: 'تتبع الموقع',
          showOpenExternal: true,
          showExternalAsSecondary: false,
          onNavigate: orderId.isEmpty
              ? null
              : () => LiveOrderTrackingScreen.open(
                    context,
                    orderId: orderId,
                    title: 'تتبع المزود',
                    destinationLabel: _address,
                    fallbackDestinationLat: coords?.$1,
                    fallbackDestinationLng: coords?.$2,
                    viewerRole: 'customer',
                  ),
          onTap: orderId.isEmpty
              ? null
              : () => LiveOrderTrackingScreen.open(
                    context,
                    orderId: orderId,
                    title: 'تتبع المزود',
                    destinationLabel: _address,
                    fallbackDestinationLat: coords?.$1,
                    fallbackDestinationLng: coords?.$2,
                    viewerRole: 'customer',
                  ),
        ),
        const SizedBox(height: 8),
        Text(
          coords == null
              ? 'الاتفاق تم — افتح التتبع لرؤية موقع المزود (إحداثيات العنوان غير محفوظة لهذا الطلب).'
              : 'التتبع الحي متاح بعد الاتفاق على السعر — يظهر موقع المزود في الطريق.',
          style: TextStyle(
            fontSize: 12,
            color: AmanaTheme.onSurfaceVariant.withValues(alpha: 0.95),
          ),
        ),
      ],
    );
  }

  Widget _photosCard() {
    return _bentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'صور وفيديو المشكلة',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AmanaTheme.onSurfaceVariant,
            ),
          ),
          const Divider(color: AmanaTheme.outlineVariant, height: 16),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (_canAddPhotos)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: SizedBox(
                      width: 96,
                      child: _customerAddPhotoTile(),
                    ),
                  ),
                if (_canAddPhotos && !_hasProblemVideo)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: SizedBox(
                      width: 96,
                      child: _customerAddVideoTile(),
                    ),
                  ),
                ..._attachmentUrls.map(
                  (url) => Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: SizedBox(
                      width: 96,
                      child: _customerPhotoTile(url),
                    ),
                  ),
                ),
                if (_attachmentUrls.isEmpty && !_canAddPhotos)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'لا توجد صور أو فيديو',
                      style: TextStyle(color: AmanaTheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerAddPhotoTile() {
    return AspectRatio(
      aspectRatio: 1,
      child: InkWell(
        onTap: _uploadingAttachment ? null : _addAttachment,
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AmanaTheme.outlineVariant,
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_uploadingAttachment)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.add_a_photo, color: AmanaTheme.outline),
              const SizedBox(height: 4),
              Text(
                _uploadingAttachment ? 'جاري الرفع...' : 'إضافة صورة',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AmanaTheme.outline),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _customerAddVideoTile() {
    return AspectRatio(
      aspectRatio: 1,
      child: InkWell(
        key: const Key('order-add-video'),
        onTap: _uploadingAttachment ? null : _addVideoAttachment,
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AmanaTheme.outlineVariant,
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_uploadingAttachment)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.videocam_outlined, color: AmanaTheme.outline),
                const SizedBox(height: 4),
                Text(
                  _uploadingAttachment ? 'جاري الرفع...' : 'إضافة فيديو',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AmanaTheme.outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _customerPhotoTile(String url) {
    if (looksLikeVideo(url)) {
      return AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AmanaVideoMark(
            label: 'فيديو المشكلة',
            onTap: () => showAmanaVideoPlayer(
              context,
              url,
              title: 'فيديو المشكلة',
            ),
          ),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const ColoredBox(
            color: AmanaTheme.surfaceContainer,
            child: Icon(Icons.broken_image),
          ),
        ),
      ),
    );
  }

  Widget _negotiationCard() {
    final summary = _order?.negotiationSummaryAr(_myRole) ?? '';
    final amountLabel = _order?.offerPriceLabel ?? '—';
    return _bentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'الاتفاق المالي',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AmanaTheme.onSurfaceVariant,
            ),
          ),
          const Divider(color: AmanaTheme.outlineVariant, height: 16),
          if (_canAccept) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: AmanaTheme.secondaryFixed.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AmanaTheme.primaryDark, width: 1.5),
              ),
              child: Column(
                children: [
                  const Text(
                    'السعر المقترح',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AmanaTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    amountLabel,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AmanaTheme.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            summary,
            style: const TextStyle(fontSize: 14, color: AmanaTheme.onSurface),
          ),
          const SizedBox(height: 12),
          if (_canAccept)
            FilledButton(
              onPressed: _accepting ? null : _acceptOffer,
              style: FilledButton.styleFrom(
                backgroundColor: AmanaTheme.primaryDark,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _accepting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'تأكيد السعر',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          if (_canPropose) ...[
            if (_canAccept) const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _proposing ? null : _proposePrice,
              style: OutlinedButton.styleFrom(
                foregroundColor: AmanaTheme.primaryDark,
                side: const BorderSide(color: AmanaTheme.primaryDark, width: 2),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_canAccept ? 'إرسال عرض مضاد' : 'اقتراح سعر'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ratingSection() {
    if (_showRate && _review == null) {
      return _bentoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'تقييمك للخدمة',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AmanaTheme.onSurfaceVariant,
              ),
            ),
            const Divider(color: AmanaTheme.outlineVariant, height: 16),
            const Text(
              'لم تقيّم هذه الخدمة بعد',
              style: TextStyle(fontSize: 14, color: AmanaTheme.onSurface),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _openRate,
              icon: const Icon(Icons.star),
              label: const Text('قيّم الخدمة الآن'),
              style: FilledButton.styleFrom(
                backgroundColor: AmanaTheme.primaryDark,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final review = _review!;
    return _bentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تقييمك للخدمة',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AmanaTheme.onSurfaceVariant,
            ),
          ),
          const Divider(color: AmanaTheme.outlineVariant, height: 16),
          Row(
            children: List.generate(5, (i) {
              final filled = i < review.rating;
              return Icon(
                filled ? Icons.star : Icons.star_border,
                size: 28,
                color: AmanaTheme.warningAmber,
              );
            }),
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"${review.comment}"',
              style: const TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: AmanaTheme.onSurface,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentSection() {
    return _bentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'السعر',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AmanaTheme.onSurfaceVariant,
            ),
          ),
          const Divider(color: AmanaTheme.outlineVariant, height: 16),
          Row(
            children: [
              const Text(
                'تكلفة الخدمة',
                style: TextStyle(fontSize: 16, color: AmanaTheme.onSurface),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${AmanaOrder.formatAmount(_serviceCost)} ج.س',
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, color: AmanaTheme.onSurface),
                ),
              ),
            ],
          ),
          if (_discount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'خصم',
                  style: TextStyle(fontSize: 16, color: AmanaTheme.successGreen),
                ),
                Text(
                  '${AmanaOrder.formatAmount(_discount)}- ج.س',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AmanaTheme.successGreen,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Divider(
            color: AmanaTheme.outlineVariant,
            height: 1,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'الإجمالي',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AmanaTheme.primaryDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${AmanaOrder.formatAmount(_totalPaid)} ج.س',
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AmanaTheme.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionsSection() {
    final buttons = <Widget>[];

    if (_order?.isCompleted == true || !_useLive) {
      buttons.add(
        _primaryAction(
          icon: Icons.refresh,
          label: 'إعادة حجز هذا الفني',
          onPressed: _rebook,
        ),
      );
      buttons.add(const SizedBox(height: 12));
      buttons.add(
        _outlineAction(
          icon: Icons.share,
          label: 'مشاركة الإيصال',
          onPressed: _shareReceipt,
        ),
      );
    } else {
      if (_showArrivalConfirm) {
        buttons.add(
          _primaryAction(
            icon: Icons.hail,
            label: 'تأكيد الوصول',
            onPressed: _confirmArrival,
          ),
        );
        buttons.add(const SizedBox(height: 12));
        buttons.add(
          _outlineAction(
            icon: Icons.location_off_outlined,
            label: 'لم يصل بعد',
            onPressed: _denyArrival,
            color: AmanaTheme.errorRed,
          ),
        );
      }
      if (_showComplete) {
        if (buttons.isNotEmpty) buttons.add(const SizedBox(height: 12));
        buttons.add(
          _primaryAction(
            icon: Icons.done_all,
            label: 'تأكيد الاستلام',
            onPressed: _openComplete,
          ),
        );
      }
      if (_showRate) {
        if (buttons.isNotEmpty) buttons.add(const SizedBox(height: 12));
        buttons.add(
          _primaryAction(
            icon: Icons.star,
            label: 'تقييم الخدمة',
            onPressed: _openRate,
          ),
        );
      }
      if (_showCancel) {
        if (buttons.isNotEmpty) buttons.add(const SizedBox(height: 12));
        buttons.add(
          _outlineAction(
            icon: Icons.cancel_outlined,
            label: 'إلغاء الطلب',
            onPressed: _openCancel,
            color: AmanaTheme.errorRed,
          ),
        );
      }
      if (buttons.isEmpty) {
        buttons.add(
          _outlineAction(
            icon: Icons.chat,
            label: 'محادثة المزود',
            onPressed: _openChat,
          ),
        );
      }
    }

    return Column(children: buttons);
  }

  Widget _primaryAction({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: FilledButton.styleFrom(
          backgroundColor: AmanaTheme.primaryDark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _outlineAction({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color color = AmanaTheme.primaryDark,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color),
        label: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: color, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
