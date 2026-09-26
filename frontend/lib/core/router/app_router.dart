import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/academies/presentation/academies_list_screen.dart';
import '../../features/attendance/presentation/attendance_marking_screen.dart';
import '../../features/auth/data/login_screen.dart';
import '../../features/courses/presentation/course_detail_screen.dart';
import '../../features/courses/presentation/courses_list_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/enrollment/presentation/enrollment_wizard_screen.dart';
import '../../features/firms/presentation/all_firm_admins_screen.dart';
import '../../features/firms/presentation/firm_detail_screen.dart';
import '../../features/firms/presentation/firms_list_screen.dart';
import '../../features/students/presentation/student_profile_screen.dart';
import '../../features/students/presentation/students_directory_screen.dart';
import '../session/session_controller.dart';
import '../widgets/admin_shell.dart';
import '../widgets/nav_item.dart';

/// Returns true if [role] is allowed to view [location] per kAllNavItems.
bool _roleCanAccess(String location, dynamic role) {
  final matching = kAllNavItems.where((item) => location.startsWith(item.route));
  if (matching.isEmpty) return true;
  return matching.any((item) => item.visibleTo(role));
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: _SessionRefreshListenable(ref),
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final goingToLogin = state.matchedLocation == '/login';

      if (session.isLoading) return null;

      if (!session.isAuthenticated) {
        return goingToLogin ? null : '/login';
      }
      if (goingToLogin) {
        return '/dashboard';
      }
      if (!_roleCanAccess(state.matchedLocation, session.role)) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AdminShell(currentRoute: state.matchedLocation, child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/academies',
            builder: (context, state) => const AcademiesListScreen(),
          ),
          GoRoute(
            path: '/students',
            builder: (context, state) => const StudentsDirectoryScreen(),
            routes: [
              GoRoute(
                path: ':studentUuid',
                builder: (context, state) => StudentProfileScreen(
                  studentUuid: state.pathParameters['studentUuid']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/courses',
            builder: (context, state) => const CoursesListScreen(),
            routes: [
              GoRoute(
                path: ':courseUuid',
                builder: (context, state) => CourseDetailScreen(
                  courseUuid: state.pathParameters['courseUuid']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const AttendanceMarkingScreen(),
          ),
          GoRoute(
            path: '/enrollment',
            builder: (context, state) => const EnrollmentWizardScreen(),
          ),
          GoRoute(
            path: '/firms',
            builder: (context, state) => const FirmsListScreen(),
            routes: [
              GoRoute(
                path: ':firmUuid',
                builder: (context, state) => FirmDetailScreen(
                  firmUuid: state.pathParameters['firmUuid']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/firm-admins',
            builder: (context, state) => const AllFirmAdminsScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Bridges Riverpod's provider changes into a Listenable so GoRouter
/// re-evaluates `redirect` whenever auth state changes (login/logout).
class _SessionRefreshListenable extends ChangeNotifier {
  _SessionRefreshListenable(Ref ref) {
    ref.listen(sessionControllerProvider, (_, __) => notifyListeners());
  }
}