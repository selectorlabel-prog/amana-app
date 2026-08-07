import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'amana_theme.dart';
import 'app_role.dart';
import 'order_flow.dart';
import 'role_home.dart';

class AmanaApp extends StatefulWidget {
  const AmanaApp({
    super.key,
    this.roleSource = const ScaffoldSessionRoleSource(),
  });

  final SessionRoleSource roleSource;

  @override
  State<AmanaApp> createState() => _AmanaAppState();
}

class _AmanaAppState extends State<AmanaApp> {
  AppRole? _selectedRole;
  final DemoOrderFlow _orderFlow = DemoOrderFlow();

  AppRole? get _activeRole =>
      widget.roleSource.authenticatedRole ?? _selectedRole;

  @override
  void dispose() {
    _orderFlow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'أمانة',
      debugShowCheckedModeBanner: false,
      theme: AmanaTheme.light,
      locale: const Locale('ar', 'SD'),
      supportedLocales: const [Locale('ar', 'SD')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: _activeRole == null
          ? RoleGateway(onSelected: _selectRole)
          : RoleHome(
              role: _activeRole!,
              orderFlow: _orderFlow,
              onChangeRole: widget.roleSource.authenticatedRole == null
                  ? () => setState(() => _selectedRole = null)
                  : null,
            ),
    );
  }

  void _selectRole(AppRole role) {
    setState(() => _selectedRole = role);
  }
}

class RoleGateway extends StatelessWidget {
  const RoleGateway({required this.onSelected, super.key});

  final ValueChanged<AppRole> onSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.handshake_outlined,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'أمانة',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'بوابة تأسيسية لاختبار مسارات الأدوار. سيستبدل '
                    'اختيار الدور بجلسة دخول موثقة من الخادم.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  for (final role in AppRole.values) ...[
                    FilledButton.tonalIcon(
                      onPressed: () => onSelected(role),
                      icon: Icon(_iconFor(role)),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text('دخول واجهة ${role.arabicLabel}'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(AppRole role) => switch (role) {
    AppRole.customer => Icons.person_outline,
    AppRole.provider => Icons.home_repair_service_outlined,
    AppRole.admin => Icons.admin_panel_settings_outlined,
  };
}
