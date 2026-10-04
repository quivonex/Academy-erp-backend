import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../courses/data/course.dart';
import '../../courses/data/course_repository.dart';
import '../data/assignment_repository.dart';

class AssignmentPdfImportScreen extends ConsumerStatefulWidget {
  const AssignmentPdfImportScreen({super.key});

  @override
  ConsumerState<AssignmentPdfImportScreen> createState() =>
      _AssignmentPdfImportScreenState();
}

class _AssignmentPdfImportScreenState
    extends ConsumerState<AssignmentPdfImportScreen> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final instructions = TextEditingController();

  List<Course> courses = [];
  String? courseUuid;
  PlatformFile? selectedPdf;

  bool loadingCourses = false;
  bool picking = false;
  bool importing = false;
  bool imported = false;

  String? importedUuid;
  String? courseError;
  String? error;

  bool get locked => importing || picking;

  @override
  void initState() {
    super.initState();
    loadCourses();
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    instructions.dispose();
    super.dispose();
  }

  Future<void> loadCourses() async {
    if (loadingCourses || locked || imported) return;

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
          if (course.isActive) {
            all[course.uuid] = course;
          }
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

  String? pdfError(PlatformFile? file) {
    if (file == null) return 'Please select a PDF file.';

    final bytes = file.bytes;

    if (!file.name.toLowerCase().endsWith('.pdf')) {
      return 'Only PDF files are allowed.';
    }

    if (bytes == null || bytes.isEmpty) {
      return 'Could not read this PDF. Select the file again.';
    }

    if (file.size > 10 * 1024 * 1024 ||
        bytes.length > 10 * 1024 * 1024) {
      return 'PDF size must not exceed 10 MB.';
    }

    const header = [0x25, 0x50, 0x44, 0x46, 0x2D];

    if (bytes.length < header.length) {
      return 'Selected file is not a valid PDF.';
    }

    for (var i = 0; i < header.length; i++) {
      if (bytes[i] != header[i]) {
        return 'Selected file is not a valid PDF.';
      }
    }

    return null;
  }

  Future<void> choosePdf() async {
    if (locked || imported) return;

    setState(() => picking = true);

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: true,
      );

      if (!mounted || picked == null || picked.files.isEmpty) return;

      final file = picked.files.single;
      final message = pdfError(file);

      setState(() {
        selectedPdf = message == null ? file : null;
        error = message;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Could not select PDF. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  void back() {
    if (locked) return;

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/assignments');
    }
  }

  void reviewImport() {
    if (locked) return;

    context.go(
      importedUuid == null
          ? '/assignments'
          : '/assignments/$importedUuid',
    );
  }

  Future<void> importPdf() async {
    if (locked ||
        imported ||
        loadingCourses ||
        courseError != null) {
      return;
    }

    if (!form.currentState!.validate()) return;

    final message = pdfError(selectedPdf);

    if (message != null) {
      setState(() => error = message);
      return;
    }

    setState(() {
      importing = true;
      error = null;
    });

    try {
      final data = await ref.read(assignmentRepositoryProvider).importPdf(
        courseUuid: courseUuid!,
        title: title.text.trim(),
        description: description.text.trim(),
        instructions: instructions.text.trim(),
        pdfBytes: selectedPdf!.bytes!,
        pdfFileName: selectedPdf!.name,
      );

      if (!mounted) return;

      // The request succeeded; prevent another POST
      // even if navigation fails.
      setState(() => imported = true);

      final assignment = data['assignment'];
      final uuid = assignment is Map
          ? assignment['uuid']?.toString() ?? ''
          : '';

      if (!RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
        r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(uuid)) {
        setState(() {
          error = 'PDF imported, but its detail link was unavailable. '
              'Open the assignments list to review it.';
        });
        return;
      }

      setState(() => importedUuid = uuid);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PDF imported. Review questions before publishing.',
          ),
        ),
      );

      context.go('/assignments/$uuid');
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          error = imported
              ? 'PDF imported. Open the assignment to review it.'
              : 'Could not import PDF. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editable = !locked && !imported;

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
              label: const Text('Assignments'),
            ),
          ),
          const SizedBox(height: 12),
          const AdminPageHeader(
            title: 'Import Assignment from PDF',
            subtitle:
            'Upload a PDF, then review the extracted questions before publishing.',
            eyebrow: AdminEyebrow(
              section: 'Evaluation hub',
              detail: 'PDF import',
            ),
          ),
          const SizedBox(height: 24),
          AdminCard(
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FieldLabel(
                    label: 'Course',
                    required: true,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('${courseUuid}_${courses.length}'),
                      value: courseUuid,
                      isExpanded: true,
                      decoration: adminFieldDecoration(
                        context,
                        hint: 'Choose an active course',
                      ),
                      items: [
                        for (final course in courses)
                          DropdownMenuItem(
                            value: course.uuid,
                            child: Text(
                              '${course.name} (${course.code})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: editable &&
                          !loadingCourses &&
                          courseError == null
                          ? (value) {
                        setState(() {
                          courseUuid = value;
                          error = null;
                        });
                      }
                          : null,
                      validator: (v) =>
                      v == null || !courses.any((c) => c.uuid == v)
                          ? 'Please select an active course.'
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
                  if (!loadingCourses &&
                      courseError == null &&
                      courses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'No active courses available. '
                            'Create or activate a course first.',
                      ),
                    ),
                  const SizedBox(height: 16),
                  FieldLabel(
                    label: 'Assignment title',
                    required: true,
                    child: TextFormField(
                      controller: title,
                      enabled: editable,
                      maxLength: 255,
                      decoration: adminFieldDecoration(
                        context,
                        hint: 'Assignment title',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Title is required.';
                        }
                        if (v.trim().length > 255) {
                          return 'Use at most 255 characters.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  FieldLabel(
                    label: 'Description',
                    child: TextFormField(
                      controller: description,
                      enabled: editable,
                      minLines: 2,
                      maxLines: 4,
                      decoration: adminFieldDecoration(
                        context,
                        hint: 'Optional description',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FieldLabel(
                    label: 'Instructions',
                    child: TextFormField(
                      controller: instructions,
                      enabled: editable,
                      minLines: 3,
                      maxLines: 6,
                      decoration: adminFieldDecoration(
                        context,
                        hint: 'Instructions for students',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FieldLabel(
                    label: 'PDF file',
                    required: true,
                    child: AdminCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(selectedPdf?.name ?? 'No PDF selected'),
                          if (selectedPdf != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${(selectedPdf!.bytes!.length / 1024 / 1024).toStringAsFixed(2)} MB',
                            ),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              AdminOutlineButton(
                                label: picking
                                    ? 'Selecting...'
                                    : 'Select PDF',
                                icon: Icons.picture_as_pdf_outlined,
                                onPressed: editable ? choosePdf : null,
                              ),
                              if (selectedPdf != null)
                                AdminOutlineButton(
                                  label: 'Remove',
                                  icon: Icons.close,
                                  onPressed: editable
                                      ? () {
                                    setState(() {
                                      selectedPdf = null;
                                      error = null;
                                    });
                                  }
                                      : null,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Maximum size: 10 MB. Use a PDF with selectable text. '
                        'Scanned PDFs need OCR before import. '
                        'MCQs must include correct answers.',
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    AdminErrorBanner(message: error!),
                  ],
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (!imported)
                        GradientButton(
                          label: 'Import PDF',
                          icon: Icons.upload_file,
                          loading: importing,
                          onPressed: editable &&
                              !loadingCourses &&
                              courseError == null &&
                              courses.isNotEmpty
                              ? importPdf
                              : null,
                        ),
                      if (imported)
                        GradientButton(
                          label: importedUuid == null
                              ? 'Open Assignments'
                              : 'Review Assignment',
                          icon: Icons.assignment_outlined,
                          onPressed: locked ? null : reviewImport,
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