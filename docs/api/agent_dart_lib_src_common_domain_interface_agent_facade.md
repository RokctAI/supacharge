# API Reference: agent_facade

Source file: `agent/dart/lib/src/common/domain/interface/agent_facade.dart`

## Classes

### class `AgentFacade`

## Whitelisted API Endpoints

### `submitHomework`

```dart
Future<ApiResult<String>> submitHomework({
  required String studentId,
  required String lessonId,
  required List<String> filePaths,
  String? questionText,
})
```

Submits homework photos for help: uploads each of [filePaths] through
core's `api.upload.upload_file` door, then files an lms homework
question (`api.lms.submit_homework_question`) carrying the returned
file URLs. Resolves to the new question's id. [questionText] is the
student's own words when they typed any; a photos-only submission is
labelled with [lessonId]. [studentId] is kept for the call shape only
— the server binds the question to the authenticated session.
