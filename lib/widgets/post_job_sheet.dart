import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_theme.dart';

/// What the seeker filled in before posting.
class PostJobDetails {
  final double budget;
  final String description;
  const PostJobDetails({required this.budget, required this.description});
}

/// Bottom sheet shown when a seeker taps a service category, collecting the
/// budget and description for the job about to be posted.
///
/// Every posting entry point used to hard-code `budget: 0` and a generated
/// "Need help with plumbing" description, which left the whole negotiation
/// half-dead: the thesis's Hybrid Pricing model has workers either accept
/// the seeker's budget or counter it once, and there was no seeker budget to
/// accept — the worker's job card read "Rs. 0" and its primary button read
/// "Accept Rs. 0".
///
/// Returns null if the seeker backs out, in which case no job is posted.
Future<PostJobDetails?> showPostJobSheet(
  BuildContext context, {
  required String categoryName,
  required IconData categoryIcon,

  /// Pre-fills the description instead of the generated
  /// "Need help with {category}" — used by the AI assistant chat and voice
  /// search, which already have the seeker's own wording for the job.
  String? initialDescription,

  /// Pre-fills the budget, e.g. from an amount heard in a spoken request
  /// ("do hazaar ka kaam hai"). Still editable — a mis-heard number should
  /// be easy to correct, not silently posted.
  double? initialBudget,
}) {
  return showModalBottomSheet<PostJobDetails>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (sheetContext) => _PostJobSheet(
      categoryName: categoryName,
      categoryIcon: categoryIcon,
      initialDescription: initialDescription,
      initialBudget: initialBudget,
    ),
  );
}

class _PostJobSheet extends StatefulWidget {
  final String categoryName;
  final IconData categoryIcon;
  final String? initialDescription;
  final double? initialBudget;
  const _PostJobSheet({
    required this.categoryName,
    required this.categoryIcon,
    this.initialDescription,
    this.initialBudget,
  });

  @override
  State<_PostJobSheet> createState() => _PostJobSheetState();
}

class _PostJobSheetState extends State<_PostJobSheet> {
  late final _descriptionController = TextEditingController(
    text: widget.initialDescription ?? 'Need help with ${widget.categoryName.toLowerCase()}',
  );
  late final _budgetController = TextEditingController(
    text: widget.initialBudget == null ? '' : widget.initialBudget!.toStringAsFixed(0),
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _descriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      PostJobDetails(
        budget: double.parse(_budgetController.text.trim()),
        description: _descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the sheet clear of the keyboard while the budget field is focused.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: AppColors.secondaryContainer, shape: BoxShape.circle),
                      child: Icon(widget.categoryIcon, color: AppColors.onSecondaryContainer, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.categoryName, style: AppTextStyles.headlineMd),
                          Text(
                            'Set your budget — workers can accept it or counter once.',
                            style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _budgetController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Your budget (Rs.)',
                    hintText: 'e.g. 1500',
                    prefixIcon: const Icon(Symbols.payments_rounded, color: AppColors.outline),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    final parsed = double.tryParse((value ?? '').trim());
                    if (parsed == null || parsed <= 0) return 'Enter a budget greater than 0';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'What do you need done?',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Add a short description' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                    ),
                    icon: const Icon(Symbols.campaign_rounded),
                    label: Text('Post Job', style: AppTextStyles.labelLg.copyWith(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
