import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/address.dart';
import '../models/provider_price_row.dart';
import '../navigation/customer_flow.dart';
import '../services/places_service.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../theme/amana_theme.dart';
import '../utils/booking_datetime.dart';
import '../utils/device_location.dart';
import '../utils/image_source_sheet.dart';
import '../utils/media_kind.dart';
import '../utils/money_format.dart';
import '../utils/self_booking.dart';
import '../utils/service_category_icons.dart';
import '../widgets/amana_map_preview.dart';
import '../widgets/amana_playable_video.dart';
import '../widgets/amana_user_avatar.dart';
import '../widgets/verified_badge.dart';
import 'location_picker_screen.dart';

class _BookingAddress {
  const _BookingAddress({
    required this.icon,
    required this.title,
    required this.line1,
    required this.line2,
    this.id,
    this.lat,
    this.lng,
  });

  final IconData icon;
  final String title;
  final String line1;
  final String line2;
  final String? id;
  final double? lat;
  final double? lng;

  String get displayText {
    final parts = [title, line1, line2]
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length >= 2 && parts[0] == parts[1]) {
      return parts.skip(1).join(' — ');
    }
    return parts.join(' — ');
  }
}

class CustomerBookingConfirmationScreen extends StatefulWidget {
  const CustomerBookingConfirmationScreen({
    required this.providerName,
    this.serviceTitle = 'صيانة سباكة منزلية',
    this.providerId,
    this.price,
    this.category,
    this.description,
    this.providerAvatarUrl,
    this.serviceId,
    this.trustLevel = 'none',
    this.selectedPriceRows = const [],
    super.key,
  });

  final String providerName;
  final String serviceTitle;
  final String? providerId;
  final String? serviceId;
  final double? price;
  final String? category;
  final String? description;
  final String? providerAvatarUrl;
  final String trustLevel;
  final List<ProviderPriceRow> selectedPriceRows;

  @override
  State<CustomerBookingConfirmationScreen> createState() =>
      _CustomerBookingConfirmationScreenState();
}

