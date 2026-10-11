import 'package:flutter/foundation.dart';

import '../../../core/api.dart';

/// Admin records loaded from GET /api/admin/bootstrap (filled in with the admin screens).
class AdminStore extends ChangeNotifier {
  AdminStore(this.api);
  final ApiClient api;

  /// Forgets the data when the administrator signs out.
  void reset() {}
}
