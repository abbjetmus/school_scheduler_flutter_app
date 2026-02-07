import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../core/models/pocketbase_types.dart';
import '../auth/auth_store.dart' as app_auth;

class SubscriptionsStore {
  final PocketBase _pb;
  final app_auth.AuthStore _authStore;

  SubscriptionsStore(this._pb, this._authStore);

  final _subscriptions = ref<List<SubscriptionPage>>([]);
  final _loading = ref<bool>(false);

  Ref<List<SubscriptionPage>> get subscriptions => _subscriptions;
  Ref<bool> get loading => _loading;

  Future<bool> fetchAll() async {
    _loading.value = true;
    try {
      final schoolId = _authStore.currentSchoolId;
      final records = await _pb
          .collection(Collections.subscriptionPages)
          .getFullList(filter: 'school="$schoolId"');
      _subscriptions.value =
          records.map((r) => SubscriptionPage.fromRecord(r)).toList();
      return true;
    } catch (e) {
      debugPrint('SubscriptionsStore: Error fetching subscriptions: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<SubscriptionPage?> fetchById(String id) async {
    try {
      final record = await _pb.collection(Collections.subscriptionPages).getOne(id);
      return SubscriptionPage.fromRecord(record);
    } catch (e) {
      debugPrint('SubscriptionsStore: Error fetching subscription: $e');
      return null;
    }
  }

  Future<bool> create(Map<String, dynamic> data) async {
    try {
      await _pb.collection(Collections.subscriptionPages).create(body: data);
      await fetchAll();
      return true;
    } catch (e) {
      debugPrint('SubscriptionsStore: Error creating subscription: $e');
      return false;
    }
  }

  Future<bool> update(String id, Map<String, dynamic> data) async {
    try {
      await _pb.collection(Collections.subscriptionPages).update(id, body: data);
      await fetchAll();
      return true;
    } catch (e) {
      debugPrint('SubscriptionsStore: Error updating subscription: $e');
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _pb.collection(Collections.subscriptionPages).delete(id);
      _subscriptions.value =
          _subscriptions.value.where((s) => s.id != id).toList();
      return true;
    } catch (e) {
      debugPrint('SubscriptionsStore: Error deleting subscription: $e');
      return false;
    }
  }
}
