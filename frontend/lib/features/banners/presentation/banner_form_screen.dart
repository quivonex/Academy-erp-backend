import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../courses/data/course.dart';
import '../../courses/data/course_repository.dart';

import '../data/banner_repository.dart';

class BannerFormScreen extends ConsumerStatefulWidget {
  const BannerFormScreen({
    super.key,
    this.bannerUuid,
  });

  final String? bannerUuid;

  bool get isEdit => bannerUuid != null;

  @override
  ConsumerState<BannerFormScreen> createState() => _BannerFormScreenState();
}

class _BannerFormScreenState extends ConsumerState<BannerFormScreen> {
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
  String? imageFileName;

  DateTime? startsAt;
  DateTime? endsAt;

  bool isActive = true;
  bool loading = false;
  bool saving = false;

  String? existingImageUrl;
  String? error;

  @override
  void initState() {
    super.initState();
    loadInitial();
  }

  Future<void> loadInitial() async {
    setState(() {
      loading = true;
    });

    try {
      final courseResult = await ref
          .read(
            courseRepositoryProvider,
          )
          .list();

      HomeBanner? banner;

      if (widget.isEdit) {
        banner = await ref
            .read(
              bannerRepositoryProvider,
            )
            .detail(
              widget.bannerUuid!,
            );
      }

      if (!mounted) return;

      setState(() {
        courses = courseResult.results;

        if (banner != null) {
          title.text = banner.title;
          subtitle.text = banner.subtitle;
          actionLabel.text = banner.actionLabel;
          actionUrl.text = banner.actionUrl;
          displayOrder.text = banner.displayOrder.toString();

          existingImageUrl = banner.imageUrl;

          startsAt = banner.startsAt;
          endsAt = banner.endsAt;

          isActive = banner.isActive;

          if (banner.courseName != null) {
            final matches = courses.where(
              (c) => c.name == banner!.courseName,
            );

            if (matches.isNotEmpty) {
              selectedCourse = matches.first;
            }
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
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
        error = 'Image must be less than 5 MB.';
      });
      return;
    }

    setState(() {
      imageBytes = file.bytes!;
      imageFileName = file.name;
      error = null;
    });
  }

  Future<DateTime?> pickDateTime(
    DateTime? current,
  ) async {
    final initial = current ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: initial,
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

    if (!widget.isEdit && imageBytes == null) {
      setState(() {
        error = 'Please select banner image.';
      });
      return;
    }

    if (selectedCourse != null && actionUrl.text.trim().isNotEmpty) {
      setState(() {
        error = 'Select either a course or external URL, not both.';
      });
      return;
    }

    if (actionUrl.text.trim().isNotEmpty &&
        !actionUrl.text.trim().startsWith(
              'http://',
            ) &&
        !actionUrl.text.trim().startsWith(
              'https://',
            )) {
      setState(() {
        error = 'Action URL must start with http:// or https://';
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
      final order = int.tryParse(
            displayOrder.text,
          ) ??
          0;

      if (widget.isEdit) {
        await ref
            .read(
              bannerRepositoryProvider,
            )
            .update(
              uuid: widget.bannerUuid!,
              title: title.text,
              subtitle: subtitle.text,
              actionLabel: actionLabel.text,
              actionUrl: actionUrl.text,
              courseUuid: selectedCourse?.uuid,
              displayOrder: order,
              startsAt: startsAt,
              endsAt: endsAt,
              isActive: isActive,
              imageBytes: imageBytes,
              imageName: imageFileName,
            );
      } else {
        await ref
            .read(
              bannerRepositoryProvider,
            )
            .create(
              title: title.text,
              subtitle: subtitle.text,
              imageBytes: imageBytes!,
              imageName: imageFileName!,
              actionLabel: actionLabel.text,
              actionUrl: actionUrl.text,
              courseUuid: selectedCourse?.uuid,
              displayOrder: order,
              startsAt: startsAt,
              endsAt: endsAt,
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
  Widget build(
    BuildContext context,
  ) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.isEdit ? 'Edit Banner' : 'Add Banner',
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
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Subtitle',
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: pickImage,
          icon: const Icon(
            Icons.image_outlined,
          ),
          label: Text(
            imageFileName ?? 'Select Image',
          ),
        ),
        if (existingImageUrl != null &&
            existingImageUrl!.isNotEmpty &&
            imageBytes == null)
          Padding(
            padding: const EdgeInsets.only(
              top: 12,
            ),
            child: Image.network(
              existingImageUrl!,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('course_dd_${courses.length}'),
          value: courses.any((c) => c.uuid == selectedCourse?.uuid)
              ? selectedCourse?.uuid
              : '',
          decoration: const InputDecoration(
            labelText: 'Course (Optional)',
          ),
          items: [
            const DropdownMenuItem<String>(
              value: '',
              child: Text('No Course'),
            ),
            ...courses.map(
              (course) => DropdownMenuItem<String>(
                value: course.uuid,
                child: Text(
                  '${course.name} (${course.code})',
                ),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              if (value == null || value.isEmpty) {
                selectedCourse = null;
              } else {
                selectedCourse = courses.firstWhere(
                  (c) => c.uuid == value,
                );

                // course selected तर external URL clear
                actionUrl.clear();
              }
            });
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: actionLabel,
          decoration: const InputDecoration(
            labelText: 'Action Label',
          ),
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
          controller: displayOrder,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Display Order',
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Start Date',
          ),
          subtitle: Text(
            startsAt == null ? 'Not set' : startsAt.toString(),
          ),
          trailing: const Icon(
            Icons.calendar_month,
          ),
          onTap: () async {
            final result = await pickDateTime(
              startsAt,
            );

            if (result != null) {
              setState(() {
                startsAt = result;
              });
            }
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'End Date',
          ),
          subtitle: Text(
            endsAt == null ? 'Not set' : endsAt.toString(),
          ),
          trailing: const Icon(
            Icons.calendar_month,
          ),
          onTap: () async {
            final result = await pickDateTime(
              endsAt,
            );

            if (result != null) {
              setState(() {
                endsAt = result;
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
              style: const TextStyle(
                color: Colors.red,
              ),
            ),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(
            saving ? 'Saving...' : 'Save Banner',
          ),
        ),
      ],
    );
  }
}
