import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> openForm([
    AdminCourseCategory? category,
  ]) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _CategoryFormDialog(
        category: category,
      ),
    );

    if (changed == true && mounted) {
      refresh();
    }
  }

  Future<void> toggleStatus(
    AdminCourseCategory category,
  ) async {
    try {
      await ref
          .read(
            courseCategoryRepositoryProvider,
          )
          .update(
            uuid: category.uuid,
            isActive: !category.isActive,
          );

      if (mounted) {
        refresh();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
        ),
      );
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
              onPressed: refresh,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          actions: [
            GradientButton(
              label: 'Add category',
              icon: Icons.add_rounded,
              onPressed: () => openForm(),
            ),
          ],
        ),
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
              final data = snapshot.data;
              final rows = data?.results ?? const <AdminCourseCategory>[];
              final active = rows.where((c) => c.isActive).length;

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  AdminKpiGrid(
                    children: [
                      AdminKpiCard(
                        label: 'Total categories',
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
                      onAction: search.isEmpty ? () => openForm() : null,
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
                        onTap: () => openForm(category),
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
    if (name.text.trim().isEmpty) {
      setState(() {
        error = 'Category name is required.';
      });

      return;
    }

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

      if (mounted) {
        Navigator.pop(
          context,
          true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
        });
      }
    } finally {
      if (mounted) {
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
  Widget build(
    BuildContext context,
  ) {
    return AlertDialog(
      title: Text(
        isEdit ? 'Edit Category' : 'Add Category',
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Category Name *',
                ),
              ),
              const SizedBox(
                height: 12,
              ),
              TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
              ),
              const SizedBox(
                height: 12,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Active',
                ),
                value: isActive,
                onChanged: (value) {
                  setState(() {
                    isActive = value;
                  });
                },
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(
                    top: 10,
                  ),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving
              ? null
              : () => Navigator.pop(
                    context,
                  ),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(
            saving
                ? 'Saving...'
                : isEdit
                    ? 'Update'
                    : 'Create',
          ),
        ),
      ],
    );
  }
}
