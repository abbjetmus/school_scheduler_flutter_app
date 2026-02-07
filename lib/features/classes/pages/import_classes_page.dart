import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import '../../../core/di/injection_keys.dart';

class ImportClassesPage extends CompositionWidget {
  const ImportClassesPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final classesStore = inject(classesStoreKey);
    final authStore = inject(authStoreKey);

    final csvDataRef = ref<List<List<dynamic>>>([]);
    final importingRef = ref(false);
    final importResultsRef = ref<Map<String, dynamic>>({});

    void pickFile() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final content = utf8.decode(bytes);
        final csvData = const CsvToListConverter().convert(content);

        if (csvData.isNotEmpty) {
          csvDataRef.value = csvData;
          importResultsRef.value = {};
        }
      }
    }

    void importClasses() async {
      if (csvDataRef.value.length <= 1) {
        return;
      }

      importingRef.value = true;
      importResultsRef.value = {
        'total': 0,
        'success': 0,
        'failed': 0,
      };

      final data = csvDataRef.value;
      final headers = data[0].map((e) => e.toString().toLowerCase()).toList();

      final nameIndex = headers.indexOf('name');
      final extraInfoIndex = headers.indexOf('extrainfo');

      if (nameIndex == -1) {
        importingRef.value = false;
        importResultsRef.value = {
          'error': 'Kolumnen "name" saknas i CSV-filen',
        };
        return;
      }

      int total = 0;
      int success = 0;
      int failed = 0;

      for (int i = 1; i < data.length; i++) {
        final row = data[i];
        if (row.isEmpty || row.length <= nameIndex) continue;

        total++;

        final name = row[nameIndex].toString().trim();
        if (name.isEmpty) {
          failed++;
          continue;
        }

        final extraInfoRaw = extraInfoIndex != -1 && row.length > extraInfoIndex
            ? row[extraInfoIndex].toString()
            : '';

        final extraInfo = extraInfoRaw.isNotEmpty
            ? extraInfoRaw
                .split(';')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : <String>[];

        final classData = {
          'name': name,
          'school': authStore.currentSchoolId,
          'extraInfo': extraInfo,
        };

        final result = await classesStore.createClass(classData);
        if (result) {
          success++;
        } else {
          failed++;
        }
      }

      importResultsRef.value = {
        'total': total,
        'success': success,
        'failed': failed,
      };
      importingRef.value = false;

      if (success > 0) {
        await classesStore.getClasses();
      }
    }

    return (context) {
      final csvData = csvDataRef.value;
      final importing = importingRef.value;
      final importResults = importResultsRef.value;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Importera Klasser'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: importing ? null : pickFile,
                icon: const Icon(Icons.file_upload),
                label: const Text('Välj CSV-fil'),
              ),
              const SizedBox(height: 8),
              const Text(
                'CSV-filen ska ha kolumnerna: name, extraInfo (semikolon-separerad)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (importResults.containsKey('error'))
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    importResults['error'],
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (importResults.containsKey('total'))
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Importresultat',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Totalt: ${importResults['total']}'),
                      Text(
                        'Lyckades: ${importResults['success']}',
                        style: const TextStyle(color: Colors.green),
                      ),
                      Text(
                        'Misslyckades: ${importResults['failed']}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (csvData.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Förhandsgranskning (${csvData.length - 1} rader)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton.icon(
                      onPressed: importing || csvData.length <= 1
                          ? null
                          : importClasses,
                      icon: importing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(importing ? 'Importerar...' : 'Importera'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: csvData[0]
                            .map((header) => DataColumn(
                                  label: Text(
                                    header.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ))
                            .toList(),
                        rows: csvData
                            .skip(1)
                            .take(10)
                            .map(
                              (row) => DataRow(
                                cells: row
                                    .map((cell) => DataCell(
                                          Text(cell.toString()),
                                        ))
                                    .toList(),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
                if (csvData.length > 11)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Visar första 10 rader av ${csvData.length - 1}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
    };
  }
}
