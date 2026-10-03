import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';

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
  bool changing = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result = ref.read(courseRepositoryProvider).detail(widget.courseUuid);
  }

  Future<void> toggle(Course course) async {
    setState(() => changing = true);
    try {
      await ref
          .read(courseRepositoryProvider)
          .setPublished(course.uuid, !course.isPublished);
      if (mounted) setState(reload);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => changing = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Course>(
        future: result,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load course: ${snapshot.error}'),
            );
          }
          final c = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Courses'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () async {
                        final changed = await showDialog<bool>(
                          context: context,
                          builder: (_) => _EditCourseDialog(course: c),
                        );
                        if (changed == true && mounted) {
                          setState(reload);
                        }
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Course'),
                    ),
                  ],
                ),
                Text(c.name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Code: ${c.code}'),
                        Text('Category: ${c.categoryName ?? '—'}'),
                        Text('Price: ₹${c.price}'),
                        Text('Mode: ${c.deliveryMode}'),
                        Text(
                          'Duration: ${c.durationMonths?.toString() ?? '—'} months',
                        ),
                        Text(
                          'Access: ${c.accessDurationDays?.toString() ?? '—'} days',
                        ),
                        Text('Active: ${c.isActive ? 'Yes' : 'No'}'),
                        Text('Published: ${c.isPublished ? 'Yes' : 'No'}'),
                        Text(
                          'Purchasable online: ${c.isPurchasableOnline ? 'Yes' : 'No'}',
                        ),
                        Text('Featured: ${c.isFeatured ? 'Yes' : 'No'}'),
                        if (c.isFeatured)
                          Text('Featured Order: ${c.featuredOrder}'),
                        const SizedBox(height: 8),
                        Text(c.description),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: changing ? null : () => toggle(c),
                  child: Text(
                    changing
                        ? 'Updating...'
                        : (c.isPublished
                            ? 'Unpublish course'
                            : 'Publish course'),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _EditCourseDialog extends ConsumerStatefulWidget {
  const _EditCourseDialog({
    required this.course,
  });

  final Course course;

  @override
  ConsumerState<_EditCourseDialog> createState() => _EditCourseDialogState();
}

class _EditCourseDialogState extends ConsumerState<_EditCourseDialog> {
  late final TextEditingController name;
  late final TextEditingController code;
  late final TextEditingController description;
  late final TextEditingController price;
  late final TextEditingController durationMonths;
  late final TextEditingController accessDays;
  late final TextEditingController featuredOrder;

  late String mode;

  late bool isActive;
  late bool isPublished;
  late bool isPurchasableOnline;
  late bool isFeatured;

  List<AdminCourseCategory> categories = [];
  AdminCourseCategory? selectedCategory;

  String? existingCategoryName;

  bool categoryChanged = false;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();

    final course = widget.course;

    name = TextEditingController(text: course.name);
    code = TextEditingController(text: course.code);
    description = TextEditingController(text: course.description);
    price = TextEditingController(text: course.price);
    durationMonths = TextEditingController(
      text: course.durationMonths?.toString() ?? '',
    );
    accessDays = TextEditingController(
      text: course.accessDurationDays?.toString() ?? '',
    );
    featuredOrder = TextEditingController(
      text: course.featuredOrder.toString(),
    );

    mode = course.deliveryMode;
    isActive = course.isActive;
    isPublished = course.isPublished;
    isPurchasableOnline = course.isPurchasableOnline;
    isFeatured = course.isFeatured;

    existingCategoryName = course.categoryName;

    loadCategories();
  }

  Future<void> loadCategories() async {
    try {
      final result = await ref
          .read(
            courseCategoryRepositoryProvider,
          )
          .list();

      if (!mounted) return;

      setState(() {
        categories = result.results;
      });
    } catch (_) {}
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty || code.text.trim().isEmpty) {
      setState(() {
        error = 'Course name and code are required.';
      });
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ref.read(courseRepositoryProvider).update(
            uuid: widget.course.uuid,
            name: name.text,
            code: code.text,
            description: description.text,
            price: price.text,
            deliveryMode: mode,
            categoryUuid: selectedCategory?.uuid,
            updateCategory: categoryChanged,
            durationMonths: durationMonths.text.trim().isEmpty
                ? null
                : int.tryParse(durationMonths.text),
            accessDurationDays: accessDays.text.trim().isEmpty
                ? null
                : int.tryParse(accessDays.text),
            isActive: isActive,
            isPublished: isPublished,
            isPurchasableOnline: isPurchasableOnline,
            isFeatured: isFeatured,
            featuredOrder: int.tryParse(featuredOrder.text) ?? 0,
          );

      if (mounted) {
        Navigator.pop(context, true);
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
    code.dispose();
    description.dispose();
    price.dispose();
    durationMonths.dispose();
    accessDays.dispose();
    featuredOrder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Course'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Course Name',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: code,
                decoration: const InputDecoration(
                  labelText: 'Course Code',
                ),
              ),
              const SizedBox(height: 10),
              if (existingCategoryName != null && !categoryChanged)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Current Category'),
                  subtitle: Text(existingCategoryName!),
                  trailing: TextButton(
                    onPressed: () {
                      setState(() {
                        categoryChanged = true;
                      });
                    },
                    child: const Text('Change'),
                  ),
                ),
              if (existingCategoryName == null || categoryChanged)
                DropdownButtonFormField<String>(
                  key: ValueKey('edit_cat_dd_${categories.length}'),
                  value: categories.any((c) => c.uuid == selectedCategory?.uuid)
                      ? selectedCategory?.uuid
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                  ),
                  items: categories
                      .map(
                        (category) => DropdownMenuItem<String>(
                          value: category.uuid,
                          child: Text(category.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      categoryChanged = true;
                      selectedCategory = value == null
                          ? null
                          : categories.firstWhere(
                              (item) => item.uuid == value,
                            );
                    });
                  },
                ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Price',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: mode,
                decoration: const InputDecoration(
                  labelText: 'Delivery Mode',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'ONLINE',
                    child: Text('Online'),
                  ),
                  DropdownMenuItem(
                    value: 'OFFLINE',
                    child: Text('Offline'),
                  ),
                  DropdownMenuItem(
                    value: 'HYBRID',
                    child: Text('Hybrid'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    mode = value ?? mode;
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: durationMonths,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration Months',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: accessDays,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Access Duration Days',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: isActive,
                onChanged: (value) {
                  setState(() {
                    isActive = value;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Published'),
                value: isPublished,
                onChanged: (value) {
                  setState(() {
                    isPublished = value;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Purchasable Online'),
                value: isPurchasableOnline,
                onChanged: (value) {
                  setState(() {
                    isPurchasableOnline = value;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Featured'),
                value: isFeatured,
                onChanged: (value) {
                  setState(() {
                    isFeatured = value;
                  });
                },
              ),
              if (isFeatured)
                TextField(
                  controller: featuredOrder,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Featured Order',
                  ),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
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
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(
            saving ? 'Saving...' : 'Save Changes',
          ),
        ),
      ],
    );
  }
}
