import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';

import '../../course_categories/data/course_category.dart';
import '../../course_categories/data/course_category_repository.dart';

import '../data/course.dart';
import '../data/course_repository.dart';

class CoursesListScreen extends ConsumerStatefulWidget {
  const CoursesListScreen({super.key});

  @override
  ConsumerState<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends ConsumerState<CoursesListScreen> {
  final searchController = TextEditingController();
  late Future<CoursePage> result;
  String search = '';
  int page = 1;
  bool creating = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result = ref.read(courseRepositoryProvider).list(search: search, page: page);
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
    setState(() => creating = true);
    try {
      final created = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _CreateCourseDialog(),
      );
      if (!mounted || created != true) return;
      setState(() {
        searchController.clear();
        search = '';
        page = 1;
        reload();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course created successfully.')),
      );
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  String _mode(String raw) {
    final v = raw.replaceAll('_', ' ').toLowerCase();
    return v.isEmpty ? 'Course' : v[0].toUpperCase() + v.substring(1);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AdminPageHeader(
        eyebrow: const AdminEyebrow(
          section: 'Curriculum',
          detail: 'Course catalogue',
        ),
        title: 'Courses',
        titleTrailing: [
          IconButton(
            onPressed: () => setState(reload),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
        actions: [
          AdminOutlineButton(
            label: 'Categories',
            icon: Icons.category_outlined,
            onPressed: () => context.go('/course-categories'),
          ),
          GradientButton(
            label: 'Add course',
            icon: Icons.add_rounded,
            onPressed: creating ? null : _openCreate,
          ),
        ],
      ),
      const SizedBox(height: 20),
      Expanded(
        child: FutureBuilder<CoursePage>(
          future: result,
          builder: (context, snapshot) {
            final state = adminFutureState(
              snapshot,
              noun: 'courses',
              onRetry: () => setState(reload),
            );
            final data = snapshot.connectionState == ConnectionState.done &&
                !snapshot.hasError
                ? snapshot.data
                : null;
            final rows = data?.results ?? const <Course>[];
            final published = rows.where((c) => c.isPublished).length;
            final featured = rows.where((c) => c.isFeatured).length;
            final online = rows.where((c) => c.isPurchasableOnline).length;

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                AdminKpiGrid(
                  children: [
                    AdminKpiCard(
                      label: search.isEmpty ? 'Total courses' : 'Matching courses',
                      value: data == null ? '…' : '${data.count}',
                      icon: Icons.auto_stories_outlined,
                    ),
                    AdminKpiCard(
                      label: 'Published on this page',
                      value: data == null ? '…' : '$published',
                      icon: Icons.public_rounded,
                      iconBackground: const Color(0xFFECFDF5),
                      iconForeground: const Color(0xFF059669),
                      caption: data == null
                          ? null
                          : '${rows.length - published} drafts',
                    ),
                    AdminKpiCard(
                      label: 'Featured',
                      value: data == null ? '…' : '$featured',
                      icon: Icons.star_outline_rounded,
                      iconBackground: const Color(0xFFFFFBEB),
                      iconForeground: const Color(0xFFD97706),
                      caption: 'On this page',
                    ),
                    AdminKpiCard(
                      label: 'Available online',
                      value: data == null ? '…' : '$online',
                      icon: Icons.shopping_bag_outlined,
                      iconBackground: const Color(0xFFF5F3FF),
                      iconForeground: const Color(0xFF7C3AED),
                      caption: 'On this page',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AdminToolbar(
                  controller: searchController,
                  hint: 'Search by course name or code…',
                  onSearch: applySearch,
                ),
                const SizedBox(height: 18),
                if (state != null)
                  state
                else if (rows.isEmpty)
                  AdminStateMessage(
                    icon: Icons.auto_stories_outlined,
                    title: 'No courses found',
                    message: search.isEmpty
                        ? 'Add your first course to the catalogue.'
                        : 'Try a different search.',
                  )
                else ...[
                    for (final course in rows)
                      AdminListRow(
                        title: course.name,
                        initials: adminInitials(course.code),
                        seed: course.code,
                        titleBadge: course.isFeatured
                            ? const SoftBadge(
                          label: 'Featured',
                          icon: Icons.star_rounded,
                          background: Color(0xFFFFFBEB),
                          foreground: Color(0xFFD97706),
                        )
                            : null,
                        subtitle: course.description,
                        meta: [
                          SoftBadge(
                            label: course.code,
                            monospace: true,
                            background: const Color(0xFFF1F5F9),
                            foreground: const Color(0xFF334155),
                          ),
                          MetaChip(
                            icon: Icons.devices_outlined,
                            label: _mode(course.deliveryMode),
                          ),
                          if ((course.categoryName ?? '').isNotEmpty)
                            MetaChip(
                              icon: Icons.category_outlined,
                              label: course.categoryName!,
                            ),
                          if (course.durationMonths != null)
                            MetaChip(
                              icon: Icons.schedule_rounded,
                              label: '${course.durationMonths} months',
                            ),
                        ],
                        trailing: [
                          Text(
                            '₹${course.price}',
                            style: jakarta(
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF3525CD),
                              ),
                            ),
                          ),
                          ActiveBadge(
                            active: course.isPublished,
                            activeLabel: 'Published',
                            inactiveLabel: 'Draft',
                          ),
                        ],
                        onTap: () async {
                          await context.push('/courses/${course.uuid}');
                          if (mounted) setState(reload);
                        },
                      ),
                    AdminPager(
                      page: page,
                      pageSize: 20,
                      total: data!.count,
                      noun: 'courses',
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

  void applySearch() {
    setState(() {
      search = searchController.text.trim();
      page = 1;
      reload();
    });
  }
}

class _CreateCourseDialog extends ConsumerStatefulWidget {
  const _CreateCourseDialog();

  @override
  ConsumerState<_CreateCourseDialog> createState() => _CreateCourseDialogState();
}

class _CreateCourseDialogState extends ConsumerState<_CreateCourseDialog> {
  final key = GlobalKey<FormState>();

  final name = TextEditingController();
  final code = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController(text: '0.00');
  final durationMonths = TextEditingController();
  final accessDays = TextEditingController();
  final featuredOrder = TextEditingController(text: '0');

  String mode = 'ONLINE';

  List<AdminCourseCategory> categories = [];
  AdminCourseCategory? selectedCategory;

  bool isActive = true;
  bool isPublished = false;
  bool isPurchasableOnline = false;
  bool isFeatured = false;

  bool loadingCategories = false;
  bool saving = false;
  String? error;
  String? categoryError;

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  Future<void> loadCategories() async {
    if (loadingCategories || saving) return;
    final repository = ref.read(courseCategoryRepositoryProvider);
    setState(() {
      loadingCategories = true;
      categoryError = null;
    });
    try {
      final all = <AdminCourseCategory>[];
      var nextPage = 1;
      var received = 0;
      while (true) {
        final response = await repository.list(page: nextPage);
        if (!mounted) return;
        all.addAll(response.results);
        received += response.results.length;
        if (response.results.isEmpty || received >= response.count) break;
        nextPage++;
      }
      if (!mounted) return;
      setState(() {
        final unique = {for (final item in all) item.uuid: item};
        categories = unique.values.where((item) => item.isActive).toList();
        if (!categories.any((c) => c.uuid == selectedCategory?.uuid)) {
          selectedCategory = null;
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => categoryError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => categoryError = 'Could not load course categories.');
      }
    } finally {
      if (mounted) setState(() => loadingCategories = false);
    }
  }

  String? validateInteger(String? value, {bool optional = false}) {
    final text = (value ?? '').trim();
    if (optional && text.isEmpty) return null;
    final number = int.tryParse(text);
    return number == null || number < 0 || number > 2147483647
        ? 'Enter a whole number from 0 to 2147483647'
        : null;
  }

  String? validatePrice(String? value) {
    final text = (value ?? '').trim();
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
      return 'Enter a non-negative price with up to 2 decimal places';
    }
    final whole = text.split('.').first.replaceFirst(RegExp(r'^0+'), '');
    return whole.length > 8 ? 'Maximum price is 99999999.99' : null;
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    description.dispose();
    price.dispose();
    durationMonths.dispose();
    accessDays.dispose();
    featuredOrder.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || loadingCategories) return;
    if (!(key.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ref.read(courseRepositoryProvider).create(
        name: name.text,
        code: code.text,
        description: description.text,
        price: price.text.trim(),
        deliveryMode: mode,
        categoryUuid: selectedCategory?.uuid,
        durationMonths: durationMonths.text.trim().isEmpty
            ? null
            : int.parse(durationMonths.text.trim()),
        accessDurationDays: accessDays.text.trim().isEmpty
            ? null
            : int.parse(accessDays.text.trim()),
        isActive: isActive,
        isPublished: isPublished,
        isPurchasableOnline: isPurchasableOnline,
        isFeatured: isFeatured,
        featuredOrder: isFeatured ? int.parse(featuredOrder.text.trim()) : 0,
      );

      if (!mounted) return;
      setState(() => saving = false);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not create course. Please try again.');
      }
    } finally {
      if (mounted && saving) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AdminFormDialog(
      icon: Icons.auto_stories_outlined,
      title: 'Add course',
      subtitle: 'Create a course for your academy.',
      onClose: saving ? null : () => Navigator.of(context).pop(),
      body: IgnorePointer(
        ignoring: saving,
        child: Form(
          key: key,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                enabled: !saving,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Course name'),
                validator: requiredField,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: code,
                enabled: !saving,
                maxLength: 50,
                decoration: const InputDecoration(labelText: 'Course code'),
                validator: requiredField,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey('category_dd_${categories.length}_${selectedCategory?.uuid}'),
                isExpanded: true,
                value: categories.any((c) => c.uuid == selectedCategory?.uuid)
                    ? selectedCategory?.uuid
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Course Category',
                ),
                items: categories
                    .map(
                      (category) => DropdownMenuItem<String>(
                    value: category.uuid,
                    child: Text(category.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                    .toList(),
                onChanged: saving || loadingCategories ? null : (value) {
                  setState(() {
                    selectedCategory = value == null
                        ? null
                        : categories.firstWhere(
                          (item) => item.uuid == value,
                    );
                  });
                },
              ),
              if (loadingCategories) const LinearProgressIndicator(),
              if (categoryError != null) ...[
                const SizedBox(height: 10),
                AdminErrorBanner(message: categoryError!),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: saving ? null : loadCategories,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry categories'),
                  ),
                ),
              ],
              if (selectedCategory != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: saving || loadingCategories
                        ? null
                        : () => setState(() => selectedCategory = null),
                    child: const Text('Clear category'),
                  ),
                ),
              const SizedBox(height: 10),
              TextFormField(
                controller: description,
                enabled: !saving,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: durationMonths,
                enabled: !saving,
                validator: (value) => validateInteger(value, optional: true),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (Months)',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: accessDays,
                enabled: !saving,
                validator: (value) => validateInteger(value, optional: true),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Student Access Duration (Days)',
                  hintText: 'Example: 180',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: price,
                enabled: !saving,
                decoration: const InputDecoration(labelText: 'Price (₹)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: validatePrice,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: mode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Delivery mode'),
                items: const [
                  DropdownMenuItem(value: 'ONLINE', child: Text('Online')),
                  DropdownMenuItem(value: 'OFFLINE', child: Text('Offline')),
                  DropdownMenuItem(value: 'HYBRID', child: Text('Hybrid')),
                ],
                onChanged: saving ? null : (value) => setState(() => mode = value ?? mode),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: isActive,
                onChanged: saving ? null : (value) {
                  setState(() {
                    isActive = value;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Published'),
                value: isPublished,
                onChanged: saving ? null : (value) {
                  setState(() {
                    isPublished = value;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Purchasable Online'),
                value: isPurchasableOnline,
                onChanged: saving ? null : (value) {
                  setState(() {
                    isPurchasableOnline = value;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Featured Course'),
                value: isFeatured,
                onChanged: saving ? null : (value) {
                  setState(() {
                    isFeatured = value;
                  });
                },
              ),
              if (isFeatured) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: featuredOrder,
                  enabled: !saving,
                  validator: validateInteger,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Featured Order',
                    hintText: '0 = first priority',
                  ),
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
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
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: 'Save course',
          icon: Icons.check_rounded,
          loading: saving,
          onPressed: saving || loadingCategories ? null : save,
        ),
      ],
    ),
  );
}

String? requiredField(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;
