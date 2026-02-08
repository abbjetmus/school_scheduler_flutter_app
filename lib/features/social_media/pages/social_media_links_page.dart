import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_types.dart';
import '../../auth/auth_store.dart' as app_auth;

class SocialMediaLinksPage extends CompositionWidget {
  const SocialMediaLinksPage({super.key});

  static const String path = '/social-media-links';

  @override
  Widget Function(BuildContext) setup() {
    final socialMediaStore = inject(socialMediaStoreKey);
    final authStore = inject(authStoreKey);

    onMounted(() {
      (socialMediaStore as dynamic).fetchAll();
    });

    return (context) {
      final links = (socialMediaStore as dynamic).links.value as List<SocialMediaLink>;
      final loading = (socialMediaStore as dynamic).loading.value as bool;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Sociala Medier'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: links.length,
                itemBuilder: (context, index) {
                  final link = links[index];
                  return ListTile(
                    leading: Icon(_getIcon(link.icon)),
                    title: Text(link.title ?? ''),
                    subtitle: Text(link.url ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditDialog(context, socialMediaStore, authStore, link),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _showDeleteDialog(context, socialMediaStore, link),
                        ),
                      ],
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddDialog(context, socialMediaStore, authStore),
          child: const Icon(Icons.add),
        ),
      );
    };
  }

  IconData _getIcon(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'facebook':
        return Icons.facebook;
      case 'twitter':
        return Icons.telegram;
      case 'instagram':
        return Icons.camera_alt;
      case 'youtube':
        return Icons.video_library;
      case 'linkedin':
        return Icons.work;
      default:
        return Icons.link;
    }
  }

  void _showAddDialog(BuildContext context, dynamic store, dynamic authStore) {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    final iconController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lägg till social media-länk'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Titel'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: iconController,
              decoration: const InputDecoration(
                labelText: 'Ikon',
                hintText: 'facebook, twitter, instagram, etc.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () async {
              final schoolId = (authStore as app_auth.AuthStore).currentSchoolId;
              final success = await store.create({
                'title': titleController.text,
                'url': urlController.text,
                'icon': iconController.text,
                'school': schoolId,
              });

              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Länk tillagd'
                        : 'Misslyckades att lägga till länk'),
                  ),
                );
              }
            },
            child: const Text('Lägg till'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, dynamic store, dynamic authStore, SocialMediaLink link) {
    final titleController = TextEditingController(text: link.title);
    final urlController = TextEditingController(text: link.url);
    final iconController = TextEditingController(text: link.icon);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redigera social media-länk'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Titel'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: iconController,
              decoration: const InputDecoration(
                labelText: 'Ikon',
                hintText: 'facebook, twitter, instagram, etc.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () async {
              final schoolId = (authStore as app_auth.AuthStore).currentSchoolId;
              final success = await store.update(link.id, {
                'title': titleController.text,
                'url': urlController.text,
                'icon': iconController.text,
                'school': schoolId,
              });

              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Länk uppdaterad'
                        : 'Misslyckades att uppdatera länk'),
                  ),
                );
              }
            },
            child: const Text('Spara'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, dynamic store, SocialMediaLink link) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort länk'),
        content: Text('Är du säker på att du vill ta bort ${link.title}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () async {
              final success = await store.delete(link.id);

              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Länk borttagen'
                        : 'Misslyckades att ta bort länk'),
                  ),
                );
              }
            },
            child: const Text('Ta bort'),
          ),
        ],
      ),
    );
  }
}
