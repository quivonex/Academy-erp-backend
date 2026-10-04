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

class BannerCreateScreen extends ConsumerStatefulWidget {
  const BannerCreateScreen({super.key});

  @override
  ConsumerState<BannerCreateScreen> createState() =>
      _BannerCreateScreenState();
}

class _BannerCreateScreenState extends ConsumerState<BannerCreateScreen> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final subtitle = TextEditingController();
  final actionLabel = TextEditingController();
  final actionUrl = TextEditingController();
  final displayOrder = TextEditingController(text: '0');

  List<Course> courses = [];
  String? courseUuid;
  Uint8List? imageBytes;
  String? imageName;
  DateTime? startsAt;
  DateTime? endsAt;

  bool isActive = true;
  bool loadingCourses = false;
  bool picking = false;
  bool saving = false;
  bool created = false;

  String? courseError;
  String? error;

  bool get locked => saving || picking;
  bool get editable => !locked && !created;

  @override
  void initState() {
    super.initState();
    loadCourses();
  }

  @override
  void dispose() {
    for (final c in [
      title,
      subtitle,
      actionLabel,
      actionUrl,
      displayOrder,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> loadCourses() async {
    if (!editable || loadingCourses) return;

    setState(() {
      loadingCourses = true;
      courseError = null;
    });

    try {
      final all = <String, Course>{};
      final repository = ref.read(courseRepositoryProvider);

      for (var page = 1; ; page++) {
        final data = await repository.list(page: page);

        if (!mounted) return;

        for (final course in data.results) {
          all[course.uuid] = course;
        }

        if (page * 20 >= data.count) break;
      }

      if (!mounted) return;

      setState(() {
        courses = all.values.toList();
        if (!all.containsKey(courseUuid)) courseUuid = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => courseError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          courseError = 'Could not load courses. Please retry.';
        });
      }
    } finally {
      if (mounted) setState(() => loadingCourses = false);
    }
  }

  String? imageError(Uint8List? bytes, String? name) {
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

    setState(() => picking = true);

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: false,
        withData: true,
      );

      if (!mounted || picked == null || picked.files.isEmpty) return;

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

      if (!mounted) return;

      setState(() {
        imageBytes = file.bytes;
        imageName = file.name;
        error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          imageBytes = null;
          imageName = null;
          error = 'Could not read this image. '
              'Select a valid JPEG, PNG or WebP file.';
        });
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> pickDate(bool start) async {
    if (!editable) return;

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

      if (!mounted || date == null) return;

      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );

      if (!mounted || time == null) return;

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
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  void back() {
    if (locked) return;

    if (context.canPop()) {
      context.pop(created);
    } else {
      context.go('/banners');
    }
  }

  String? urlError(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) return null;
    if (text.length > 200) return 'Use at most 200 characters.';

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
    if (!editable ||
        loadingCourses ||
        courseError != null ||
        !form.currentState!.validate()) {
      return;
    }

    final message = imageError(imageBytes, imageName);

    if (message != null) {
      setState(() => error = message);
      return;
    }

    if (courseUuid != null && actionUrl.text.trim().isNotEmpty) {
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

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ref.read(bannerRepositoryProvider).create(
        title: title.text.trim(),
        subtitle: subtitle.text.trim(),
        imageBytes: imageBytes!,
        imageName: imageName!,
        actionLabel: actionLabel.text.trim(),
        actionUrl: actionUrl.text.trim(),
        courseUuid: courseUuid,
        displayOrder: int.parse(displayOrder.text.trim()),
        startsAt: startsAt,
        endsAt: endsAt,
        isActive: isActive,
      );

      if (!mounted) return;

      setState(() {
        created = true;
        saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Banner created successfully.'),
        ),
      );

      back();
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          error = created
              ? 'Banner created. Open the banners list to review it.'
              : 'Could not create banner. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget dateField(
      String label,
      DateTime? value,
      bool start,
      ) =>
      FieldLabel(
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
                onPressed: editable ? () => pickDate(start) : null,
                icon: const Icon(Icons.calendar_month_outlined),
              ),
              if (value != null)
                IconButton(
                  tooltip: 'Clear $label',
                  onPressed: editable
                      ? () {
                    setState(() {
                      if (start) {
                        startsAt = null;
                      } else {
                        endsAt = null;
                      }
                      error = null;
                    });
                  }
                      : null,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    Course? selected;

    for (final course in courses) {
      if (course.uuid == courseUuid) selected = course;
    }

    final publiclyEligible = selected == null ||
        (selected.isActive &&
            selected.isPublished &&
            selected.isPurchasableOnline);

    return PopScope(
      canPop: !locked,
      child: ListView(
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
          const AdminPageHeader(
            title: 'Create Banner',
            subtitle:
            'Add an image and an optional action to the home page.',
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
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Title is required.';
                        }
                        if (v.trim().length > 160) {
                          return 'Use at most 160 characters.';
                        }
                        return null;
                      },
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
                    required: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (imageBytes != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              imageBytes!,
                              height: 180,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                              const SizedBox(
                                height: 80,
                                child: Center(
                                  child: Text('Preview unavailable.'),
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
                              label: 'Select Image',
                              icon: Icons.image_outlined,
                              onPressed: editable ? pickImage : null,
                            ),
                            if (imageBytes != null)
                              AdminOutlineButton(
                                label: 'Remove',
                                icon: Icons.close,
                                onPressed: editable
                                    ? () {
                                  setState(() {
                                    imageBytes = null;
                                    imageName = null;
                                    error = null;
                                  });
                                }
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
                  FieldLabel(
                    label: 'Course (optional)',
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('${courseUuid}_${courses.length}'),
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
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: editable &&
                          !loadingCourses &&
                          courseError == null
                          ? (v) {
                        setState(() {
                          courseUuid = v;
                          if (v != null) actionUrl.clear();
                          error = null;
                        });
                      }
                          : null,
                    ),
                  ),
                  if (loadingCourses) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                  if (courseError != null) ...[
                    const SizedBox(height: 12),
                    AdminErrorBanner(message: courseError!),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: editable ? loadCourses : null,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry courses'),
                      ),
                    ),
                  ],
                  if (!publiclyEligible) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'This course banner will appear publicly only '
                          'when the course is active, published and '
                          'enabled for online purchase.',
                    ),
                  ],
                  const SizedBox(height: 16),
                  FieldLabel(
                    label: 'External action URL',
                    child: TextFormField(
                      controller: actionUrl,
                      enabled: editable && courseUuid == null,
                      maxLength: 200,
                      keyboardType: TextInputType.url,
                      validator: urlError,
                      decoration: adminFieldDecoration(
                        context,
                        hint: 'https://example.com',
                        helper: 'Use a course or an external URL.',
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
                        label: created ? 'Open Banners' : 'Cancel',
                        onPressed: locked ? null : back,
                      ),
                      if (!created)
                        GradientButton(
                          label: 'Create Banner',
                          icon: Icons.add,
                          loading: saving,
                          onPressed: editable &&
                              !loadingCourses &&
                              courseError == null
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