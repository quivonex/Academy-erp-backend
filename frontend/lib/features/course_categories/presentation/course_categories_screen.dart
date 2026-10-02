import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Course Categories',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            FilledButton.icon(
              onPressed: () => openForm(),
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Category',
              ),
            ),
            IconButton(
              onPressed: refresh,
              tooltip: 'Refresh',
              icon: const Icon(
                Icons.refresh,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search category',
                ),
                onSubmitted: (_) => applySearch(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: applySearch,
              child: const Text('Search'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<AdminCourseCategoryPage>(
            future: result,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Could not load categories:\n'
                        '${snapshot.error}',
                      ),
                      TextButton(
                        onPressed: refresh,
                        child: const Text(
                          'Retry',
                        ),
                      ),
                    ],
                  ),
                );
              }

              final data = snapshot.data!;

              if (data.results.isEmpty) {
                return const Center(
                  child: Text(
                    'No course categories found.',
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: data.results.length,
                      itemBuilder: (context, index) {
                        final category = data.results[index];

                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(
                                Icons.category_outlined,
                              ),
                            ),
                            title: Text(
                              category.name,
                            ),
                            subtitle: Text(
                              category.description.isEmpty
                                  ? 'No description'
                                  : category.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text(
                                    category.isActive ? 'Active' : 'Inactive',
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      openForm(
                                        category,
                                      );
                                    }

                                    if (value == 'status') {
                                      toggleStatus(
                                        category,
                                      );
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text(
                                        'Edit',
                                      ),
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
                            ),
                            onTap: () => openForm(
                              category,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${data.count} total • Page $page',
                      ),
                      IconButton(
                        onPressed: page > 1
                            ? () {
                                setState(() {
                                  page--;
                                  reload();
                                });
                              }
                            : null,
                        icon: const Icon(
                          Icons.chevron_left,
                        ),
                      ),
                      IconButton(
                        onPressed: page * 20 < data.count
                            ? () {
                                setState(() {
                                  page++;
                                  reload();
                                });
                              }
                            : null,
                        icon: const Icon(
                          Icons.chevron_right,
                        ),
                      ),
                    ],
                  ),
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
