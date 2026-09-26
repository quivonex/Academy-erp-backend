import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/login_screen.dart';
import '../../features/courses/presentation/course_detail_screen.dart';
import '../../features/courses/presentation/courses_list_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/firms/presentation/all_firm_admins_screen.dart';
import '../../features/firms/presentation/firm_detail_screen.dart';
import '../../features/firms/presentation/firms_list_screen.dart';
import '../../features/student_portal/presentation/explore_screen.dart';
import '../../features/student_portal/presentation/my_courses_screen.dart';
import '../../features/student_portal/presentation/student_register_screen.dart';
import '../../features/student_portal/presentation/student_shell.dart';
import '../../features/students/presentation/student_profile_screen.dart';
import '../../features/students/presentation/students_directory_screen.dart';
import '../../features/student_portal/presentation/course_learning_screen.dart';
import '../../features/student_portal/presentation/material_detail_screen.dart';
import '../../features/student_portal/presentation/live_class_detail_screen.dart';
import '../../features/student_portal/presentation/student_assignment_screen.dart';

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
        return session.role == UserRole.student
            ? '/student/courses'
            : '/dashboard';
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
        builder: (context, state) =>
        const StudentRegisterScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
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
                MaterialDetailScreen(
              materialUuid: state.pathParameters[
                  'materialUuid']!,
            ),
          ),
          GoRoute(
            path:
                '/student/live-classes/:liveClassUuid',
            builder: (context, state) =>
                LiveClassDetailScreen(
              liveClassUuid: state.pathParameters[
                  'liveClassUuid']!,
            ),
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