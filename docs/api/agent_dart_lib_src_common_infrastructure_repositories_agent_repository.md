# API Reference: agent_repository

Source file: `agent/dart/lib/src/common/infrastructure/repositories/agent_repository.dart`

## Classes

### class `AgentRepository`

## Whitelisted API Endpoints

### `AgentRepository(this._client)`

*No documentation provided (generation failed).*

### `resolveQuestionText({ required String lessonId, String? questionText, })`

The question text the server requires (`homework_rules.
validate_submission` refuses an empty one). [questionText] wins when
the caller has one; otherwise the lesson reference is the question,
so a photos-only submission still names what it is about.

### `submitHomework`

```dart
Future<ApiResult<String>> submitHomework({
  required String studentId,
  required String lessonId,
  required List<String> filePaths,
  String? questionText,
})
```

Two-step submission (the plan's (c)+(a) split): each photo goes up
through core's multipart upload door and only the returned
`file_url`s ride the JSON gateway call. The server binds the question
to `frappe.session.user`, so [studentId] is not sent — the
authenticated session is the student.

### `askAssistant`

```dart
Future<ApiResult<AssistantQuestionResponse>> askAssistant({
  required String studentId,
  required String questionText,
  required String subtopicRef,
  bool inLesson = false,
})
```

*No documentation provided (generation failed).*
