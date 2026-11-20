# API Reference: assistant_response

Source file: `agent/dart/lib/src/common/infrastructure/models/response/assistant_response.dart`

## Classes

### class `AssistantQuestionResponse`

Wire model for `agent.api.ask_assistant` — pins the backend's
`assistant_rules.success_response` shape:
`{"status": "success", "response": <text>, "intent": "question"}`.

## Whitelisted API Endpoints

### `AssistantQuestionResponse`

```dart
AssistantQuestionResponse({
  required this.status,
  required this.responseText,
  required this.intent,
})
```

*No documentation provided (generation failed).*

### `toJson()`

*No documentation provided (generation failed).*
