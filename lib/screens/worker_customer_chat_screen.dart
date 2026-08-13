import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../services/chat_service.dart';
import '../services/session_controller.dart';
import '../services/dialer.dart';

/// Maps to: worker_customer_chat/code.html
/// Real-time chat tied to a specific job (`jobs/{jobId}/messages`), used by
/// both the worker and the seeker side of that job.
class WorkerCustomerChatScreen extends StatefulWidget {
  final String jobId;
  final String contactName;
  final String? contactPhone;
  const WorkerCustomerChatScreen({super.key, required this.jobId, this.contactName = 'Contact', this.contactPhone});

  @override
  State<WorkerCustomerChatScreen> createState() => _WorkerCustomerChatScreenState();
}

class _WorkerCustomerChatScreenState extends State<WorkerCustomerChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final uid = SessionController.instance.uid;
    if (text.isEmpty || uid == null) return;
    _controller.clear();
    await ChatService.instance.send(jobId: widget.jobId, senderId: uid, text: text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final me = SessionController.instance.uid;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contactName),
        actions: [
          if (widget.contactPhone?.isNotEmpty ?? false)
            IconButton(icon: const Icon(Symbols.call_rounded), onPressed: () => callPhone(widget.contactPhone!), color: AppColors.primary),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: ChatService.instance.watchMessages(widget.jobId),
                builder: (context, snap) {
                  final messages = snap.data ?? const [];
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  if (messages.isEmpty) {
                    return Center(child: Text('Say hello to get started', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)));
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  });
                  return ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      final outgoing = m.senderId == me;
                      return Column(
                        crossAxisAlignment: outgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: outgoing ? AppColors.primary : AppColors.surfaceContainerHighest,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft: Radius.circular(outgoing ? 20 : 4),
                                bottomRight: Radius.circular(outgoing ? 4 : 20),
                              ),
                            ),
                            child: Text(m.text, style: AppTextStyles.bodyMd.copyWith(color: outgoing ? Colors.white : AppColors.onSurface)),
                          ),
                          const SizedBox(height: 4),
                          if (m.createdAt != null)
                            Text('${m.createdAt!.hour.toString().padLeft(2, '0')}:${m.createdAt!.minute.toString().padLeft(2, '0')}', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.9), border: Border(top: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3)))),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        filled: true,
                        fillColor: AppColors.surfaceContainerLowest,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary,
                    child: IconButton(icon: const Icon(Symbols.send_rounded, color: Colors.white, size: 20, fill: 1), onPressed: _send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