class _CustomerBookingConfirmationScreenState
    extends State<CustomerBookingConfirmationScreen> {

  bool _isAsap = true;
  DateTime? _scheduledAt;
  String? _addressId;
  String _addressText = '';
  double? _lat;
  double? _lng;
  int? _selectedSavedIndex;

  bool _processing = false;
  bool _loadingAddresses = false;
  bool _pickingPhoto = false;
  bool _pickingVideo = false;
  bool _locating = false;
  bool _searching = false;
  String? _workDetailsError;
  final _notesController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _districtController = TextEditingController();
  final _addressSearchController = TextEditingController();
  final _pendingPhotos = <XFile>[];
  XFile? _pendingVideo;
  List<_BookingAddress> _savedAddresses = const [];
  List<PlaceSuggestion> _suggestions = const [];
  Timer? _searchDebounce;
  int _searchGen = 0;
  late bool _providerVerified;
  double? _avgRating;
  int _ratingCount = 0;

  String get _chosenAddress {
    final typed = _addressSearchController.text.trim();
    if (typed.isNotEmpty) return typed;
    return _addressText.trim();
  }

  /// ولاية، مدينة، حي العميل، ثم المعلم إن كُتب.
  String get _serviceAddressLine {
    final address = _chosenAddress;
    final district = _districtController.text.trim();
    final landmark = _landmarkController.text.trim();
    var line = PlacesService.composePlaceLabel(
      base: address,
      district: district,
    );
    if (landmark.isEmpty || line.contains(landmark)) return line;
    if (line.isEmpty) return landmark;
    return '$line — $landmark';
  }

  void _offerDistrict(String? value) {
    final next = value?.trim() ?? '';
    if (next.isEmpty ||
        PlacesService.isUnnamedRoad(next) ||
        _districtController.text.trim().isNotEmpty) {
      return;
    }
    _districtController.text = next;
  }

  double get _displayPrice => widget.price ?? 0;

  List<RequestedPriceLine> get _selectedLines {
    final providerId = widget.providerId?.trim() ?? '';
    if (providerId.isEmpty) return const [];
    return [
      for (final row in widget.selectedPriceRows)
        if (row.title.trim().isNotEmpty && row.amount > 0) row.toRequestedLine(),
    ];
  }

  /// Saved order name: the specialty, not the free-text description.
  String get _bookedSpecialty {
    final specialty = widget.category?.trim() ?? '';
    final description = widget.description?.trim() ?? '';
    final title = widget.serviceTitle.trim();
    if (specialty.isNotEmpty && specialty != description) return specialty;
    if (title.isNotEmpty && title != description) return title;
    if (specialty.isNotEmpty) return specialty;
    return title.isEmpty ? 'خدمة' : title;
  }

  String get _priceLabel {
    if (widget.price == null) return 'يُتفق عليه لاحقاً';
    return '${formatMoney(widget.price!)} ج.س';
  }

  String get _appointmentSummary {
    if (_isAsap) return BookingDateTime.asapLabelAr;
    if (_scheduledAt != null) {
      return BookingDateTime.formatAppointmentAr(_scheduledAt!);
    }
    return 'لم يُحدد بعد';
  }

  bool get _hasPickedLocation =>
      _addressText.trim().isNotEmpty || (_lat != null && _lng != null);

  bool get _isSelfBooking {
    if (!SupabaseService.isInitialized) return false;
    return isSelfProviderBooking(
      widget.providerId,
      SupabaseService.instance.currentUserId,
    );
  }

  @override
  void initState() {
    super.initState();
    _providerVerified = ServiceTrustBadge.shows(widget.trustLevel);
    _loadAddresses();
    _loadTrust();
  }

  Future<void> _loadTrust() async {
    final id = widget.providerId?.trim() ?? '';
    if (id.isEmpty ||
        !SupabaseService.isInitialized ||
        !SupabaseService.instance.hasSession) {
      return;
    }
    try {
      final stats = await SupabaseService.instance.fetchProviderPublicStats(id);
      if (!mounted) return;
      setState(() {
        _providerVerified = ServiceTrustBadge.shows(widget.trustLevel);
        if (stats != null && stats.hasRating) {
          _avgRating = stats.avgRating;
          _ratingCount = stats.ratingCount;
        }
      });
    } on Object catch (error) {
      debugPrint('[Booking] trust line failed: $error');
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _notesController.dispose();
    _landmarkController.dispose();
    _districtController.dispose();
    _addressSearchController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadAddresses() async {
    if (!SupabaseService.isInitialized ||
        !SupabaseService.instance.hasSession) {
      return;
    }
    setState(() => _loadingAddresses = true);
    try {
      final rows = await SupabaseService.instance.fetchAddresses();
      if (!mounted) return;
      setState(() {
        _savedAddresses = rows.map(_fromSaved).toList();
        _loadingAddresses = false;
        if (_savedAddresses.isNotEmpty && !_hasPickedLocation) {
          final defaultIdx = _savedAddresses.indexWhere(
            (a) => rows.any((r) => r.id == a.id && r.isDefault),
          );
          _applySaved(defaultIdx >= 0 ? defaultIdx : 0);
        }
      });
    } on Object catch (error) {
      debugPrint('[Booking] load addresses failed: $error');
      if (mounted) setState(() => _loadingAddresses = false);
    }
  }

  _BookingAddress _fromSaved(SavedAddress row) {
    final icon = switch (row.label) {
      'العمل' || 'المكتب' => Icons.work,
      'المنزل' || 'البيت' => Icons.home,
      _ => Icons.location_on,
    };
    final parts = row.addressText.split('\n');
    return _BookingAddress(
      id: row.id,
      icon: icon,
      title: row.label,
      line1: parts.isNotEmpty ? parts.first : row.addressText,
      line2: parts.length > 1 ? parts.sublist(1).join(' ') : '',
      lat: row.lat,
      lng: row.lng,
    );
  }

  void _applySaved(int index) {
    if (index < 0 || index >= _savedAddresses.length) return;
    final a = _savedAddresses[index];
    _selectedSavedIndex = index;
    _addressId = a.id;
    _addressText = a.displayText;
    _lat = a.lat;
    _lng = a.lng;
    _addressSearchController.text = a.displayText;
    _suggestions = const [];
    _offerDistrict(PlacesService.splitDistrict(a.displayText).district);
  }

  void _setPicked({
    required String text,
    double? lat,
    double? lng,
    String? addressId,
    int? savedIndex,
  }) {
    setState(() {
      _addressText = text.trim();
      _lat = lat;
      _lng = lng;
      _addressId = addressId;
      _selectedSavedIndex = savedIndex;
      _addressSearchController.text = _addressText;
      _suggestions = const [];
    });
  }

  void _onAddressQueryChanged(String value) {
    _searchDebounce?.cancel();
    final typed = value.trim();
    final confirmed = _addressText.trim();
    if (typed != confirmed) {
      setState(() {
        _addressText = '';
        _lat = null;
        _lng = null;
        _addressId = null;
        _selectedSavedIndex = null;
      });
    }
    if (typed.length < 2) {
      PlacesService.abandonSession();
      setState(() => _suggestions = const []);
      return;
    }
    final gen = ++_searchGen;
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_runSearch(typed, gen));
    });
  }

  Future<void> _runSearch(String query, int gen) async {
    setState(() => _searching = true);
    final results = await PlacesService.autocomplete(query);
    if (!mounted || gen != _searchGen) return;
    if (_addressSearchController.text.trim() != query) return;
    setState(() {
      _suggestions = results;
      _searching = false;
    });
  }

  Future<void> _pickSuggestion(PlaceSuggestion suggestion) async {
    _searchGen++;
    setState(() => _searching = true);
    final details = await PlacesService.details(suggestion.placeId);
    if (!mounted) return;
    setState(() => _searching = false);
    final base = (details?.areaBase.trim().isNotEmpty == true)
        ? details!.areaBase.trim()
        : suggestion.description;
    _offerDistrict(details?.neighborhood);
    _setPicked(
      text: base,
      lat: details?.lat,
      lng: details?.lng,
    );
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final fix = await readCurrentDeviceLocation();
      PlacesService.rememberSearchBias(fix.lat, fix.lng);
      final area = await PlacesService.reverseArea(fix.lat, fix.lng);
      if (!mounted) return;
      final text = (area != null && area.baseLabel.isNotEmpty)
          ? area.baseLabel
          : 'الموقع الحالي';
      _offerDistrict(area?.neighborhood);
      _setPicked(text: text, lat: fix.lat, lng: fix.lng);
    } on DeviceLocationException catch (error) {
      _toast(error.messageAr);
    } on Object catch (error) {
      debugPrint('[Booking] current location failed: $error');
      _toast('تعذّر الحصول على الموقع الحالي');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickOnMap() async {
    final picked = await LocationPickerScreen.open(
      context,
      initialLat: _lat,
      initialLng: _lng,
      initialAddressHint: _addressText,
      title: 'تحديد موقع الخدمة',
    );
    if (picked == null || !mounted) return;
    var text = picked.addressHint?.trim() ?? '';
    if (text.isEmpty ||
        PlacesService.looksLikeCoordinateLabel(text) ||
        PlacesService.isUnnamedRoad(text)) {
      text = 'موقع على الخريطة';
    }
    final split = PlacesService.splitDistrict(text);
    _offerDistrict(split.district);
    _setPicked(
      text: split.base.isEmpty ? text : split.base,
      lat: picked.lat,
      lng: picked.lng,
    );
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = _scheduledAt != null && _scheduledAt!.isAfter(now)
        ? _scheduledAt!
        : now.add(const Duration(minutes: 30));
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: BookingDateTime.startOfToday(now: now),
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'اختر تاريخ الخدمة',
      cancelText: 'إلغاء',
      confirmText: 'التالي',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      helpText: 'اختر وقت الخدمة',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );
    if (time == null || !mounted) return;
    final slot = BookingDateTime.combine(date, time.hour, time.minute);
    if (BookingDateTime.isPastSlot(slot, now: DateTime.now())) {
      _toast('لا يمكن اختيار وقت في الماضي. اختر وقتاً لاحقاً.');
      return;
    }
    setState(() {
      _isAsap = false;
      _scheduledAt = slot;
    });
  }

  Future<void> _confirm() async {
    if (!_isAsap) {
      if (_scheduledAt == null) {
        _toast('اختر تاريخ ووقت الخدمة، أو «في أقرب وقت».');
        return;
      }
      if (BookingDateTime.isPastSlot(_scheduledAt!)) {
        _toast('لا يمكن اختيار وقت في الماضي.');
        return;
      }
    }

    if (_lat != null &&
        _lng != null &&
        _districtController.text.trim().isEmpty) {
      _toast('اكتب اسم الحي لإكمال العنوان');
      return;
    }

    var addressText = _serviceAddressLine.trim();
    if (addressText.isEmpty) {
      _toast('حدد عنوان الخدمة: موقعك الحالي، البحث، أو الخريطة.');
      return;
    }
    if (_notesController.text.trim().isEmpty) {
      const message =
          'اكتب ماذا تريد من المزود القيام به قبل إرسال الطلب.';
      setState(() => _workDetailsError = message);
      _toast(message);
      return;
    }
    if (_workDetailsError != null) {
      setState(() => _workDetailsError = null);
    }

    final assignedId = widget.providerId?.trim();
    if (assignedId != null &&
        assignedId.isNotEmpty &&
        SupabaseService.isInitialized &&
        SupabaseService.instance.hasSession) {
      final working =
          await SupabaseService.instance.isProviderWorking(assignedId);
      if (!working) {
        _toast(kProviderNotWorkingMessage);
        return;
      }
    }

    if (_isSelfBooking) {
      _toast(kSelfBookingMessage);
      return;
    }

    var createdOk = false;
    setState(() => _processing = true);

    try {
      var lat = _lat;
      var lng = _lng;
      if ((lat == null || lng == null) && _chosenAddress.isNotEmpty) {
        final geo = await PlacesService.geocodeAddress(_chosenAddress);
        if (geo != null) {
          lat = geo.lat;
          lng = geo.lng;
          final base = geo.areaBase.trim().isNotEmpty
              ? geo.areaBase.trim()
              : _chosenAddress;
          _offerDistrict(geo.neighborhood);
          if (mounted) {
            setState(() {
              _lat = lat;
              _lng = lng;
              _addressText = base;
              _addressSearchController.text = base;
            });
          }
          addressText = _serviceAddressLine.trim();
        }
      }
      if (lat == null || lng == null) {
        _toast(
          'حدد موقع الخدمة على الخريطة أو استخدم موقعك الحالي لحفظ الإحداثيات.',
        );
        return;
      }
      if (_districtController.text.trim().isEmpty) {
        _toast('اكتب اسم الحي لإكمال العنوان');
        return;
      }
      addressText = _serviceAddressLine.trim();

      if (!SupabaseService.isInitialized ||
          !SupabaseService.instance.hasSession) {
        if (mounted) {
          _toast('يجب تسجيل الدخول لإنشاء الطلب.');
        }
        return;
      }

      final notes = _notesController.text.trim();
      if (notes.isEmpty) {
        if (mounted) {
          const message =
              'اكتب ماذا تريد من المزود القيام به قبل إرسال الطلب.';
          setState(() => _workDetailsError = message);
          _toast(message);
        }
        return;
      }
      final appointmentLine = _isAsap
          ? BookingDateTime.asapLabelAr
          : BookingDateTime.formatAppointmentAr(_scheduledAt!);
      final noteLines = <String>[
        if (notes.isNotEmpty) notes,
        if (widget.description != null &&
            widget.description!.trim().isNotEmpty)
          'الوصف: ${widget.description!.trim()}',
        if (widget.category != null && widget.category!.trim().isNotEmpty)
          'التصنيف: ${widget.category!.trim()}',
        'الموعد: $appointmentLine',
        'العنوان: $addressText',
        if (lat != null && lng != null) 'الموقع: $lat,$lng',
        'المزود: ${widget.providerName}',
      ];
      final providerId = widget.providerId?.trim();
      final created = await SupabaseService.instance.createOrder(
        serviceName: _bookedSpecialty,
        price: widget.price ?? (_displayPrice > 0 ? _displayPrice : null),
        providerId: (providerId != null &&
                providerId.isNotEmpty &&
                SupabaseService.isLikelyUuid(providerId))
            ? providerId
            : null,
        addressId: _addressId,
        serviceLat: lat,
        serviceLng: lng,
        scheduledAt: _isAsap ? null : _scheduledAt,
        isAsap: _isAsap,
        serviceAddressText: addressText,
        notes: noteLines.join('\n'),
        providerServiceId: widget.serviceId,
        requestedPriceLines: _selectedLines,
      );
      createdOk = true;
      if (_pendingPhotos.isNotEmpty) {
        var uploaded = 0;
        for (final file in _pendingPhotos) {
          try {
            await StorageService.instance.uploadOrderAttachment(
              created.id,
              file,
            );
            uploaded++;
          } on Object catch (photoError) {
            debugPrint('[Booking] photo upload failed: $photoError');
          }
        }
        if (uploaded < _pendingPhotos.length && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم إنشاء الطلب، وتعذّر رفع ${_pendingPhotos.length - uploaded} صورة. يمكنك إضافتها من تفاصيل الطلب أو المحادثة.',
              ),
            ),
          );
        }
      }
      final pendingVideo = _pendingVideo;
      if (pendingVideo != null) {
        try {
          await StorageService.instance.uploadOrderAttachment(
            created.id,
            pendingVideo,
          );
        } on Object catch (videoError) {
          debugPrint('[Booking] video upload failed: $videoError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'تم إنشاء الطلب، وتعذّر رفع فيديو المشكلة. يمكنك إضافته من تفاصيل الطلب.',
                ),
              ),
            );
          }
        }
      }
    } on Object catch (error) {
      debugPrint('[Booking] createOrder failed: $error');
      if (mounted) {
        final detail = isOrderSelfPartyError(error)
            ? kSelfBookingMessage
            : isProviderNotWorkingError(error)
                ? kProviderNotWorkingMessage
                : error is StateError && error.message.isNotEmpty
                    ? error.message
                    : 'تعذّر حفظ الطلب في قاعدة البيانات. لم يتم إنشاء الطلب.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(detail)),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _processing = false);
    }

    if (!mounted || !createdOk) return;
    customerFlow.confirmBooking(context, providerName: widget.providerName);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AmanaTheme.surface,
        body: Column(
          children: [
            _header(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  const Text(
                    'ملخص الخدمة',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AmanaTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _serviceSummary(),
                  const SizedBox(height: 24),
                  const Text(
                    'اختر الموعد',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AmanaTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _appointmentSection(),
                  const SizedBox(height: 24),
                  const Text(
                    'عنوان الخدمة',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AmanaTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'اختر نتيجة البحث، أو موقعك الحالي، أو نقطة على الخريطة. إذا لم يظهر الشارع، اكتب معلماً قريباً.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AmanaTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _addressSection(),
                  const SizedBox(height: 24),
                  const Text(
                    'صور المشكلة (اختياري)',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AmanaTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'أضف صوراً توضّح العطل حتى يقدّر المزود العمل بدقة.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AmanaTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _photosRow(),
                  const SizedBox(height: 24),
                  const Text(
                    'فيديو المشكلة (اختياري)',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AmanaTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'فيديو قصير حتى $shortVideoMaxSeconds ثانية '
                    '(${shortVideoMaxBytes ~/ (1024 * 1024)} ميجابايت) يوضح العطل. فيديو واحد كحد أقصى.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AmanaTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _videoRow(),
                  if (_selectedLines.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'الخدمات المختارة',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AmanaTheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final line in _selectedLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line.detailLine,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: AmanaTheme.onSurface,
                          ),
                        ),
                      ),
                    Text(
                      RequestedPriceLine.totalLabel(_selectedLines),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AmanaTheme.primaryDark,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'معلومات إضافية للعمل المطلوب',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AmanaTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('bookingWorkDetailsField'),
                    controller: _notesController,
                    maxLines: 3,
                    onChanged: (_) {
                      if (_workDetailsError != null) {
                        setState(() => _workDetailsError = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'ماذا تريد من المزود القيام به بالضبط',
                      errorText: _workDetailsError,
                      errorMaxLines: 3,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (_isSelfBooking) ...[
                    const SizedBox(height: 20),
                    _selfBookingBanner(),
                  ],
                ],
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  static const _maxBookingPhotos = 6;

  Future<void> _addPendingPhoto() async {
    if (_pickingPhoto ||
        _pickingVideo ||
        _pendingPhotos.length >= _maxBookingPhotos) {
      return;
    }
    final source = await showImageSourceSheet(context);
    if (source == null || !mounted) return;
    setState(() => _pickingPhoto = true);
    try {
      final file = await StorageService.instance.pickImage(source: source);
      if (file == null) {
        if (mounted) setState(() => _pickingPhoto = false);
        return;
      }
      if (!mounted) return;
      setState(() {
        _pendingPhotos.add(file);
        _pickingPhoto = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _pickingPhoto = false);
      final detail = error is StateError && error.message.isNotEmpty
          ? error.message
          : 'تعذّر اختيار الصورة';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(detail)));
    }
  }

  Widget _photosRow() {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: SizedBox(width: 96, child: _addPhotoTile()),
          ),
          for (var i = 0; i < _pendingPhotos.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: SizedBox(width: 96, child: _pendingPhotoTile(i)),
            ),
        ],
      ),
    );
  }

  Widget _addPhotoTile() {
    final full = _pendingPhotos.length >= _maxBookingPhotos;
    return AspectRatio(
      aspectRatio: 1,
      child: InkWell(
        onTap: (_pickingPhoto || _pickingVideo || full) ? null : _addPendingPhoto,
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
                if (_pickingPhoto)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.add_a_photo, color: AmanaTheme.outline),
                const SizedBox(height: 4),
                Text(
                  full
                      ? 'الحد $_maxBookingPhotos'
                      : (_pickingPhoto ? 'جاري الاختيار...' : 'إضافة صورة'),
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

  Widget _pendingPhotoTile(int index) {
    final path = _pendingPhotos[index].path;
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: path.isEmpty
                ? const ColoredBox(
                    color: AmanaTheme.surfaceContainer,
                    child: Icon(Icons.image),
                  )
                : Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: AmanaTheme.surfaceContainer,
                      child: Icon(Icons.broken_image),
                    ),
                  ),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: InkWell(
              onTap: () => setState(() => _pendingPhotos.removeAt(index)),
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _videoRow() {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: SizedBox(
              width: 96,
              child: _pendingVideo == null
                  ? _addVideoTile()
                  : _pendingVideoTile(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addPendingVideo() async {
    if (_pickingVideo || _pickingPhoto || _pendingVideo != null) return;
    final source = await showImageSourceSheet(context);
    if (source == null || !mounted) return;
    setState(() => _pickingVideo = true);
    try {
      final file = await StorageService.instance.pickVideo(source: source);
      if (file == null) {
        if (mounted) setState(() => _pickingVideo = false);
        return;
      }
      if (!mounted) return;
      setState(() {
        _pendingVideo = file;
        _pickingVideo = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _pickingVideo = false);
      final detail = error is StateError && error.message.isNotEmpty
          ? error.message
          : 'تعذّر اختيار الفيديو';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(detail)));
    }
  }

  Widget _addVideoTile() {
    return AspectRatio(
      aspectRatio: 1,
      child: InkWell(
        key: const Key('booking-add-video'),
        onTap: (_pickingVideo || _pickingPhoto) ? null : _addPendingVideo,
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
                if (_pickingVideo)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.videocam_outlined, color: AmanaTheme.outline),
                const SizedBox(height: 4),
                Text(
                  _pickingVideo ? 'جاري الاختيار...' : 'إضافة فيديو',
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

  Widget _pendingVideoTile() {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            child: AmanaVideoMark(label: 'فيديو المشكلة'),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: InkWell(
              onTap: () => setState(() => _pendingVideo = null),
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AmanaTheme.surface,
        border: Border(bottom: BorderSide(color: AmanaTheme.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_forward, color: AmanaTheme.primaryDark),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'تأكيد الحجز',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AmanaTheme.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    ),
    );
  }

  Widget _serviceSummary() {
    final category = widget.category?.trim().isNotEmpty == true
        ? widget.category!.trim()
        : 'خدمة';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AmanaTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AmanaTheme.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AmanaTheme.primaryFixed,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AmanaTheme.outlineVariant),
                  ),
                  child: Icon(
                    serviceCategoryIcon(null, nameHint: category),
                    key: const Key('booking-category-icon'),
                    color: AmanaTheme.primaryDark,
                    size: 40,
                  ),
                ),
                Positioned(
                  bottom: -6,
                  left: -6,
                  child: AmanaUserAvatar(
                    key: const Key('booking-provider-photo'),
                    imageUrl: widget.providerAvatarUrl,
                    fallbackLabel: widget.providerName,
                    size: 44,
                    borderColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _bookedSpecialty,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AmanaTheme.primaryDark,
                        ),
                      ),
                    ),
                    if (category != _bookedSpecialty)
                      Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AmanaTheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AmanaTheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'مزود الخدمة: ${widget.providerName}',
                  style: const TextStyle(color: AmanaTheme.onSurfaceVariant),
                ),
                if (_providerVerified ||
                    (_ratingCount > 0 && _avgRating != null)) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (_providerVerified)
                        ServiceTrustBadge(
                          trustLevel: widget.trustLevel,
                          compact: true,
                        ),
                      if (_providerVerified &&
                          _ratingCount > 0 &&
                          _avgRating != null)
                        const SizedBox(width: 8),
                      if (_ratingCount > 0 && _avgRating != null) ...[
                        const Icon(
                          Icons.star,
                          size: 14,
                          color: AmanaTheme.warningAmber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_avgRating!.toStringAsFixed(1)} ($_ratingCount)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                if (widget.description != null &&
                    widget.description!.trim().isNotEmpty)
                  Text(
                    widget.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AmanaTheme.onSurfaceVariant,
                    ),
                  ),
                Text(
                  _priceLabel,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AmanaTheme.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appointmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() {
            _isAsap = true;
            _scheduledAt = null;
          }),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _isAsap ? AmanaTheme.primaryDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isAsap
                    ? AmanaTheme.primaryDark
                    : AmanaTheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bolt,
                  color: _isAsap ? Colors.white : AmanaTheme.primaryDark,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    BookingDateTime.asapLabelAr,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _isAsap ? Colors.white : AmanaTheme.primaryDark,
                    ),
                  ),
                ),
                Icon(
                  _isAsap
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: _isAsap ? Colors.white : AmanaTheme.primaryDark,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickDateTime,
          icon: const Icon(Icons.event),
          label: Text(
            _isAsap || _scheduledAt == null
                ? 'اختيار التاريخ والوقت'
                : BookingDateTime.formatAppointmentAr(_scheduledAt!),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AmanaTheme.primaryDark,
            side: BorderSide(
              color: !_isAsap && _scheduledAt != null
                  ? AmanaTheme.primaryDark
                  : AmanaTheme.outlineVariant,
              width: !_isAsap && _scheduledAt != null ? 2 : 1,
            ),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AmanaTheme.primaryFixed,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule, color: AmanaTheme.primaryDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'الموعد المختار: $_appointmentSummary',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AmanaTheme.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _addressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hasPickedLocation) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AmanaTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AmanaTheme.primaryDark, width: 2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place, color: AmanaTheme.primaryDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'العنوان المختار',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AmanaTheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _serviceAddressLine.trim().isEmpty
                            ? 'موقع محدد على الخريطة'
                            : _serviceAddressLine,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (_lat == null || _lng == null)
                        const Text(
                          'لم تُحفظ النقطة بعد — حدّدها على الخريطة أو من موقعك الحالي.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AmanaTheme.secondary,
                          ),
                        ),
                      if (_lat != null && _lng != null) ...[
                        const SizedBox(height: 8),
                        AmanaMapPreview(
                          lat: _lat,
                          lng: _lng,
                          height: 120,
                          label: _addressText,
                          showOpenExternal: false,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: const Text('موقعي الحالي'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AmanaTheme.primaryDark,
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickOnMap,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('تحديد على الخريطة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AmanaTheme.primaryDark,
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
          ],
        ),
        if (_lat != null && _lng != null) ...[
          const SizedBox(height: 12),
          TextField(
            key: const Key('bookingDistrictField'),
            controller: _districtController,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'الحي',
              hintText: 'اكتب اسم الحي',
              prefixIcon: const Icon(Icons.holiday_village_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          key: const Key('bookingAddressField'),
          controller: _addressSearchController,
          onChanged: _onAddressQueryChanged,
          decoration: InputDecoration(
            hintText: 'ابحث أو اكتب العنوان (حي، شارع، معلم…)',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_addressSearchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _addressSearchController.clear();
                          _setPicked(text: '', lat: null, lng: null);
                        },
                      )),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('bookingLandmarkField'),
          controller: _landmarkController,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'معلم للموقع (اختياري)',
            hintText: 'بجوار المسجد، عمارة، طابق…',
            prefixIcon: const Icon(Icons.signpost_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AmanaTheme.outlineVariant),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _suggestions.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(_suggestions[i].description),
                    onTap: () => _pickSuggestion(_suggestions[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (_loadingAddresses)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_savedAddresses.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'عناوين محفوظة',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AmanaTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_savedAddresses.length, _savedAddressCard),
        ],
      ],
    );
  }

  Widget _savedAddressCard(int i) {
    final a = _savedAddresses[i];
    final selected = _selectedSavedIndex == i;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _applySaved(i)),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AmanaTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected ? AmanaTheme.primaryDark : AmanaTheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(a.icon, color: AmanaTheme.primaryDark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      a.line1,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AmanaTheme.onSurfaceVariant,
                      ),
                    ),
                    if (a.line2.isNotEmpty)
                      Text(
                        a.line2,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AmanaTheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: AmanaTheme.primaryDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selfBookingBanner() {
    return Container(
      key: const Key('self-booking-warning'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AmanaTheme.secondary),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AmanaTheme.secondary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              kSelfBookingMessage,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AmanaTheme.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AmanaTheme.surface,
        border: Border(top: BorderSide(color: AmanaTheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isSelfBooking) ...[
            _selfBookingBanner(),
            const SizedBox(height: 10),
          ],
          Text(
            'الموعد: $_appointmentSummary',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AmanaTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'العنوان: ${_serviceAddressLine.trim().isEmpty ? 'لم يُحدد بعد' : _serviceAddressLine}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AmanaTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: (_processing || _isSelfBooking) ? null : _confirm,
            style: FilledButton.styleFrom(
              backgroundColor: AmanaTheme.primaryDark,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _processing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('تأكيد الحجز', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
