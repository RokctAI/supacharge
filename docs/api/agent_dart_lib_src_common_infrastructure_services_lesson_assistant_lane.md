# API Reference: lesson_assistant_lane

Source file: `agent/dart/lib/src/common/infrastructure/services/lesson_assistant_lane.dart`

## Classes

### class `LessonAssistantLane`

The agent side of a lesson's private assistant lane.
A host's lesson assistant bridge (lms_sdk's `LessonAssistantBridge`,
implemented in the host's composed lesson route, ADR-005) wraps this:
agent_sdk never imports lms_sdk, so the lane speaks agent_sdk's own
[ChatMessage] and the host maps it onto the lesson's message type.
Every question goes through [AssistantService.forLesson], so it carries
`in_lesson: true` and the current [subtopicRef] (empty until the lesson
reports one) to `api.ask_assistant` on the platform gateway, and the
transcript is kept under the lesson's session id.

## Whitelisted API Endpoints

### `LessonAssistantLane`

```dart
LessonAssistantLane({
  required this.lessonSessionId,
  required this.serverBaseUrl,
  this.displayName = 'Assistant',
  this.studentId = '',
  String subtopicRef = '',
  AgentFacade? facade,
  AssistantHistoryStore? history,
})
```

*No documentation provided (generation failed).*

### `subtopicRef(String ref)`

Points later questions at [ref]. A blank ref is ignored, so a lesson
event without a ref never clears a known subtopic.

### `ask(String text)`

Asks [text]. Completes when the answer has arrived on [replies], or
the failure on [errors]; never throws for a backend failure.

### `dispose()`

*No documentation provided (generation failed).*
