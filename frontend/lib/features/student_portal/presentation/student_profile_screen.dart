import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/session/session_controller.dart';

class StudentProfileScreen
    extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() =>
      _StudentProfileScreenState();
}

class _StudentProfileScreenState
    extends ConsumerState<StudentProfileScreen> {
  late Future<Map<String, dynamic>> _profile;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _profile = _fetchProfile();
  }

  Future<Map<String, dynamic>> _fetchProfile() async {
    try {
      final response = await ref
          .read(dioProvider)
          .get(ApiUrls.me);

      final body = response.data;

      if (body is! Map || body['data'] is! Map) {
        throw const ApiException(
          'Invalid profile response.',
        );
      }

      return Map<String, dynamic>.from(
        body['data'] as Map,
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<void> _refresh() async {
    final next = _fetchProfile();

    setState(() => _profile = next);

    try {
      await next;
    } catch (_) {
      // FutureBuilder खाली error दाखवेल.
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    setState(() => _loggingOut = true);

    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .logout();

      // Session बदलल्यावर router login/explore कडे नेईल.
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loggingOut = false);
      }
    }
  }

  String _value(
      Map<String, dynamic> profile,
      String key,
      ) {
    final value =
        profile[key]?.toString().trim() ?? '';

    return value.isEmpty ? 'Not provided' : value;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState !=
              ConnectionState.done) {
            return ListView(
              physics:
              const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 100),
                Center(
                  child: CircularProgressIndicator(),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return ListView(
              physics:
              const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Could not load profile: '
                      '${snapshot.error}',
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _refresh,
                  child: const Text('Retry'),
                ),
              ],
            );
          }

          final profile = snapshot.data!;

          final fullName = [
            profile['first_name']?.toString() ?? '',
            profile['last_name']?.toString() ?? '',
          ].where(
                (part) => part.trim().isNotEmpty,
          ).join(' ');

          final displayName = fullName.isEmpty
              ? _value(profile, 'email')
              : fullName;

          return ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 12),
              CircleAvatar(
                radius: 34,
                child: Text(
                  displayName.isEmpty
                      ? 'S'
                      : displayName[0].toUpperCase(),
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  displayName,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall,
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  _value(profile, 'firm_name'),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.email_outlined,
                      ),
                      title: const Text('Email'),
                      subtitle: Text(
                        _value(profile, 'email'),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.phone_outlined,
                      ),
                      title: const Text('Phone'),
                      subtitle: Text(
                        _value(profile, 'phone'),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.school_outlined,
                      ),
                      title: const Text('Academy'),
                      subtitle: Text(
                        _value(profile, 'firm_name'),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.badge_outlined,
                      ),
                      title: const Text('Account type'),
                      subtitle: Text(
                        _value(profile, 'user_type'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed:
                _loggingOut ? null : _logout,
                icon: const Icon(Icons.logout),
                label: Text(
                  _loggingOut
                      ? 'Logging out...'
                      : 'Log out',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}