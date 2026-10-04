import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
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

class _BannerDetailScreenState
    extends ConsumerState<BannerDetailScreen> {
  final form = GlobalKey<FormState>();

  final title = TextEditingController();
  final subtitle = TextEditingController();
  final actionLabel = TextEditingController();
  final actionUrl = TextEditingController();
  final displayOrder = TextEditingController(text: '0');

  List<Course> courses = [];

  String? courseUuid;
  String? existingCourseName;
  Uint8List? imageBytes;
  String? imageName;
  DateTime? startsAt;
  DateTime? endsAt;

  bool isActive = true;
  bool loadingCourses = false;
  bool picking = false;
  bool saving = false;
  bool deleting = false;
  bool deleted = false;
  bool changed = false;
  bool courseChanged = false;

  int revision = 0;

  late Future<HomeBanner> bannerFuture;

  String? courseError;
  String? error;

  bool get locked => saving || picking || deleting;
  bool get editable => !locked && !deleted;

  bool get hasCourse =>
      courseUuid != null ||
          (!courseChanged && existingCourseName != null);

  bool current(int ticket) =>
      mounted && ticket == revision;

  @override
  void initState() {
    super.initState();
    reload();
    loadCourses();
  }

  @override
  void didUpdateWidget(
      covariant BannerDetailScreen oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.bannerUuid != widget.bannerUuid) {
      revision++;

      saving = picking = deleting = deleted = changed = false;
      loadingCourses = false;

      error = courseError = null;
      imageBytes = null;
      imageName = null;
      courseUuid = existingCourseName = null;
      courseChanged = false;

      reload();
      loadCourses();
    }
  }

  void initialise(HomeBanner banner) {
    title.text = banner.title;
    subtitle.text = banner.subtitle;
    actionLabel.text = banner.actionLabel;
    actionUrl.text = banner.actionUrl;
    displayOrder.text = banner.displayOrder.toString();

    startsAt = banner.startsAt?.toLocal();
    endsAt = banner.endsAt?.toLocal();
    isActive = banner.isActive;
    existingCourseName = banner.courseName;

    courseChanged = false;
    courseUuid = null;
    imageBytes = null;
    imageName = null;
  }

  void reload() {
    final ticket = revision;

    bannerFuture = ref
        .read(bannerRepositoryProvider)
        .detail(widget.bannerUuid)
        .then((banner) {
      if (current(ticket)) initialise(banner);
      return banner;
    });
  }

  @override
  void dispose() {
    for (final controller in [
      title,
      subtitle,
      actionLabel,
      actionUrl,
      displayOrder,
    ]) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> loadCourses() async {
    if (!editable || loadingCourses) return;

    final ticket = revision;

    setState(() {
      loadingCourses = true;
      courseError = null;
    });

    try {
      final all = <String, Course>{};
      final repository = ref.read(courseRepositoryProvider);

      for (var page = 1; ; page++) {
        final data = await repository.list(page: page);

        if (!current(ticket)) return;

        for (final course in data.results) {
          all[course.uuid] = course;
        }

        if (page * 20 >= data.count) break;
      }

      if (!current(ticket)) return;

      setState(() {
        courses = all.values.toList();

        if (!all.containsKey(courseUuid)) {
          courseUuid = null;
        }
      });
    } on ApiException catch (e) {
      if (current(ticket)) {
        setState(() => courseError = e.message);
      }
    } catch (_) {
      if (current(ticket)) {
        setState(() {
          courseError = 'Could not load courses. Please retry.';
        });
      }
    } finally {
      if (current(ticket)) {
        setState(() => loadingCourses = false);
      }
    }
  }

  String? imageError(
      Uint8List? bytes,
      String? name,
      ) {
    if (bytes == null || name == null || bytes.isEmpty) {
      return 'Please select a banner image.';
    }

    if (bytes.length > 5 * 1024 * 1024) {
      return 'Image size must not exceed 5 MB.';
    }

    final ext = name.toLowerCase().split('.').last;

    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      return 'Use a JPEG, PNG or WebP image.';
    }

    bool prefix(List<int> expected) {
      if (bytes.length < expected.length) return false;

      for (var i = 0; i < expected.length; i++) {
        if (bytes[i] != expected[i]) return false;
      }

      return true;
    }

    final jpeg = prefix([0xFF, 0xD8, 0xFF]);

    final png = prefix([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]);

    final webp = bytes.length >= 12 &&
        prefix([0x52, 0x49, 0x46, 0x46]) &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;

    if ((['jpg', 'jpeg'].contains(ext) && jpeg) ||
        (ext == 'png' && png) ||
        (ext == 'webp' && webp)) {
      return null;
    }

    return 'Image contents do not match its file type.';
  }

  Future<void> pickImage() async {
    if (!editable) return;

    final ticket = revision;
    setState(() => picking = true);

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: false,
        withData: true,
      );

      if (!current(ticket) ||
          picked == null ||
          picked.files.isEmpty) {
        return;
      }

      final file = picked.files.single;

      final message = file.size > 5 * 1024 * 1024
          ? 'Image size must not exceed 5 MB.'
          : imageError(file.bytes, file.name);

      if (message != null) {
        setState(() {
          imageBytes = null;
          imageName = null;
          error = message;
        });
        return;
      }

      final codec = await ui.instantiateImageCodec(
        file.bytes!,
        targetWidth: 1,
        targetHeight: 1,
      );

      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }

      if (!current(ticket)) return;

      setState(() {
        imageBytes = file.bytes;
        imageName = file.name;
        error = null;
      });
    } catch (_) {
      if (current(ticket)) {
        setState(() {
          imageBytes = null;
          imageName = null;
          error = 'Could not read this image. '
              'Select a valid JPEG, PNG or WebP file.';
        });
      }
    } finally {
      if (current(ticket)) {
        setState(() => picking = false);
      }
    }
  }

  Future<void> pickDate(bool start) async {
    if (!editable) return;

    final ticket = revision;
    setState(() => picking = true);

    try {
      final initial =
          (start ? startsAt : endsAt) ?? DateTime.now();

      final day = DateTime(
        initial.year,
        initial.month,
        initial.day,
      );

      final date = await showDatePicker(
        context: context,
        initialDate: day,
        firstDate: day.isBefore(DateTime(2000))
            ? day
            : DateTime(2000),
        lastDate: day.isAfter(DateTime(2100, 12, 31))
            ? day
            : DateTime(2100, 12, 31),
      );

      if (!current(ticket) || date == null) return;

      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );

      if (!current(ticket) || time == null) return;

      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

      setState(() {
        if (start) {
          startsAt = value;
        } else {
          endsAt = value;
        }
        error = null;
      });
    } catch (_) {
      if (current(ticket)) {
        setState(() {
          error = 'Could not open the date picker. Please retry.';
        });
      }
    } finally {
      if (current(ticket)) {
        setState(() => picking = false);
      }
    }
  }

  void back() {
    if (locked) return;

    if (context.canPop()) {
      context.pop(changed || deleted);
    } else {
      context.go('/banners');
    }
  }

  String? urlError(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) return null;

    if (text.length > 200) {
      return 'Use at most 200 characters.';
    }

    final uri = Uri.tryParse(text);

    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !['http', 'https'].contains(uri.scheme.toLowerCase())) {
      return 'Enter a valid HTTP or HTTPS URL.';
    }

    return null;
  }

  String? orderError(String? value) {
    final text = value?.trim() ?? '';
    final number = int.tryParse(text);

    if (!RegExp(r'^\d+$').hasMatch(text) ||
        number == null ||
        number < 0 ||
        number > 2147483647) {
      return 'Enter a whole number from 0 to 2147483647.';
    }

    return null;
  }

  Future<void> save() async {
    if (!editable || form.currentState?.validate() != true) {
      return;
    }

    if (courseChanged &&
        (loadingCourses || courseError != null)) {
      return;
    }

    if (hasCourse && actionUrl.text.trim().isNotEmpty) {
      setState(() {
        error = 'Choose either a course or an external URL.';
      });
      return;
    }

    if (startsAt != null &&
        endsAt != null &&
        !endsAt!.isAfter(startsAt!)) {
      setState(() {
        error = 'End date must be after start date.';
      });
      return;
    }

    final ticket = revision;

    setState(() {
      saving = true;
      error = null;
    });

    try {
      final updated =
      await ref.read(bannerRepositoryProvider).update(
        uuid: widget.bannerUuid,
        title: title.text.trim(),
        subtitle: subtitle.text.trim(),
        imageBytes: imageBytes,
        imageName: imageName,
        actionLabel: actionLabel.text.trim(),
        actionUrl: actionUrl.text.trim(),
        courseUuid: courseUuid,
        updateCourse: courseChanged,
        displayOrder: int.parse(displayOrder.text.trim()),
        startsAt: startsAt,
        endsAt: endsAt,
        isActive: isActive,
      );

      if (!current(ticket)) return;

      setState(() {
        initialise(updated);
        bannerFuture = Future.value(updated);
        changed = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Banner updated successfully.'),
        ),
      );
    } on ApiException catch (e) {
      if (current(ticket)) {
        setState(() => error = e.message);
      }
    } catch (_) {
      if (current(ticket)) {
        setState(() {
          error = 'Could not update banner. Please try again.';
        });
      }
    } finally {
      if (current(ticket)) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> deleteBanner() async {
    if (!editable) return;

    final ticket = revision;

    setState(() {
      deleting = true;
      error = null;
    });

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete banner?'),
          content: const Text(
            'The banner and its image will be permanently deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                false,
              ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                true,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (!current(ticket) || confirmed != true) return;

      await ref
          .read(bannerRepositoryProvider)
          .delete(widget.bannerUuid);

      if (!current(ticket)) return;

      setState(() {
        deleted = true;
        changed = true;
        deleting = false;
      });

      back();
    } on ApiException catch (e) {
      if (current(ticket)) {
        setState(() => error = e.message);
      }
    } catch (_) {
      if (current(ticket)) {
        setState(() {
          error = deleted
              ? 'Banner deleted. Return to the banners list.'
              : 'Could not delete banner. Please retry.';
        });
      }
    } finally {
      if (current(ticket)) {
        setState(() => deleting = false);
      }
    }
  }

  Widget dateField(
      String label,
      DateTime? value,
      bool start,
      ) {
    return FieldLabel(
      label: label,
      child: InputDecorator(
        decoration: adminFieldDecoration(context),
        child: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(_date(value)),
            IconButton(
              tooltip: 'Choose $label',
              onPressed: editable
                  ? () => pickDate(start)
                  : null,
              icon: const Icon(Icons.calendar_month_outlined),
            ),
            if (value != null)
              IconButton(
                tooltip: 'Clear $label',
                onPressed: editable
                    ? () => setState(() {
                  if (start) {
                    startsAt = null;
                  } else {
                    endsAt = null;
                  }
                  error = null;
                })
                    : null,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Course? selected;

    for (final course in courses) {
      if (course.uuid == courseUuid) {
        selected = course;
      }
    }

    final publiclyEligible = selected == null ||
        (selected.isActive &&
            selected.isPublished &&
            selected.isPurchasableOnline);

    return PopScope(
      canPop: !locked,
      child: FutureBuilder<HomeBanner>(
        future: bannerFuture,
        builder: (context, snapshot) {
          if (deleted) {
            return Center(
              child: AdminOutlineButton(
                label: 'Open Banners',
                onPressed: back,
              ),
            );
          }

          final state = adminFutureState(
            snapshot,
            noun: 'banner',
            onRetry: () => setState(reload),
          );

          if (state != null) return state;

          final banner = snapshot.data;

          if (banner == null) {
            return const Center(
              child: Text('Banner unavailable.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: locked ? null : back,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Banners'),
                ),
              ),
              const SizedBox(height: 12),
              AdminPageHeader(
                title: 'Banner Details',
                subtitle: 'Edit the image, action and schedule.',
                actions: [
                  AdminOutlineButton(
                    label: deleting ? 'Deleting...' : 'Delete',
                    icon: Icons.delete_outline,
                    danger: true,
                    onPressed: editable ? deleteBanner : null,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AdminCard(
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FieldLabel(
                        label: 'Title',
                        required: true,
                        child: TextFormField(
                          controller: title,
                          enabled: editable,
                          maxLength: 160,
                          decoration: adminFieldDecoration(
                            context,
                            hint: 'Banner title',
                          ),
                          validator: (v) =>
                          v == null || v.trim().isEmpty
                              ? 'Title is required.'
                              : v.trim().length > 160
                              ? 'Use at most 160 characters.'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FieldLabel(
                        label: 'Subtitle',
                        child: TextFormField(
                          controller: subtitle,
                          enabled: editable,
                          minLines: 2,
                          maxLines: 4,
                          decoration: adminFieldDecoration(
                            context,
                            hint: 'Optional subtitle',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FieldLabel(
                        label: 'Banner image',
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                          children: [
                            if (imageBytes == null &&
                                banner.imageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius:
                                BorderRadius.circular(12),
                                child: Image.network(
                                  banner.imageUrl,
                                  height: 180,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                  const SizedBox(
                                    height: 80,
                                    child: Center(
                                      child: Text(
                                        'Preview unavailable.',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (imageBytes != null) ...[
                              ClipRRect(
                                borderRadius:
                                BorderRadius.circular(12),
                                child: Image.memory(
                                  imageBytes!,
                                  height: 180,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                  const SizedBox(
                                    height: 80,
                                    child: Center(
                                      child: Text(
                                        'Preview unavailable.',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(imageName!),
                              Text(
                                '${(imageBytes!.length / 1024 / 1024).toStringAsFixed(2)} MB',
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                AdminOutlineButton(
                                  label: 'Replace Image',
                                  icon: Icons.image_outlined,
                                  onPressed:
                                  editable ? pickImage : null,
                                ),
                                if (imageBytes != null)
                                  AdminOutlineButton(
                                    label: 'Keep Saved Image',
                                    icon: Icons.close,
                                    onPressed: editable
                                        ? () => setState(() {
                                      imageBytes = null;
                                      imageName = null;
                                      error = null;
                                    })
                                        : null,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'JPEG, PNG or WebP. Maximum size: 5 MB.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (!courseChanged &&
                          existingCourseName != null) ...[
                        Text(
                          'Current course: $existingCourseName',
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: editable
                                ? () => setState(() {
                              courseChanged = true;
                              courseUuid = null;
                            })
                                : null,
                            child: const Text(
                              'Change / remove course',
                            ),
                          ),
                        ),
                      ],
                      if (courseChanged &&
                          existingCourseName != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: editable
                                ? () => setState(() {
                              courseChanged = false;
                              courseUuid = null;
                              actionUrl.clear();
                              error = null;
                            })
                                : null,
                            child: const Text(
                              'Keep current course',
                            ),
                          ),
                        ),
                      if (courseChanged ||
                          existingCourseName == null)
                        FieldLabel(
                          label: 'Course (optional)',
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(
                              '${courseUuid}_${courses.length}',
                            ),
                            value: courseUuid,
                            isExpanded: true,
                            decoration: adminFieldDecoration(
                              context,
                              hint: 'No course action',
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('No course action'),
                              ),
                              for (final course in courses)
                                DropdownMenuItem(
                                  value: course.uuid,
                                  child: Text(
                                    '${course.name} (${course.code})'
                                        '${course.isActive ? '' : ' — inactive'}',
                                    overflow:
                                    TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: editable &&
                                !loadingCourses &&
                                courseError == null
                                ? (v) => setState(() {
                              courseChanged = true;
                              courseUuid = v;

                              if (v != null) {
                                actionUrl.clear();
                              }

                              error = null;
                            })
                                : null,
                          ),
                        ),
                      if (loadingCourses) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(),
                      ],
                      if (courseError != null) ...[
                        const SizedBox(height: 12),
                        AdminErrorBanner(
                          message: courseError!,
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed:
                            editable ? loadCourses : null,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry courses'),
                          ),
                        ),
                      ],
                      if (!publiclyEligible) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'This course banner will appear publicly '
                              'only when the course is active, published '
                              'and enabled for online purchase.',
                        ),
                      ],
                      const SizedBox(height: 16),
                      FieldLabel(
                        label: 'External action URL',
                        child: TextFormField(
                          controller: actionUrl,
                          enabled: editable && !hasCourse,
                          maxLength: 200,
                          keyboardType: TextInputType.url,
                          validator: urlError,
                          decoration: adminFieldDecoration(
                            context,
                            hint: 'https://example.com',
                            helper:
                            'Use a course or an external URL.',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FieldLabel(
                        label: 'Action label',
                        child: TextFormField(
                          controller: actionLabel,
                          enabled: editable,
                          maxLength: 60,
                          decoration: adminFieldDecoration(
                            context,
                            hint: 'View Course',
                          ),
                          validator: (v) =>
                          (v?.trim().length ?? 0) > 60
                              ? 'Use at most 60 characters.'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FieldLabel(
                        label: 'Display order',
                        required: true,
                        child: TextFormField(
                          controller: displayOrder,
                          enabled: editable,
                          keyboardType: TextInputType.number,
                          validator: orderError,
                          decoration: adminFieldDecoration(
                            context,
                            hint: '0',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      dateField('Starts at', startsAt, true),
                      const SizedBox(height: 16),
                      dateField('Ends at', endsAt, false),
                      const SizedBox(height: 8),
                      const Text(
                        'Dates use local time. Clear a date '
                            'to remove that schedule limit.',
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: isActive,
                        onChanged: editable
                            ? (v) => setState(() => isActive = v)
                            : null,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        AdminErrorBanner(message: error!),
                      ],
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          AdminOutlineButton(
                            label: 'Back to Banners',
                            onPressed: locked ? null : back,
                          ),
                          GradientButton(
                            label: 'Save Changes',
                            icon: Icons.save_outlined,
                            loading: saving,
                            onPressed: editable &&
                                (!courseChanged ||
                                    (!loadingCourses &&
                                        courseError == null))
                                ? save
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _date(DateTime? value) {
  if (value == null) return 'Not set';

  final d = value.toLocal();

  String two(int n) => n.toString().padLeft(2, '0');

  return '${two(d.day)}/${two(d.month)}/${d.year} '
      '${two(d.hour)}:${two(d.minute)}';
}