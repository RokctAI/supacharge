import 'package:base_sdk/src/handlers/handlers.dart';
import 'package:base_sdk/src/models/models.dart';

import 'package:base_sdk/src/models/data/user.dart';
import 'package:base_sdk/src/models/data/wallet_data.dart';

abstract class WalletRepositoryFacade {
  Future<ApiResult<List<UserModel>>> searchSending(Map<String, dynamic> params);
  Future<ApiResult<WalletHistoryData>> sendWalletBalance(
    String userUuid,
    double amount,
  );
  Future<ApiResult<dynamic>> walletTopUp({
    required double amount,
    String? token,
  });
  Future<ApiResult<List<WalletHistoryData>>> getWalletHistory();
}
