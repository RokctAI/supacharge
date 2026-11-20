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

### `askAssistant`

```dart
Future<ApiResult<AssistantQuestionResponse>> askAssistant({
  required String studentId,
  required String questionText,
  required String subtopicRef,
  bool inLesson = false,
})
```

Asks the real backend assistant (`agent.api.ask_assistant`) a question.
The server answers with an LLM response or fails with its own error
(e.g. "Assistant Not Configured") — there is no client-side fallback
answer.
[inLesson] is sent explicitly on every call (`in_lesson`): true when
the question is asked from inside a lesson, where the server's plan
gate fails closed. It does not depend on [subtopicRef], which is empty
before a lesson's first subtopic.
