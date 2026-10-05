import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/user_role.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../courses/data/course.dart';
import '../../courses/data/course_repository.dart';
import '../../enrollments/data/enrollment.dart';
import '../../enrollments/data/enrollment_repository.dart';
import '../../firms/data/firm_repository.dart';
import '../../firms/data/firm_admin_repository.dart';
import '../../live_classes/data/live_class.dart';
import '../../live_classes/data/live_class_repository.dart';
import '../data/dashboard_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    if (session.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (session.role == UserRole.superAdmin) {
      return const _SuperDashboard();
    }

    if ((session.role != UserRole.academyAdmin &&
        session.role != UserRole.firmStaff) ||
        (session.firmUuid ?? '').isEmpty) {
      return const AdminStateMessage(
        icon: Icons.lock_outline,
        title: 'Academy dashboard unavailable',
        message: 'Sign in with an academy admin account linked to a firm.',
      );
    }

    return _AcademyDashboard(
      key: ValueKey('${session.userUuid}_${session.firmUuid}'),
      firmName: session.firmName ?? 'Your academy',
    );
  }
}

class _SuperDashboard extends ConsumerWidget {
  const _SuperDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firms = ref.watch(firmsListProvider);
    final admins = ref.watch(allFirmAdminsProvider);

    void refresh() {
      ref.invalidate(firmsListProvider);
      ref.invalidate(allFirmAdminsProvider);
    }

    final firmList = firms.valueOrNull;
    final adminList = admins.valueOrNull;

    String value(int? number, bool failed) =>
        number?.toString() ?? (failed ? '—' : '…');

