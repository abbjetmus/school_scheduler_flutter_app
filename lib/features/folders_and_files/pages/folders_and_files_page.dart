import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_types.dart';
import '../../auth/auth_store.dart' as app_auth;

class FoldersAndFilesPage extends CompositionWidget {
  final String? folderId;

  const FoldersAndFilesPage({super.key, this.folderId});

  @override
  Widget Function(BuildContext) setup() {
    final foldersStore = inject(foldersAndFilesStoreKey);
    final authStore = inject(authStoreKey);
    final props = widget();

    onMounted(() {
      final currentFolderId = props.value.folderId;
      if (currentFolderId != null) {
        (foldersStore as dynamic).getFolderById(currentFolderId);
      } else {
        (foldersStore as dynamic).getRootFolder();
      }
    });

    return (context) {
      final currentFolder = (foldersStore as dynamic).currentFolder.value as FolderAndFile?;
      final subfolders = (foldersStore as dynamic).subfolders.value as List<FolderAndFile>;
      final loading = (foldersStore as dynamic).loading.value as bool;

      return Scaffold(
        appBar: AppBar(
          title: Text(currentFolder?.name ?? 'Filer & Mappar'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  if (currentFolder != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Sökväg: ${currentFolder.path}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  if (subfolders.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Mappar',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...subfolders.map((folder) => ListTile(
                          leading: const Icon(Icons.folder),
                          title: Text(folder.name),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _showDeleteDialog(context, foldersStore, folder),
                          ),
                          onTap: () {
                            context.go('/folders-and-files/${folder.id}');
                          },
                          onLongPress: () => _showDeleteDialog(context, foldersStore, folder),
                        )),
                  ],
                  if (currentFolder != null && currentFolder.files.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Filer',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...currentFolder.files.map((file) => ListTile(
                          leading: const Icon(Icons.insert_drive_file),
                          title: Text(file),
                        )),
                  ],
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showActionMenu(context, foldersStore, authStore, currentFolder),
          child: const Icon(Icons.add),
        ),
      );
    };
  }

  void _showActionMenu(BuildContext context, dynamic store, dynamic authStore, FolderAndFile? currentFolder) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.create_new_folder),
            title: const Text('Ny mapp'),
            onTap: () {
              Navigator.of(context).pop();
              _showNewFolderDialog(context, store, authStore, currentFolder);
            },
          ),
        ],
      ),
    );
  }

  void _showNewFolderDialog(BuildContext context, dynamic store, dynamic authStore, FolderAndFile? currentFolder) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ny mapp'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Mappnamn'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () async {
              final schoolId = (authStore as app_auth.AuthStore).currentSchoolId;
              final folderName = nameController.text;
              final currentPath = currentFolder?.path ?? '';
              final newPath = currentPath.isEmpty ? folderName : '$currentPath/$folderName';

              final success = await store.createFolder({
                'name': folderName,
                'parentFolder': currentFolder?.id,
                'school': schoolId,
                'path': newPath,
              });

              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Mapp skapad'
                        : 'Misslyckades att skapa mapp'),
                  ),
                );
              }
            },
            child: const Text('Skapa'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, dynamic store, FolderAndFile folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort mapp'),
        content: Text('Är du säker på att du vill ta bort ${folder.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () async {
              final success = await store.deleteFolder(folder.id);

              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Mapp borttagen'
                        : 'Misslyckades att ta bort mapp'),
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
