import 'package:flutter/material.dart';

import '../session/user_role.dart';

class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.roles,
  });

  final String label;
  final IconData icon;
  final String route;
  final List<UserRole> roles;

  bool visibleTo(UserRole role) => roles.contains(role);
}

const List<NavItem> kAllNavItems = [
  NavItem(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    route: '/dashboard',
    roles: [
      UserRole.superAdmin,
      UserRole.academyAdmin,
    ],
  ),
  NavItem(
    label: 'Students',
    icon: Icons.school_outlined,
    route: '/students',
    roles: [
      UserRole.academyAdmin,
    ],
  ),
  NavItem(
    label: 'Teachers',
    icon: Icons.co_present_outlined,
    route: '/teachers',
    roles: [
      UserRole.academyAdmin,
    ],
  ),
  NavItem(
    label: 'Staff',
    icon: Icons.badge_outlined,
    route: '/staff',
    roles: [
      UserRole.academyAdmin,
    ],
  ),
  NavItem(
    label: 'Courses',
    icon: Icons.auto_stories_outlined,
    route: '/courses',
    roles: [
      UserRole.academyAdmin,
    ],
  ),
  NavItem(
    label: 'Course Categories',
    icon: Icons.category_outlined,
    route: '/course-categories',
    roles: [
      UserRole.academyAdmin,
    ],
  ),
  NavItem(
    label: 'Enrollments',
    icon: Icons.how_to_reg_outlined,
    route: '/enrollments',
    roles: [
      UserRole.academyAdmin,
    ],
  ),
  NavItem(
    label: 'Fees',
    icon: Icons.account_balance_wallet_outlined,
    route: '/fees',
    roles: [
      UserRole.academyAdmin,
    ],
  ),
  NavItem(
    label: 'Live Classes',
    icon: Icons.video_camera_front_outlined,
    route: '/live-classes',
    roles: [
      UserRole.academyAdmin,
    ],
  ),
  NavItem(
    label: 'Materials',
    icon: Icons.video_library_outlined,
    route: '/materials',
    roles: [
      UserRole.academyAdmin,
    ],
  ),
  NavItem(
    label: 'Assignments',
    icon: Icons.assignment_outlined,
    route: '/assignments',
    roles: [
      UserRole.academyAdmin,
    ],
  ),
  NavItem(
    label: 'Subjects',
    icon: Icons.menu_book_outlined,
    route: '/subjects',
    roles: [
      UserRole.academyAdmin,
    ],
  ),
  NavItem(
    label: 'Banners',
    icon: Icons.view_carousel_outlined,
    route: '/banners',
    roles: [
      UserRole.academyAdmin,
    ],
  ),
  // Super Admin only
  NavItem(
    label: 'Firms',
    icon: Icons.business_outlined,
    route: '/firms',
    roles: [
      UserRole.superAdmin,
    ],
  ),
  NavItem(
    label: 'Firm Admins',
    icon: Icons.admin_panel_settings_outlined,
    route: '/firm-admins',
    roles: [
      UserRole.superAdmin,
    ],
  ),
];
