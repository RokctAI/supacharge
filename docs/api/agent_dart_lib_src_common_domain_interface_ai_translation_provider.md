# API Reference: ai_translation_provider

Source file: `agent/dart/lib/src/common/domain/interface/ai_translation_provider.dart`

## Classes

### class `AiTranslationProvider`

Consumer-owned slice of the backend settings/translation surface that
agent_sdk's AI-translation feature needs.
The host app implements this with a small adapter wrapping whichever
repository actually serves `/ai-translations` (historically the manager
settings repository) and injects it by overriding
`aiTranslationRepositoryProvider`. See the commented example in
`src/di/agent_di.dart`.

## Whitelisted API Endpoints

### `getAiTranslation({ required AiTranslationRequest model, })`

*No documentation provided (generation failed).*
