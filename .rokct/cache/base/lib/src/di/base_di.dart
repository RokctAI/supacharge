import 'package:get_it/get_it.dart';

import 'package:base_sdk/src/handlers/http_service.dart';
import 'package:base_sdk/src/services/local_storage.dart';

/// Kernel registrations every composed app needs.
///
/// Called from the host app's `main()` (the installer generates the call for
/// composed apps; hand-wired hosts call it directly) BEFORE any feature
/// SDK's `*SdkDependencies.register`. Requires [LocalStorage.init] to have
/// completed.
class BaseSdkDependencies {
  static void register(GetIt getIt) {
    if (!getIt.isRegistered<HttpService>()) {
      getIt.registerLazySingleton<HttpService>(() => HttpService());
    }
    if (!getIt.isRegistered<Map>()) {
      getIt.registerSingleton<Map>(LocalStorage.getTranslations());
    }
  }
}
