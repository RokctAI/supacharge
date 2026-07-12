import 'package:base_sdk/src/models/data/cart_data.dart';
import 'package:base_sdk/src/models/request/cart_request.dart';
import 'package:base_sdk/src/handlers/api_result.dart';

abstract class CartRepositoryFacade {
  Future<ApiResult<CartModel>> getCart(String shopId);

  Future<ApiResult<CartModel>> getCartInGroup(
    String? cartId,
    String? shopId,
    String? cartUuid,
  );

  Future<ApiResult<dynamic>> startGroupOrder({required String cartId});

  Future<ApiResult<dynamic>> changeStatus({
    required String? userUuid,
    required String? cartId,
  });

  Future<ApiResult<CartModel>> deleteCart({required String cartId});

  Future<ApiResult<dynamic>> deleteUser({
    required String cartId,
    required String userId,
  });

  Future<ApiResult<CartModel>> removeProductCart({
    required String cartDetailId,
    List<String> listOfId,
  });

  Future<ApiResult<CartModel>> createAndCart({required CartRequest cart});

  Future<ApiResult<CartModel>> insertCart({required CartRequest cart});

  Future<ApiResult<CartModel>> insertCartWithGroup({required CartRequest cart});

  Future<ApiResult<CartModel>> createCart({required CartRequest cart});
}
