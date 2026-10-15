import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';

/// Loads a screen's data from the API with loading / error states and a
/// reload for pull-to-refresh (the web's `useApi` hook).
mixin ApiLoader<T extends StatefulWidget> on State<T> {
  bool loading = true;
  String? loadError;

  ApiClient get api => context.read<ApiClient>();

  /// Fetches the data and stores it in fields of the State.
  Future<void> fetch();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => reload(showSpinner: true));
  }

  Future<void> reload({bool showSpinner = false}) async {
    if (showSpinner) setState(() => loading = true);
    try {
      await fetch();
      loadError = null;
    } catch (error) {
      loadError = apiErrorMessage(error);
    }
    if (mounted) setState(() => loading = false);
  }
}

List<Map<String, dynamic>> asList(Object? data) => data is List ? [for (final item in data) Map<String, dynamic>.from(item as Map)] : [];

Map<String, dynamic>? asMap(Object? data) => data is Map ? Map<String, dynamic>.from(data) : null;
