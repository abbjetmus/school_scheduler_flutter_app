import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'dart:async';

import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_types.dart';
import '../../attendance/services/nfc_reader_service.dart';
import '../../attendance/services/usb_reader_service.dart';

class StudentsListPage extends CompositionWidget {
  const StudentsListPage({super.key});

  static const String path = '/students';

  @override
  Widget Function(BuildContext) setup() {
    final studentsStore = inject(studentsStoreKey);
    final classesStore = inject(classesStoreKey);
    final nfcService = inject(nfcReaderServiceKey);
    final usbService = inject(usbReaderServiceKey);
    final contextRef = useContext();

    final currentPage = ref(1);
    final totalPages = ref(1);
    final totalItems = ref(0);
    final searchQuery = ref('');
    final perPage = 20;
    Timer? searchDebounce;

    void loadStudents() async {
      final result = await studentsStore.getStudentsPaginated(
        page: currentPage.value,
        perPage: perPage,
        search: searchQuery.value.isEmpty ? null : searchQuery.value,
      );
      totalPages.value = result.totalPages;
      totalItems.value = result.totalItems;
    }

    void showStudentDialog(BuildContext context, {Student? student}) {
      final nameController = TextEditingController(text: student?.name ?? '');
      final emailController = TextEditingController(text: student?.email ?? '');
      final cardIdController = TextEditingController(text: student?.cardId ?? '');
      String? selectedClassId = student?.classId;

      // Subscribe to card reader streams while dialog is open
      final usbSub = usbService.cardIdStream.listen((cardId) {
        cardIdController.text = cardId;
      });
      final nfcSub = nfcService.cardIdStream.listen((cardId) {
        cardIdController.text = cardId;
      });

      showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(student == null ? 'Lägg till elev' : 'Redigera elev'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Namn', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'E-post', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: cardIdController,
                      decoration: InputDecoration(
                        labelText: 'Kort-ID',
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.contactless),
                        helperText: UsbReaderService.isSupported || NfcReaderService.isNfcSupported
                            ? 'Skanna ett kort för att fylla i automatiskt'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedClassId,
                      decoration: const InputDecoration(labelText: 'Klass', border: OutlineInputBorder()),
                      items: classesStore.classes.value.map((classGroup) {
                        return DropdownMenuItem(value: classGroup.id, child: Text(classGroup.name ?? ''));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedClassId = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  usbSub.cancel();
                  nfcSub.cancel();
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Avbryt'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final data = {
                    'name': nameController.text,
                    'email': emailController.text,
                    'cardId': cardIdController.text,
                    'classId': selectedClassId,
                  };

                  bool success;
                  if (student == null) {
                    success = await studentsStore.createStudent(data);
                  } else {
                    success = await studentsStore.updateStudent(student.id, data);
                  }

                  usbSub.cancel();
                  nfcSub.cancel();

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }

                  if (success) {
                    loadStudents();
                    final ctx = contextRef.value;
                    if (ctx != null && ctx.mounted) {
                      ScaffoldMessenger.of(
                        ctx,
                      ).showSnackBar(SnackBar(content: Text(student == null ? 'Elev skapad' : 'Elev uppdaterad')));
                    }
                  }
                },
                child: const Text('Spara'),
              ),
            ],
          ),
        ),
      );
    }

    void deleteStudent(BuildContext context, Student student) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ta bort elev'),
          content: Text('Är du säker på att du vill ta bort ${student.name}?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Avbryt')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final success = await studentsStore.removeStudent(student.id);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (success) {
                  loadStudents();
                  final ctx = contextRef.value;
                  if (ctx != null && ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Elev borttagen')));
                  }
                }
              },
              child: const Text('Ta bort'),
            ),
          ],
        ),
      );
    }

    onMounted(() {
      classesStore.getClasses();
      loadStudents();
    });

    onUnmounted(() {
      searchDebounce?.cancel();
    });

    return (context) => Scaffold(
      appBar: AppBar(title: const Text('Elever')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Sök elever',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                searchDebounce?.cancel();
                searchDebounce = Timer(const Duration(milliseconds: 500), () {
                  searchQuery.value = value;
                  currentPage.value = 1;
                  loadStudents();
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Visar ${studentsStore.students.value.length} av ${totalItems.value} elever',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: studentsStore.loading.value
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: studentsStore.students.value.length,
                    itemBuilder: (context, index) {
                      final student = studentsStore.students.value[index];
                      final studentClass = classesStore.classes.value.where((c) => c.id == student.classId).firstOrNull;

                      return ListTile(
                        title: Text(student.name),
                        subtitle: Text(
                          '${student.email ?? ''}${studentClass != null ? ' • ${studentClass.name ?? ''}' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => showStudentDialog(context, student: student),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteStudent(context, student),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (totalPages.value > 1)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: currentPage.value > 1
                        ? () {
                            currentPage.value--;
                            loadStudents();
                          }
                        : null,
                    child: const Text('Föregående'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Sida ${currentPage.value} av ${totalPages.value}'),
                  ),
                  ElevatedButton(
                    onPressed: currentPage.value < totalPages.value
                        ? () {
                            currentPage.value++;
                            loadStudents();
                          }
                        : null,
                    child: const Text('Nästa'),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showStudentDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
