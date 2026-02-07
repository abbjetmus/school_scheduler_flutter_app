import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';

import '../../../core/di/injection_keys.dart';

class ImportHaldorIdsPage extends CompositionWidget {
  const ImportHaldorIdsPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final studentsStore = inject(studentsStoreKey);
    final classesStore = inject(classesStoreKey);
    final contextRef = useContext();

    final parsedData = ref<List<Map<String, String>>>([]);
    final importing = ref(false);
    final importProgress = ref(0);
    final importTotal = ref(0);
    final importResults = ref<String?>(null);

    void pickFile() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final csvString = utf8.decode(file.bytes!);
          final rows = const CsvToListConverter().convert(csvString);

          if (rows.isEmpty) {
            final ctx = contextRef.value;
            if (ctx != null && ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('CSV-filen är tom')),
              );
            }
            return;
          }

          // First row should be headers: email, class, haldorStudentId
          final headers = rows.first.map((e) => e.toString().toLowerCase()).toList();
          final emailIndex = headers.indexOf('email');
          final classIndex = headers.indexOf('class');
          final haldorIdIndex = headers.indexWhere(
            (h) => h == 'haldorstudentid' || h == 'haldor_student_id' || h == 'haldor id',
          );

          if (emailIndex == -1 || classIndex == -1 || haldorIdIndex == -1) {
            final ctx = contextRef.value;
            if (ctx != null && ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('CSV måste innehålla kolumnerna: email, class, haldorStudentId'),
                ),
              );
            }
            return;
          }

          final data = <Map<String, String>>[];
          for (var i = 1; i < rows.length; i++) {
            final row = rows[i];
            if (row.length > emailIndex && row.length > classIndex && row.length > haldorIdIndex) {
              data.add({
                'email': row[emailIndex].toString(),
                'class': row[classIndex].toString(),
                'haldorStudentId': row[haldorIdIndex].toString(),
              });
            }
          }

          parsedData.value = data;
          importResults.value = null;
        }
      }
    }

    void importHaldorIds() async {
      if (parsedData.value.isEmpty) return;

      importing.value = true;
      importProgress.value = 0;
      importTotal.value = parsedData.value.length;

      final classes = classesStore.classes.value;
      final classMap = {for (var c in classes) (c.name ?? '').toLowerCase(): c.id};

      int successful = 0;
      int failed = 0;
      final errors = <String>[];

      for (final row in parsedData.value) {
        final className = row['class']?.toLowerCase() ?? '';
        final classId = classMap[className];

        if (classId == null) {
          errors.add('Rad ${importProgress.value + 1}: Klass "${row['class']}" hittades inte');
          failed++;
        } else {
          final email = row['email'] ?? '';
          final haldorId = row['haldorStudentId'] ?? '';

          if (email.isEmpty || haldorId.isEmpty) {
            errors.add('Rad ${importProgress.value + 1}: E-post eller Haldor-ID saknas');
            failed++;
          } else {
            final success = await studentsStore.updateStudentHaldorIdByEmail(
              email,
              classId,
              haldorId,
            );

            if (success) {
              successful++;
            } else {
              errors.add('Rad ${importProgress.value + 1}: Kunde inte uppdatera elev med e-post $email');
              failed++;
            }
          }
        }

        importProgress.value++;
      }

      importing.value = false;
      importResults.value = 'Import klar!\n'
          'Lyckade: $successful\n'
          'Misslyckade: $failed\n'
          '${errors.isNotEmpty ? '\nFel:\n${errors.join('\n')}' : ''}';

      final ctx = contextRef.value;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Import klar! $successful lyckade, $failed misslyckade')),
        );
      }
    }

    onMounted(() {
      classesStore.getClasses();
    });

    return (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Importera Haldor-ID'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CSV-format',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'CSV-filen måste innehålla följande kolumner:\n'
                          '• email - Elevens e-post\n'
                          '• class - Klassnamn (måste matcha exakt)\n'
                          '• haldorStudentId - Haldor student-ID',
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: importing.value ? null : pickFile,
                          icon: const Icon(Icons.file_upload),
                          label: const Text('Välj CSV-fil'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (parsedData.value.isNotEmpty) ...[
                  Text(
                    'Förhandsgranskning (${parsedData.value.length} rader)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Card(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('E-post')),
                              DataColumn(label: Text('Klass')),
                              DataColumn(label: Text('Haldor-ID')),
                            ],
                            rows: parsedData.value.map((row) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(row['email'] ?? '')),
                                  DataCell(Text(row['class'] ?? '')),
                                  DataCell(Text(row['haldorStudentId'] ?? '')),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (importing.value)
                    Column(
                      children: [
                        LinearProgressIndicator(
                          value: importTotal.value > 0
                              ? importProgress.value / importTotal.value
                              : 0,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Importerar ${importProgress.value} av ${importTotal.value}...',
                        ),
                      ],
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: importHaldorIds,
                      icon: const Icon(Icons.upload),
                      label: const Text('Importera'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  if (importResults.value != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          importResults.value!,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
  }
}
