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
  ConsumerState<StudentsDirectoryScreen> createState() => _StudentsDirectoryScreenState();
}

class _StudentsDirectoryScreenState extends ConsumerState<StudentsDirectoryScreen> {
  final searchController = TextEditingController();
  late Future<StudentPage> result;
  String search = '';
  int page = 1;
  bool creating = false;

  @override
  void initState() { super.initState(); reload(); }
  void reload() { result = ref.read(studentRepositoryProvider).list(search: search, page: page); }
  void goToPage(int next) { setState(() { page = next; reload(); }); }
  @override
  void dispose() { searchController.dispose(); super.dispose(); }

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

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AdminPageHeader(
        eyebrow: const AdminEyebrow(
          section: 'Academic records',
          detail: 'Student lifecycle management',
        ),
        title: 'Students',
        titleTrailing: [
          IconButton(
            onPressed: () => setState(reload),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
        actions: [
          GradientButton(
            label: 'Add student',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: creating ? null : _openCreate,
          ),
        ],
      ),
      const SizedBox(height: 20),
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

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                AdminKpiGrid(
                  children: [
                    AdminKpiCard(
                      label: search.isEmpty ? 'Total students' : 'Matching students',
                      value: data == null ? '…' : '${data.count}',
                      icon: Icons.groups_rounded,
                      caption: search.isEmpty ? 'All registered students' : 'Current search',
                    ),
                    AdminKpiCard(
                      label: 'Active on this page',
                      value: data == null ? '…' : '$activeHere',
                      icon: Icons.verified_outlined,
                      iconBackground: const Color(0xFFECFDF5),
                      iconForeground: const Color(0xFF059669),
                      caption: data == null || onPage.isEmpty
                          ? null
                          : '${(activeHere * 100 / onPage.length).round()}% active',
                      captionColor: const Color(0xFF059669),
                    ),
                    AdminKpiCard(
                      label: 'Inactive on this page',
                      value: data == null
                          ? '…'
                          : '${onPage.length - activeHere}',
                      icon: Icons.person_off_outlined,
                      iconBackground: const Color(0xFFFFF1F2),
                      iconForeground: const Color(0xFFE11D48),
                    ),
                    AdminKpiCard(
                      label: 'Current page',
                      value: '$page',
                      icon: Icons.layers_outlined,
                      iconBackground: const Color(0xFFF0F9FF),
                      iconForeground: const Color(0xFF0284C7),
                      caption: '20 per page',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AdminToolbar(
                  controller: searchController,
                  hint: 'Search by name, admission number, email or phone…',
                  onSearch: applySearch,
                ),
                const SizedBox(height: 18),
                if (state != null)
                  state
                else if (onPage.isEmpty)
                  AdminStateMessage(
                    icon: Icons.person_search_rounded,
                    title: 'No students found',
                    message: search.isEmpty
                        ? 'Add your first student to get started.'
                        : 'Try a different search.',
                  )
                else ...[
                    for (final student in onPage)
                      AdminListRow(
                        title: student.fullName.isEmpty
                            ? student.admissionNumber
                            : student.fullName,
                        initials: adminInitials(student.fullName.isEmpty
                            ? student.admissionNumber
                            : student.fullName),
                        seed: student.admissionNumber,
                        titleBadge: SoftBadge(
                          label: student.admissionNumber,
                          monospace: true,
                          background: const Color(0xFFF1F5F9),
                          foreground: const Color(0xFF334155),
                        ),
                        meta: [
                          if (student.email.isNotEmpty)
                            MetaChip(
                              icon: Icons.mail_outline_rounded,
                              label: student.email,
                            ),
                          if (student.phone.isNotEmpty)
                            MetaChip(
                              icon: Icons.call_outlined,
                              label: student.phone,
                            ),
                          if ((student.joinedDate ?? '').isNotEmpty)
                            MetaChip(
                              icon: Icons.event_outlined,
                              label: 'Joined ${student.joinedDate}',
                            ),
                        ],
                        trailing: [ActiveBadge(active: student.isActive)],
                        onTap: () async {
                          await context.push('/students/${student.uuid}');
                          if (mounted) setState(reload);
                        },
                      ),
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
  );

  void applySearch() { setState(() { search = searchController.text.trim(); page = 1; reload(); }); }
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
