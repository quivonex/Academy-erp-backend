import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../course_categories/data/course_category.dart';
import '../../course_categories/data/course_category_repository.dart';
import '../data/course.dart';
import '../data/course_repository.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  const CourseDetailScreen({super.key, required this.courseUuid});
  final String courseUuid;

  @override
  ConsumerState<CourseDetailScreen> createState() =>
      _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  late Future<Course> result;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(covariant CourseDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseUuid != widget.courseUuid) reload();
  }

  void reload() {
    result = ref.read(courseRepositoryProvider).detail(widget.courseUuid);
  }

  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/courses');
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> toggleStatus(Course course) async {
    if (busy) return;
    final repository = ref.read(courseRepositoryProvider);
    final uuid = course.uuid;
    setState(() => busy = true);
    try {
      final updated = await repository.setPublished(uuid, !course.isPublished);
      if (!mounted || widget.courseUuid != uuid) return;
      setState(() => result = Future<Course>.value(updated));
      showMessage(updated.isPublished
          ? 'Course published successfully.'
          : 'Course unpublished successfully.');
    } on ApiException catch (e) {
      if (mounted && widget.courseUuid == uuid) showMessage(e.message);
    } catch (_) {
      if (mounted && widget.courseUuid == uuid) {
        showMessage('Could not change publication status. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editCourse(Course course) async {
    if (busy) return;
    final repository = ref.read(courseRepositoryProvider);
    final uuid = course.uuid;
    setState(() => busy = true);
    try {
      final updated = await showDialog<Course>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EditCourseDialog(
          course: course,
          repository: repository,
        ),
      );
      if (!mounted || updated == null || widget.courseUuid != uuid) return;
      setState(() => result = Future<Course>.value(updated));
      showMessage('Course updated successfully.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Course>(
    future: result,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError || !snapshot.hasData) {
        final error = snapshot.error;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: goBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Courses'),
                ),
              ),
              AdminStateMessage(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load course',
                message: error is ApiException
                    ? error.message
                    : 'Please try again.',
                actionLabel: 'Retry',
                onAction: () => setState(reload),
                isError: true,
              ),
            ],
          ),
        );
      }

      final course = snapshot.data!;
      final name = course.name.trim().isEmpty
          ? course.code
          : course.name;
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: goBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Courses'),
              ),
            ),
            const SizedBox(height: 8),
            AdminCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InitialsBadge(label: adminInitials(name)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SoftBadge(
                              label: course.code,
                              monospace: true,
                            ),
                            ActiveBadge(active: course.isActive),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: busy ? null : () => setState(reload),
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Course information',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 14),
                  _InfoRow(label: 'Code', value: course.code),
                  _InfoRow(label: 'Category', value: course.categoryName ?? ''),
                  _InfoRow(label: 'Price', value: '₹${course.price}'),
                  _InfoRow(label: 'Delivery mode', value: course.deliveryMode),
                  _InfoRow(
                    label: 'Duration',
                    value: course.durationMonths == null
                        ? '—' : '${course.durationMonths} months',
                  ),
                  _InfoRow(
                    label: 'Student access',
                    value: course.accessDurationDays == null
                        ? '—' : '${course.accessDurationDays} days',
                  ),
                  _InfoRow(label: 'Active', value: course.isActive ? 'Yes' : 'No'),
                  _InfoRow(label: 'Published', value: course.isPublished ? 'Yes' : 'No'),
                  _InfoRow(label: 'Purchasable online',
                      value: course.isPurchasableOnline ? 'Yes' : 'No'),
                  _InfoRow(label: 'Featured', value: course.isFeatured ? 'Yes' : 'No'),
                  if (course.isFeatured)
                    _InfoRow(label: 'Featured order',
                        value: course.featuredOrder.toString()),
                  _InfoRow(label: 'Description', value: course.description),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                GradientButton(
                  label: 'Edit course',
                  icon: Icons.edit_outlined,
                  onPressed: busy ? null : () => editCourse(course),
                ),
                AdminOutlineButton(
                  label: course.isPublished
                      ? 'Unpublish course' : 'Publish course',
                  icon: Icons.public_rounded,
                  danger: course.isPublished,
                  onPressed: busy ? null : () => toggleStatus(course),
                ),
              ],
            ),
            if (busy) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      );
    },
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labelWidget = Text(label, style: textTheme.bodySmall);
    final valueWidget = SelectableText(
      value.trim().isEmpty ? '—' : value,
      style: textTheme.bodyMedium,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 480) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: 4),
                valueWidget,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 160, child: labelWidget),
              const SizedBox(width: 16),
              Expanded(child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}

