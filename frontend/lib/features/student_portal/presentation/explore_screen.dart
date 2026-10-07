import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/user_role.dart';
import '../../../core/theme/app_colors.dart';
import '../data/student_portal_repository.dart';
import 'home_banners.dart';
import 'widgets/student_ui.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() =>
      _ExploreScreenState();
}

class _ExploreScreenState
    extends ConsumerState<ExploreScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  Timer? _searchTimer;

  List<CourseCategory> _categories = [];
  List<PublicCourse> _courses = [];

  String? _selectedCategoryUuid;
  String? _error;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  int _page = 1;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();

    _loadCategories();
    _loadCourses(reset: true);
  }

  Future<void> _loadCategories() async {
    try {
      final result = await ref
          .read(studentPortalRepositoryProvider)
          .categories();

      if (!mounted) return;

      setState(() => _categories = result);
    } catch (_) {
      // Categories fail झाल्या तरी course list दिसेल.
    }
  }

  Future<void> _loadCourses({
    required bool reset,
  }) async {
    if (!reset && (_loadingMore || !_hasMore)) {
      return;
    }

    final requestId = ++_requestId;
    final requestedPage = reset ? 1 : _page + 1;

    setState(() {
      _error = null;

      if (reset) {
        _loading = true;
        _loadingMore = false;
        _courses = [];
        _hasMore = true;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final result = await ref
          .read(studentPortalRepositoryProvider)
          .publicCourses(
        search: _searchController.text,
        categoryUuid:
        _selectedCategoryUuid,
        page: requestedPage,
      );

      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        if (reset) {
          _courses = result.items;
        } else {
          _courses.addAll(result.items);
        }

        _page = requestedPage;
        _hasMore = result.hasNext;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) {
        return;
      }

      setState(() {
        _error = error.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchTimer?.cancel();

    _searchTimer = Timer(
      const Duration(milliseconds: 400),
          () => _loadCourses(reset: true),
    );
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wide screens (web / desktop) get the full web layout; phones keep
    // the mobile layout with the bottom navigation.
    return MediaQuery.sizeOf(context).width >= 900
        ? _buildWeb(context)
        : _buildMobile(context);
  }

  // ───────────────────────────── Web layout ─────────────────────────────

  Widget _buildWeb(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final isStudent = session.role == UserRole.student;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final sidePad = width > 1264 ? (width - 1200) / 2 : 32.0;

    final academyLabel = session.firmName?.trim().isNotEmpty == true
        ? session.firmName!.trim()
        : 'the academy';

    Widget section(Widget child) => Padding(
          padding: EdgeInsets.symmetric(horizontal: sidePad),
          child: child,
        );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: _WebTopNav(
          sidePad: sidePad,
          isStudent: isStudent,
          academyLabel: session.firmName,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadCategories(),
            _loadCourses(reset: true),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 56),
            section(
              Column(
                children: [
                  Text(
                    'Find your next course',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: width >= 1100 ? 52 : 42,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.6,
                      height: 1.1,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Text(
                      'Explore courses, live classes and study materials '
                      'available at $academyLabel.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        fontSize: 18,
                        height: 1.55,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 580),
                    child: _webSearchField(context),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    runSpacing: 8,
                    children: [
                      FilterPill(
                        label: 'All',
                        selected: _selectedCategoryUuid == null,
                        onTap: () {
                          _selectedCategoryUuid = null;
                          _loadCourses(reset: true);
                        },
                      ),
                      for (final category in _categories)
                        FilterPill(
                          label: category.name,
                          selected: _selectedCategoryUuid == category.uuid,
                          onTap: () {
                            _selectedCategoryUuid = category.uuid;
                            _loadCourses(reset: true);
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            section(const HomeBanners(height: 320)),
            const SizedBox(height: 40),
            section(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Featured & popular',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.6,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Courses currently open at $academyLabel.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_loading && _courses.isNotEmpty)
                        TonalPill(
                          label: _hasMore
                              ? '${_courses.length}+ courses available'
                              : _courses.length == 1
                                  ? '1 course available'
                                  : '${_courses.length} courses available',
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 24),
                  if (_loading)
                    const StudentLoading()
                  else if (_error != null && _courses.isEmpty)
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: StudentStateMessage(
                          icon: Icons.wifi_off_rounded,
                          title: 'Courses could not load',
                          message: _error!,
                          actionLabel: 'Try again',
                          onAction: () => _loadCourses(reset: true),
                          isError: true,
                        ),
                      ),
                    )
                  else if (_courses.isEmpty)
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: StudentStateMessage(
                          icon: Icons.search_off_rounded,
                          title: 'No courses found',
                          message: _searchController.text.isEmpty
                              ? 'Try another category.'
                              : 'Try a different search or category.',
                        ),
                      ),
                    )
                  else ...[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 1000 ? 3 : 2;
                        const gap = 24.0;
                        final cardWidth =
                            (constraints.maxWidth - gap * (columns - 1)) /
                                columns;

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final course in _courses)
                              SizedBox(
                                width: cardWidth,
                                child: _CourseCard(
                                  course: course,
                                  gridMode: true,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      InlineError(message: 'Could not load more: $_error'),
                    ],
                    if (_hasMore) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: SizedBox(
                          width: 280,
                          child: LoadMoreButton(
                            label: 'Load more courses',
                            loading: _loadingMore,
                            onPressed: () => _loadCourses(reset: false),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 64),
            _WebFooter(sidePad: sidePad, isStudent: isStudent),
          ],
        ),
      ),
    );
  }

  Widget _webSearchField(BuildContext context) {
    final colors = context.colors;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F4F46E5),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {});
          _onSearchChanged(value);
        },
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search courses, subjects or topics…',
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          prefixIcon: Icon(Icons.search_rounded, color: colors.textSubtle),
          border: border(const Color(0xFFE2E8F0)),
          enabledBorder: border(const Color(0xFFE2E8F0)),
          focusedBorder: border(const Color(0xFF6366F1), 1.5),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    _searchTimer?.cancel();
                    _loadCourses(reset: true);
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
    );
  }

  // ──────────────────────────── Mobile layout ───────────────────────────

  Widget _buildMobile(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final isStudent = session.role == UserRole.student;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        toolbarHeight: 68,
        leadingWidth: 68,
        titleSpacing: 4,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Center(child: AcademyMark(size: 40)),
        ),
        title: StudentBarTitle(
          eyebrow: session.firmName,
          title: 'Explore',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: isStudent
                ? Tooltip(
                    message: 'Profile',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => context.go('/student/profile'),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: colors.primaryDeep,
                        child: const Icon(
                          Icons.person_rounded,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => context.go('/login'),
                    child: const Text('Sign in'),
                  ),
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          isStudent ? const StudentBottomNav(selectedIndex: 0) : null,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadCategories(),
            _loadCourses(reset: true),
          ]);
        },
        child: StudentPageFrame(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              kStudentPagePadding,
              4,
              kStudentPagePadding,
              24,
            ),
            children: [
              Text(
                'Find your next course',
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                session.firmName == null || session.firmName!.isEmpty
                    ? 'Explore courses available at the academy.'
                    : 'Explore courses available at ${session.firmName}.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: colors.cardShadow,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {});
                    _onSearchChanged(value);
                  },
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search courses, subjects…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colors.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          BorderSide(color: colors.primary, width: 2),
                    ),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              _searchTimer?.cancel();
                              _loadCourses(reset: true);
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    FilterPill(
                      label: 'All',
                      selected: _selectedCategoryUuid == null,
                      onTap: () {
                        _selectedCategoryUuid = null;
                        _loadCourses(reset: true);
                      },
                    ),
                    for (final category in _categories)
                      FilterPill(
                        label: category.name,
                        selected: _selectedCategoryUuid == category.uuid,
                        onTap: () {
                          _selectedCategoryUuid = category.uuid;
                          _loadCourses(reset: true);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const HomeBanners(),
              SectionHeader(
                title: 'Featured & popular',
                trailing: _loading || _courses.isEmpty
                    ? null
                    : TonalPill(
                        label: _hasMore
                            ? '${_courses.length}+ courses'
                            : _courses.length == 1
                                ? '1 course'
                                : '${_courses.length} courses',
                      ),
              ),
              if (_loading)
                const StudentLoading()
              else if (_error != null && _courses.isEmpty)
                StudentStateMessage(
                  icon: Icons.wifi_off_rounded,
                  title: 'Courses could not load',
                  message: _error!,
                  actionLabel: 'Try again',
                  onAction: () => _loadCourses(reset: true),
                  isError: true,
                )
              else if (_courses.isEmpty)
                StudentStateMessage(
                  icon: Icons.search_off_rounded,
                  title: 'No courses found',
                  message: _searchController.text.isEmpty
                      ? 'Try another category.'
                      : 'Try a different search or category.',
                )
              else ...[
                for (final course in _courses) _CourseCard(course: course),
                if (_error != null)
                  InlineError(message: 'Could not load more: $_error'),
                if (_hasMore)
                  LoadMoreButton(
                    label: 'Load more courses',
                    loading: _loadingMore,
                    onPressed: () => _loadCourses(reset: false),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Web top navigation: brand, section links and sign-in / profile.
class _WebTopNav extends StatelessWidget {
  const _WebTopNav({
    required this.sidePad,
    required this.isStudent,
    required this.academyLabel,
  });

  final double sidePad;
  final bool isStudent;
  final String? academyLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    Widget link(String label, String? route, {bool active = false}) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor:
                active ? colors.primaryTonal : Colors.transparent,
            foregroundColor:
                active ? colors.primary : const Color(0xFF475569),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: textTheme.labelLarge?.copyWith(
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          onPressed: route == null ? null : () => context.go(route),
          child: Text(label),
        ),
      );
    }

    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: sidePad),
      decoration: const BoxDecoration(
        color: Color(0xF7FFFFFF),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const AcademyMark(size: 40),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    academyLabel?.trim().isNotEmpty == true
                        ? academyLabel!.trim()
                        : 'Academy',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'VidyaSetu',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 32),
            link('Explore courses', '/explore', active: true),
            if (isStudent) ...[
              link('My courses', '/student/courses'),
              link('Live classes', '/student/live-classes'),
            ],
            const Spacer(),
            if (isStudent)
              Tooltip(
                message: 'Profile',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.go('/student/profile'),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: colors.primaryDeep,
                    child: const Icon(
                      Icons.person_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            else
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => context.go('/login'),
                child: const Text('Sign in'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Web footer: brand line, quick links and copyright.
class _WebFooter extends StatelessWidget {
  const _WebFooter({required this.sidePad, required this.isStudent});

  final double sidePad;
  final bool isStudent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final linkStyle = textTheme.bodyMedium?.copyWith(
      color: const Color(0xFF475569),
    );

    Widget link(String label, String route) => InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => context.go(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(label, style: linkStyle),
          ),
        );

    return Container(
      padding: EdgeInsets.fromLTRB(sidePad, 40, sidePad, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const AcademyMark(size: 32),
                        const SizedBox(width: 10),
                        Text(
                          'VidyaSetu',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Text(
                        'Courses, live classes and study materials '
                        'from your academy, in one place.',
                        style: textTheme.bodySmall?.copyWith(height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learning',
                      style: textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    link('Explore courses', '/explore'),
                    if (isStudent) ...[
                      link('My courses', '/student/courses'),
                      link('Live classes', '/student/live-classes'),
                    ],
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account',
                      style: textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (isStudent)
                      link('My profile', '/student/profile')
                    else ...[
                      link('Sign in', '/login'),
                      link('Create student account', '/register'),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Divider(height: 1, color: Color(0xFFEEF0F5)),
          const SizedBox(height: 18),
          Text(
            '© ${DateTime.now().year} VidyaSetu. All rights reserved.',
            style: textTheme.bodySmall?.copyWith(color: colors.textSubtle),
          ),
        ],
      ),
    );
  }
}

/// Deterministic premium gradient per course so cards feel distinct.
List<Color> _courseGradient(String seed) {
  const palettes = [
    [Color(0xFF3525CD), Color(0xFF6366F1)], // indigo
    [Color(0xFF5B21B6), Color(0xFF8B5CF6)], // violet
    [Color(0xFF065F46), Color(0xFF10B981)], // emerald
    [Color(0xFF1E3A8A), Color(0xFF3B82F6)], // royal blue
  ];
  final sum = seed.codeUnits.fold<int>(0, (a, b) => a + b);
  return palettes[sum % palettes.length];
}

String _prettyMode(String mode) {
  final value = mode.trim().replaceAll('_', ' ').toLowerCase();
  if (value.isEmpty) return 'Course';
  return value[0].toUpperCase() + value.substring(1);
}

String _priceLabel(String price) {
  final amount = double.tryParse(price);
  if (amount != null && amount == 0) return 'Free';
  return '₹$price';
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    this.gridMode = false,
  });

  final PublicCourse course;

  /// Grid cells on the web layout: no bottom margin and a fixed-height body
  /// so every card in a row lines up.
  final bool gridMode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final gradient = _courseGradient(course.name + course.code);
    void open() => context.push('/explore/${course.uuid}');

    return PremiumCard(
      padding: EdgeInsets.zero,
      margin: gridMode ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16),
      onTap: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              height: 128,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -12,
                    bottom: -18,
                    child: Icon(
                      Icons.auto_stories_rounded,
                      size: 120,
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (course.isFeatured)
                              const TonalPill(
                                label: 'Featured',
                                icon: Icons.star_rounded,
                                background: Color(0xFFFFF4D6),
                                foreground: Color(0xFF92400E),
                              ),
                            if ((course.categoryName ?? '').isNotEmpty)
                              TonalPill(
                                label: course.categoryName!,
                                background: Colors.white,
                                foreground: gradient.first,
                              ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                course.code,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.labelMedium?.copyWith(
                                  color: Colors.white
                                      .withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                            TonalPill(
                              label: _prettyMode(course.deliveryMode),
                              background:
                                  Colors.black.withValues(alpha: 0.28),
                              foreground: Colors.white,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: SizedBox(
              height: gridMode ? 142 : null,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge,
                ),
                if (course.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    course.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
                if ((course.firmName ?? '').isNotEmpty ||
                    course.durationMonths != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if ((course.firmName ?? '').isNotEmpty) ...[
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: colors.primaryTonal,
                          child: Text(
                            initialsOf(course.firmName!),
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            course.firmName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelLarge,
                          ),
                        ),
                      ] else
                        const Spacer(),
                      if (course.durationMonths != null)
                        TonalPill(
                          label: course.durationMonths == 1
                              ? '1 month'
                              : '${course.durationMonths} months',
                          icon: Icons.schedule_rounded,
                          background: colors.successBg,
                          foreground: colors.success,
                        ),
                    ],
                  ),
                ],
              ],
            ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7FE),
              border: Border(top: BorderSide(color: colors.borderSubtle)),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Course fee', style: textTheme.bodySmall),
                      Text(
                        _priceLabel(course.price),
                        style: textTheme.titleLarge?.copyWith(
                          color: colors.primaryDeep,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primaryDeep,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.only(left: 18, right: 12),
                  ),
                  onPressed: open,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View course'),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PublicCourseDetailScreen extends ConsumerStatefulWidget {
  const PublicCourseDetailScreen({
    super.key,
    required this.uuid,
  });

  final String uuid;

  @override
  ConsumerState<PublicCourseDetailScreen> createState() =>
      _PublicCourseDetailScreenState();
}

class _PublicCourseDetailScreenState
    extends ConsumerState<PublicCourseDetailScreen> {
  late Future<PublicCourse> _course;
  Future<bool>? _hasAccess;

  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  @override
  void didUpdateWidget(covariant PublicCourseDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.uuid != widget.uuid) {
      _loadCourse();
      _hasAccess = null;
    }
  }

  void _loadCourse() {
    _course = ref
        .read(studentPortalRepositoryProvider)
        .publicCourse(widget.uuid);
  }

  Future<bool> _checkAccess() async {
    try {
      await ref
          .read(studentPortalRepositoryProvider)
          .myCourse(widget.uuid);
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 404) return false;
      rethrow;
    }
  }

  Widget _courseAction({
    required bool isAuthenticated,
    required bool isStudent,
    required PublicCourse course,
  }) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    Widget note(String text, {IconData icon = Icons.info_outline_rounded}) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
            ),
          ),
        ],
      );
    }

    if (!isAuthenticated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          note(
            'Sign in with a student account to check your course access.',
            icon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () {
              final loginPath = Uri(
                path: '/login',
                queryParameters: {
                  'returnTo': '/explore/${widget.uuid}',
                },
              );

              context.go(loginPath.toString());
            },
            child: const Text('Sign in'),
          ),
        ],
      );
    }

    if (!isStudent) {
      return note('Course learning is available to student accounts.');
    }

    return FutureBuilder<bool>(
      future: _hasAccess ??= _checkAccess(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              note(
                'Could not check course access: ${snapshot.error}',
                icon: Icons.error_outline_rounded,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() => _hasAccess = _checkAccess());
                },
                child: const Text('Try again'),
              ),
            ],
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              note(
                'You are enrolled in this course.',
                icon: Icons.verified_rounded,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primaryDeep,
                ),
                onPressed: () => context.go(
                  '/student/courses/${widget.uuid}',
                ),
                icon: const Icon(Icons.play_circle_fill_rounded),
                label: const Text('Continue learning'),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            note(
              'You do not have access to this course yet.',
              icon: Icons.lock_outline,
            ),
            const SizedBox(height: 14),
            if (double.tryParse(course.price) != null &&
                double.parse(course.price) > 0)
              FilledButton.icon(
                onPressed: () {
                  final uri = Uri(
                    path: '/student/course-payment/${course.uuid}',
                    queryParameters: {
                      'name': course.name,
                      'amount': course.price,
                    },
                  );

                  context.push(uri.toString());
                },
                icon: const Icon(Icons.info_outline_rounded),
                label: const Text('Fees & Enrollment'),
              )
            else
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Contact the academy to request course access.',
                      ),
                    ),
                  );
                },
                child: const Text('Request Access'),
              ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => context.go('/student/courses'),
              child: const Text('View My Courses'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final isStudent =
        session.isAuthenticated && session.role == UserRole.student;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: const Text('Course details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to Explore',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/explore');
            }
          },
        ),
      ),
      body: FutureBuilder<PublicCourse>(
        future: _course,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StudentPageFrame(
              child: ListView(
                padding: const EdgeInsets.all(kStudentPagePadding),
                children: [
                  StudentStateMessage(
                    icon: Icons.wifi_off_rounded,
                    title: 'Course could not load',
                    message: '${snapshot.error}',
                    actionLabel: 'Try again',
                    onAction: () => setState(_loadCourse),
                    isError: true,
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final course = snapshot.data!;
          final gradient = _courseGradient(course.name + course.code);

          return StudentPageFrame(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                kStudentPagePadding,
                4,
                kStudentPagePadding,
                32,
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradient,
                    ),
                    boxShadow: colors.heroShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (course.isFeatured)
                            const TonalPill(
                              label: 'Featured',
                              icon: Icons.star_rounded,
                              background: Color(0xFFFFF4D6),
                              foreground: Color(0xFF92400E),
                            ),
                          TonalPill(
                            label: course.categoryName ?? course.code,
                            background: Colors.white.withValues(alpha: 0.18),
                            foreground: Colors.white,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        course.name,
                        style: textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      if ((course.firmName ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.apartment_rounded,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                course.firmName!,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _FactTile(
                        icon: Icons.payments_outlined,
                        label: 'Fee',
                        value: _priceLabel(course.price),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FactTile(
                        icon: Icons.devices_rounded,
                        label: 'Mode',
                        value: _prettyMode(course.deliveryMode),
                      ),
                    ),
                    if (course.durationMonths != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FactTile(
                          icon: Icons.event_rounded,
                          label: 'Duration',
                          value: course.durationMonths == 1
                              ? '1 month'
                              : '${course.durationMonths} months',
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                const SectionHeader(
                  title: 'About this course',
                  icon: Icons.menu_book_rounded,
                ),
                PremiumCard(
                  child: Text(
                    course.description.isEmpty
                        ? 'Description is not available.'
                        : course.description,
                    style: textTheme.bodyLarge?.copyWith(height: 1.55),
                  ),
                ),
                const SectionHeader(
                  title: 'Your access',
                  icon: Icons.verified_user_outlined,
                ),
                PremiumCard(
                  child: _courseAction(
                    isAuthenticated: session.isAuthenticated,
                    isStudent: isStudent,
                    course: course,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return PremiumCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, size: 34, radius: 10),
          const SizedBox(height: 10),
          Text(label, style: textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
