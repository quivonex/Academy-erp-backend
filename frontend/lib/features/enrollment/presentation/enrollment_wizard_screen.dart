import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../application/enrollment_wizard_notifier.dart';
import '../data/enrollment_repository.dart';

class EnrollmentWizardScreen extends ConsumerStatefulWidget {
  const EnrollmentWizardScreen({super.key});

  @override
  ConsumerState<EnrollmentWizardScreen> createState() => _EnrollmentWizardScreenState();
}

class _EnrollmentWizardScreenState extends ConsumerState<EnrollmentWizardScreen> {
  final _studentSearchController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  @override
  void dispose() {
    _studentSearchController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      controller.text = picked.toIso8601String().split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wizard = ref.watch(enrollmentWizardProvider);
    final coursesAsync = ref.watch(courseOptionsProvider);
    final colors = context.colors;
    final notifier = ref.read(enrollmentWizardProvider.notifier);

    if (wizard.isComplete) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: colors.success, size: 48),
          const SizedBox(height: 16),
          Text('Enrollment created', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '${wizard.studentName} has been enrolled successfully.',
            style: TextStyle(color: colors.textMuted),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: notifier.reset,
            child: const Text('Create another enrollment'),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New enrollment', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),

          if (wizard.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.dangerBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(wizard.errorMessage!, style: TextStyle(color: colors.danger)),
              ),
            ),

          Text('Student', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (wizard.studentUuid != null)
            Chip(
              label: Text(wizard.studentName ?? wizard.studentUuid!),
              onDeleted: () => notifier.setStudent(uuid: '', name: ''),
            )
          else
            TextField(
              controller: _studentSearchController,
              decoration: const InputDecoration(
                labelText: 'Search student by name',
                prefixIcon: Icon(Icons.search),
                helperText: 'Select a student from the students list first',
              ),
            ),

          const SizedBox(height: 20),
          Text('Course', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          coursesAsync.when(
            data: (courses) => DropdownButtonFormField<String>(
              value: wizard.courseUuid,
              decoration: const InputDecoration(labelText: 'Select a course'),
              items: [
                for (final course in courses)
                  DropdownMenuItem(value: course.uuid, child: Text(course.name)),
              ],
              onChanged: (uuid) {
                if (uuid != null) notifier.setCourse(uuid);
              },
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Could not load courses: $e'),
          ),

          const SizedBox(height: 20),
          Text('Dates (optional)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startDateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Start date',
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  onTap: () async {
                    await _pickDate(_startDateController);
                    notifier.setDates(startDate: _startDateController.text);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _endDateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'End date',
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  onTap: () async {
                    await _pickDate(_endDateController);
                    notifier.setDates(endDate: _endDateController.text);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: wizard.isSubmitting ? null : notifier.submit,
              child: wizard.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Enrollment'),
            ),
          ),
        ],
      ),
    );
  }
}