class _EditCourseDialog extends ConsumerStatefulWidget {
  const _EditCourseDialog({required this.course, required this.repository});
  final Course course;
  final CourseRepository repository;

  @override
  ConsumerState<_EditCourseDialog> createState() => _EditCourseDialogState();
}

class _EditCourseDialogState extends ConsumerState<_EditCourseDialog> {
  final key = GlobalKey<FormState>();

  late final name = TextEditingController(text: widget.course.name);
  late final code = TextEditingController(text: widget.course.code);
  late final description = TextEditingController(text: widget.course.description);
  late final price = TextEditingController(text: widget.course.price);
  late final durationMonths = TextEditingController(text: widget.course.durationMonths?.toString() ?? '');
  late final accessDays = TextEditingController(text: widget.course.accessDurationDays?.toString() ?? '');
  late final featuredOrder = TextEditingController(text: widget.course.featuredOrder.toString());

  late String mode = widget.course.deliveryMode;

  List<AdminCourseCategory> categories = [];
  AdminCourseCategory? selectedCategory;
  bool categoryChanged = false;
  bool choosingCategory = false;

  late bool isActive = widget.course.isActive;
  late bool isPublished = widget.course.isPublished;
  late bool isPurchasableOnline = widget.course.isPurchasableOnline;
  late bool isFeatured = widget.course.isFeatured;

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
          categoryChanged = false;
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
      final updated = await widget.repository.update(
        uuid: widget.course.uuid,
        name: name.text,
        code: code.text,
        description: description.text,
        price: price.text.trim(),
        deliveryMode: mode,
        categoryUuid: selectedCategory?.uuid,
        updateCategory: categoryChanged,
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
        featuredOrder: isFeatured ? int.parse(featuredOrder.text.trim()) : widget.course.featuredOrder,
      );

      if (!mounted) return;
      setState(() => saving = false);
      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not update course. Please try again.');
      }
    } finally {
      if (mounted && saving) setState(() => saving = false);
    }
  }

  Widget categoryField() {
    final categoryLabel = categoryChanged
        ? selectedCategory?.name ?? 'No category'
        : widget.course.categoryName ?? 'No category';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label: 'Category', child: Text(categoryLabel)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: saving || loadingCategories
                  ? null : () => setState(() => choosingCategory = true),
              child: const Text('Choose category'),
            ),
            if (categoryChanged
                ? selectedCategory != null
                : widget.course.categoryName != null)
              TextButton(
                onPressed: saving ? null : () => setState(() {
                  categoryChanged = true;
                  selectedCategory = null;
                  choosingCategory = false;
                }),
                child: const Text('Remove category'),
              ),
            if (categoryChanged || choosingCategory)
              TextButton(
                onPressed: saving ? null : () => setState(() {
                  categoryChanged = false;
                  selectedCategory = null;
                  choosingCategory = false;
                }),
                child: const Text('Keep original category'),
              ),
          ],
        ),
        if (loadingCategories) const LinearProgressIndicator(),
        if (categoryError != null) ...[
          const SizedBox(height: 8),
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
        if (choosingCategory && !loadingCategories && categoryError == null)
          DropdownButtonFormField<String>(
            key: ValueKey(selectedCategory?.uuid),
            value: selectedCategory?.uuid,
            isExpanded: true,
            decoration: adminFieldDecoration(context,
                hint: categories.isEmpty ? 'No active categories' : 'Select category'),
            items: categories.map((category) => DropdownMenuItem<String>(
              value: category.uuid,
              child: Text(category.name, overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: saving ? null : (value) {
              if (value == null) return;
              setState(() {
                selectedCategory = categories.firstWhere((c) => c.uuid == value);
                categoryChanged = true;
                choosingCategory = false;
              });
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AdminFormDialog(
      icon: Icons.edit_outlined,
      title: 'Edit course',
      subtitle: 'Update this course’s information.',
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
              categoryField(),
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
          label: 'Save changes',
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
