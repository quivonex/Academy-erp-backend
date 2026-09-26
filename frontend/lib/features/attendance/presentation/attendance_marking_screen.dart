import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../enrollment/data/enrollment_repository.dart';
import '../../students/data/student_repository.dart';
import '../data/attendance_models.dart';
import '../data/attendance_repository.dart';

const _statusOptions = ['present', 'absent', 'late', 'excused'];

class AttendanceMarkingScreen extends ConsumerStatefulWidget {
  const AttendanceMarkingScreen({super.key});

  @override
  ConsumerState<AttendanceMarkingScreen> createState() => _AttendanceMarkingScreenState();
}

class _AttendanceMarkingScreenState extends ConsumerState<AttendanceMarkingScreen> {
  int? _batchId;
  final List<AttendanceMark> _marks = [];
  final _searchController = TextEditingController();
  bool _isSubmitting = false;
  String? _feedback;

  Future<void> _addStudent(String query) async {
    if (query.trim().isEmpty) return;
    final page = await ref.read(studentRepositoryProvider).list(search: query);
    final results = page.results;
    if (results.isEmpty || !mounted) return;
    final student = results.first;
    if (_marks.any((m) => m.studentId == student.id)) return;
    setState(() {
      _marks.add(AttendanceMark(studentId: student.id, studentName: student.fullName));
      _searchController.clear();
    });
  }

  Future<void> _submit() async {
    if (_batchId == null || _marks.isEmpty) return;
    setState(() {
      _isSubmitting = true;
      _feedback = null;
    });
    try {
      await ref.read(attendanceRepositoryProvider).submitAttendance(
            batchId: _batchId!,
            sessionDate: DateTime.now(),
            marks: _marks,
          );
      setState(() => _feedback = 'Attendance submitted successfully.');
    } on ApiException catch (e) {
      setState(() => _feedback = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(batchOptionsProvider);
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Batch Daily Attendance', style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 16),
        batchesAsync.when(
          data: (batches) => DropdownButtonFormField<int>(
            initialValue: _batchId,
            decoration: const InputDecoration(labelText: 'Batch'),
            items: [for (final b in batches) DropdownMenuItem(value: b.id, child: Text(b.name))],
            onChanged: (value) => setState(() => _batchId = value),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Could not load batches: $e'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(labelText: 'Add student by name or code', prefixIcon: Icon(Icons.person_add_outlined)),
          onSubmitted: _addStudent,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: _marks.isEmpty
                ? Center(child: Text('Add students above to build today\'s roster.', style: TextStyle(color: colors.textMuted)))
                : ListView.separated(
                    itemCount: _marks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final mark = _marks[index];
                      return ListTile(
                        title: Text(mark.studentName),
                        trailing: DropdownButton<String>(
                          value: mark.status,
                          items: [
                            for (final s in _statusOptions)
                              DropdownMenuItem(value: s, child: Text(s.toUpperCase())),
                          ],
                          onChanged: (value) => setState(() => mark.status = value ?? mark.status),
                        ),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 16),
        if (_feedback != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_feedback!)),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: (_batchId == null || _marks.isEmpty || _isSubmitting) ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save & Submit Attendance'),
          ),
        ),
      ],
    );
  }
}
