import 'package:base_sdk/src/services/tr_keys.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:base_sdk/src/presentation/app_assets.dart';

import 'package:base_sdk/src/services/enums.dart';

abstract class AppConstants {
  AppConstants._();

  static const bool isDemo = bool.fromEnvironment('IS_DEMO');
  static const bool isPhoneFirebase = true;
  static const int scheduleInterval = 60;
  static SignUpType get signUpType =>
      SignUpType.values.byName(const String.fromEnvironment('SIGN_UP_TYPE'));
  static const bool use24Format = true;
  static const double radius = 16;

  /// api urls
  static const String baseUrl = String.fromEnvironment('BASE_URL');
  static const String wsBaseUrl = String.fromEnvironment('WS_BASE_URL');
  static const String wsSecret = String.fromEnvironment('WS_SECRET');
  static const String webUrl = String.fromEnvironment('WEB_URL');
  static const String drawingBaseUrl = String.fromEnvironment('ROUTING_API');
  static String adminPageUrl = String.fromEnvironment('ADMIN_URL');
  static const String googleApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );
  static const String firebaseWebKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
  );
  static const String geminiKey = String.fromEnvironment('GEMINI_KEY');
  static const String uriPrefix = String.fromEnvironment('URL_PREFIX');
  static const String routingBaseUrl = String.fromEnvironment('ROUTING_API');
  static const String routingKey = String.fromEnvironment('ROUTING_KEY');
  static const String deepLinkHost = String.fromEnvironment('DEEP_LINK_URL');
  static const String androidPackageName = String.fromEnvironment(
    'CUSTOMER_ANDROID_PACKAGE_NAME',
  );
  static const String iosPackageName = String.fromEnvironment(
    'CUSTOMER_IOS_PACKAGE_NAME',
  );

  /// newStores and Recommendation Time
  static int newShopDays = 60;

  /// Operating time
  static String isOpen = '6am';
  static String isClosed = '10pm';
  static bool isMaintain = false;
  static bool bgImg = true;

  /// Google Maps POI
  static bool showGooglePOILayer = true;

  /// hero tags
  static const String heroTagSelectUser = 'heroTagSelectUser';
  static const String heroTagSelectAddress = 'heroTagSelectAddress';
  static const String heroTagSelectCurrency = 'heroTagSelectCurrency';

  /// PayFast
  static const String passphrase = String.fromEnvironment('PAYFAST_PASSPHRASE');
  static const String merchantId = String.fromEnvironment(
    'PAYFAST_MERCHANT_ID',
  );
  static const String merchantKey = String.fromEnvironment(
    'PAYFAST_MERCHANT_KEY',
  );

  static const String demoUserLogin = String.fromEnvironment('DEMO_USER_LOGIN');
  static const String demoUserPassword = String.fromEnvironment(
    'DEMO_USER_PASSWORD',
  );

  /// locales
  static String localeCodeEn = const String.fromEnvironment('LOCALE_CODE');

  /// auth phone fields
  static bool isNumberLengthAlwaysSame = const bool.fromEnvironment(
    'IS_NUMBER_LENGTH_ALWAYS_SAME',
  );
  static const String countryCodeISO = String.fromEnvironment('COUNTRY_ISO');
  static bool showFlag = const bool.fromEnvironment('SHOW_FLAG');
  static bool showArrowIcon = const bool.fromEnvironment('SHOW_ARROW_ICON');

  /// location
  static final double demoLatitude = double.parse(
    const String.fromEnvironment('DEMO_LATITUDE'),
  );
  static final double demoLongitude = double.parse(
    const String.fromEnvironment('DEMO_LONGITUDE'),
  );
  static const double pinLoadingMin = 0.116666667;
  static const double pinLoadingMax = 0.611111111;

  /// Weather
  static const String openWeatherApiKey = String.fromEnvironment(
    'OPEN_WEATHER_API_KEY',
  );
  static const bool weatherIcon = true;
  static const int rainPOP = 60;

  static const Duration timeRefresh = Duration(seconds: 30);

  /// social sign-in
  static const socialSignIn = [
    FlutterRemix.google_fill,
    FlutterRemix.facebook_fill,
    FlutterRemix.apple_fill,
  ];

  static const socialSignInAndroid = [
    FlutterRemix.google_fill,
    FlutterRemix.facebook_fill,
  ];

  static const List infoImage = [
    Assets.imagesSave,
    Assets.imagesDelivery,
    Assets.imagesFast,
    Assets.imagesSet,
  ];

  static const List infoTitle = [
    TrKeys.saveTime,
    TrKeys.deliveryRestriction,
    TrKeys.fast,
    TrKeys.set,
  ];

  static const payLater = ["progress", "canceled", "rejected"];
  static const genderList = ["male", "female"];

  static const bool fixed = true;

  static bool cardDirect = false;

  /// Marketplace Settings
  static bool enableMarketplace = true;
  static String defaultShopId = "";
}
