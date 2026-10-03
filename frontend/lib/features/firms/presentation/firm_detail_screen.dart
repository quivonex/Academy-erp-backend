import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/status_pill.dart';
import '../data/firm_model.dart';
import '../data/firm_repository.dart';
import 'firm_admins_section.dart';
import 'firms_list_screen.dart' show FirmStatusPanel;

class FirmDetailScreen extends ConsumerWidget {
  const FirmDetailScreen({super.key, required this.firmUuid});

  final String firmUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firmAsync = ref.watch(firmDetailProvider(firmUuid));
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return firmAsync.when(
      data: (firm) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Breadcrumb
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => context.go('/firms'),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Text(
                      'Firms',
                      style: textTheme.labelLarge?.copyWith(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 18, color: colors.textSubtle),
                ),
                Flexible(
                  child: Text(
                    firm.name,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Header(
              firm: firm,
              onEdit: () => _showEditDialog(context, ref, firm),
              onToggleActive: () => _toggleActive(context, ref, firm),
            ),
            const SizedBox(height: 20),
            _InfoGrid(firm: firm),
            if (firm.address != null && firm.address!.isNotEmpty) ...[
              const SizedBox(height: 16),
              AdminCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const AdminIconTile(
                      icon: Icons.location_on_outlined,
                      size: 40,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Registered address',
                              style: _tileLabel(context)),
                          const SizedBox(height: 4),
                          SelectableText(
                            firm.address!,
                            style: textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),

            // ─── Firm admins section (GET/POST /firms/{uuid}/admins/) ───
            FirmAdminsSection(firmUuid: firm.uuid, firmName: firm.name),
            const SizedBox(height: 24),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => SingleChildScrollView(
        child: AdminStateMessage(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load firm',
          message: '$error',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(firmDetailProvider(firmUuid)),
          isError: true,
        ),
      ),
    );
  }

  Future<void> _showEditDialog(
      BuildContext context,
      WidgetRef ref,
      Firm firm,
      ) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => _EditFirmDialog(firm: firm),
    );
    if (updated == true) {
      ref.invalidate(firmDetailProvider(firmUuid));
      ref.invalidate(firmsListProvider);
    }
  }

  Future<void> _toggleActive(
      BuildContext context,
      WidgetRef ref,
      Firm firm,
      ) async {
    final repo = ref.read(firmRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final FirmStatusResponse result;
      if (firm.isActive) {
        result = await repo.deactivate(firm.uuid);
      } else {
        result = await repo.activate(firm.uuid);
      }

      messenger.showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      ref.invalidate(firmDetailProvider(firmUuid));
      ref.invalidate(firmsListProvider);
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: context.colors.danger,
        ),
      );
    }
  }
}

TextStyle? _tileLabel(BuildContext context) =>
    Theme.of(context).textTheme.labelMedium?.copyWith(
          color: const Color(0xFF64748B),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        );

class _Header extends StatelessWidget {
  const _Header({
    required this.firm,
    required this.onEdit,
    required this.onToggleActive,
  });

  final Firm firm;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final compact = MediaQuery.sizeOf(context).width < 760;

