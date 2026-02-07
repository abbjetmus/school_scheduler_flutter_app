import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_types.dart';

class SettingsPage extends CompositionWidget {
  const SettingsPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final settingsStore = inject(settingsStoreKey);

    onMounted(() {
      (settingsStore as dynamic).fetchSchool();
    });

    return (context) {
      final school = (settingsStore as dynamic).school.value as School?;
      final loading = (settingsStore as dynamic).loading.value as bool;

      if (loading || school == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Inställningar')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      return Scaffold(
        appBar: AppBar(title: const Text('Inställningar')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSchoolNameCard(context, settingsStore, school),
            const SizedBox(height: 16),
            _buildAddressCard(context, settingsStore, school),
            const SizedBox(height: 16),
            _buildColorCard(context, settingsStore, school),
            const SizedBox(height: 16),
            _buildImageCard(context, settingsStore, school),
            const SizedBox(height: 16),
            _buildEmailDomainsCard(context, settingsStore),
            const SizedBox(height: 16),
            _buildHaldorSchoolIdCard(context, settingsStore, school),
          ],
        ),
      );
    };
  }

  Widget _buildSchoolNameCard(BuildContext context, dynamic store, School school) {
    final controller = TextEditingController(text: school.name);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Skolnamn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final success = await store.updateSchoolName(controller.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Skolnamn uppdaterat' : 'Misslyckades')),
                  );
                }
              },
              child: const Text('Spara'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard(BuildContext context, dynamic store, School school) {
    final controller = TextEditingController(text: school.address);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Adress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final success = await store.updateSchoolAddress(controller.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Adress uppdaterad' : 'Misslyckades')),
                  );
                }
              },
              child: const Text('Spara'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorCard(BuildContext context, dynamic store, School school) {
    final controller = TextEditingController(text: school.color);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Färg', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '#RRGGBB',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _parseColor(controller.text),
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final success = await store.updateSchoolColor(controller.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Färg uppdaterad' : 'Misslyckades')),
                  );
                }
              },
              child: const Text('Spara'),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) return Colors.grey;
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  Widget _buildImageCard(BuildContext context, dynamic store, School school) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Skolbild', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (school.image != null && school.image!.isNotEmpty)
              Image.network(
                'https://skolpunkten.se/api/files/schools/${school.id}/${school.image}',
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 100),
              ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                  withData: true,
                );

                if (result != null && result.files.single.bytes != null) {
                  final success = await store.updateSchoolImage(
                    result.files.single.bytes!,
                    result.files.single.name,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(success ? 'Bild uppdaterad' : 'Misslyckades')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.upload),
              label: const Text('Välj bild'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailDomainsCard(BuildContext context, dynamic store) {
    final controller = TextEditingController();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tillåtna e-postdomäner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: (store.allowedEmailDomains as List<String>).map((domain) {
                return Chip(
                  label: Text(domain),
                  onDeleted: () async {
                    final updated = List<String>.from(store.allowedEmailDomains)..remove(domain);
                    final success = await store.updateAllowedEmailDomains(updated);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(success ? 'Domän borttagen' : 'Misslyckades')),
                      );
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'exempel.se',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    if (controller.text.isNotEmpty) {
                      final updated = List<String>.from(store.allowedEmailDomains)..add(controller.text);
                      final success = await store.updateAllowedEmailDomains(updated);
                      if (context.mounted) {
                        if (success) {
                          controller.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Domän tillagd')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Misslyckades')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Lägg till'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHaldorSchoolIdCard(BuildContext context, dynamic store, School school) {
    final controller = TextEditingController(text: school.haldorSchoolId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Haldor Skol-ID', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final success = await store.updateHaldorSchoolId(controller.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Haldor Skol-ID uppdaterat' : 'Misslyckades')),
                  );
                }
              },
              child: const Text('Spara'),
            ),
          ],
        ),
      ),
    );
  }
}
