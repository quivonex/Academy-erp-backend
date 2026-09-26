import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/open_external_link.dart';

import '../data/student_portal_repository.dart';

class MaterialDetailScreen
    extends ConsumerStatefulWidget {
  const MaterialDetailScreen({
    super.key,
    required this.materialUuid,
  });

  final String materialUuid;

  @override
  ConsumerState<MaterialDetailScreen>
  createState() =>
      _MaterialDetailScreenState();
}

class _MaterialDetailScreenState
    extends ConsumerState<MaterialDetailScreen> {
  late Future<Map<String, dynamic>> _material;
  late Future<Map<String, dynamic>> _progress;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final api = ref.read(
      studentPortalRepositoryProvider,
    );

    _material = api.material(
      widget.materialUuid,
    );

    _progress = api.materialProgress(
      widget.materialUuid,
    );
  }

  Future<void> _markCompleted() async {
    setState(() => _saving = true);

    try {
      final api = ref.read(
        studentPortalRepositoryProvider,
      );

      await api.saveMaterialProgress(
        materialUuid: widget.materialUuid,
        markCompleted: true,
      );

      if (!mounted) return;

      setState(() {
        _progress = api.materialProgress(
          widget.materialUuid,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Progress saved'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _material,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load material: '
                  '${snapshot.error}',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final material = snapshot.data!;
        final url =
        material['content_url']?.toString();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              material['title']
                  ?.toString() ??
                  'Study material',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              material['description']
                  ?.toString() ??
                  '',
            ),
            const SizedBox(height: 12),
            Chip(
              label: Text(
                material['material_type']
                    ?.toString() ??
                    'MATERIAL',
              ),
            ),
            const SizedBox(height: 20),
            if (url != null &&
                url.isNotEmpty) ...[
              const Text('Content URL'),
              const SizedBox(height: 8),
              SelectableText(url),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => openExternalLink(
                  context,
                  url,
                ),
                icon: const Icon(Icons.open_in_new),
                label: Text(
                  material['material_type'] == 'VIDEO'
                      ? 'Watch video'
                      : 'Open material',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: url),
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Link copied',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy link'),
              ),
            ] else
              const Text(
                'Content link is not available.',
              ),
            const SizedBox(height: 24),
            FutureBuilder<Map<String, dynamic>>(
              future: _progress,
              builder: (context, progress) {
                if (!progress.hasData) {
                  return const SizedBox.shrink();
                }

                final completed =
                    progress.data!['is_completed'] ==
                        true;

                return Text(
                  completed
                      ? 'Status: Completed'
                      : 'Status: In progress',
                );
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed:
              _saving ? null : _markCompleted,
              child: Text(
                _saving
                    ? 'Saving...'
                    : 'Mark as completed',
              ),
            ),
          ],
        );
      },
    );
  }
}