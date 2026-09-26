import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/student_portal_repository.dart';

class HomeBanners extends ConsumerStatefulWidget {
  const HomeBanners({super.key});

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
    if (_loading) {
      return const SizedBox(
        height: 210,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _banners.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final banner = _banners[index];

              final imageUrl =
                  banner['image_url']
                      ?.toString() ??
                      '';

              final courseUuid =
              banner['course_uuid']
                  ?.toString();

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                ),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: courseUuid != null &&
                        courseUuid.isNotEmpty
                        ? () => context.go(
                      '/explore/$courseUuid',
                    )
                        : null,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imageUrl.isNotEmpty)
                          Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            headers: const {
                              'ngrok-skip-browser-warning':
                              'true',
                            },
                            errorBuilder:
                                (_, __, ___) =>
                            const ColoredBox(
                              color:
                              Color(0xFFE9EEF8),
                            ),
                          )
                        else
                          const ColoredBox(
                            color:
                            Color(0xFFE9EEF8),
                          ),

                        // Image वर text स्पष्ट दिसण्यासाठी.
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient:
                            LinearGradient(
                              begin:
                              Alignment.topCenter,
                              end:
                              Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black
                                    .withOpacity(0.78),
                              ],
                            ),
                          ),
                        ),

                        Padding(
                          padding:
                          const EdgeInsets.all(
                            16,
                          ),
                          child: Column(
                            mainAxisAlignment:
                            MainAxisAlignment.end,
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                banner['title']
                                    ?.toString() ??
                                    '',
                                maxLines: 2,
                                overflow: TextOverflow
                                    .ellipsis,
                                style:
                                Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                  color:
                                  Colors.white,
                                ),
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                banner['subtitle']
                                    ?.toString() ??
                                    '',
                                maxLines: 2,
                                overflow: TextOverflow
                                    .ellipsis,
                                style:
                                const TextStyle(
                                  color:
                                  Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        if (_banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: List.generate(
              _banners.length,
                  (index) => Container(
                width:
                _currentIndex == index
                    ? 18
                    : 7,
                height: 7,
                margin:
                const EdgeInsets.symmetric(
                  horizontal: 3,
                ),
                decoration: BoxDecoration(
                  color: _currentIndex ==
                      index
                      ? Theme.of(context)
                      .colorScheme
                      .primary
                      : Colors.grey.shade400,
                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}