    Widget failure() => AdminStateMessage(
      icon: Icons.cloud_off,
      title: 'Could not load directory',
      message: 'Please retry.',
      actionLabel: 'Retry',
      onAction: refresh,
      isError: true,
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        AdminPageHeader(
          title: 'Academy overview',
          subtitle: 'Manage academies and firm administrators.',
          actions: [
            AdminOutlineButton(
              label: 'Refresh',
              icon: Icons.refresh,
              onPressed: refresh,
            ),
            GradientButton(
              label: 'Firms',
              onPressed: () => context.go('/firms'),
            ),
            AdminOutlineButton(
              label: 'Firm admins',
              onPressed: () => context.go('/firm-admins'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        AdminKpiGrid(
          children: [
            AdminKpiCard(
              label: 'Academies',
              value: value(firmList?.length, firms.hasError),
              icon: Icons.apartment,
            ),
            AdminKpiCard(
              label: 'Active academies',
              value: value(
                firmList?.where((f) => f.isActive).length,
                firms.hasError,
              ),
              icon: Icons.verified,
            ),
            AdminKpiCard(
              label: 'Firm admins',
              value: value(adminList?.length, admins.hasError),
              icon: Icons.admin_panel_settings,
            ),
            AdminKpiCard(
              label: 'Active admins',
              value: value(
                adminList?.where((a) => a.isActive).length,
                admins.hasError,
              ),
              icon: Icons.people,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Institutions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        firms.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (_, __) => failure(),
          data: (items) => items.isEmpty
              ? const Text('No academies registered.')
              : Column(
            children: [
              for (final firm in items.take(6))
                AdminListRow(
                  title: firm.name,
                  subtitle: '${firm.code} • ${firm.email ?? ''}',
                  icon: Icons.apartment,
                  titleBadge: ActiveBadge(active: firm.isActive),
                  onTap: () => context.push('/firms/${firm.uuid}'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Recent admins',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        admins.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (_, __) => failure(),
          data: (items) {
            final sorted = [...items]
              ..sort((a, b) => b.dateJoined.compareTo(a.dateJoined));

            if (sorted.isEmpty) {
              return const Text('No firm admins registered.');
            }

            return Column(
              children: [
                for (final admin in sorted.take(6))
                  AdminListRow(
                    title: admin.fullName,
                    subtitle: '${admin.email} • ${admin.firmName}',
                    icon: Icons.person_outline,
                    titleBadge: ActiveBadge(active: admin.isActive),
                    onTap: () => context.go('/firm-admins'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReportQuery {
  const _ReportQuery({
    this.type = DashboardReport.collection,
    this.courseUuid,
    this.courseName,
    this.status,
    this.from,
    this.to,
  });

  final DashboardReport type;
  final String? courseUuid;
  final String? courseName;
  final String? status;
  final DateTime? from;
  final DateTime? to;
}

class _AcademyDashboard extends ConsumerStatefulWidget {
  const _AcademyDashboard({
    super.key,
    required this.firmName,
  });

  final String firmName;

  @override
  ConsumerState<_AcademyDashboard> createState() =>
      _AcademyDashboardState();
}

class _AcademyDashboardState
    extends ConsumerState<_AcademyDashboard> {
  late Future<DashboardSummary> summaryFuture;
  late Future<DashboardReportPage> reportFuture;
  late Future<List<LiveClassPage>> classesFuture;
  late Future<EnrollmentPage> enrollmentsFuture;

  List<Course> courses = [];
  DashboardReport draftType = DashboardReport.collection;
  String? draftCourse;
  String? draftStatus;
  DateTime? draftFrom;
  DateTime? draftTo;

  _ReportQuery query = const _ReportQuery();
  int page = 1;

  bool loadingCourses = false;
  bool refreshing = false;
  bool picking = false;

  String? courseError;
  String? filterError;

  bool get locked => refreshing || picking;

  DashboardRepository get repo =>
      ref.read(dashboardRepositoryProvider);

  @override
  void initState() {
    super.initState();
    loadAll();
    loadCourses();
  }

  void loadAll() {
    summaryFuture = repo.summary();
    loadReport();
    loadOperations();
  }

  void loadReport() {
    reportFuture = repo.report(
      type: query.type,
      page: page,
      courseUuid: query.courseUuid,
      status: query.status,
      dateFrom: query.from,
      dateTo: query.to,
    );
  }

  void loadOperations() {
    final classes = ref.read(liveClassRepositoryProvider);

    classesFuture = Future.wait([
      classes.list(status: 'LIVE'),
      classes.list(status: 'SCHEDULED'),
    ]);

    enrollmentsFuture =
        ref.read(enrollmentManagementRepositoryProvider).list();
  }

  Future<void> refresh() async {
    if (locked) return;

    setState(() {
      refreshing = true;
      page = 1;
      loadAll();
    });

    try {
      await Future.wait<Object?>([
        summaryFuture,
        reportFuture,
        classesFuture,
        enrollmentsFuture,
      ]);
    } catch (_) {
      // Each section displays its own error and Retry action.
    } finally {
      if (mounted) {
        setState(() => refreshing = false);
      }
    }
  }

  Future<void> loadCourses() async {
    if (loadingCourses || locked) return;

    setState(() {
      loadingCourses = true;
      courseError = null;
    });

    try {
      final all = <String, Course>{};

      for (var p = 1; ; p++) {
        final data = await ref
            .read(courseRepositoryProvider)
            .list(page: p);

        if (!mounted) return;

        for (final course in data.results) {
          all[course.uuid] = course;
        }

        if (p * 20 >= data.count) break;
      }

      if (mounted) {
        setState(() {
          courses = all.values.toList();

          if (draftCourse != null &&
              !all.containsKey(draftCourse)) {
            draftCourse = null;
          }
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => courseError = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          courseError =
          'Could not load courses. Retry to use the course filter.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => loadingCourses = false);
      }
    }
  }

  void applyFilters() {
    if (locked) return;

    if (draftType.usesDates &&
        draftFrom != null &&
        draftTo != null &&
        draftTo!.isBefore(draftFrom!)) {
      setState(() {
        filterError = 'Date to must be on or after date from.';
      });
      return;
    }

    String? courseName;

    for (final course in courses) {
      if (course.uuid == draftCourse) {
        courseName = '${course.name} (${course.code})';
      }
    }

    setState(() {
      filterError = null;
      page = 1;

      query = _ReportQuery(
        type: draftType,
        courseUuid: draftCourse,
        courseName: courseName,
        status: draftType == DashboardReport.enrollments
            ? draftStatus
            : null,
        from: draftType.usesDates ? draftFrom : null,
        to: draftType.usesDates ? draftTo : null,
      );

      loadReport();
    });
  }

  void changePage(int next) {
    if (locked || next < 1) return;

    setState(() {
      page = next;
      loadReport();
    });
  }

  Future<void> pickDate(bool from) async {
    if (locked) return;
    setState(() => picking = true);

    try {
      final initial =
          (from ? draftFrom : draftTo) ?? DateTime.now();
      final day = DateTime(
        initial.year,
        initial.month,
        initial.day,
      );

      final picked = await showDatePicker(
        context: context,
        initialDate: day,
        firstDate: day.isBefore(DateTime(2000))
            ? day
            : DateTime(2000),
        lastDate: day.isAfter(DateTime(2100, 12, 31))
            ? day
            : DateTime(2100, 12, 31),
      );

      if (mounted && picked != null) {
        setState(() {
          if (from) {
            draftFrom = picked;
          } else {
            draftTo = picked;
          }
          filterError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          filterError =
          'Could not open the date picker. Please retry.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => picking = false);
      }
    }
  }

  Future<void> navigate(String route) async {
    if (locked) return;
    await context.push(route);
    if (mounted) await refresh();
  }

  Widget metrics(List<DashboardMetric> values) =>
      AdminKpiGrid(
        children: [
          for (final metric in values)
            AdminKpiCard(
              label: metric.label,
              value: metric.text,
              caption: metric.caption,
              icon: metric.money
                  ? Icons.payments_outlined
                  : Icons.analytics_outlined,
            ),
        ],
      );

  Widget dateControl(
      String label,
      DateTime? date,
      bool from,
      ) =>
      FieldLabel(
        label: label,
        child: InputDecorator(
          decoration: adminFieldDecoration(context),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(date == null ? 'No limit' : formatDate(date)),
              IconButton(
                tooltip: 'Choose $label',
                onPressed: locked ? null : () => pickDate(from),
                icon: const Icon(Icons.event),
              ),
              if (date != null)
                IconButton(
                  tooltip: 'Clear $label',
                  onPressed: locked
                      ? null
                      : () => setState(() {
                    if (from) {
                      draftFrom = null;
                    } else {
                      draftTo = null;
                    }
                    filterError = null;
                  }),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ),
      );

  Widget filters() => AdminCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormRow(
          left: FieldLabel(
            label: 'Report',
            child: DropdownButtonFormField<DashboardReport>(
              value: draftType,
              isExpanded: true,
              decoration: adminFieldDecoration(context),
              items: [
                for (final type in DashboardReport.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(type.title),
                  ),
              ],
              onChanged: locked
                  ? null
                  : (v) => setState(() {
                draftType =
                    v ?? DashboardReport.collection;
                filterError = null;
              }),
            ),
          ),
          right: FieldLabel(
            label: 'Course',
            child: DropdownButtonFormField<String>(
              key: ValueKey(
                '${draftCourse}_${courses.length}',
              ),
              value: draftCourse,
              isExpanded: true,
              decoration: adminFieldDecoration(context),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All courses'),
                ),
                for (final course in courses)
                  DropdownMenuItem(
                    value: course.uuid,
                    child: Text(
                      '${course.name} (${course.code})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: locked ||
                  loadingCourses ||
                  courseError != null
                  ? null
                  : (v) => setState(() => draftCourse = v),
            ),
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
            child: TextButton(
              onPressed: locked ? null : loadCourses,
              child: const Text('Retry courses'),
            ),
          ),
        ],
        if (draftType == DashboardReport.enrollments) ...[
          const SizedBox(height: 16),
          FieldLabel(
            label: 'Enrollment status',
            child: DropdownButtonFormField<String>(
              value: draftStatus,
              decoration: adminFieldDecoration(context),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All statuses'),
                ),
                for (final status in [
                  'PENDING',
                  'ACTIVE',
                  'COMPLETED',
                  'CANCELLED',
                ])
                  DropdownMenuItem(
                    value: status,
                    child: Text(status),
                  ),
              ],
              onChanged: locked
                  ? null
                  : (v) => setState(() => draftStatus = v),
            ),
          ),
        ],
        if (draftType.usesDates) ...[
          const SizedBox(height: 16),
          Text(
            draftType == DashboardReport.collection
                ? 'Filter by payment date'
                : 'Filter by due date',
          ),
          const SizedBox(height: 8),
          FormRow(
            left: dateControl(
              'Date from',
              draftFrom,
              true,
            ),
            right: dateControl(
              'Date to',
              draftTo,
              false,
            ),
          ),
          if (draftType == DashboardReport.dues)
            const Text(
              'A date filter excludes accounts without a due date.',
            ),
        ],
        if (filterError != null) ...[
          const SizedBox(height: 12),
          AdminErrorBanner(message: filterError!),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            GradientButton(
              label: 'Apply filters',
              icon: Icons.filter_alt_outlined,
              onPressed: locked ? null : applyFilters,
            ),
            AdminOutlineButton(
              label: 'Reset filters',
              onPressed: locked
                  ? null
                  : () {
                setState(() {
                  draftCourse = draftStatus = null;
                  draftFrom = draftTo = null;
                  filterError = null;
                });
                applyFilters();
              },
            ),
          ],
        ),
      ],
    ),
  );

  Widget reportResults() =>
      FutureBuilder<DashboardReportPage>(
        future: reportFuture,
        builder: (context, snapshot) {
          final state = adminFutureState(
            snapshot,
            noun: query.type.title,
            onRetry: () {
              if (!locked) setState(loadReport);
            },
          );

          if (state != null) return state;

          final data = snapshot.data;
          if (data == null) {
            return const Text('Report unavailable.');
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                query.type.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Applied: ${query.courseName ?? 'All courses'}'
                    '${query.status == null ? '' : ' • ${query.status}'}'
                    '${query.type.usesDates ? ' • ${query.from == null ? 'Any start date' : formatDate(query.from!)} to ${query.to == null ? 'Any end date' : formatDate(query.to!)}' : ''}',
              ),
              const SizedBox(height: 16),
              metrics(data.metrics),
              const SizedBox(height: 16),
              if (data.rows.isEmpty)
                AdminStateMessage(
                  icon: Icons.search_off,
                  title: data.count == 0
                      ? 'No matching records'
                      : 'No records on this page',
                  message:
                  'Adjust filters, refresh or use a previous page.',
                ),
              for (final row in data.rows) ...[
                AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.title,
                        style:
                        Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(row.subtitle),
                      if ((row.status ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SoftBadge(label: row.status!),
                      ],
                      const SizedBox(height: 8),
                      for (final detail in row.details)
                        Text(detail),
                      if (row.route != null)
                        TextButton.icon(
                          onPressed: locked
                              ? null
                              : () => navigate(row.route!),
                          icon: const Icon(Icons.open_in_new),
                          label: Text(
                            query.type == DashboardReport.grading
                                ? 'Open submissions'
                                : 'Open details',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              IgnorePointer(
                ignoring: locked,
                child: AdminPager(
                  page: page,
                  pageSize: DashboardRepository.pageSize,
                  total: data.count,
                  noun: 'records',
                  onPage: changePage,
                ),
              ),
            ],
          );
        },
      );

  Widget operations() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Live and scheduled class preview',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      FutureBuilder<List<LiveClassPage>>(
        future: classesFuture,
        builder: (context, snapshot) {
          final state = adminFutureState(
            snapshot,
            noun: 'classes',
            onRetry: () {
              if (!locked) setState(loadOperations);
            },
          );

          if (state != null) return state;

          final items = (snapshot.data ?? [])
              .expand((p) => p.results)
              .where((c) => c.isActive)
              .take(5)
              .toList();

          if (items.isEmpty) {
            return const Text(
              'No classes in the current preview.',
            );
          }

          return Column(
            children: [
              for (final c in items)
                AdminListRow(
                  title: c.title,
                  subtitle: '${c.courseName} • ${c.teacherName}',
                  icon: Icons.sensors,
                  titleBadge: SoftBadge(label: c.status),
                  meta: [
                    Text(
                      formatDate(
                        c.scheduledAt.toLocal(),
                      ),
                    ),
                  ],
                  onTap: locked
                      ? null
                      : () => navigate(
                    '/live-classes/${c.uuid}',
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 24),
      Text(
        'Recent enrollments',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      FutureBuilder<EnrollmentPage>(
        future: enrollmentsFuture,
        builder: (context, snapshot) {
          final state = adminFutureState(
            snapshot,
            noun: 'enrollments',
            onRetry: () {
              if (!locked) setState(loadOperations);
            },
          );

          if (state != null) return state;

          final items =
              snapshot.data?.results ?? <Enrollment>[];

          if (items.isEmpty) {
            return const Text('No enrollments yet.');
          }

          return Column(
            children: [
              for (final e in items.take(6))
                AdminListRow(
                  title: e.studentName,
                  subtitle: e.courseName,
                  icon: Icons.how_to_reg,
                  titleBadge: SoftBadge(label: e.status),
                  onTap: locked
                      ? null
                      : () => navigate(
                    '/enrollments/${e.uuid}',
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !locked,
    child: RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          AdminPageHeader(
            title: widget.firmName,
            subtitle: 'Academy overview and reports',
            actions: [
              AdminOutlineButton(
                label: refreshing ? 'Refreshing...' : 'Refresh',
                icon: Icons.refresh,
                onPressed: locked ? null : refresh,
              ),
            ],
          ),
          const SizedBox(height: 24),
          FutureBuilder<DashboardSummary>(
            future: summaryFuture,
            builder: (context, snapshot) {
              final state = adminFutureState(
                snapshot,
                noun: 'dashboard summary',
                onRetry: () {
                  if (!locked) {
                    setState(() {
                      summaryFuture = repo.summary();
                    });
                  }
                },
              );

              if (state != null) return state;

              return snapshot.data == null
                  ? const Text('Summary unavailable.')
                  : metrics(snapshot.data!.metrics);
            },
          ),
          const SizedBox(height: 24),
          AdminCard(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final entry in {
                  'Students': '/students',
                  'Teachers': '/teachers',
                  'Staff': '/staff',
                  'Courses': '/courses',
                  'Enrollments': '/enrollments',
                  'Fees': '/fees',
                  'Live classes': '/live-classes',
                  'Materials': '/materials',
                  'Assignments': '/assignments',
                  'Banners': '/banners',
                }.entries)
                  AdminOutlineButton(
                    label: entry.key,
                    onPressed: locked
                        ? null
                        : () => navigate(entry.value),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          filters(),
          const SizedBox(height: 24),
          reportResults(),
          const SizedBox(height: 28),
          operations(),
        ],
      ),
    ),
  );
}