import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/assignment_submission.dart';
import '../data/assignment_repository.dart';

class AssignmentSubmissionsScreen
    extends ConsumerStatefulWidget {
  const AssignmentSubmissionsScreen({
    super.key,
    required this.assignmentUuid,
  });

  final String assignmentUuid;

  @override
  ConsumerState<AssignmentSubmissionsScreen>
      createState() =>
          _AssignmentSubmissionsScreenState();
}

class _AssignmentSubmissionsScreenState
    extends ConsumerState<
        AssignmentSubmissionsScreen> {
  late Future<AssignmentSubmissionPage> result;

  String? statusFilter;

  int page = 1;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result = ref
        .read(assignmentRepositoryProvider)
        .submissions(
          assignmentUuid:
              widget.assignmentUuid,
          status: statusFilter,
          page: page,
        );
  }

  void refresh() {
    setState(reload);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => context.pop(),
          icon:
              const Icon(Icons.arrow_back),
          label:
              const Text('Assignment'),
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: Text(
                'Student Submissions',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall,
              ),
            ),

            SizedBox(
              width: 180,
              child:
                  DropdownButtonFormField<
                      String>(
                value:
                    statusFilter ?? 'ALL',
                decoration:
                    const InputDecoration(
                  labelText: 'Status',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'ALL',
                    child: Text('All'),
                  ),
                  DropdownMenuItem(
                    value: 'SUBMITTED',
                    child:
                        Text('Submitted'),
                  ),
                  DropdownMenuItem(
                    value: 'GRADED',
                    child: Text('Graded'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    statusFilter =
                        value == 'ALL'
                            ? null
                            : value;

                    page = 1;

                    reload();
                  });
                },
              ),
            ),

            IconButton(
              onPressed: refresh,
              icon:
                  const Icon(Icons.refresh),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Expanded(
          child: FutureBuilder<
              AssignmentSubmissionPage>(
            future: result,
            builder: (
              context,
              snapshot,
            ) {
              if (snapshot.connectionState !=
                  ConnectionState.done) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not load submissions:\n'
                    '${snapshot.error}',
                  ),
                );
              }

              final data =
                  snapshot.data!;

              if (data.results.isEmpty) {
                return const Center(
                  child: Text(
                    'No student submissions found.',
                  ),
                );
              }

              return ListView.builder(
                itemCount:
                    data.results.length,
                itemBuilder:
                    (context, index) {
                  final submission =
                      data.results[index];

                  return Card(
                    child: ListTile(
                      leading:
                          const CircleAvatar(
                        child: Icon(
                          Icons.person_outline,
                        ),
                      ),

                      title: Text(
                        submission.studentName,
                      ),

                      subtitle: Text(
                        '${submission.admissionNumber}'
                        '\n'
                        'Submitted: ${_date(submission.submittedAt)}',
                      ),

                      isThreeLine: true,

                      trailing: Column(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                        crossAxisAlignment:
                            CrossAxisAlignment.end,
                        children: [
                          Chip(
                            label: Text(
                              submission.status,
                            ),
                          ),

                          if (submission
                                  .totalMarksObtained !=
                              null)
                            Text(
                              '${submission.totalMarksObtained} marks',
                            ),
                        ],
                      ),

                      onTap: () async {
                        await context.push(
                          '/assignments/'
                          '${widget.assignmentUuid}'
                          '/submissions/'
                          '${submission.uuid}',
                        );

                        if (mounted) {
                          refresh();
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

String _date(DateTime? value) {
  if (value == null) {
    return '—';
  }

  final local = value.toLocal();

  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year}';
}
