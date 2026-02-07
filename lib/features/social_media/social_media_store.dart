import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../core/models/pocketbase_types.dart';
import '../auth/auth_store.dart' as app_auth;

class SocialMediaStore {
  final PocketBase _pb;
  final app_auth.AuthStore _authStore;

  SocialMediaStore(this._pb, this._authStore);

  final _links = ref<List<SocialMediaLink>>([]);
  final _loading = ref<bool>(false);

  Ref<List<SocialMediaLink>> get links => _links;
  Ref<bool> get loading => _loading;

  Future<bool> fetchAll() async {
    _loading.value = true;
    try {
      final schoolId = _authStore.currentSchoolId;
      final records = await _pb
          .collection(Collections.socialMediaLinks)
          .getFullList(filter: 'school="$schoolId"');
      _links.value =
          records.map((r) => SocialMediaLink.fromRecord(r)).toList();
      return true;
    } catch (e) {
      debugPrint('SocialMediaStore: Error fetching links: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> create(Map<String, dynamic> data) async {
    try {
      await _pb.collection(Collections.socialMediaLinks).create(body: data);
      await fetchAll();
      return true;
    } catch (e) {
      debugPrint('SocialMediaStore: Error creating link: $e');
      return false;
    }
  }

  Future<bool> update(String id, Map<String, dynamic> data) async {
    try {
      await _pb.collection(Collections.socialMediaLinks).update(id, body: data);
      await fetchAll();
      return true;
    } catch (e) {
      debugPrint('SocialMediaStore: Error updating link: $e');
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _pb.collection(Collections.socialMediaLinks).delete(id);
      _links.value = _links.value.where((l) => l.id != id).toList();
      return true;
    } catch (e) {
      debugPrint('SocialMediaStore: Error deleting link: $e');
      return false;
    }
  }
}
