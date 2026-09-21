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


import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:agent_sdk/agent_sdk.dart';
// The generated host router (app_router.gr.dart) names this type in the
// AssistantChatRoute args signature.
export 'package:agent_sdk/agent_sdk.dart' show AssistantService;
import 'package:${package}/presentation/theme/theme.dart';

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

  // Set when the assistant backend reports a failure. The banner shows only
  // a friendly, persona-named line in system voice — never a chat bubble
  // from the persona. The server's own reason (e.g. its "assistant not
  // configured" message) is admin detail: it goes to telemetry via
  // AssistantService and is never rendered to students.
  bool _assistantUnavailable = false;

  String get _assistantName => widget.assistantService.displayName;

  String get _unavailableBannerText => _assistantName.trim().isEmpty
      ? "The assistant isn't available right now"
      : "$_assistantName isn't available right now";

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
    widget.assistantService.errors.listen((_) {
      if (mounted) {
        setState(() {
          _assistantUnavailable = true;
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
      _assistantUnavailable = false;
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
          if (_assistantUnavailable)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppStyle.red.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _unavailableBannerText,
                style: AppStyle.interRegular(size: 13, color: AppStyle.red),
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
