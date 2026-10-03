import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../courses/data/course.dart';
import '../../courses/data/course_repository.dart';

import '../data/banner_repository.dart';

class BannerDetailScreen extends ConsumerStatefulWidget {
  const BannerDetailScreen({
    super.key,
    required this.bannerUuid,
  });

  final String bannerUuid;

  @override
  ConsumerState<BannerDetailScreen> createState() =>
      _BannerDetailScreenState();
}

class _BannerDetailScreenState extends ConsumerState<BannerDetailScreen> {
  late Future<HomeBanner> bannerFuture;

  final title = TextEditingController();

  final subtitle = TextEditingController();

  final actionLabel = TextEditingController();

  final actionUrl = TextEditingController();

  final displayOrder = TextEditingController();

  List<Course> courses = [];

  Course? selectedCourse;

  String? existingCourseName;

  bool courseChanged = false;

  DateTime? startsAt;
  DateTime? endsAt;

  bool isActive = true;

  Uint8List? imageBytes;
  String? imageName;

  bool formLoaded = false;
  bool saving = false;
  bool deleting = false;

  String? error;

  @override
  void initState() {
    super.initState();

    loadCourses();

    reload();
  }

  void reload() {
    bannerFuture = ref
        .read(bannerRepositoryProvider)
        .detail(widget.bannerUuid);
  }

  Future<void> loadCourses() async {
    try {
      final result = await ref
          .read(courseRepositoryProvider)
          .list();

      if (!mounted) return;

      setState(() {
        courses = result.results;
      });
    } catch (_) {}
  }

