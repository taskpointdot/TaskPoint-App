import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../models/emergency_contact.dart';
import '../services/emergency_service.dart';
import '../services/session_controller.dart';
import '../services/dialer.dart';
import 'no_emergency_contacts_screen.dart';

/// Maps to: emergency_contacts_management/code.html
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  bool _showAddForm = false;
  bool _saving = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveContact() async {
    final uid = SessionController.instance.uid;
    if (uid == null || _nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await EmergencyService.instance.addContact(uid: uid, name: _nameController.text.trim(), phone: _phoneController.text.trim());
      _nameController.clear();
      _phoneController.clear();
      if (mounted) setState(() => _showAddForm = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeContact(EmergencyContact c) async {
    final uid = SessionController.instance.uid;
    if (uid == null) return;
    await EmergencyService.instance.deleteContact(uid: uid, contactId: c.id);
  }

  @override
  Widget build(BuildContext context) {
    final uid = SessionController.instance.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<EmergencyContact>>(
      stream: EmergencyService.instance.watchContacts(uid),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final contacts = snap.data!;
        // Mirrors the real "empty state" this screen represents: once every
        // contact is removed, show the dedicated no-contacts screen instead
        // of an empty list.
        if (contacts.isEmpty && !_showAddForm) {
          return const NoEmergencyContactsScreen();
        }

        return Scaffold(
          appBar: const AppTopBar(title: 'Emergency Contacts'),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.sm, AppSpacing.marginMobile, AppSpacing.lg),
              children: [
                for (final c in contacts) ...[
                  _ContactCard(contact: c, onDelete: () => _removeContact(c)),
                  const SizedBox(height: AppSpacing.md),
                ],
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _showAddForm = !_showAddForm),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    icon: const Icon(Symbols.add_rounded),
                    label: Text('Naya Contact Shamil Karain', style: AppTextStyles.labelLg.copyWith(color: Colors.white)),
                  ),
                ),
                if (_showAddForm) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add New Contact', style: AppTextStyles.headlineMd),
                        const SizedBox(height: AppSpacing.md),
                        Text('Full Name', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(prefixIcon: Icon(Symbols.badge_rounded), hintText: 'e.g. Bhai'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text('Phone Number', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(prefixIcon: Icon(Symbols.phone_iphone_rounded), hintText: '+92 300 0000000'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () => setState(() => _showAddForm = false),
                                  child: const Text('Cancel'),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _saving ? null : _saveContact,
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                  child: Text(_saving ? 'Saving...' : 'Save Contact', style: AppTextStyles.labelLg.copyWith(color: Colors.white)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ContactCard extends StatelessWidget {
  final EmergencyContact contact;
  final VoidCallback onDelete;
  const _ContactCard({required this.contact, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.soft,
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.secondaryContainer.withOpacity(0.5), shape: BoxShape.circle),
            child: const Icon(Symbols.person_rounded, color: AppColors.secondary, fill: 1),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name, style: AppTextStyles.labelLg),
                const SizedBox(height: 2),
                Text(contact.phone, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Symbols.call_rounded, color: AppColors.primary, fill: 1, size: 20),
              onPressed: () => callPhone(contact.phone),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Symbols.delete_outline_rounded, color: AppColors.error, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
