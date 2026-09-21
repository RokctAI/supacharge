// Copyright (c) 2026 ROKCT INTELLIGENCE (PTY) LTD
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, version 3.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

// The blog repository's wire contract with base's `tenant/api/blog/blog.py`
// through the universal platform gateway.
//
// What a later edit could quietly undo:
//
//   * `get_blog(name)` takes the Blog DOCNAME under the kwarg `name` — the
//     pre-fork payload key `uuid` was silently dropped by Frappe, so the
//     call raised "missing argument: name" on every open of a blog;
//   * the list rows only carry that docname because the repository mirrors
//     `name` into the `uuid` slot base_sdk's BlogData reads — without the
//     mirror the details call is handed null;
//   * both calls stay guest calls to the gateway path, with the prefix-free
//     `api.blog.*` cmds promotions' frappe manifest whitelists.

import 'package:base_sdk/src/handlers/handlers.dart';
import 'package:base_sdk/src/handlers/http_service.dart';
import 'package:base_sdk/src/handlers/platform_gateway.dart';
import 'package:base_sdk/src/models/models.dart';
import 'package:corporate_sdk/src/common/infrastructure/repositories/blogs_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

/// HttpService whose Dio never touches the network: every request is
/// recorded and resolved through [respond] — the same stubbing shape as
/// base_sdk's app_usage_service_test. No FrappeResponseInterceptor is
/// installed, so [respond] answers the already-unwrapped gateway body.
class _StubHttpService extends HttpService {
  _StubHttpService(this.respond);

  final dynamic Function(RequestOptions options) respond;
  final List<RequestOptions> requests = [];

  @override
  Dio client({bool requireAuth = false, bool routing = false}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://unit.test'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(options);
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: respond(options),
          ),
          true,
        );
      },
    ));
    return dio;
  }
}

void main() {
  late _StubHttpService http;

  _StubHttpService install(dynamic Function(RequestOptions) respond) {
    final stub = _StubHttpService(respond);
    GetIt.instance.registerSingleton<HttpService>(stub);
    return stub;
  }

  tearDown(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<HttpService>()) {
      getIt.unregister<HttpService>();
    }
  });

  group('BlogsRepository.getBlogDetails', () {
    test('sends the Blog docname as `name`, never `uuid`', () async {
      http = install((_) => {
            'data': {'name': 'BLOG-0001', 'title': 'Hello'},
            'status_code': 200,
          });

      final result = await BlogsRepository().getBlogDetails('BLOG-0001');

      expect(http.requests, hasLength(1));
      final request = http.requests.single;
      expect(request.method, 'POST');
      expect(request.path, kPlatformGatewayPath);
      final body = request.data as Map;
      expect(body['cmd'], 'api.blog.get_blog');
      expect(body['payload'], {'name': 'BLOG-0001'});
      expect((body['payload'] as Map).containsKey('uuid'), isFalse,
          reason: 'Blog has no uuid field; get_blog(name) is the signature');

      expect(result, isA<Success<BlogDetailsResponse>>());
      final details = (result as Success<BlogDetailsResponse>).data;
      expect(details.data?.uuid, 'BLOG-0001',
          reason: 'the docname is mirrored into the uuid slot BlogData reads');
    });
  });

  group('BlogsRepository.getBlogs', () {
    test('lists through the gateway and mirrors each docname into uuid',
        () async {
      http = install((_) => {
            'data': [
              {'name': 'BLOG-0001', 'title': 'One', 'type': 'blog'},
              {'name': 'BLOG-0002', 'title': 'Two', 'type': 'blog'},
            ],
            'status_code': 200,
          });

      final result = await BlogsRepository().getBlogs(1, 'blog');

      final body = http.requests.single.data as Map;
      expect(body['cmd'], 'api.blog.get_blogs');
      expect((body['payload'] as Map)['type'], 'blog');

      expect(result, isA<Success<BlogsPaginateResponse>>());
      final page = (result as Success<BlogsPaginateResponse>).data;
      expect(page.data?.map((b) => b.uuid).toList(),
          ['BLOG-0001', 'BLOG-0002'],
          reason: 'what getBlogDetails is later handed as the docname');
    });
  });

  group('BlogsRepository.withBlogDocnames', () {
    test('mirrors name into uuid for list rows and a single data map', () {
      expect(
        BlogsRepository.withBlogDocnames({
          'data': [
            {'name': 'A'},
            {'name': 'B', 'uuid': 'kept'},
          ],
        }),
        {
          'data': [
            {'name': 'A', 'uuid': 'A'},
            {'name': 'B', 'uuid': 'kept'},
          ],
        },
      );
      expect(
        BlogsRepository.withBlogDocnames({
          'data': {'name': 'A'},
        }),
        {
          'data': {'name': 'A', 'uuid': 'A'},
        },
      );
    });

    test('passes any other shape through untouched', () {
      expect(BlogsRepository.withBlogDocnames(null), isNull);
      expect(BlogsRepository.withBlogDocnames('oops'), 'oops');
      expect(BlogsRepository.withBlogDocnames({'data': 'oops'}),
          {'data': 'oops'});
      expect(BlogsRepository.withBlogDocnames({'message': 'x'}),
          {'message': 'x'});
    });
  });
}
