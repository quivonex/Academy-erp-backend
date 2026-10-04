import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/login_screen.dart';
import '../../features/courses/presentation/course_detail_screen.dart';
import '../../features/courses/presentation/courses_list_screen.dart';
import '../../features/course_categories/presentation/course_categories_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/firms/presentation/all_firm_admins_screen.dart';
import '../../features/firms/presentation/firm_detail_screen.dart';
import '../../features/firms/presentation/firms_list_screen.dart';
import '../../features/firms/presentation/super_admin_profile_screen.dart';
import '../../features/student_portal/presentation/explore_screen.dart';
import '../../features/student_portal/presentation/my_courses_screen.dart';
import '../../features/student_portal/presentation/student_register_screen.dart';
import '../../features/student_portal/presentation/student_shell.dart';
import '../../features/students/presentation/student_profile_screen.dart';
import '../../features/students/presentation/students_directory_screen.dart';
import '../../features/teachers/presentation/teacher_detail_screen.dart';
import '../../features/teachers/presentation/teachers_list_screen.dart';
import '../../features/staff/presentation/staff_list_screen.dart';
import '../../features/staff/presentation/staff_detail_screen.dart';
import '../../features/enrollments/presentation/enrollment_detail_screen.dart';
import '../../features/enrollments/presentation/enrollments_list_screen.dart';
import '../../features/enrollments/presentation/bulk_chapter_video_access_screen.dart';
import '../../features/fees/presentation/fee_account_detail_screen.dart';
import '../../features/fees/presentation/fee_accounts_list_screen.dart';
import '../../features/live_classes/presentation/live_classes_list_screen.dart';
import '../../features/live_classes/presentation/live_class_detail_screen.dart';
import '../../features/materials/presentation/materials_list_screen.dart';
import '../../features/materials/presentation/material_detail_screen.dart';
import '../../features/assignments/presentation/assignments_list_screen.dart';
import '../../features/assignments/presentation/assignment_detail_screen.dart';
import '../../features/assignments/presentation/assignment_submissions_screen.dart';
import '../../features/assignments/presentation/assignment_submission_detail_screen.dart';
import '../../features/assignments/presentation/assignment_pdf_import_screen.dart';
import '../../features/subjects/presentation/subjects_list_screen.dart';
import '../../features/banners/presentation/banners_list_screen.dart';
import '../../features/banners/presentation/banner_create_screen.dart';
import '../../features/banners/presentation/banner_detail_screen.dart';
import '../../features/subjects/presentation/subject_detail_screen.dart';
import '../../features/subjects/presentation/chapter_detail_screen.dart';
import '../../features/subjects/presentation/lesson_detail_screen.dart';
import '../../features/student_portal/presentation/course_learning_screen.dart';
import '../../features/student_portal/presentation/material_detail_screen.dart' as portal_mat;
import '../../features/student_portal/presentation/live_class_detail_screen.dart' as portal_live;
import '../../features/student_portal/presentation/student_assignment_screen.dart';
import '../../features/student_portal/presentation/course_payment_screen.dart';
import '../../features/student_portal/presentation/student_profile_screen.dart'
    as portal;
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/notifications/presentation/notification_send_screen.dart';
import '../../features/notifications/presentation/device_notification_screen.dart';
import '../../features/student_portal/presentation/all_live_classes_screen.dart';
import '../session/session_controller.dart';
import '../session/user_role.dart';
import '../widgets/admin_shell.dart';
import '../widgets/nav_item.dart';

