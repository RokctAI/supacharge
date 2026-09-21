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

// compliance-ignore-file: flutter-http-timeout (test double: Dio uses a scripted in-memory adapter, no real network)

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agent_sdk/agent_sdk.dart';
import 'package:base_sdk/base_sdk.dart'
    show ApiResultPatterns, HttpService, getIt, kPlatformGatewayPath;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// AgentRepository.submitHomework after the fix-wave 2026-09-02 A2 repoint:
/// the never-aliased `agent.api.submit_homework` multipart call is gone;
/// photos go up through core's `api.upload.upload_file` door and only the
/// returned `file_url`s ride the JSON gateway call to
/// `api.lms.submit_homework_question`. Pinned with a scripted Dio adapter
/// (the lms_upload_queue_test seam): request paths, multipart field names,
/// the gateway `cmd` + payload keys, and the id the server answers with.
class _FakeHttpService implements HttpService {
  _FakeHttpService(this.handle);

  final ResponseBody Function(RequestOptions options) handle;

  @override
  Dio client({bool requireAuth = false, bool routing = false}) =>
      Dio(BaseOptions(baseUrl: 'https://unit.test'))
        ..httpClientAdapter = _ScriptedAdapter(handle);
}

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.handle);

  final ResponseBody Function(RequestOptions options) handle;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      handle(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, {int status = 200}) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  late Directory tmp;
  late List<RequestOptions> requests;
  late _FakeHttpService http;
  var uploads = 0;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('agent_repository_test');
    requests = [];
    uploads = 0;
    http = _FakeHttpService((options) {
      requests.add(options);
      if (options.path == AgentRepository.uploadPath) {
        uploads += 1;
        return _json({
          'message': {'file_url': '/private/files/photo-$uploads.jpg'},
        });
      }
      if (options.path == kPlatformGatewayPath) {
        return _json({
          'message': {'id': 'HWQ-0001', 'status': 'submitted'},
        });
      }
      return _json({'exc_type': 'DoesNotExistError'}, status: 404);
    });
    if (getIt.isRegistered<HttpService>()) {
      getIt.unregister<HttpService>();
    }
    getIt.registerSingleton<HttpService>(http);
  });

  tearDown(() {
    if (getIt.isRegistered<HttpService>()) {
      getIt.unregister<HttpService>();
    }
    tmp.deleteSync(recursive: true);
  });

  File photo(String name) => File('${tmp.path}/$name')
    ..writeAsBytesSync(List<int>.filled(16, 0xAB));

  group('AgentRepository.submitHomework', () {
    test('uploads each photo via upload_file, then files the lms question',
        () async {
      final repo = AgentRepository(http.client(requireAuth: true));
      final a = photo('a.jpg');
      final b = photo('b.jpg');

      final result = await repo.submitHomework(
        studentId: 'STU-1',
        lessonId: 'LESSON-7',
        filePaths: [a.path, b.path],
        questionText: 'Why does the discriminant decide the roots?',
      );

      expect(result.when(success: (id) => id, failure: (_, __) => null),
          'HWQ-0001');

      // Two multipart uploads on the direct dotted door, then one gateway
      // call — never a bare `agent.api.submit_homework` path.
      expect(requests.map((r) => r.path), [
        AgentRepository.uploadPath,
        AgentRepository.uploadPath,
        kPlatformGatewayPath,
      ]);
      expect(requests.every((r) => r.method == 'POST'), isTrue);
      expect(AgentRepository.uploadPath,
          '/api/v1/method/rcore.api.upload.upload_file');

      for (final upload in requests.take(2)) {
        final form = upload.data as FormData;
        expect(form.files.map((f) => f.key), ['file']);
        expect(
            form.fields.any((f) => f.key == 'is_private' && f.value == '1'),
            isTrue);
      }

      final call = requests.last.data as Map;
      expect(call['cmd'], 'api.lms.submit_homework_question');
      expect(call['cmd'], AgentRepository.submitCmd);
      expect(call['payload'], {
        'question_text': 'Why does the discriminant decide the roots?',
        'attachments': ['/private/files/photo-1.jpg', '/private/files/photo-2.jpg'],
      });
      // The session is the student: no student_id / lesson_id keys leak
      // into a server signature that does not take them.
      expect(call['payload'], isNot(contains('student_id')));
      expect(call['payload'], isNot(contains('lesson_id')));
    });

    test('a photos-only submission is labelled with the lesson and sends no'
        ' attachments key when there are no files', () async {
      final repo = AgentRepository(http.client(requireAuth: true));

      final result = await repo.submitHomework(
        studentId: 'STU-1',
        lessonId: 'LESSON-7',
        filePaths: const [],
      );

      expect(result.when(success: (id) => id, failure: (_, __) => null),
          'HWQ-0001');
      expect(requests.map((r) => r.path), [kPlatformGatewayPath]);
      final call = requests.single.data as Map;
      expect(call['payload'], {'question_text': 'Homework for lesson LESSON-7'});
    });

    test('resolveQuestionText prefers the student\'s own trimmed words',
        () {
      expect(
        AgentRepository.resolveQuestionText(
            lessonId: 'L1', questionText: '  help with q3  '),
        'help with q3',
      );
      expect(
        AgentRepository.resolveQuestionText(lessonId: 'L1', questionText: '  '),
        'Homework for lesson L1',
      );
      expect(
        AgentRepository.resolveQuestionText(lessonId: 'L1'),
        'Homework for lesson L1',
      );
    });

    test('an upload failure surfaces as a failure and never reaches the'
        ' gateway', () async {
      http = _FakeHttpService((options) {
        requests.add(options);
        return _json({'exc_type': 'ValidationError'}, status: 417);
      });
      getIt.unregister<HttpService>();
      getIt.registerSingleton<HttpService>(http);
      final repo = AgentRepository(http.client(requireAuth: true));

      final result = await repo.submitHomework(
        studentId: 'STU-1',
        lessonId: 'LESSON-7',
        filePaths: [photo('a.jpg').path],
      );

      expect(result.when(success: (_) => false, failure: (_, __) => true),
          isTrue);
      expect(requests.map((r) => r.path), [AgentRepository.uploadPath]);
    });

    test('an unexpected submit response shape is a failure, not a bogus id',
        () async {
      http = _FakeHttpService((options) {
        requests.add(options);
        return _json({'message': 'ok'});
      });
      getIt.unregister<HttpService>();
      getIt.registerSingleton<HttpService>(http);
      final repo = AgentRepository(http.client(requireAuth: true));

      final result = await repo.submitHomework(
        studentId: 'STU-1',
        lessonId: 'LESSON-7',
        filePaths: const [],
      );

      expect(result.when(success: (_) => false, failure: (_, __) => true),
          isTrue);
    });
  });
}
