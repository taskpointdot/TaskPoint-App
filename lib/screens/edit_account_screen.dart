import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_settings_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/buttons.dart';
import '../services/session_controller.dart';

/// Reached from ProfileSettingsScreen's "Edit Account" tile. Lets the user
/// update their display name and email. Phone number is read-only here —
/// it's the Firebase Auth identity itself, so changing it needs a new
/// OTP-verification flow, not a plain field edit.
class EditAccountScreen extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  final String initialEmail;

  const EditAccountScreen({
    super.key,
    required this.initialName,
    required this.initialPhone,
    this.initialEmail = '',
  });

  @override
  State<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() => _saving = true);
    try {
      await SessionController.instance.updateProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: t(context, en: 'Edit Account', ur: 'Account Edit Karain')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Center(
                child: Stack(
                  children: [
                    const CircleAvatar(radius: 48, backgroundColor: AppColors.surfaceContainer, child: Icon(Symbols.person_rounded, size: 48, color: AppColors.onSurfaceVariant)),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Symbols.edit_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(t(context, en: 'Full Name', ur: 'Pura Naam'), style: AppTextStyles.labelLg),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(prefixIcon: const Icon(Symbols.person_rounded)),
                validator: (v) => (v == null || v.trim().isEmpty) ? t(context, en: 'Name is required', ur: 'Naam likhna zaroori hai') : null,
              ),
              const SizedBox(height: 16),
              Text(t(context, en: 'Phone Number', ur: 'Phone Number'), style: AppTextStyles.labelLg),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                enabled: false,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Symbols.call_rounded),
                  helperText: t(context, en: 'Verified with OTP — cannot be changed here', ur: 'OTP se verify hua — yahan tabdeel nahi ho sakta'),
                ),
              ),
              const SizedBox(height: 16),
              Text(t(context, en: 'Email (optional)', ur: 'Email (optional)'), style: AppTextStyles.labelLg),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(prefixIcon: const Icon(Symbols.mail_rounded)),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // optional
                  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
                  return ok ? null : t(context, en: 'Enter a valid email', ur: 'Sahi email likhain');
                },
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: _saving ? t(context, en: 'Saving...', ur: 'Save ho raha hai...') : t(context, en: 'Save Changes', ur: 'Changes Save Karain'),
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
