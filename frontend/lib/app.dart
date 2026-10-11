import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api.dart';
import 'core/router.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'features/admin/data/admin_store.dart';

/// EduTrack SIS for students and administrators, on the same REST API as the
/// web portals.
class EduTrackApp extends StatefulWidget {
  const EduTrackApp({super.key, this.api, this.restoreSession = true});

  /// Injected in tests; the real app builds one for [apiUrl].
  final ApiClient? api;
  final bool restoreSession;

  @override
  State<EduTrackApp> createState() => _EduTrackAppState();
}

class _EduTrackAppState extends State<EduTrackApp> {
  late final ApiClient _api = widget.api ?? ApiClient(TokenStore());
  late final Session _session = Session(_api);
  late final AdminStore _adminStore = AdminStore(_api);

  @override
  void initState() {
    super.initState();
    if (widget.restoreSession) _session.restore();
    // The admin data belongs to the signed-in administrator only.
    _session.addListener(() {
      if (_session.user?.isAdmin != true) _adminStore.reset();
    });
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          Provider.value(value: _api),
          ChangeNotifierProvider.value(value: _session),
          ChangeNotifierProvider.value(value: _adminStore),
        ],
        child: AppRouterScope(
          session: _session,
          builder: (context, router) => MaterialApp.router(
            title: 'EduTrack SIS',
            debugShowCheckedModeBanner: false,
            theme: studentTheme,
            routerConfig: router,
          ),
        ),
      );
}
