import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/post_job_sheet.dart';
import '../services/session_controller.dart';
import '../services/jobs_service.dart';
import '../services/geo_utils.dart';
import 'request_success_screen.dart';

const _suggestionChips = ['Plumber', 'Electrician', 'Carpenter', 'Mason', 'Painter'];

/// Maps to: ai_assistant_chat/code.html
/// The Roman-Urdu chat used to describe a job before it's posted. No NLP
/// (out of scope — that needs an OpenAI key this project doesn't have), so
/// this doesn't parse free text into a category/budget: each message the
/// seeker sends is real and persisted to `users/{uid}/aiChatMessages`, and
/// "Post This Job" turns the latest message straight into a real job with
/// [JobsService.postJob].
class AiAssistantChatScreen extends StatefulWidget {
  const AiAssistantChatScreen({super.key});

  @override
  State<AiAssistantChatScreen> createState() => _AiAssistantChatScreenState();
}

class _AiAssistantChatScreenState extends State<AiAssistantChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String? _lastUserMessage;
  bool _posting = false;

  CollectionReference<Map<String, dynamic>>? get _messagesRef {
    final uid = SessionController.instance.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('aiChatMessages');
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? text]) async {
    final value = (text ?? _controller.text).trim();
    final ref = _messagesRef;
    if (value.isEmpty || ref == null) return;
    _controller.clear();
    setState(() => _lastUserMessage = value);
    await ref.add({'fromAi': false, 'text': value, 'createdAt': FieldValue.serverTimestamp()});
    await ref.add({
      'fromAi': true,
      'text': 'Samajh gaya. Jab aap tayyar hon, neeche "Post This Job" dabayein taake yeh kaam nearby workers tak pohnch jaye.',
      'createdAt': FieldValue.serverTimestamp(),
    });
    _scrollToBottom();
  }

  Future<void> _postJob() async {
    final uid = SessionController.instance.uid;
    final description = _lastUserMessage;
    if (uid == null || description == null || _posting) return;
    // Same budget step as the category grid, so a job described in chat
    // reaches workers with a real number attached rather than Rs. 0.
    final details = await showPostJobSheet(
      context,
      categoryName: 'General',
      categoryIcon: Symbols.handyman_rounded,
      initialDescription: description,
    );
    if (details == null || !mounted) return;
    setState(() => _posting = true);
    try {
      final position = await currentDevicePosition();
      final jobId = await JobsService.instance.postJob(
        seekerId: uid,
        categoryName: 'General',
        description: details.description,
        budget: details.budget,
        location: position,
      );
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => RequestSuccessScreen(jobId: jobId)));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _pickSuggestion(String label) => _send(label);

  Future<void> _clearConversation() async {
    final ref = _messagesRef;
    if (ref == null) return;
    final docs = await ref.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in docs.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
    setState(() => _lastUserMessage = null);
  }

  void _openMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(AppRadius.full))),
              ListTile(
                leading: const Icon(Symbols.delete_sweep_rounded),
                title: const Text('Clear conversation'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _clearConversation();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = _messagesRef;
    return Scaffold(
      appBar: AppTopBar(
        title: 'AI Assistant',
        trailing: IconButton(icon: const Icon(Symbols.more_vert_rounded), onPressed: _openMenu),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ref == null
                ? const SizedBox.shrink()
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: ref.orderBy('createdAt').snapshots(),
                    builder: (context, snap) {
                      final docs = snap.data?.docs ?? const [];
                      _scrollToBottom();
                      return ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.lg, AppSpacing.marginMobile, 280),
                        children: [
                          if (docs.isEmpty)
                            _MessageBubble(fromAi: true, text: 'Aap ko kya kaam karwana hai? (What work do you want to get done?)'),
                          for (final d in docs) ...[
                            _MessageBubble(fromAi: d.data()['fromAi'] as bool? ?? false, text: d.data()['text'] as String? ?? ''),
                            const SizedBox(height: AppSpacing.md),
                          ],
                        ],
                      );
                    },
                  ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.lg, AppSpacing.marginMobile, AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.95),
                  border: Border(top: BorderSide(color: AppColors.surfaceVariant)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_lastUserMessage != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _posting ? null : _postJob,
                          icon: const Icon(Symbols.send_rounded, size: 18),
                          label: Text(_posting ? 'Posting...' : 'Post This Job'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
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
                          child: IconButton(icon: const Icon(Symbols.send_rounded, color: Colors.white, size: 20, fill: 1), onPressed: () => _send()),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _suggestionChips.length,
                        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (context, i) => InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          onTap: () => _pickSuggestion(_suggestionChips[i]),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                            decoration: BoxDecoration(color: AppColors.primaryContainer.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.md)),
                            alignment: Alignment.center,
                            child: Text(_suggestionChips[i], style: AppTextStyles.labelLg.copyWith(color: AppColors.primaryContainer)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final bool fromAi;
  final String text;
  const _MessageBubble({required this.fromAi, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: fromAi ? MainAxisAlignment.start : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (fromAi) ...[
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
            child: const Icon(Symbols.smart_toy_rounded, color: AppColors.onPrimaryContainer, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: fromAi ? AppColors.surfaceContainerLow : AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(fromAi ? 4 : 16),
                bottomRight: Radius.circular(fromAi ? 16 : 4),
              ),
            ),
            child: Text(text, style: AppTextStyles.bodyLg.copyWith(color: fromAi ? AppColors.onSurface : Colors.white)),
          ),
        ),
      ],
    );
  }
}