bool _roleCanAccess(String location, UserRole? role) {
  if (role == null) return false;

  final matching = kAllNavItems.where(
        (item) => location.startsWith(item.route),
  );

  if (matching.isEmpty) return true;

  return matching.any((item) => item.visibleTo(role));
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/explore',
    refreshListenable: _SessionRefreshListenable(ref),
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final location = state.matchedLocation;
      final goingToLogin = location == '/login';

      final isPublic = goingToLogin ||
          location == '/register' ||
          location.startsWith('/explore');

      if (session.isLoading) return null;

      if (!session.isAuthenticated) {
        return isPublic ? null : '/login';
      }

      if (goingToLogin || location == '/register') {
        final returnTo = state.uri.queryParameters['returnTo'];

        final courseDetailPath = RegExp(
          r'^/explore/[0-9a-fA-F]{8}-'
          r'[0-9a-fA-F]{4}-'
          r'[0-9a-fA-F]{4}-'
          r'[0-9a-fA-F]{4}-'
          r'[0-9a-fA-F]{12}$',
        );

        if (session.role == UserRole.student &&
            returnTo != null &&
            courseDetailPath.hasMatch(returnTo)) {
          return returnTo;
        }

        return session.role == UserRole.student
            ? '/student/courses'
            : '/dashboard';
      }

      if (location == '/super-admin/profile' &&
          session.role != UserRole.superAdmin) {
        return '/dashboard';
      }

      if (session.role == UserRole.student) {
        return isPublic || location.startsWith('/student/')
            ? null
            : '/student/courses';
      }

      if (location.startsWith('/student/')) {
        return '/dashboard';
      }

      if (!_roleCanAccess(location, session.role)) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/explore',
        builder: (context, state) => const ExploreScreen(),
        routes: [
          GoRoute(
            path: ':courseUuid',
            builder: (context, state) =>
                PublicCourseDetailScreen(
                  uuid: state.pathParameters['courseUuid']!,
                ),
          ),
        ],
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => StudentRegisterScreen(
          returnTo: state.uri.queryParameters['returnTo'],
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          returnTo: state.uri.queryParameters['returnTo'],
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => StudentShell(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/student/courses',
            builder: (context, state) =>
                const MyCoursesScreen(),
            routes: [
              GoRoute(
                path: ':courseUuid',
                builder: (context, state) =>
                    CourseLearningScreen(
                  courseUuid: state.pathParameters[
                      'courseUuid']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/student/materials/:materialUuid',
            builder: (context, state) =>
                portal_mat.MaterialDetailScreen(
              materialUuid: state.pathParameters[
                  'materialUuid']!,
            ),
          ),
          GoRoute(
            path: '/student/live-classes',
            builder: (context, state) =>
                const AllLiveClassesScreen(),
          ),
          GoRoute(
            path:
                '/student/live-classes/:liveClassUuid',
            builder: (context, state) =>
                portal_live.LiveClassDetailScreen(
              liveClassUuid: state.pathParameters[
                  'liveClassUuid']!,
            ),
          ),
          GoRoute(
            path: '/student/profile',
            builder: (context, state) =>
                const portal.StudentProfileScreen(),
          ),
          GoRoute(
            path:
                '/student/course-payment/:courseUuid',
            builder: (context, state) {
              return CoursePaymentScreen(
                courseUuid:
                    state.pathParameters[
                        'courseUuid']!,
                courseName:
                    state.uri.queryParameters[
                            'name'] ??
                        'Course',
                amount:
                    state.uri.queryParameters[
                            'amount'] ??
                        '0.00',
              );
            },
          ),
          GoRoute(
            path:
                '/student/assignments/:assignmentUuid',
            builder: (context, state) =>
                StudentAssignmentScreen(
              assignmentUuid: state.pathParameters[
                  'assignmentUuid']!,
            ),
            routes: [
              GoRoute(
                path: 'result',
                builder: (context, state) =>
                    StudentAssignmentResultScreen(
                  assignmentUuid:
                      state.pathParameters[
                          'assignmentUuid']!,
                ),
              ),
            ],
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(
          currentRoute: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) =>
            const DashboardScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
            routes: [
              GoRoute(
                path: 'send',
                builder: (context, state) =>
                    const NotificationSendScreen(),
              ),
              GoRoute(
                path: 'devices',
                builder: (context, state) =>
                    const DeviceNotificationScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/super-admin/profile',
            builder: (context, state) => const SuperAdminProfileScreen(),
          ),
          GoRoute(
            path: '/students',
            builder: (context, state) =>
            const StudentsDirectoryScreen(),
            routes: [
              GoRoute(
                path: ':studentUuid',
                builder: (context, state) =>
                    StudentProfileScreen(
                      studentUuid:
                      state.pathParameters['studentUuid']!,
                    ),
              ),
            ],
          ),
          GoRoute(
            path: '/teachers',
            builder: (context, state) =>
                const TeachersListScreen(),
            routes: [
              GoRoute(
                path: ':teacherUuid',
                builder: (context, state) =>
                    TeacherDetailScreen(
                  teacherUuid:
                      state.pathParameters[
                          'teacherUuid']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/staff',
            builder: (context, state) =>
                const StaffListScreen(),
            routes: [
              GoRoute(
                path: ':staffUuid',
                builder: (context, state) =>
                    StaffDetailScreen(
                  staffUuid:
                      state.pathParameters[
                          'staffUuid']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/courses',
            builder: (context, state) =>
            const CoursesListScreen(),
            routes: [
              GoRoute(
                path: ':courseUuid',
                builder: (context, state) =>
                    CourseDetailScreen(
                      courseUuid:
                      state.pathParameters['courseUuid']!,
                    ),
              ),
            ],
          ),
          GoRoute(
            path: '/course-categories',
            builder: (context, state) =>
                const CourseCategoriesScreen(),
          ),
          GoRoute(
            path: '/enrollments',
            builder: (context, state) =>
                const EnrollmentsListScreen(),
            routes: [
              GoRoute(
                path: 'video-access',
                builder: (context, state) =>
                    const BulkChapterVideoAccessScreen(),
              ),
              GoRoute(
                path: ':enrollmentUuid',
                builder: (context, state) =>
                    EnrollmentDetailScreen(
                  enrollmentUuid:
                      state.pathParameters[
                          'enrollmentUuid']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/fees',
            builder: (context, state) =>
                const FeeAccountsListScreen(),
            routes: [
              GoRoute(
                path: ':enrollmentUuid',
                builder: (context, state) =>
                    FeeAccountDetailScreen(
                  enrollmentUuid:
                      state.pathParameters[
                          'enrollmentUuid']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/live-classes',
            builder: (context, state) =>
                const LiveClassesListScreen(),
            routes: [
              GoRoute(
                path: ':liveClassUuid',
                builder: (context, state) =>
                    LiveClassDetailScreen(
                  liveClassUuid:
                      state.pathParameters[
                          'liveClassUuid']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/materials',
            builder: (context, state) =>
                const MaterialsListScreen(),
            routes: [
              GoRoute(
                path: ':materialUuid',
                builder: (context, state) =>
                    MaterialDetailScreen(
                  materialUuid:
                      state.pathParameters[
                          'materialUuid']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/assignments',
            builder: (context, state) =>
                const AssignmentsListScreen(),
            routes: [
              GoRoute(
                path: 'import-pdf',
                builder: (context, state) =>
                    const AssignmentPdfImportScreen(),
              ),
              GoRoute(
                path: ':assignmentUuid',
                builder: (context, state) =>
                    AssignmentDetailScreen(
                  assignmentUuid:
                      state.pathParameters[
                          'assignmentUuid']!,
                ),
                routes: [
                  GoRoute(
                    path: 'submissions',
                    builder: (context, state) => AssignmentSubmissionsScreen(
                      assignmentUuid: state.pathParameters['assignmentUuid']!,
                    ),
                    routes: [
                      GoRoute(
                        path: ':submissionUuid',
                        builder: (context, state) => AssignmentSubmissionDetailScreen(
                          submissionUuid: state.pathParameters['submissionUuid']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/subjects',
            builder: (context, state) =>
                const SubjectsListScreen(),
            routes: [
              GoRoute(
                path: ':subjectUuid',
                builder: (context, state) =>
                    SubjectDetailScreen(
                  subjectUuid:
                      state.pathParameters[
                          'subjectUuid']!,
                ),
                routes: [
                  GoRoute(
                    path: 'chapters/:chapterUuid',
                    builder: (context, state) =>
                        ChapterDetailScreen(
                      subjectUuid:
                          state.pathParameters[
                              'subjectUuid']!,
                      chapterUuid:
                          state.pathParameters[
                              'chapterUuid']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'lessons/:lessonUuid',
                        builder: (context, state) =>
                            LessonDetailScreen(
                          lessonUuid:
                              state.pathParameters[
                                  'lessonUuid']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/banners',
            builder: (context, state) =>
                const BannersListScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) =>
                    const BannerCreateScreen(),
              ),
              GoRoute(
                path: ':bannerUuid',
                builder: (context, state) =>
                    BannerDetailScreen(
                  bannerUuid:
                      state.pathParameters[
                          'bannerUuid']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/firms',
            builder: (context, state) =>
            const FirmsListScreen(),
            routes: [
              GoRoute(
                path: ':firmUuid',
                builder: (context, state) =>
                    FirmDetailScreen(
                      firmUuid:
                      state.pathParameters['firmUuid']!,
                    ),
              ),
            ],
          ),
          GoRoute(
            path: '/firm-admins',
            builder: (context, state) =>
            const AllFirmAdminsScreen(),
          ),
        ],
      ),
    ],
  );
});

class _SessionRefreshListenable extends ChangeNotifier {
  _SessionRefreshListenable(Ref ref) {
    ref.listen(
      sessionControllerProvider,
          (_, __) => notifyListeners(),
    );
  }
}