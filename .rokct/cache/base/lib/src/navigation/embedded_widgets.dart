import 'package:base_sdk/src/models/data/bonus_data.dart';
import 'package:base_sdk/src/models/data/cart_data.dart';
import 'package:base_sdk/src/models/data/order_active_model.dart';
import 'package:base_sdk/src/models/data/order_body_data.dart';
import 'package:base_sdk/src/models/data/product_data.dart';
import 'package:base_sdk/src/models/data/saved_card.dart';
import 'package:flutter/widgets.dart';

/// Cross-SDK widget indirection.
///
/// Legacy customer UI composes widgets across feature boundaries (product
/// modal inside search results, payment sheet inside checkout, ...). Feature
/// SDKs must not import each other, so consumers call these registry methods
/// and the host app supplies an implementation returning the real widgets.
abstract class EmbeddedWidgets {
  static EmbeddedWidgets I = _UnsetEmbeddedWidgets();

  Widget becomeDriverPage();
  Widget bonusScreen({required BonusModel? bonus});
  Widget cartClearDialog({required VoidCallback cancel, required VoidCallback clear, bool? isLoading});
  Widget cartOrderItem({required VoidCallback add, required VoidCallback remove, required CartDetail? cart, bool? isActive, Detail? cartTwo, bool? isOwn, String? symbol, bool? isAddComment});
  Widget chatPage({required String roleId, required String name});
  Widget introPage();
  Widget languageScreen({required VoidCallback onSave});
  Widget loanScreen();
  Widget orderMap({required dynamic markers, required dynamic latLng, required dynamic polylineCoordinates, required bool isLoading});
  Widget payFastWebView({required String url, Function(bool)? onComplete, Function(String, Map<String, String>)? onTokenCaptured, dynamic preloadedController});
  Widget paymentScreen({OrderBodyData? orderData, required Function(bool) onPaymentComplete, ScrollController? scrollController, bool? tokenizeOnly});
  Widget phoneVerify();
  Widget policyPage();
  Widget productScreen({String? productId, ProductData? data, String? cartId, required ScrollController controller});
  Widget resetPasswordPage();
  Widget savedCardsWidget({required Function(SavedCardModel?) onCardSelected, SavedCardModel? initialSelectedCard, bool? hideManagement});
  Widget termPage();
  void preloadPayFastWebView(BuildContext context, String paymentUrl);
}

class _UnsetEmbeddedWidgets implements EmbeddedWidgets {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError(
          'EmbeddedWidgets.I has not been set by the host app. Assign an '
          'implementation in main() before running the app.');
}
