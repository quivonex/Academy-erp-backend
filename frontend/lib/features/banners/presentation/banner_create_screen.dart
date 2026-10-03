import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../courses/data/course.dart';
import '../../courses/data/course_repository.dart';

import '../data/banner_repository.dart';

class BannerCreateScreen extends ConsumerStatefulWidget {
  const BannerCreateScreen({
    super.key,
  });

  @override
  ConsumerState<BannerCreateScreen> createState() =>
      _BannerCreateScreenState();
}

class _BannerCreateScreenState extends ConsumerState<BannerCreateScreen> {
  final title = TextEditingController();
  final subtitle = TextEditingController();
  final actionLabel = TextEditingController();
  final actionUrl = TextEditingController();
  final displayOrder = TextEditingController(
    text: '0',
  );

  List<Course> courses = [];
  Course? selectedCourse;

  Uint8List? imageBytes;
  String? imageName;

  DateTime? startsAt;
  DateTime? endsAt;

  bool isActive = true;
  bool saving = false;

  String? error;

  @override
  void initState() {
    super.initState();
    loadCourses();
  }

  Future<void> loadCourses() async {
    try {
      final result = await ref.read(courseRepositoryProvider).list();

      if (!mounted) return;

      setState(() {
        courses = result.results;
      });
    } catch (_) {}
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

    if (result == null) return;

    final file = result.files.single;

    if (file.bytes == null) return;

    setState(() {
      imageBytes = file.bytes;
      imageName = file.name;
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

    if (imageBytes == null || imageName == null) {
      setState(() {
        error = 'Please select banner image.';
      });

      return;
    }

    if (selectedCourse != null && actionUrl.text.trim().isNotEmpty) {
      setState(() {
        error = 'Select either Course or External URL, not both.';
      });

      return;
    }

    if (startsAt != null && endsAt != null && !endsAt!.isAfter(startsAt!)) {
      setState(() {
        error = 'End date must be after start date.';
      });

      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ref.read(bannerRepositoryProvider).create(
            title: title.text,
            subtitle: subtitle.text,
            imageBytes: imageBytes!,
            imageName: imageName!,
            actionLabel: actionLabel.text,
            actionUrl: actionUrl.text,
            courseUuid: selectedCourse?.uuid,
            displayOrder: int.tryParse(
                  displayOrder.text,
                ) ??
                0,
            startsAt: startsAt,
            endsAt: endsAt,
            isActive: isActive,
          );

      if (mounted) {
        Navigator.pop(
          context,
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
    return ListView(
      children: [
        Text(
          'Create Banner',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: title,
          decoration: const InputDecoration(
            labelText: 'Title *',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: subtitle,
          decoration: const InputDecoration(
            labelText: 'Subtitle',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: pickImage,
          icon: const Icon(
            Icons.image_outlined,
          ),
          label: Text(
            imageName ?? 'Select Banner Image',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('course_dd_${courses.length}'),
          value: courses.any((c) => c.uuid == selectedCourse?.uuid)
              ? selectedCourse?.uuid
              : null,
          decoration: const InputDecoration(
            labelText: 'Course (Optional)',
          ),
          items: courses
              .map(
                (course) => DropdownMenuItem(
                  value: course.uuid,
                  child: Text(
                    course.name,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
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
        const SizedBox(height: 12),
        TextField(
          controller: actionUrl,
          enabled: selectedCourse == null,
          decoration: const InputDecoration(
            labelText: 'External Action URL',
            hintText: 'https://example.com',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: actionLabel,
          decoration: const InputDecoration(
            labelText: 'Action Label',
            hintText: 'View Course',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: displayOrder,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Display Order',
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Starts At'),
          subtitle: Text(
            startsAt?.toString() ?? 'Not set',
          ),
          onTap: () async {
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
          title: const Text('Ends At'),
          subtitle: Text(
            endsAt?.toString() ?? 'Not set',
          ),
          onTap: () async {
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
          title: const Text('Active'),
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
              top: 12,
            ),
            child: Text(
              error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: saving ? null : save,
            icon: const Icon(Icons.save),
            label: Text(
              saving ? 'Saving...' : 'Create Banner',
            ),
          ),
        ),
      ],
    );
  }
}
