import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_keys.dart';

class SubscriptionsListPage extends CompositionWidget {
  const SubscriptionsListPage({super.key});

  static const String path = '/subscriptions';

  @override
  Widget Function(BuildContext) setup() {
    final subscriptionsStore = inject(subscriptionsStoreKey);

    // Load subscriptions on init
    onMounted(() {
      subscriptionsStore.fetchAll();
    });

    return (context) {
      final subscriptions = subscriptionsStore.subscriptions.value;
      final loading = subscriptionsStore.loading.value;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Prenumerationer'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : subscriptions.isEmpty
                ? const Center(
                    child: Text(
                      'Inga prenumerationer',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: subscriptions.length,
                    itemBuilder: (context, index) {
                      final subscription = subscriptions[index];
                      return ListTile(
                        title: Text(subscription.title ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                context.push('/edit-subscription/${subscription.id}');
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Bekräfta borttagning'),
                                    content: Text(
                                      'Är du säker på att du vill ta bort "${subscription.title ?? ''}"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text('Avbryt'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text('Ta bort'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed == true) {
                                  await subscriptionsStore.delete(subscription.id);
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            context.push('/create-subscription');
          },
          child: const Icon(Icons.add),
        ),
      );
    };
  }
}
