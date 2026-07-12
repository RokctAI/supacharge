library base_sdk;

// Shared kernel for all RokctAI feature SDKs. This barrel carries the
// commonly-consumed surface; anything else is importable via
// package:base_sdk/src/... paths.

// Handlers (HTTP plumbing, result/failure types)
export 'src/handlers/api_result.dart';
export 'src/handlers/http_service.dart';
export 'src/handlers/network_exceptions.dart';
export 'src/handlers/network_helpers.dart';
export 'src/handlers/token_interceptor.dart';

// Constants + assets
export 'src/constants/app_constants.dart';
export 'src/presentation/app_assets.dart';

// Kernel services
export 'src/services/app_connectivity.dart';
export 'src/services/app_helpers.dart';
export 'src/services/local_storage.dart';
export 'src/services/storage_keys.dart';
export 'src/services/tr_keys.dart';

// Offline database (shared Drift instance + generic JSON document store)
export 'src/database/app_database.dart';
export 'src/database/kv_tables.dart';

// DI facade accessors (repository interfaces resolved via get_it)
export 'src/di/injection.dart';
export 'src/di/base_di.dart';

// Host-backed indirection for navigation and cross-SDK widget embedding
export 'src/navigation/app_routes.dart';
export 'src/navigation/embedded_widgets.dart';

// Kernel session models
export 'src/models/models.dart';
