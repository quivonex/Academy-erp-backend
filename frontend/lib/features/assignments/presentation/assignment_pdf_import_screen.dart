import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../courses/data/course.dart';
import '../../courses/data/course_repository.dart';

import '../data/assignment.dart';
import '../data/assignment_repository.dart';

class AssignmentPdfImportScreen extends ConsumerStatefulWidget {
  const AssignmentPdfImportScreen({
    super.key,
  });

  @override
  ConsumerState<AssignmentPdfImportScreen> createState() =>
      _AssignmentPdfImportScreenState();
}

class _AssignmentPdfImportScreenState
    extends ConsumerState<AssignmentPdfImportScreen> {
  final title = TextEditingController();
  final description = TextEditingController();
  final instructions = TextEditingController();

  Course? selectedCourse;
  List<Course> courses = [];
  bool loadingCourses = false;

  PlatformFile? selectedPdf;
  bool importing = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadCourses();
  }

  Future<void> loadCourses() async {
    setState(() {
      loadingCourses = true;
    });

    try {
      final result = await ref.read(courseRepositoryProvider).list();
      if (mounted) {
        setState(() {
          courses = result.results;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          loadingCourses = false;
        });
      }
    }
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    instructions.dispose();
    super.dispose();
  }

  Future<void> choosePdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
      ],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;

    if (file.size > 10 * 1024 * 1024) {
      setState(() {
        error = 'PDF size must not exceed 10 MB.';
      });

      return;
    }

    setState(() {
      selectedPdf = file;
      error = null;
    });
  }

  Future<void> importPdf() async {
    if (selectedCourse == null) {
      setState(() {
        error = 'Please select a course.';
      });

      return;
    }

    if (title.text.trim().isEmpty) {
      setState(() {
        error = 'Assignment title is required.';
      });

      return;
    }

    if (selectedPdf == null || selectedPdf!.bytes == null) {
      setState(() {
        error = 'Please select a PDF file.';
      });

      return;
    }

    setState(() {
      importing = true;
      error = null;
    });

    try {
      final data = await ref
          .read(
            assignmentRepositoryProvider,
          )
          .importPdf(
            courseUuid: selectedCourse!.uuid,
            title: title.text,
            description: description.text,
            instructions: instructions.text,
            pdfBytes: selectedPdf!.bytes!,
            pdfFileName: selectedPdf!.name,
          );

      final assignmentMap = Map<String, dynamic>.from(
        data['assignment'] as Map,
      );

      final assignment = Assignment.fromJson(
        assignmentMap,
      );

      if (mounted) {
        context.go(
          '/assignments/${assignment.uuid}',
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
          importing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Assignments'),
          ),
          const SizedBox(height: 8),
          Text(
            'Import Assignment from PDF',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload a PDF and the system will extract questions for review before publishing.',
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Assignment Title',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: instructions,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Instructions',
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: selectedCourse?.uuid,
                    decoration: const InputDecoration(
                      labelText: 'Course',
                    ),
                    items: courses
                        .map(
                          (course) => DropdownMenuItem<String>(
                            value: course.uuid,
                            child: Text('${course.name} (${course.code})'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedCourse = courses.firstWhere((c) => c.uuid == value);
                        error = null;
                      });
                    },
                  ),
                  if (loadingCourses) const LinearProgressIndicator(),
                  const SizedBox(height: 20),
                  const Text(
                    'PDF File',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedPdf == null
                              ? 'No PDF selected'
                              : selectedPdf!.name,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: choosePdf,
                        icon: const Icon(
                          Icons.picture_as_pdf_outlined,
                        ),
                        label: const Text(
                          'Select PDF',
                        ),
                      ),
                    ],
                  ),
                  if (selectedPdf != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${(selectedPdf!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Text('Maximum PDF size: 10 MB'),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: importing ? null : importPdf,
                    icon: const Icon(
                      Icons.upload_file,
                    ),
                    label: Text(
                      importing ? 'Importing...' : 'Import PDF',
                    ),
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
