import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/open_external_link.dart';
import '../data/student_portal_repository.dart';

class HomeBanners extends ConsumerStatefulWidget {
  const HomeBanners({super.key, this.height = 196});

  /// Banner height; the web Explore layout passes a taller value.
  final double height;

  @override
  ConsumerState<HomeBanners> createState() =>
      _HomeBannersState();
}

class _HomeBannersState extends ConsumerState<HomeBanners> {
  final PageController _pageController =
  PageController();

  Timer? _slideTimer;
  Timer? _refreshTimer;

  List<Map<String, dynamic>> _banners = [];
  int _currentIndex = 0;
  bool _loading = true;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();

    _loadBanners();

    // पुढचा banner दर 5 सेकंदांनी दाखवा.
    _slideTimer = Timer.periodic(
      const Duration(seconds: 5),
          (_) => _showNextBanner(),
    );

    // नवीन banner जोडला असल्यास तो list मध्ये आणा.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
          (_) => _loadBanners(),
    );
  }

  Future<void> _loadBanners() async {
    if (_fetching) return;

    _fetching = true;

    try {
      final banners = await ref
          .read(studentPortalRepositoryProvider)
          .banners();

      if (!mounted) return;

      setState(() {
        _banners = banners;
        _loading = false;

        if (_banners.isEmpty ||
            _currentIndex >= _banners.length) {
          _currentIndex = 0;
        }
      });

      // Backend वर banner कमी झाले असल्यास योग्य page वर या.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _pageController.hasClients &&
            _banners.isNotEmpty &&
            _pageController.page != _currentIndex) {
          _pageController.jumpToPage(_currentIndex);
        }
      });
    } catch (_) {
      if (!mounted) return;

      // Refresh fail झाला तरी आधीचे banners स्क्रीनवर ठेवा.
      setState(() => _loading = false);
    } finally {
      _fetching = false;
    }
  }

  void _showNextBanner() {
    if (!mounted ||
        !_pageController.hasClients ||
        _banners.length < 2) {
      return;
    }

    final nextIndex =
        (_currentIndex + 1) % _banners.length;

    _pageController.animateToPage(
      nextIndex,
      duration: const Duration(
        milliseconds: 450,
      ),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _refreshTimer?.cancel();
    _pageController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: colors.primaryTonal,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      );
    }

    if (_banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          SizedBox(
            height: widget.height,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _banners.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                final banner = _banners[index];

                final imageUrl = banner['image_url']?.toString() ?? '';
                final courseUuid = banner['course_uuid']?.toString();
                final hasCourse =
                    courseUuid != null && courseUuid.isNotEmpty;

                final actionUrl =
                    banner['action_url']?.toString().trim() ?? '';
                final actionLabel =
                    banner['action_label']?.toString().trim() ?? '';

                final actionUri = Uri.tryParse(actionUrl);
                final hasExternalAction = actionUri != null &&
                    (actionUri.scheme == 'http' ||
                        actionUri.scheme == 'https') &&
                    actionUri.host.isNotEmpty;

                final ctaLabel = actionLabel.isNotEmpty
                    ? actionLabel
                    : hasCourse
                        ? 'View course'
                        : 'Learn more';
                final title = banner['title']?.toString() ?? '';
                final subtitle = banner['subtitle']?.toString() ?? '';

                final gradientFallback = DecoratedBox(
                  decoration: BoxDecoration(gradient: colors.heroGradient),
                );

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: colors.heroShadow,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Material(
                        color: colors.primaryDeep,
                        child: InkWell(
                          onTap: hasCourse
                              ? () => context.push('/explore/$courseUuid')
                              : hasExternalAction
                                  ? () => openExternalLink(context, actionUrl)
                                  : null,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (imageUrl.isNotEmpty)
                                Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  headers: const {
                                    'ngrok-skip-browser-warning': 'true',
                                  },
                                  errorBuilder: (_, __, ___) =>
                                      gradientFallback,
                                )
                              else
                                gradientFallback,

                              // Indigo scrim so text stays readable.
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0x10000000),
                                      Color(0xE01E1A5C),
                                    ],
                                  ),
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    if (title.isNotEmpty)
                                      Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            textTheme.headlineSmall?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    if (subtitle.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        subtitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: const Color(0xFFDAD7FF),
                                        ),
                                      ),
                                    ],
                                    if (hasCourse || hasExternalAction) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.fromLTRB(
                                            14, 8, 10, 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              ctaLabel,
                                              style: textTheme.labelLarge
                                                  ?.copyWith(
                                                color: colors.primaryDeep,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              hasCourse
                                                  ? Icons.arrow_forward_rounded
                                                  : Icons.open_in_new_rounded,
                                              size: 16,
                                              color: colors.primaryDeep,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_banners.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _banners.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: _currentIndex == index ? 20 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? colors.primary
                        : colors.primaryTonalBorder,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