    final identity = Row(
      children: [
        GradientAvatar(
          label: firm.name.isNotEmpty ? firm.name[0].toUpperCase() : '?',
          seed: firm.code,
          size: 64,
          statusDot: firm.isActive
              ? const Color(0xFF10B981)
              : const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    firm.name,
                    style: jakarta(
                      textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  StatusPill(
                    label: firm.status.toUpperCase(),
                    tone: toneForStatus(firm.status),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SoftBadge(
                    label: firm.code,
                    monospace: true,
                    background: const Color(0xFFF1F5F9),
                    foreground: const Color(0xFF334155),
                  ),
                  Text(
                    '•  Educational institution',
                    style: textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF475569),
                    ),
                  ),
                  if (firm.address?.trim().isNotEmpty == true)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Text(
                        '•  ${firm.address!.trim()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        AdminOutlineButton(
          label: 'Edit firm',
          icon: Icons.edit_outlined,
          onPressed: onEdit,
        ),
        firm.isActive
            ? AdminOutlineButton(
                label: 'Deactivate',
                icon: Icons.block_rounded,
                danger: true,
                onPressed: onToggleActive,
              )
            : GradientButton(
                label: 'Activate',
                icon: Icons.check_circle_outline_rounded,
                onPressed: onToggleActive,
              ),
      ],
    );

    return AdminCard(
      gradientWash: true,
      padding: const EdgeInsets.all(24),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [identity, const SizedBox(height: 18), actions],
            )
          : Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 16),
                actions,
              ],
            ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.firm});

  final Firm firm;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final valueStyle = textTheme.titleSmall?.copyWith(
      color: const Color(0xFF0F172A),
      fontWeight: FontWeight.w600,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        const gap = 16.0;
        final unit = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final wide = columns >= 2 ? unit * 2 + gap : unit;

        Widget tile({
          required String label,
          required Widget child,
          Widget? trailing,
          double? width,
        }) {
          return SizedBox(
            width: width ?? unit,
            child: AdminCard(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 58,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(label, style: _tileLabel(context)),
                        ),
                        if (trailing != null) trailing,
                      ],
                    ),
                    child,
                  ],
                ),
              ),
            ),
          );
        }

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            tile(
              label: 'Firm code',
              child: Align(
                alignment: Alignment.centerLeft,
                child: SoftBadge(
                  label: firm.code,
                  monospace: true,
                  background: const Color(0xFFF1F5F9),
                  foreground: const Color(0xFF0F172A),
                ),
              ),
            ),
            tile(
              label: 'Official email',
              child: SelectableText(
                firm.email?.isNotEmpty == true ? firm.email! : '—',
                maxLines: 1,
                style: valueStyle?.copyWith(
                  color: firm.email?.isNotEmpty == true
                      ? colors.primary
                      : colors.textSubtle,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            tile(
              label: 'Contact phone',
              child: SelectableText(
                firm.phone?.isNotEmpty == true ? firm.phone! : '—',
                maxLines: 1,
                style: valueStyle,
              ),
            ),
            tile(
              label: 'Firm status',
              trailing: Text(
                'Active: ${firm.isActive ? 'Yes' : 'No'}',
                style: textTheme.labelSmall?.copyWith(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusPill(
                  label: firm.status.toUpperCase(),
                  tone: toneForStatus(firm.status),
                  compact: true,
                ),
              ),
            ),
            tile(
              label: 'System UUID',
              width: wide,
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      firm.uuid,
                      maxLines: 1,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy UUID',
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: firm.uuid));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('UUID copied')),
                        );
                      }
                    },
                    icon: Icon(Icons.copy_rounded,
                        size: 18, color: colors.textMuted),
                  ),
                ],
              ),
            ),
            tile(
              label: 'Created date',
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 16, color: colors.textMuted),
                  const SizedBox(width: 8),
                  Text(formatDate(firm.createdAt), style: valueStyle),
                ],
              ),
            ),
            tile(
              label: 'Last updated',
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 16, color: colors.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    firm.updatedAt != null
                        ? formatDate(firm.updatedAt!)
                        : '—',
                    style: valueStyle,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// ---------------------------------------------
/// Edit Firm Dialog  →  PATCH /firms/{uuid}/
/// ---------------------------------------------
class _EditFirmDialog extends ConsumerStatefulWidget {
  const _EditFirmDialog({required this.firm});
  final Firm firm;

  @override
  ConsumerState<_EditFirmDialog> createState() => _EditFirmDialogState();
}

class _EditFirmDialogState extends ConsumerState<_EditFirmDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  late String _status;
  late bool _isActive;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final f = widget.firm;
    _nameController = TextEditingController(text: f.name);
    _codeController = TextEditingController(text: f.code);
    _emailController = TextEditingController(text: f.email ?? '');
    _phoneController = TextEditingController(text: f.phone ?? '');
    _addressController = TextEditingController(text: f.address ?? '');
    _status = f.status;
    _isActive = f.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormDialog(
      icon: Icons.edit_note_rounded,
      title: 'Edit firm',
      subtitle: 'Update institution details for ${widget.firm.name}.',
      onClose:
          _isSubmitting ? null : () => Navigator.of(context).pop(false),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormRow(
              left: FieldLabel(
                label: 'Firm name',
                required: true,
                child: TextFormField(
                  controller: _nameController,
                  decoration: adminFieldDecoration(
                    context,
                    icon: Icons.school_outlined,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              right: FieldLabel(
                label: 'Firm code',
                required: true,
                child: TextFormField(
                  controller: _codeController,
                  decoration: adminFieldDecoration(
                    context,
                    icon: Icons.tag_rounded,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FormRow(
              left: FieldLabel(
                label: 'Email',
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: adminFieldDecoration(
                    context,
                    icon: Icons.mail_outline_rounded,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
              ),
              right: FieldLabel(
                label: 'Contact phone',
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: adminFieldDecoration(
                    context,
                    icon: Icons.call_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: 'Campus address',
              child: TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: adminFieldDecoration(
                  context,
                  icon: Icons.location_on_outlined,
                ),
              ),
            ),
            const SizedBox(height: 18),
            FirmStatusPanel(
              status: _status,
              isActive: _isActive,
              onStatusChanged: (v) => setState(() => _status = v ?? 'ACTIVE'),
              onActiveChanged: (v) => setState(() => _isActive = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              AdminErrorBanner(message: _error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF334155),
            minimumSize: const Size(0, 44),
          ),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: 'Save changes',
          icon: Icons.check_rounded,
          loading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref.read(firmRepositoryProvider).update(
        widget.firm.uuid,
        FirmUpdateRequest(
          name: _nameController.text.trim(),
          code: _codeController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          status: _status,
          isActive: _isActive,
        ),
      );

      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}