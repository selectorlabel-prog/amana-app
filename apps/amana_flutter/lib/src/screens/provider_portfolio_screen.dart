import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/profile_controller.dart';
import '../models/provider_portfolio.dart';
import '../models/provider_service.dart';
import '../services/storage_service.dart';
import '../utils/blocked_contact.dart';
import '../services/supabase_service.dart';
import '../theme/amana_theme.dart';
import '../utils/image_source_sheet.dart';
import '../utils/media_kind.dart';
import '../widgets/amana_playable_video.dart';
import '../widgets/amana_user_avatar.dart';
import '../widgets/provider_trust_sheet.dart';

class ProviderPortfolioScreen extends StatefulWidget {
  const ProviderPortfolioScreen({super.key});

  static const emptyStateKey = Key('portfolio-empty');

  @override
  State<ProviderPortfolioScreen> createState() => _ProviderPortfolioScreenState();
}

class _ProviderPortfolioScreenState extends State<ProviderPortfolioScreen> {
  List<ProviderPortfolioItem> _items = const [];
  List<ProviderService> _approved = const [];
  bool _loading = true;
  String? _error;

  bool get _useLive =>
      SupabaseService.isInitialized && SupabaseService.instance.hasSession;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_useLive) {
      setState(() {
        _loading = false;
        _items = const [];
        _approved = const [];
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await SupabaseService.instance.fetchMyPortfolioItems();
      final services = await SupabaseService.instance.fetchMyProviderServices();
      if (!mounted) return;
      setState(() {
        _items = items;
        _approved = services
            .where((s) => s.isCategoryApproved)
            .toList(growable: false);
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل المعرض.\n$error';
        _loading = false;
        _items = const [];
      });
    }
  }

  void _previewAsCustomer() {
    final id = _useLive ? SupabaseService.instance.currentUserId : null;
    final name = profileController.fullName.trim().isEmpty
        ? 'مزود'
        : profileController.fullName.trim();
    showProviderTrustSheet(
      context,
      providerId: id,
      providerName: name,
      providerAvatarUrl:
          profileController.avatarUrl.isEmpty ? null : profileController.avatarUrl,
      isVerified: false,
      previewOnly: true,
    );
  }

  Future<void> _onAdd() async {
    if (!_useLive) {
      _snack('سجّل الدخول لإضافة أعمال إلى المعرض');
      return;
    }
    if (_items.length >= ProviderPortfolioItem.maxPerProvider) {
      _snack('الحد الأقصى ${ProviderPortfolioItem.maxPerProvider} أعمال');
      return;
    }
    if (_approved.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('يلزم فئة معتمدة'),
            content: const Text(
              'أضف فئة خدمة واحصل على اعتمادها من الإدارة أولاً، ثم يمكنك رفع صور أو فيديو قصير في معرض الأعمال.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حسناً'),
              ),
            ],
          ),
        ),
      );
      return;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UploadProjectSheet(approvedServices: _approved),
    );
    if (saved == true && mounted) {
      _snack('تم حفظ العمل');
      await _load();
    }
  }

  Future<void> _onDelete(ProviderPortfolioItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف العمل'),
          content: Text('هل تريد حذف «${item.title}» من المعرض؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseService.instance.deleteProviderPortfolioItem(item.id);
      final path = item.storagePath;
      if (path != null && path.isNotEmpty) {
        await StorageService.instance.deletePortfolioFile(path);
      }
      if (!mounted) return;
      _snack('تم حذف العمل');
      await _load();
    } on Object catch (error) {
      if (!mounted) return;
      _snack('تعذّر الحذف.\n$error');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AmanaTheme.background,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _appBar(context)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const Text(
                    'معرض الأعمال',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AmanaTheme.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'أضف صوراً حقيقية أو فيديو قصيراً من أعمالك لزيادة ثقة العملاء.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AmanaTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_error != null)
                    Text(
                      _error!,
                      style: const TextStyle(color: AmanaTheme.errorRed),
                    )
                  else if (_items.isEmpty)
                    const Padding(
                      key: ProviderPortfolioScreen.emptyStateKey,
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'لا أعمال بعد',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AmanaTheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final item in _items) ...[
                      _itemCard(item),
                      const SizedBox(height: 12),
                    ],
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _previewAsCustomer,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AmanaTheme.primaryDark,
                      side: const BorderSide(color: AmanaTheme.primaryDark),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('معاينة كما يراها العميل'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _onAdd,
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('إضافة مشروع جديد'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AmanaTheme.primaryDark,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appBar(BuildContext context) {
    return ListenableBuilder(
      listenable: profileController,
      builder: (context, _) {
        final avatar = profileController.avatarUrl;
        return SafeArea(
          bottom: false,
          child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: AmanaTheme.surfaceContainerLowest,
            border: Border(bottom: BorderSide(color: AmanaTheme.outlineVariant)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_forward, color: AmanaTheme.primaryDark),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Expanded(
                child: Text(
                  'أمانة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AmanaTheme.primaryDark,
                  ),
                ),
              ),
              AmanaUserAvatar(
                imageUrl: avatar.isEmpty ? null : avatar,
                fallbackLabel: profileController.fullName,
                size: 40,
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _itemCard(ProviderPortfolioItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AmanaTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AmanaTheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: !item.hasUrl
                ? Container(color: AmanaTheme.surfaceContainerLow)
                : item.isVideo
                    ? AmanaVideoMark(
                        label: 'فيديو',
                        onTap: () => showAmanaVideoPlayer(
                          context,
                          item.url,
                          title: item.title.trim().isEmpty
                              ? 'فيديو العمل'
                              : item.title.trim(),
                        ),
                      )
                    : Image.network(
                        item.url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AmanaTheme.surfaceContainerLow,
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AmanaTheme.primaryDark,
                        ),
                      ),
                      if ((item.caption ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.caption!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AmanaTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (item.isHidden) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'مخفي عن العملاء',
                          style: TextStyle(
                            fontSize: 12,
                            color: AmanaTheme.errorRed,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'حذف',
                  onPressed: () => _onDelete(item),
                  icon: const Icon(Icons.delete_outline, color: AmanaTheme.errorRed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadProjectSheet extends StatefulWidget {
  const _UploadProjectSheet({required this.approvedServices});

  final List<ProviderService> approvedServices;

  @override
  State<_UploadProjectSheet> createState() => _UploadProjectSheetState();
}

class _UploadProjectSheetState extends State<_UploadProjectSheet> {
  final _title = TextEditingController();
  final _caption = TextEditingController();
  String? _serviceId;
  XFile? _file;
  var _video = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.approvedServices.isNotEmpty) {
      _serviceId = widget.approvedServices.first.id;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _caption.dispose();
    super.dispose();
  }

  String _label(ProviderService s) {
    final cat = s.category?.trim() ?? '';
    final title = s.title.trim();
    if (cat.isNotEmpty && title.isNotEmpty && cat != title) {
      return '$cat — $title';
    }
    if (title.isNotEmpty) return title;
    if (cat.isNotEmpty) return cat;
    return 'خدمة';
  }

  Future<void> _pick({required bool video}) async {
    final source = await showImageSourceSheet(context);
    if (source == null) return;
    try {
      final file = video
          ? await StorageService.instance.pickVideo(source: source)
          : await StorageService.instance.pickImage(source: source);
      if (!mounted || file == null) return;
      setState(() {
        _file = file;
        _video = video;
      });
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    final serviceId = _serviceId?.trim() ?? '';
    if (_file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر صورة أو فيديو للعمل أولاً')),
      );
      return;
    }
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل عنوان العمل')),
      );
      return;
    }
    if (serviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر فئة معتمدة')),
      );
      return;
    }
    if (containsBlockedContact(title) ||
        containsBlockedContact(_caption.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kBlockedContactMessage)),
      );
      return;
    }

    setState(() => _saving = true);
    StorageUploadResult? uploaded;
    try {
      if (_video) {
        uploaded = await StorageService.instance.uploadPortfolioMedia(_file!);
        await SupabaseService.client.rpc(
          'add_provider_portfolio_item',
          params: {
            'p_title': title,
            'p_caption': _caption.text.trim(),
            'p_storage_path': uploaded.path,
            'p_url': uploaded.url,
            'p_service_id': serviceId,
            'p_media_type': 'video',
          },
        );
      } else {
        uploaded = await StorageService.instance.uploadPortfolioImage(_file!);
        await SupabaseService.instance.addProviderPortfolioItem(
          title: title,
          caption: _caption.text.trim(),
          storagePath: uploaded.path,
          url: uploaded.url,
          serviceId: serviceId,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on Object catch (error) {
      if (uploaded != null) {
        await StorageService.instance.deletePortfolioFile(uploaded.path);
      }
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_portfolioSaveError(error))),
      );
    }
  }

  String _portfolioSaveError(Object error) {
    final lower = error.toString().toLowerCase();
    final needsSql = _video &&
        (lower.contains('media_type') ||
            lower.contains('pgrst202') ||
            lower.contains('could not find the function') ||
            lower.contains('schema cache'));
    if (!needsSql) return 'تعذّر حفظ العمل.\n$error';
    return 'تعذّر حفظ العمل.\n$error\n'
        'شغّل supabase/150_short_video_media.sql في محرر SQL ثم أعد المحاولة.';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AmanaTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AmanaTheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'رفع عمل جديد',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AmanaTheme.primaryDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _saving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _saving
                    ? null
                    : () => _pick(video: _file != null && _video),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AmanaTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AmanaTheme.outlineVariant,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _file == null
                            ? Icons.cloud_upload
                            : (_video
                                ? Icons.play_circle_fill
                                : Icons.check_circle),
                        size: 48,
                        color: _file == null
                            ? AmanaTheme.onSurfaceVariant
                            : AmanaTheme.successGreen,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _file == null
                            ? 'انقر لاختيار صورة العمل'
                            : (_video ? 'تم اختيار الفيديو' : 'تم اختيار الصورة'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'JPG أو PNG — حد أقصى 5 ميجابايت',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: AmanaTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: _saving ? null : () => _pick(video: true),
                  icon: const Icon(Icons.videocam_outlined),
                  label: Text(
                    'إضافة فيديو (حتى $shortVideoMaxSeconds ثانية)',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'عنوان العمل',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AmanaTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _title,
                enabled: !_saving,
                decoration: const InputDecoration(
                  hintText: 'مثال: تركيب لوحة كهربائية',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'الفئة المعتمدة',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AmanaTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _serviceId,
                items: [
                  for (final s in widget.approvedServices)
                    DropdownMenuItem(value: s.id, child: Text(_label(s))),
                ],
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v != null) setState(() => _serviceId = v);
                      },
              ),
              const SizedBox(height: 12),
              const Text(
                'الوصف (اختياري)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AmanaTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _caption,
                enabled: !_saving,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'اشرح باختصار ماذا قدمت في هذا العمل...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AmanaTheme.primaryDark,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _saving ? 'جاري الحفظ...' : 'حفظ العمل',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
