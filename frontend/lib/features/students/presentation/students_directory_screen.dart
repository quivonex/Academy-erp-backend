import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../data/student.dart';
import '../data/student_repository.dart';

class StudentsDirectoryScreen extends ConsumerStatefulWidget {
  const StudentsDirectoryScreen({super.key});

  @override
  ConsumerState<StudentsDirectoryScreen> createState() =>
      _StudentsDirectoryScreenState();
}

class _StudentsDirectoryScreenState
    extends ConsumerState<StudentsDirectoryScreen> {
  final searchController = TextEditingController();
  late Future<StudentPage> result;
  String search = '';
  String statusFilter = 'ALL'; // ALL | ACTIVE | INACTIVE
  int page = 1;
  bool creating = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result = ref
        .read(studentRepositoryProvider)
        .list(search: search, page: page);
  }

  void goToPage(int next) {
    setState(() {
      page = next;
      reload();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreate() async {
    if (creating) return;
    final repository = ref.read(studentRepositoryProvider);
    setState(() => creating = true);
    try {
      final created = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CreateStudentDialog(repository),
      );
      if (!mounted || created != true) return;
      setState(() {
        searchController.clear();
        search = '';
        statusFilter = 'ALL';
        page = 1;
        reload();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student created successfully.')),
      );
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  void applySearch() {
    setState(() {
      search = searchController.text.trim();
      page = 1;
      reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top header matching screenshot ("Students" + refresh + "Add Student")
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Text(
                  'Students',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => setState(reload),
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: Color(0xFF334155),
                  ),
                  tooltip: 'Refresh',
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: creating ? null : _openCreate,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Add Student'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3730A3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<StudentPage>(
              future: result,
              builder: (context, snapshot) {
                final state = adminFutureState(
                  snapshot,
                  noun: 'students',
                  onRetry: () => setState(reload),
                );
                final data = snapshot.connectionState == ConnectionState.done &&
                    !snapshot.hasError
                    ? snapshot.data
                    : null;
                final onPage = data?.results ?? const <Student>[];
                final activeHere = onPage.where((s) => s.isActive).length;
                final inactiveHere = onPage.length - activeHere;
                final totalPages = data == null || data.count == 0
                    ? 1
                    : ((data.count - 1) ~/ 20) + 1;

                final visibleStudents = switch (statusFilter) {
                  'ACTIVE' => onPage.where((s) => s.isActive).toList(),
                  'INACTIVE' => onPage.where((s) => !s.isActive).toList(),
                  _ => onPage,
                };

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  children: [
                    // 2x2 / Responsive KPI grid matching screenshot
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final columns = width < 600
                            ? 2
                            : width < 1000
                            ? 2
                            : 4;
                        const gap = 12.0;
                        final cardWidth =
                            (width - gap * (columns - 1)) / columns;

                        final pct = data == null || onPage.isEmpty
                            ? null
                            : '${(activeHere * 100 / onPage.length).round()}%';

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _StudentStatCard(
                                label: search.isEmpty
                                    ? 'Total students'
                                    : 'Matching',
                                value: data == null ? '…' : '${data.count}',
                                caption: search.isEmpty
                                    ? 'All registered'
                                    : 'Current search',
                                icon: Icons.groups_rounded,
                                iconColor: const Color(0xFF4F46E5),
                                iconBg: const Color(0xFFEEF2FF),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _StudentStatCard(
                                label: 'Active on page',
                                value: data == null ? '…' : '$activeHere',
                                badgeText: pct,
                                caption: 'Fully enrolled',
                                captionColor: const Color(0xFF059669),
                                icon: Icons.verified_rounded,
                                iconColor: const Color(0xFF059669),
                                iconBg: const Color(0xFFECFDF5),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _StudentStatCard(
                                label: 'Inactive',
                                value: data == null ? '…' : '$inactiveHere',
                                caption: 'Needs review',
                                icon: Icons.person_off_outlined,
                                iconColor: const Color(0xFFE11D48),
                                iconBg: const Color(0xFFFFF1F2),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _StudentStatCard(
                                label: 'Current page',
                                value: '$page',
                                valueSuffix: '/ $totalPages',
                                caption: '20 per page',
                                icon: Icons.layers_outlined,
                                iconColor: const Color(0xFF0284C7),
                                iconBg: const Color(0xFFF0F9FF),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Search bar with prominent blue "Search" button
                    _SearchBarCard(
                      controller: searchController,
                      onSearch: applySearch,
                      onClear: search.isEmpty && searchController.text.isEmpty
                          ? null
                          : () {
                        searchController.clear();
                        applySearch();
                      },
                    ),
                    const SizedBox(height: 14),

                    // Filter pill strip ("All", "Active", "Inactive")
                    if (data != null) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterPill(
                              label: 'All (${onPage.length})',
                              selected: statusFilter == 'ALL',
                              onTap: () => setState(() => statusFilter = 'ALL'),
                            ),
                            const SizedBox(width: 8),
                            _FilterPill(
                              label: 'Active ($activeHere)',
                              selected: statusFilter == 'ACTIVE',
                              onTap: () =>
                                  setState(() => statusFilter = 'ACTIVE'),
                            ),
                            const SizedBox(width: 8),
                            _FilterPill(
                              label: 'Inactive ($inactiveHere)',
                              selected: statusFilter == 'INACTIVE',
                              onTap: () =>
                                  setState(() => statusFilter = 'INACTIVE'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (state != null)
                      state
                    else if (visibleStudents.isEmpty)
                      AdminStateMessage(
                        icon: Icons.person_search_rounded,
                        title: 'No students found',
                        message: search.isEmpty
                            ? 'Add your first student to get started.'
                            : 'Try a different search or filter.',
                      )
                    else ...[
                        for (final student in visibleStudents) ...[
                          _StudentDirectoryCard(
                            student: student,
                            onTap: () async {
                              await context.push('/students/${student.uuid}');
                              if (mounted) setState(reload);
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        AdminPager(
                          page: page,
                          pageSize: 20,
                          total: data!.count,
                          noun: 'students',
                          onPage: goToPage,
                        ),
                      ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentStatCard extends StatelessWidget {
  const _StudentStatCard({
    required this.label,
    required this.value,
    this.valueSuffix,
    this.badgeText,
    required this.caption,
    this.captionColor = const Color(0xFF64748B),
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  final String label;
  final String value;
  final String? valueSuffix;
  final String? badgeText;
  final String caption;
  final Color captionColor;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF334155),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: jakarta(
                  textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    fontSize: 28,
                    letterSpacing: -0.6,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (valueSuffix != null) ...[
                const SizedBox(width: 4),
                Text(
                  valueSuffix!,
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (badgeText != null) ...[
                const SizedBox(width: 8),
                Text(
                  badgeText!,
                  style: textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF059669),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: captionColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBarCard extends StatelessWidget {
  const _SearchBarCard({
    required this.controller,
    required this.onSearch,
    this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 20,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
              decoration: const InputDecoration(
                hintText: 'Search name, adm, email...',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
              visualDensity: VisualDensity.compact,
            ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: onSearch,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Search',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF3730A3) : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
              selected ? const Color(0xFF3730A3) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? Colors.white : const Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentDirectoryCard extends StatelessWidget {
  const _StudentDirectoryCard({
    required this.student,
    required this.onTap,
  });

  final Student student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final displayName =
    student.fullName.isEmpty ? student.admissionNumber : student.fullName;
    final initials = adminInitials(displayName);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top section: Avatar + Name & Admission badge + Status pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1D4ED8),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              displayName,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                student.admissionNumber,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3730A3),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (student.email.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(
                                Icons.mail_outline_rounded,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  student.email,
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: student.isActive
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: student.isActive
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          student.isActive ? 'Active' : 'Inactive',
                          style: textTheme.labelSmall?.copyWith(
                            color: student.isActive
                                ? const Color(0xFF15803D)
                                : const Color(0xFFB91C1C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Bottom soft strip with phone / joined date & action circles
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (student.phone.isNotEmpty) ...[
                      const Icon(
                        Icons.call_outlined,
                        size: 14,
                        color: Color(0xFF1D4ED8),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        student.phone,
                        style: textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF1E293B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (student.phone.isNotEmpty &&
                        (student.joinedDate ?? '').isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '•',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ),
                    if ((student.joinedDate ?? '').isNotEmpty) ...[
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          student.joinedDate!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEF2FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Color(0xFF3730A3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateStudentDialog extends StatefulWidget {
  const _CreateStudentDialog(this.repository);
  final StudentRepository repository;

  @override
  State<_CreateStudentDialog> createState() => _CreateStudentDialogState();
}

class _CreateStudentDialogState extends State<_CreateStudentDialog> {
  final key = GlobalKey<FormState>();
  final admission = TextEditingController();
  final first = TextEditingController();
  final last = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  bool saving = false;
  String? error;

  @override
  void dispose() {
    admission.dispose();
    first.dispose();
    last.dispose();
    email.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    if (!(key.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repository.create(
        admissionNumber: admission.text,
        firstName: first.text,
        lastName: last.text,
        email: email.text,
        phone: phone.text,
      );
      if (!mounted) return;
      setState(() => saving = false);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not create student. Please try again.');
      }
    } finally {
      if (mounted && saving) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AdminFormDialog(
      icon: Icons.person_add_alt_1_rounded,
      title: 'Add student',
      subtitle: 'Create a student record for your academy.',
      onClose: saving ? null : () => Navigator.of(context).pop(),
      body: Form(
        key: key,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldLabel(
              label: 'Admission number',
              required: true,
              child: TextFormField(
                controller: admission,
                enabled: !saving,
                maxLength: 50,
                textInputAction: TextInputAction.next,
                decoration: adminFieldDecoration(
                  context,
                  hint: 'Enter admission number',
                  icon: Icons.badge_outlined,
                ),
                validator: requiredField,
              ),
            ),
            const SizedBox(height: 16),
            FormRow(
              left: FieldLabel(
                label: 'First name',
                required: true,
                child: TextFormField(
                  controller: first,
                  enabled: !saving,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: adminFieldDecoration(
                    context,
                    hint: 'First name',
                    icon: Icons.person_outline_rounded,
                  ),
                  validator: requiredField,
                ),
              ),
              right: FieldLabel(
                label: 'Last name',
                child: TextFormField(
                  controller: last,
                  enabled: !saving,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: adminFieldDecoration(
                    context,
                    hint: 'Optional',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: 'Email',
              child: TextFormField(
                controller: email,
                enabled: !saving,
                maxLength: 254,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: adminFieldDecoration(
                  context,
                  hint: 'Optional',
                  icon: Icons.mail_outline_rounded,
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(text)
                      ? null
                      : 'Enter a valid email';
                },
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: 'Phone',
              child: TextFormField(
                controller: phone,
                enabled: !saving,
                maxLength: 20,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                decoration: adminFieldDecoration(
                  context,
                  hint: 'Optional',
                  icon: Icons.call_outlined,
                ),
                onFieldSubmitted: (_) => save(),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              AdminErrorBanner(message: error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: 'Save student',
          icon: Icons.check_rounded,
          loading: saving,
          onPressed: saving ? null : save,
        ),
      ],
    ),
  );
}

String? requiredField(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;