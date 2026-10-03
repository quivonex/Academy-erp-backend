import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';

import '../data/course_category.dart';
import '../data/course_category_repository.dart';

class CourseCategoriesScreen extends ConsumerStatefulWidget {
  const CourseCategoriesScreen({
    super.key,
  });

  @override
  ConsumerState<CourseCategoriesScreen> createState() =>
      _CourseCategoriesScreenState();
}

class _CourseCategoriesScreenState
    extends ConsumerState<CourseCategoriesScreen> {
  final searchController = TextEditingController();

  late Future<AdminCourseCategoryPage> result;

  String search = '';
  int page = 1;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result = ref
        .read(
      courseCategoryRepositoryProvider,
    )
        .list(
      search: search,
      page: page,
    );
  }

  void refresh() {
    setState(reload);
  }

  void applySearch() {
    setState(() {
      search = searchController.text.trim();

      page = 1;

      reload();
    });
  }

  Future<void> openForm([AdminCourseCategory? category]) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final changed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CategoryFormDialog(category: category),
      );
      if (!mounted || changed != true) return;
      setState(() {
        if (category == null) {
          searchController.clear();
          search = '';
          page = 1;
        }
        reload();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(category == null
            ? 'Category created successfully.'
            : 'Category updated successfully.')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> toggleStatus(AdminCourseCategory category) async {
    if (busy) return;
    final repository = ref.read(courseCategoryRepositoryProvider);
    setState(() => busy = true);
    try {
      final updated = await repository.update(
        uuid: category.uuid,
        isActive: !category.isActive,
      );
      if (!mounted) return;
      refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(updated.isActive
            ? 'Category activated successfully.'
            : 'Category deactivated successfully.')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
              'Could not update category status. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _goToPage(int value) {
    setState(() {
      page = value;
      reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          eyebrow: const AdminEyebrow(
            section: 'Curriculum',
            detail: 'Course taxonomy',
          ),
          title: 'Course categories',
          subtitle: 'Group courses into streams students can browse.',
          titleTrailing: [
            IconButton(
              onPressed: busy ? null : refresh,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          actions: [
            GradientButton(
              label: 'Add category',
              icon: Icons.add_rounded,
              onPressed: busy ? null : () => openForm(),
            ),
          ],
        ),
        if (busy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 20),
        Expanded(
          child: FutureBuilder<AdminCourseCategoryPage>(
            future: result,
            builder: (context, snapshot) {
              final state = adminFutureState(
                snapshot,
                noun: 'categories',
                onRetry: refresh,
              );
              final data = snapshot.connectionState == ConnectionState.done &&
                  !snapshot.hasError
                  ? snapshot.data
                  : null;
              final rows = data?.results ?? const <AdminCourseCategory>[];
              final active = rows.where((c) => c.isActive).length;

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  AdminKpiGrid(
                    children: [
                      AdminKpiCard(
                        label: search.isEmpty ? 'Total categories' : 'Matching categories',
                        value: data == null ? '…' : '${data.count}',
                        icon: Icons.category_outlined,
                      ),
                      AdminKpiCard(
                        label: 'Active on this page',
                        value: data == null ? '…' : '$active',
                        icon: Icons.verified_outlined,
                        iconBackground: const Color(0xFFECFDF5),
                        iconForeground: const Color(0xFF059669),
                      ),
                      AdminKpiCard(
                        label: 'Hidden on this page',
                        value: data == null ? '…' : '${rows.length - active}',
                        icon: Icons.visibility_off_outlined,
                        iconBackground: const Color(0xFFF8FAFC),
                        iconForeground: const Color(0xFF64748B),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AdminToolbar(
                    controller: searchController,
                    hint: 'Search categories…',
                    onSearch: applySearch,
                  ),
                  const SizedBox(height: 18),
                  if (state != null)
                    state
                  else if (rows.isEmpty)
                    AdminStateMessage(
                      icon: Icons.category_outlined,
                      title: 'No course categories found',
                      message: search.isEmpty
                          ? 'Create a category to organise your courses.'
                          : 'Try a different search.',
                      actionLabel: search.isEmpty ? 'Add category' : null,
                      onAction: search.isEmpty && !busy ? () => openForm() : null,
                    )
                  else ...[
                      for (final category in rows)
                        AdminListRow(
                          title: category.name,
                          icon: Icons.category_outlined,
                          subtitle: category.description.isEmpty
                              ? 'No description'
                              : category.description,
                          trailing: [
                            ActiveBadge(active: category.isActive),
                            PopupMenuButton<String>(
                              enabled: !busy,
                              tooltip: 'Actions',
                              icon: const Icon(Icons.more_vert_rounded),
                              onSelected: (value) {
                                if (value == 'edit') openForm(category);
                                if (value == 'status') toggleStatus(category);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'status',
                                  child: Text(
                                    category.isActive
                                        ? 'Deactivate'
                                        : 'Activate',
                                  ),
                                ),
                              ],
                            ),
                          ],
                          onTap: busy ? null : () => openForm(category),
                        ),
                      AdminPager(
                        page: page,
                        pageSize: 20,
                        total: data!.count,
                        noun: 'categories',
                        onPage: _goToPage,
                      ),
                    ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryFormDialog extends ConsumerStatefulWidget {
  const _CategoryFormDialog({
    this.category,
  });

  final AdminCourseCategory? category;

  @override
  ConsumerState<_CategoryFormDialog> createState() =>
      _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<_CategoryFormDialog> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();

  final description = TextEditingController();

  bool isActive = true;
  bool saving = false;

  String? error;

  bool get isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();

    final category = widget.category;

    if (category != null) {
      name.text = category.name;

      description.text = category.description;

      isActive = category.isActive;
    }
  }

  Future<void> save() async {
    if (saving) return;
    if (!(formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      error = null;
    });

    try {
      final repository = ref.read(
        courseCategoryRepositoryProvider,
      );

      if (isEdit) {
        await repository.update(
          uuid: widget.category!.uuid,
          name: name.text,
          description: description.text,
          isActive: isActive,
        );
      } else {
        await repository.create(
          name: name.text,
          description: description.text,
          isActive: isActive,
        );
      }

      if (!mounted) return;
      setState(() => saving = false);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not save category. Please try again.');
      }
    } finally {
      if (mounted && saving) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AdminFormDialog(
      icon: Icons.category_outlined,
      title: isEdit ? 'Edit category' : 'Add category',
      subtitle: 'Group courses into a category.',
      onClose: saving ? null : () => Navigator.of(context).pop(),
      body: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldLabel(
              label: 'Category name',
              required: true,
              child: TextFormField(
                controller: name,
                enabled: !saving,
                maxLength: 150,
                textInputAction: TextInputAction.next,
                decoration: adminFieldDecoration(
                  context,
                  hint: 'Enter category name',
                  icon: Icons.category_outlined,
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty
                    ? 'Category name is required'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: 'Description',
              child: TextFormField(
                controller: description,
                enabled: !saving,
                maxLines: 3,
                keyboardType: TextInputType.multiline,
                decoration: adminFieldDecoration(
                  context,
                  hint: 'Optional',
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: isActive,
              onChanged: saving
                  ? null
                  : (value) => setState(() => isActive = value),
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
          label: isEdit ? 'Save changes' : 'Create category',
          icon: Icons.check_rounded,
          loading: saving,
          onPressed: saving ? null : save,
        ),
      ],
    ),
  );
}
