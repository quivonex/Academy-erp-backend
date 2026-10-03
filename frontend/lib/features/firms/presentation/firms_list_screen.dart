import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/status_pill.dart';

import '../data/firm_model.dart';
import '../data/firm_repository.dart';

class FirmsListScreen extends ConsumerStatefulWidget {
  const FirmsListScreen({super.key});

  @override
  ConsumerState<FirmsListScreen> createState() =>
      _FirmsListScreenState();
}

class _FirmsListScreenState
    extends ConsumerState<FirmsListScreen> {
  final _searchController = TextEditingController();

  String _search = '';
  String _status = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(firmsListProvider);

    try {
      await ref.read(firmsListProvider.future);
    } catch (_) {
      // The provider displays the error with a retry action.
    }
  }

  void _openRegisterDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _RegisterFirmDialog(),
    );
  }

  bool _matches(Firm firm) {
    final query = _search.trim().toLowerCase();

    final matchesSearch = query.isEmpty ||
        [
          firm.name,
          firm.code,
          firm.email ?? '',
          firm.phone ?? '',
        ].any(
              (value) => value.toLowerCase().contains(query),
        );

    final matchesStatus = _status == 'ALL' ||
        firm.status.toUpperCase() == _status;

    return matchesSearch && matchesStatus;
  }

  @override
  Widget build(BuildContext context) {
    final firmsAsync = ref.watch(firmsListProvider);
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final all = firmsAsync.valueOrNull;

    int countFor(String status) {
      if (all == null) return 0;

      if (status == 'ALL') {
        return all.length;
      }

      return all
          .where(
            (firm) => firm.status.toUpperCase() == status,
      )
          .length;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          title: 'Firm Management Directory',
          subtitle:
          'Manage educational institutes, portal access and '
              'academy credentials.',
          titleTrailing: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _refresh,
              icon: Icon(
                Icons.sync_rounded,
                color: colors.textMuted,
              ),
            ),
            if (all != null)
              SoftBadge(
                label: all.length == 1
                    ? '1 academy registered'
                    : '${all.length} academies registered',
                dot: true,
                background: const Color(0xFFF1F5F9),
                foreground: const Color(0xFF334155),
              ),
          ],
          actions: [
            GradientButton(
              label: 'Register new firm',
              icon: Icons.add_rounded,
              onPressed: _openRegisterDialog,
            ),
          ],
        ),
        const SizedBox(height: 22),
        AdminSearchField(
          controller: _searchController,
          hint: 'Search by firm name, code, email or phone…',
          onChanged: (value) {
            setState(() => _search = value);
          },
          onClear: () {
            _searchController.clear();
            setState(() => _search = '');
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in [
                    'ALL',
                    'ACTIVE',
                    'INACTIVE',
                    'SUSPENDED',
                  ])
                    CountFilterPill(
                      label: status,
                      count: all == null
                          ? null
                          : countFor(status),
                      selected: _status == status,
                      onTap: () {
                        setState(() => _status = status);
                      },
                    ),
                ],
              ),
            ),
            if (all != null &&
                MediaQuery.sizeOf(context).width >= 700)
              Text(
                'Showing ${all.where(_matches).length} '
                    'of ${all.length} firms',
                style: textTheme.bodySmall,
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: firmsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => SingleChildScrollView(
              child: AdminStateMessage(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load firms',
                message: '$error',
                actionLabel: 'Retry',
                onAction: _refresh,
                isError: true,
              ),
            ),
            data: (firms) {
              final filtered = firms
                  .where(_matches)
                  .toList();

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  physics:
                  const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: filtered.isEmpty
                      ? 1
                      : filtered.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (filtered.isEmpty) {
                      return AdminStateMessage(
                        icon: firms.isEmpty
                            ? Icons.apartment_rounded
                            : Icons.search_off_rounded,
                        title: firms.isEmpty
                            ? 'No firms registered yet'
                            : 'No matching firms',
                        message: firms.isEmpty
                            ? 'Register your first academy '
                            'to get started.'
                            : 'No firms match your search '
                            'or filter.',
                      );
                    }

                    final firm = filtered[index];

                    return _FirmCard(
                      firm: firm,
                      onTap: () async {
                        await context.push(
                          '/firms/${firm.uuid}',
                        );

                        if (mounted) {
                          await _refresh();
                        }
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FirmCard extends StatelessWidget {
  const _FirmCard({
    required this.firm,
    required this.onTap,
  });

  final Firm firm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final metaStyle = textTheme.bodySmall?.copyWith(
      color: const Color(0xFF475569),
    );

    Widget meta(IconData icon, String text) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: colors.textSubtle,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: metaStyle,
            ),
          ),
        ],
      );
    }

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      onTap: onTap,
      child: Row(
        children: [
          GradientAvatar(
            label: adminInitials(firm.name),
            seed: firm.code,
            size: 48,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment:
                  WrapCrossAlignment.center,
                  children: [
                    Text(
                      firm.name,
                      style: jakarta(
                        textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    StatusPill(
                      label: firm.status.toUpperCase(),
                      tone: toneForStatus(firm.status),
                    ),
                    if (firm.isActive)
                      Icon(
                        Icons.verified_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
                    SoftBadge(
                      label: 'Code: ${firm.code}',
                      monospace: true,
                      background: const Color(0xFFF1F5F9),
                      foreground: const Color(0xFF334155),
                    ),
                    Text(
                      firm.isActive
                          ? '•  Enabled'
                          : '•  Disabled',
                      style: textTheme.labelMedium?.copyWith(
                        color: firm.isActive
                            ? const Color(0xFF475569)
                            : colors.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 18,
                  runSpacing: 6,
                  children: [
                    if (firm.email?.isNotEmpty == true)
                      meta(
                        Icons.mail_outline_rounded,
                        firm.email!,
                      ),
                    if (firm.phone?.isNotEmpty == true)
                      meta(
                        Icons.call_outlined,
                        firm.phone!,
                      ),
                    meta(
                      Icons.calendar_today_outlined,
                      'Created: ${formatDate(firm.createdAt)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            color: colors.textSubtle,
          ),
        ],
      ),
    );
  }
}

class _RegisterFirmDialog extends ConsumerStatefulWidget {
  const _RegisterFirmDialog();

  @override
  ConsumerState<_RegisterFirmDialog> createState() =>
      _RegisterFirmDialogState();
}

class _RegisterFirmDialogState
    extends ConsumerState<_RegisterFirmDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  String _status = 'ACTIVE';
  bool _isActive = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting ||
        !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref.read(firmRepositoryProvider).create(
        FirmCreateRequest(
          name: _nameController.text.trim(),
          code: _codeController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          address:
          _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          status: _status,
          isActive: _isActive,
        ),
      );

      if (!mounted) return;

      ref.invalidate(firmsListProvider);
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
          'Could not register firm. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: !_isSubmitting,
      child: AdminFormDialog(
        icon: Icons.domain_add_rounded,
        title: 'Register new firm',
        subtitle:
        'Enter institution details to provision '
            'a new tenant portal.',
        onClose: _isSubmitting
            ? null
            : () => Navigator.of(context).pop(),
        body: IgnorePointer(
          ignoring: _isSubmitting,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                FormRow(
                  left: FieldLabel(
                    label: 'Firm name',
                    required: true,
                    child: TextFormField(
                      controller: _nameController,
                      decoration: adminFieldDecoration(
                        context,
                        hint: 'e.g. Oxford STEM Academy',
                        icon: Icons.school_outlined,
                      ),
                      validator: (value) {
                        return value == null ||
                            value.trim().isEmpty
                            ? 'Required'
                            : null;
                      },
                    ),
                  ),
                  right: FieldLabel(
                    label: 'Firm code',
                    required: true,
                    child: TextFormField(
                      controller: _codeController,
                      textCapitalization:
                      TextCapitalization.characters,
                      decoration: adminFieldDecoration(
                        context,
                        hint: 'e.g. ABC003',
                        icon: Icons.tag_rounded,
                      ),
                      validator: (value) {
                        return value == null ||
                            value.trim().isEmpty
                            ? 'Required'
                            : null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FormRow(
                  left: FieldLabel(
                    label: 'Email',
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType:
                      TextInputType.emailAddress,
                      decoration: adminFieldDecoration(
                        context,
                        hint: 'admin@academy.edu',
                        icon: Icons.mail_outline_rounded,
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return null;
                        }

                        if (!value.contains('@')) {
                          return 'Enter a valid email';
                        }

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
                        hint: '+91 98765 43210',
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
                      hint: 'Street, city, state',
                      icon: Icons.location_on_outlined,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FirmStatusPanel(
                  status: _status,
                  isActive: _isActive,
                  onStatusChanged: (value) {
                    setState(() {
                      _status = value ?? 'ACTIVE';
                    });
                  },
                  onActiveChanged: (value) {
                    setState(() => _isActive = value);
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  AdminErrorBanner(message: _error!),
                ],
                const SizedBox(height: 8),
                Text(
                  'Fields marked * are required.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSubtle,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting
                ? null
                : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Cancel'),
          ),
          GradientButton(
            label: 'Register firm',
            icon: Icons.add_rounded,
            loading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

// Shared by Register Firm and Edit Firm dialogs.
class FirmStatusPanel extends StatelessWidget {
  const FirmStatusPanel({
    required this.status,
    required this.isActive,
    required this.onStatusChanged,
    required this.onActiveChanged,
  });

  final String status;
  final bool isActive;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Firm status',
                  style: textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  initialValue: status,
                  isDense: true,
                  decoration:
                  adminFieldDecoration(context).copyWith(
                    fillColor: Colors.white,
                    contentPadding:
                    const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'ACTIVE',
                      child: Text('ACTIVE'),
                    ),
                    DropdownMenuItem(
                      value: 'INACTIVE',
                      child: Text('INACTIVE'),
                    ),
                    DropdownMenuItem(
                      value: 'SUSPENDED',
                      child: Text('SUSPENDED'),
                    ),
                  ],
                  onChanged: onStatusChanged,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              height: 1,
              color: Color(0xFFE2E8F0),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portal access enabled',
                      style: textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Sets the firm\'s active flag '
                          '(Is Active).',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                onChanged: onActiveChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}