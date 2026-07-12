import 'package:flutter/material.dart';
import 'package:base_sdk/src/models/data/order_active_model.dart';
import 'package:base_sdk/src/models/models.dart';
import 'package:base_sdk/src/services/enums.dart';

import 'package:base_sdk/src/handlers/handlers.dart';

abstract class OrdersRepositoryFacade {
  Future<ApiResult<GetCalculateModel>> getCalculate({
    required String cartId,
    required double lat,
    required double long,
    required DeliveryTypeEnum type,
    String? coupon,
  });

  Future<ApiResult<OrderActiveModel>> createOrder(OrderBodyData orderBody);

  Future<ApiResult> createAutoOrder({
    required String from,
    required String orderId,
    String? to,
    String? cronPattern,
    String? paymentMethod,
    String? savedCardId,
  });

  Future<ApiResult> pauseAutoOrder(String autoOrderId);

  Future<ApiResult> resumeAutoOrder(String autoOrderId);

  Future<ApiResult> deleteAutoOrder(String orderId);

  Future<ApiResult<void>> createRepeatingOrder({
    required String orderId,
    required String startDate,
    required String cronPattern,
    String? endDate,
  });

  Future<ApiResult<void>> deleteRepeatingOrder({
    required String repeatingOrderId,
  });

  Future<ApiResult<OrderPaginateResponse>> getCompletedOrders(int page);

  Future<ApiResult<OrderPaginateResponse>> getActiveOrders(int page);

  Future<ApiResult<OrderPaginateResponse>> getHistoryOrders(int page);

  Future<ApiResult<RefundOrdersModel>> getRefundOrders(int page);

  Future<ApiResult<OrderActiveModel>> getSingleOrder(String orderId);

  Future<ApiResult<LocalLocation>> getDriverLocation(String deliveryId);

  Future<ApiResult<void>> cancelOrder(String orderId);

  Future<ApiResult<void>> refundOrder(String orderId, String title);

  Future<ApiResult<void>> addReview(
    String orderId, {
    required double rating,
    required String comment,
  });

  Future<ApiResult<String>> process(
    OrderBodyData orderBody,
    String name, {
    BuildContext? context,
    bool forceCardPayment = false,
    bool enableTokenization = false,
  });

  Future<ApiResult<String>> tipProcess({
    required String orderId,
    required double tip,
  });

  Future<ApiResult<CouponResponse>> checkCoupon({
    required String coupon,
    required String shopId,
  });

  Future<ApiResult<CashbackModel>> checkCashback({
    required String shopId,
    required double amount,
  });
}
