import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_types.dart';

class UsersListPage extends CompositionWidget {
  const UsersListPage({super.key});

  static const String path = '/users';

  @override
  Widget Function(BuildContext) setup() {
    final usersStore = inject(usersStoreKey);
    final authStore = inject(authStoreKey);

    onMounted(() {
      final schoolId = authStore.currentSchoolId;
      (usersStore as dynamic).getUsers(schoolId: schoolId);
    });

    return (context) {
      final users = (usersStore as dynamic).users.value as List<User>;
      final loading = (usersStore as dynamic).loading.value as bool;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Användare'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    title: Text(user.name ?? ''),
                    subtitle: Text(user.email),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditDialog(context, usersStore, user),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _showDeleteDialog(context, usersStore, user),
                        ),
                      ],
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddDialog(context, usersStore, authStore),
          child: const Icon(Icons.add),
        ),
      );
    };
  }

  void _showAddDialog(BuildContext context, dynamic store, dynamic authStore) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lägg till användare'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Namn'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'E-post'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () async {
              final tempPassword = store.generateTemporaryPassword();
              final schoolId = authStore.currentSchoolId;

              final success = await store.createUser({
                'name': nameController.text,
                'email': emailController.text,
                'password': tempPassword,
                'passwordConfirm': tempPassword,
                'school': schoolId,
              });

              if (context.mounted) {
                Navigator.of(context).pop();
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Användare skapad. Tillfälligt lösenord: $tempPassword'),
                      duration: const Duration(seconds: 10),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Misslyckades att skapa användare')),
                  );
                }
              }
            },
            child: const Text('Lägg till'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, dynamic store, User user) {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redigera användare'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Namn'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'E-post'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () async {
              final success = await store.updateUser(user.id, {
                'name': nameController.text,
                'email': emailController.text,
              });

              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Användare uppdaterad'
                        : 'Misslyckades att uppdatera användare'),
                  ),
                );
              }
            },
            child: const Text('Spara'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, dynamic store, User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort användare'),
        content: Text('Är du säker på att du vill ta bort ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () async {
              final success = await store.removeUser(user.id);

              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Användare borttagen'
                        : 'Misslyckades att ta bort användare'),
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
