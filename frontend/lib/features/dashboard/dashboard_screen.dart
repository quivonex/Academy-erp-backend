import 'package:flutter/material.dart';

import '../auth/auth_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.user,
    required this.onLogout,
  });

  final LoggedInUser user;
  final Future<void> Function() onLogout;

  String get roleName {
    return user.userType.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academy ERP'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await onLogout();

              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${user.fullName.isEmpty ? user.email : user.fullName}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              roleName,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF667085),
              ),
            ),
            if (user.firmName != null && user.firmName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                user.firmName!,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF667085),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const Card(
              child: ListTile(
                leading: Icon(Icons.verified_user_outlined),
                title: Text('Login successful'),
                subtitle: Text(
                  'Your access and refresh tokens are securely stored on this device.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}