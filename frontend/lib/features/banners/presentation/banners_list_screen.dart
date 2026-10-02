import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/banner_repository.dart';

class BannersListScreen extends ConsumerStatefulWidget {
  const BannersListScreen({
    super.key,
  });

  @override
  ConsumerState<BannersListScreen> createState() =>
      _BannersListScreenState();
}

class _BannersListScreenState extends ConsumerState<BannersListScreen> {
  late Future<HomeBannerPage> result;

  int page = 1;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result = ref.read(bannerRepositoryProvider).list(
          page: page,
        );
  }

  void refresh() {
    setState(reload);
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Banners',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            FilledButton.icon(
              onPressed: () async {
                await context.push(
                  '/banners/create',
                );

                if (mounted) {
                  refresh();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Banner'),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<HomeBannerPage>(
            future: result,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not load banners:\n${snapshot.error}',
                  ),
                );
              }

              final data = snapshot.data!;

              if (data.results.isEmpty) {
                return const Center(
                  child: Text(
                    'No banners found.',
                  ),
                );
              }

              return ListView.builder(
                itemCount: data.results.length,
                itemBuilder: (context, index) {
                  final banner = data.results[index];

                  return Card(
                    child: ListTile(
                      leading: banner.imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(
                                6,
                              ),
                              child: Image.network(
                                banner.imageUrl,
                                width: 90,
                                height: 55,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(
                              Icons.image,
                            ),
                      title: Text(
                        banner.title,
                      ),
                      subtitle: Text(
                        [
                          if (banner.courseName != null) banner.courseName!,
                          'Order: ${banner.displayOrder}',
                        ].join(' • '),
                      ),
                      trailing: Chip(
                        label: Text(
                          banner.isActive ? 'Active' : 'Inactive',
                        ),
                      ),
                      onTap: () async {
                        await context.push(
                          '/banners/${banner.uuid}',
                        );

                        if (mounted) {
                          refresh();
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