  void initialiseForm(
    HomeBanner banner,
  ) {
    if (formLoaded) return;

    title.text = banner.title;

    subtitle.text = banner.subtitle;

    actionLabel.text = banner.actionLabel;

    actionUrl.text = banner.actionUrl;

    displayOrder.text = banner.displayOrder.toString();

    existingCourseName = banner.courseName;

    startsAt = banner.startsAt?.toLocal();

    endsAt = banner.endsAt?.toLocal();

    isActive = banner.isActive;

    formLoaded = true;
  }

  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'webp',
      ],
      withData: true,
    );

    if (result == null) {
      return;
    }

    final file = result.files.single;

    if (file.bytes == null) {
      return;
    }

    if (file.size > 5 * 1024 * 1024) {
      setState(() {
        error = 'Image must be 5 MB or smaller.';
      });

      return;
    }

    setState(() {
      imageBytes = file.bytes;

      imageName = file.name;

      error = null;
    });
  }

  Future<DateTime?> pickDateTime(
    DateTime? current,
  ) async {
    final initial = current ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (date == null || !mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        initial,
      ),
    );

    if (time == null) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty) {
      setState(() {
        error = 'Banner title is required.';
      });

      return;
    }

    final externalUrl = actionUrl.text.trim();

    final hasCourse = selectedCourse != null ||
        (!courseChanged && existingCourseName != null);

    if (hasCourse && externalUrl.isNotEmpty) {
      setState(() {
        error =
            'Banner can link to either a course or an external URL, not both.';
      });

      return;
    }

    if (startsAt != null && endsAt != null && !endsAt!.isAfter(startsAt!)) {
      setState(() {
        error = 'End date/time must be after start date/time.';
      });

      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ref
          .read(
            bannerRepositoryProvider,
          )
          .update(
            uuid: widget.bannerUuid,
            title: title.text,
            subtitle: subtitle.text,
            actionLabel: actionLabel.text,
            actionUrl: actionUrl.text,
            courseUuid: selectedCourse?.uuid,
            updateCourse: courseChanged,
            displayOrder: int.tryParse(
                  displayOrder.text,
                ) ??
                0,
            startsAt: startsAt,
            endsAt: endsAt,
            isActive: isActive,
            imageBytes: imageBytes,
            imageName: imageName,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Banner updated successfully.',
          ),
        ),
      );

      setState(() {
        formLoaded = false;

        imageBytes = null;
        imageName = null;

        selectedCourse = null;
        courseChanged = false;

        reload();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Future<void> deleteBanner() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Banner',
          ),
          content: const Text(
            'Are you sure you want to delete this banner? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                false,
              ),
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                true,
              ),
              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      deleting = true;
      error = null;
    });

    try {
      await ref
          .read(
            bannerRepositoryProvider,
          )
          .delete(
            widget.bannerUuid,
          );

      if (!mounted) return;

      context.pop();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();

        deleting = false;
      });
    }
  }

  @override
  void dispose() {
    title.dispose();
    subtitle.dispose();
    actionLabel.dispose();
    actionUrl.dispose();
    displayOrder.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return FutureBuilder<HomeBanner>(
      future: bannerFuture,
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
                  'Could not load banner:\n'
                  '${snapshot.error}',
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      reload();
                    });
                  },
                  child: const Text(
                    'Retry',
                  ),
                ),
              ],
            ),
          );
        }

        final banner = snapshot.data!;

        initialiseForm(
          banner,
        );

        return ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Banner Details',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: deleting ? null : deleteBanner,
                  icon: const Icon(
                    Icons.delete_outline,
                  ),
                  label: Text(
                    deleting ? 'Deleting...' : 'Delete',
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 20,
            ),
            if (banner.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  12,
                ),
                child: Image.network(
                  banner.imageUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return Container(
                      height: 180,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        size: 50,
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(
              height: 20,
            ),
            TextField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'Title *',
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            TextField(
              controller: subtitle,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Subtitle',
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            OutlinedButton.icon(
              onPressed: saving ? null : pickImage,
              icon: const Icon(
                Icons.image_outlined,
              ),
              label: Text(
                imageName ?? 'Replace Banner Image',
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            if (existingCourseName != null && !courseChanged)
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.school_outlined,
                  ),
                  title: const Text(
                    'Current Course',
                  ),
                  subtitle: Text(
                    existingCourseName!,
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      setState(() {
                        courseChanged = true;

                        selectedCourse = null;
                      });
                    },
                    child: const Text(
                      'Change',
                    ),
                  ),
                ),
              ),
            if (existingCourseName == null || courseChanged)
              DropdownButtonFormField<String>(
                key: ValueKey('detail_course_dd_${courses.length}'),
                value: courses.any((c) => c.uuid == selectedCourse?.uuid)
                    ? selectedCourse?.uuid
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Linked Course',
                  helperText: 'Optional. Leave empty for no course.',
                ),
                items: courses
                    .map(
                      (course) => DropdownMenuItem<String>(
                        value: course.uuid,
                        child: Text(
                          '${course.name} (${course.code})',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    courseChanged = true;

                    selectedCourse = value == null
                        ? null
                        : courses.firstWhere(
                            (item) => item.uuid == value,
                          );

                    if (selectedCourse != null) {
                      actionUrl.clear();
                    }
                  });
                },
              ),
            if (courseChanged && existingCourseName != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      courseChanged = false;

                      selectedCourse = null;
                    });
                  },
                  child: const Text(
                    'Keep Current Course',
                  ),
                ),
              ),
            const SizedBox(
              height: 12,
            ),
            TextField(
              controller: actionUrl,
              enabled: selectedCourse == null,
              decoration: const InputDecoration(
                labelText: 'External Action URL',
                hintText: 'https://example.com',
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            TextField(
              controller: actionLabel,
              decoration: const InputDecoration(
                labelText: 'Action Label',
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            TextField(
              controller: displayOrder,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Display Order',
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Starts At',
              ),
              subtitle: Text(
                _formatDateTime(
                  startsAt,
                ),
              ),
              trailing: const Icon(
                Icons.calendar_month_outlined,
              ),
              onTap: saving
                  ? null
                  : () async {
                      final value = await pickDateTime(
                        startsAt,
                      );

                      if (value != null && mounted) {
                        setState(() {
                          startsAt = value;
                        });
                      }
                    },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Ends At',
              ),
              subtitle: Text(
                _formatDateTime(
                  endsAt,
                ),
              ),
              trailing: const Icon(
                Icons.calendar_month_outlined,
              ),
              onTap: saving
                  ? null
                  : () async {
                      final value = await pickDateTime(
                        endsAt,
                      );

                      if (value != null && mounted) {
                        setState(() {
                          endsAt = value;
                        });
                      }
                    },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Active',
              ),
              value: isActive,
              onChanged: saving
                  ? null
                  : (value) {
                      setState(() {
                        isActive = value;
                      });
                    },
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(
                  top: 12,
                ),
                child: Text(
                  error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(
              height: 20,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: saving ? null : save,
                icon: const Icon(
                  Icons.save_outlined,
                ),
                label: Text(
                  saving ? 'Saving...' : 'Save Changes',
                ),
              ),
            ),
            const SizedBox(
              height: 30,
            ),
          ],
        );
      },
    );
  }
}

String _formatDateTime(
  DateTime? value,
) {
  if (value == null) {
    return 'Not set';
  }

  final local = value.toLocal();

  String two(
    int number,
  ) =>
      number.toString().padLeft(
            2,
            '0',
          );

  return '${two(local.day)}/'
      '${two(local.month)}/'
      '${local.year} '
      '${two(local.hour)}:'
      '${two(local.minute)}';
}
