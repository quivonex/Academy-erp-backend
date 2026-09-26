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

/// The full nav tree from both shells in the Stitch export. `AdminShell`
/// filters this by the current user's role, so adding a new module later
/// means adding one entry here — not touching shell layout code.
const List<NavItem> kAllNavItems = [
  NavItem(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    route: '/dashboard',
    roles: [UserRole.superAdmin, UserRole.academyAdmin, UserRole.firmStaff, UserRole.teacher],
  ),
  NavItem(
    label: 'Academies',
    icon: Icons.account_balance_outlined,
    route: '/academies',
    roles: [UserRole.superAdmin, UserRole.academyAdmin, UserRole.firmStaff, UserRole.teacher],
  ),
  NavItem(
    label: 'Students',
    icon: Icons.school_outlined,
    route: '/students',
    roles: [UserRole.superAdmin, UserRole.academyAdmin, UserRole.firmStaff, UserRole.teacher],
  ),
  NavItem(
    label: 'Courses',
    icon: Icons.auto_stories_outlined,
    route: '/courses',
    roles: [UserRole.superAdmin, UserRole.academyAdmin, UserRole.firmStaff, UserRole.teacher],
  ),
  NavItem(
    label: 'Attendance',
    icon: Icons.fact_check_outlined,
    route: '/attendance',
    roles: [UserRole.superAdmin, UserRole.academyAdmin, UserRole.firmStaff, UserRole.teacher],
  ),
  NavItem(
    label: 'Enrollment',
    icon: Icons.how_to_reg_outlined,
    route: '/enrollment',
    roles: [UserRole.superAdmin, UserRole.academyAdmin, UserRole.firmStaff, UserRole.teacher],
  ),
  NavItem(
    label: 'Firms',
    icon: Icons.business_outlined,
    route: '/firms',
    roles: [UserRole.superAdmin, UserRole.academyAdmin, UserRole.firmStaff, UserRole.teacher],
  ),
  NavItem(
    label: 'Firm Admins',
    icon: Icons.admin_panel_settings_outlined,
    route: '/firm-admins',
    roles: [UserRole.superAdmin, UserRole.academyAdmin, UserRole.firmStaff, UserRole.teacher],
  ),
];
