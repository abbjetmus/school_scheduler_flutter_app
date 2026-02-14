import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_types.dart';
import '../settings_store.dart';

class SettingsPage extends CompositionWidget {
  const SettingsPage({super.key});

  static const String path = '/settings';

  @override
  Widget Function(BuildContext) setup() {
    final settingsStore = inject(settingsStoreKey);
    final attendanceApiService = inject(attendanceApiServiceKey);
    final showToken = ref(false);
    final soundEnabled = ref(attendanceApiService.soundEnabled);
    final (tokenController, _, __) = useTextEditingController();

    // Default sync dates: current week Monday 00:00 to Sunday 23:59
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final syncStartDate = ref<DateTime>(DateTime(monday.year, monday.month, monday.day));
    final syncEndDate = ref<DateTime>(DateTime(sunday.year, sunday.month, sunday.day, 23, 59));

    onMounted(() async {
      await settingsStore.fetchSchool();
      await settingsStore.fetchToken();
      final token = settingsStore.token.value;
      if (token != null) {
        tokenController.text = token.token;
      }
    });

    return (context) {
      final school = settingsStore.school.value;
      final loading = settingsStore.loading.value;

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
            const SizedBox(height: 16),
            _buildHaldorTokenCard(
              context,
              settingsStore,
              tokenController,
              showToken,
            ),
            const SizedBox(height: 16),
            Card(
              child: SwitchListTile(
                title: const Text('Ljud vid närvaroregistrering'),
                subtitle: const Text('Spela upp ljud vid incheckning, utcheckning och fel'),
                secondary: const Icon(Icons.volume_up),
                value: soundEnabled.value,
                onChanged: (value) {
                  soundEnabled.value = value;
                  attendanceApiService.soundEnabled = value;
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildCalendarSyncCard(
              context,
              settingsStore,
              syncStartDate,
              syncEndDate,
            ),
          ],
        ),
      );
    };
  }

  Widget _buildSchoolNameCard(BuildContext context, SettingsStore store, School school) {
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

  Widget _buildAddressCard(BuildContext context, SettingsStore store, School school) {
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

  Widget _buildColorCard(BuildContext context, SettingsStore store, School school) {
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
                    decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '#RRGGBB'),
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

  Widget _buildImageCard(BuildContext context, SettingsStore store, School school) {
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
                final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);

                if (result != null && result.files.single.bytes != null) {
                  final success = await store.updateSchoolImage(result.files.single.bytes!, result.files.single.name);
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

  Widget _buildEmailDomainsCard(BuildContext context, SettingsStore store) {
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
              children: store.allowedEmailDomains.map((domain) {
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
                    decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'exempel.se'),
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
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Domän tillagd')));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Misslyckades')));
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

  Widget _buildHaldorSchoolIdCard(BuildContext context, SettingsStore store, School school) {
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

  Widget _buildHaldorTokenCard(
    BuildContext context,
    SettingsStore store,
    TextEditingController tokenController,
    Ref<bool> showToken,
  ) {
    final tokenRecord = store.token.value;
    final isLoading = store.tokenLoading.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.vpn_key),
                SizedBox(width: 8),
                Text('Haldor Token', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              TextField(
                controller: tokenController,
                obscureText: !showToken.value,
                decoration: InputDecoration(
                  labelText: 'Token',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(showToken.value ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      showToken.value = !showToken.value;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: tokenController.text.isEmpty || tokenRecord == null
                    ? null
                    : () async {
                        final success = await store.updateToken(tokenController.text);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(success ? 'Token uppdaterad' : 'Misslyckades')),
                          );
                        }
                      },
                icon: const Icon(Icons.save),
                label: const Text('Uppdatera token'),
              ),
              if (tokenRecord == null) ...[
                const SizedBox(height: 8),
                Text(
                  'Ingen token hittades för denna skola.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSyncCard(
    BuildContext context,
    SettingsStore store,
    Ref<DateTime> syncStartDate,
    Ref<DateTime> syncEndDate,
  ) {
    final isSyncing = store.syncLoading.value;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.sync),
                SizedBox(width: 8),
                Text('Synkronisera kalenderhändelser', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: syncStartDate.value,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        syncStartDate.value = DateTime(picked.year, picked.month, picked.day);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Startdatum',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(dateFormat.format(syncStartDate.value)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: syncEndDate.value,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        syncEndDate.value = DateTime(picked.year, picked.month, picked.day, 23, 59);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Slutdatum',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(dateFormat.format(syncEndDate.value)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: isSyncing
                  ? null
                  : () async {
                      final result = await store.syncCalendarEvents(
                        syncStartDate.value,
                        syncEndDate.value,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result.success
                                  ? 'Kalenderhändelser synkroniserade'
                                  : 'Fel vid synkronisering: ${result.error}',
                            ),
                          ),
                        );
                      }
                    },
              icon: isSyncing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
              label: const Text('Synkronisera händelser'),
            ),
          ],
        ),
      ),
    );
  }
}
