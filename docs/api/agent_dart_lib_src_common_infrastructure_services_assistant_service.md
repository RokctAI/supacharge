# API Reference: assistant_service

Source file: `agent/dart/lib/src/common/infrastructure/services/assistant_service.dart`

## Classes

### class `ChatMessage`

### class `AssistantChatError`

An assistant failure surfaced to the UI as an error — never disguised as
a chat answer. [message] carries the server's own reason (e.g. the
backend's "Assistant Not Configured" text) when one arrived — that detail
is for diagnostics/telemetry only: student-facing surfaces must not
render it (admin conditions like a missing key are not for students).

### class `AssistantService`

Chat pipeline for the AI assistant.
Every question is answered by the real backend
(`agent.api.ask_assistant`, via [AgentFacade.askAssistant]) — the server
owns the LLM call and its credential config. There is no client-side
canned-answer path: when the backend fails (including the server's
honest "Assistant Not Configured" error), the failure is emitted on
[errors] for the host UI to render as an error, and nothing is injected
into the chat stream.
The assistant's display name is configurable per host app (each product
brands its own persona) — pass it via [displayName]; it is used as the
`sender` on generated responses.

## Whitelisted API Endpoints

### `ChatMessage`

```dart
ChatMessage({
  required this.id,
  required this.text,
  required this.sender,
  required this.timestamp,
})
```

*No documentation provided (generation failed).*

### `AssistantChatError({required this.message, this.statusCode})`

*No documentation provided (generation failed).*

### `AssistantService`

```dart
AssistantService({
  required this.incomingChat,
  required this.outgoingChat,
  required this.serverBaseUrl,
  this.displayName = 'Assistant',
  this.subtopicRef = '',
  this.studentId = '',
  this.inLesson = false,
  this.historySession = kAssistantChatHistorySession,
  AgentFacade? facade,
  AssistantHistoryStore? history,
})
```

*No documentation provided (generation failed).*

### `AssistantService`

```dart
AssistantService(
  incomingChat: incomingChat,
  outgoingChat: outgoingChat,
  serverBaseUrl: serverBaseUrl,
  displayName: displayName,
  subtopicRef: subtopicRef,
  studentId: studentId,
  inLesson: true,
  historySession: lessonSessionId,
  facade: facade,
  history: history
)
```

*No documentation provided (generation failed).*

### `loadHistory()`

The signed-in account's saved conversation, oldest first, for the
host to show when the assistant opens. Empty when there is none, no
history store, or it cannot be read - never an error, online or
offline. Another account's messages are never returned.

### `processIncomingMessage(ChatMessage message)`

Sends an incoming student message to the real assistant backend and
injects the server's answer into [outgoingChat]. On failure the
server's error is emitted on [errors] — never a fabricated answer.

### `dispose()`

Stops listening and closes what this service owns ([errors]). The
chat controllers belong to whoever passed them in (the host's comms
transport), so they are NOT closed here: closing them broke every
other listener and any later service bound to the same controllers.
