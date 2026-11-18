import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
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
    if (_marks.any((m) => m.studentUuid == student.uuid)) return;
    setState(() {
      _marks.add(AttendanceMark(studentUuid: student.uuid, studentName: student.fullName));
      _searchController.clear();
    });
  }

  Future<void> _submit() async {
    if (_marks.isEmpty) return;
    setState(() {
      _isSubmitting = true;
      _feedback = null;
    });
    try {
      await ref.read(attendanceRepositoryProvider).submitAttendance(
            courseUuid: '',
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
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily Attendance', style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.warningBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: colors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Attendance tracking is coming soon. The backend module is under development.',
                  style: TextStyle(fontSize: 13, color: colors.warning),
                ),
              ),
            ],
          ),
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
            onPressed: (_marks.isEmpty || _isSubmitting) ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save & Submit Attendance'),
          ),
        ),
      ],
    );
  }
}
