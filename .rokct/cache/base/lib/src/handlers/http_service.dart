import 'package:dio/dio.dart';
import 'package:base_sdk/src/constants/app_constants.dart';

import 'package:base_sdk/src/handlers/token_interceptor.dart';

class HttpService {
  Dio client({bool requireAuth = false, bool routing = false}) => Dio(
        BaseOptions(
          baseUrl: routing ? AppConstants.drawingBaseUrl : AppConstants.baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          headers: {
            'Accept':
                'application/json, application/geo+json, application/gpx+xml, img/png; charset=utf-8',
            'Content-type': 'application/json',
          },
        ),
      )
        ..interceptors.add(TokenInterceptor(requireAuth: requireAuth))
        ..interceptors.add(const FrappeResponseInterceptor())
        ..interceptors.add(
          LogInterceptor(
            responseHeader: false,
            requestHeader: true,
            responseBody: true,
            requestBody: true,
          ),
        );
}

class FrappeResponseInterceptor extends Interceptor {
  const FrappeResponseInterceptor();

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.data is Map && response.data.containsKey('message')) {
      response.data = response.data['message'];
    }
    handler.next(response);
  }
}
