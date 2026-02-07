import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../core/models/pocketbase_types.dart';
import '../auth/auth_store.dart' as app_auth;

class FoldersAndFilesStore {
  final PocketBase _pb;
  final app_auth.AuthStore _authStore;

  FoldersAndFilesStore(this._pb, this._authStore);

  final _rootFolder = ref<FolderAndFile?>(null);
  final _currentFolder = ref<FolderAndFile?>(null);
  final _subfolders = ref<List<FolderAndFile>>([]);
  final _loading = ref<bool>(false);

  Ref<FolderAndFile?> get rootFolder => _rootFolder;
  Ref<FolderAndFile?> get currentFolder => _currentFolder;
  Ref<List<FolderAndFile>> get subfolders => _subfolders;
  Ref<bool> get loading => _loading;

  Future<bool> getRootFolder() async {
    final schoolId = _authStore.currentSchoolId;
    if (schoolId == null) return false;
    _loading.value = true;
    try {
      final record = await _pb
          .collection(Collections.foldersAndFiles)
          .getFirstListItem(
            'school="$schoolId" && name="root"',
            expand: 'foldersAndFilesViaParentFolder',
          );
      _rootFolder.value = FolderAndFile.fromRecord(record);
      _currentFolder.value = _rootFolder.value;
      _loadSubfolders(record);
      return true;
    } catch (e) {
      if (e is ClientException && e.statusCode == 404) {
        try {
          final newRoot = await _pb
              .collection(Collections.foldersAndFiles)
              .create(body: {
                'name': 'root',
                'school': schoolId,
                'path': '/root',
              });
          _rootFolder.value = FolderAndFile.fromRecord(newRoot);
          _currentFolder.value = _rootFolder.value;
          _subfolders.value = [];
          return true;
        } catch (createError) {
          debugPrint('FoldersAndFilesStore: Error creating root folder: $createError');
          return false;
        }
      }
      debugPrint('FoldersAndFilesStore: Error getting root folder: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> getFolderById(String id) async {
    _loading.value = true;
    try {
      final record = await _pb
          .collection(Collections.foldersAndFiles)
          .getOne(id, expand: 'foldersAndFilesViaParentFolder');
      _currentFolder.value = FolderAndFile.fromRecord(record);
      _loadSubfolders(record);
      return true;
    } catch (e) {
      debugPrint('FoldersAndFilesStore: Error getting folder: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  void _loadSubfolders(RecordModel record) {
    final expandData = record.get<List<RecordModel>>('expand.foldersAndFilesViaParentFolder');
    if (expandData.isNotEmpty) {
      _subfolders.value =
          expandData.map((r) => FolderAndFile.fromRecord(r)).toList();
    } else {
      _subfolders.value = [];
    }
  }

  Future<bool> createFolder(Map<String, dynamic> data) async {
    try {
      await _pb.collection(Collections.foldersAndFiles).create(body: data);
      if (_currentFolder.value != null) {
        await getFolderById(_currentFolder.value!.id);
      }
      return true;
    } catch (e) {
      debugPrint('FoldersAndFilesStore: Error creating folder: $e');
      return false;
    }
  }

  Future<bool> updateFolder(String id, Map<String, dynamic> data) async {
    try {
      await _pb.collection(Collections.foldersAndFiles).update(id, body: data);
      if (_currentFolder.value != null) {
        await getFolderById(_currentFolder.value!.id);
      }
      return true;
    } catch (e) {
      debugPrint('FoldersAndFilesStore: Error updating folder: $e');
      return false;
    }
  }

  Future<bool> deleteFolder(String id) async {
    try {
      await _pb.collection(Collections.foldersAndFiles).delete(id);
      if (_currentFolder.value != null) {
        await getFolderById(_currentFolder.value!.id);
      }
      return true;
    } catch (e) {
      debugPrint('FoldersAndFilesStore: Error deleting folder: $e');
      return false;
    }
  }
}
