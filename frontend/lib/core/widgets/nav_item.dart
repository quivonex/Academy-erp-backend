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
    roles: [UserRole.academyAdmin],
  ),
  NavItem(
    label: 'Courses',
    icon: Icons.auto_stories_outlined,
    route: '/courses',
    roles: [UserRole.academyAdmin],
  ),
  NavItem(
    label: 'Firms',
    icon: Icons.business_outlined,
    route: '/firms',
    roles: [UserRole.superAdmin],
  ),
  NavItem(
    label: 'Firm Admins',
    icon: Icons.admin_panel_settings_outlined,
    route: '/firm-admins',
    roles: [UserRole.superAdmin],
  ),
];