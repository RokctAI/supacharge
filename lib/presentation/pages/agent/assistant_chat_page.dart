// ==========================================
// [GENERATED TEMPLATE FILE]
// This file was installed from: agent_sdk
// Feel free to modify and customize this code.
// Note: If you edit this file, the SDK installer will detect your changes
// and automatically skip overwriting it during future upgrades.
// ==========================================

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:agent_sdk/agent_sdk.dart';
// The generated host router (app_router.gr.dart) names this type in the
// AssistantChatRoute args signature.
export 'package:agent_sdk/agent_sdk.dart' show AssistantService;
import 'package:supacharge/core/presentation/theme/theme.dart';

@RoutePage(name: 'AssistantChatRoute')
class AssistantChatPage extends StatefulWidget {
  final AssistantService assistantService;

  const AssistantChatPage({
    super.key,
    required this.assistantService,
  });

  @override
  State<AssistantChatPage> createState() => _AssistantChatPageState();
}

class _AssistantChatPageState extends State<AssistantChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];

  String get _assistantName => widget.assistantService.displayName;

  @override
  void initState() {
    super.initState();
    widget.assistantService.outgoingChat.stream.listen((message) {
      if (mounted) {
        setState(() {
          _messages.add(message);
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_controller.text.isEmpty) return;

    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: _controller.text,
      sender: 'Student',
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(msg);
    });

    widget.assistantService.incomingChat.add(msg);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.mainBack,
      appBar: AppBar(
        backgroundColor: AppStyle.mainBack,
        title: Text(
          'Chat with $_assistantName',
          style: AppStyle.interNormal(size: 16),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isAssistant = msg.sender == _assistantName;
                return Align(
                  alignment: isAssistant
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isAssistant
                          ? AppStyle.primary.withOpacity(0.15)
                          : AppStyle.subCategory,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${msg.sender}: ${msg.text}',
                      style: AppStyle.interRegular(size: 14),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: AppStyle.interRegular(size: 14),
                    decoration: InputDecoration(
                      hintText: 'Ask $_assistantName...',
                      hintStyle: AppStyle.interRegular(
                        size: 14,
                        color: AppStyle.textHint,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: AppStyle.icons,
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
