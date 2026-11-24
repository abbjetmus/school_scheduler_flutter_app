import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../features/kiosk/pin_dialog.dart';
import '../../features/reader/pcsc_reader_service.dart';
import '../di/injection_keys.dart';
import '../theme/app_theme.dart';

class _NavItem {
  const _NavItem(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}

const _nav = [
  _NavItem('/', 'Utlåning', Icons.contactless_outlined),
  _NavItem('/loans', 'Lån', Icons.swap_horiz),
  _NavItem('/books', 'Böcker', Icons.menu_book_outlined),
  _NavItem('/cards', 'Kort/Blipp', Icons.badge_outlined),
  _NavItem('/settings', 'Inställningar', Icons.settings_outlined),
];

/// Sidomenyn — samma som i webben (layouts/admin.vue): ljus, märke överst,
/// blått piller för aktiv sida. Längst ned: läsarens läge och vem som är
/// inloggad. I kioskläget finns bara utlåningen och knappen "Lås upp".
class AppShell extends CompositionWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final auth = inject(authStoreKey);
    final hub = inject(readerHubKey);
    final kiosk = inject(kioskStoreKey);
    final contextRef = useContext();

    final readerState = ref(hub.pcsc.state);
    final readerName = ref(hub.pcsc.readerName);
    StreamSubscription<PcscReaderState>? sub;
    StreamSubscription<void>? closeSub;
    onMounted(() {
      sub = hub.pcsc.stateStream.listen((s) {
        readerState.value = s;
        readerName.value = hub.pcsc.readerName;
      });
      // Windows försöker stänga fönstret i kioskläget — fråga efter PIN.
      closeSub = kiosk.closeRequests.listen((_) {
        final ctx = contextRef.value;
        if (ctx != null && ctx.mounted) showUnlockDialog(ctx, kiosk, closing: true);
      });
    });
    onUnmounted(() {
      sub?.cancel();
      closeSub?.cancel();
    });

    return (context) {
      final user = auth.user.value;
      final location = props.value.location;
      final polling = readerState.value == PcscReaderState.polling;
      final locked = kiosk.active.value;
      return Scaffold(
        body: Row(
          children: [
            Container(
              width: 248,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(right: BorderSide(color: AppColors.line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.local_library_outlined, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Skolpunkten',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                              Text(
                                auth.schoolName.value.isEmpty ? 'Bibliotek' : 'Bibliotek · ${auth.schoolName.value}',
                                style: const TextStyle(fontSize: 12.5, color: AppColors.ink3, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final item in locked ? _nav.take(1) : _nav)
                    _NavTile(
                      item: item,
                      active: item.path == '/' ? location == '/' : location.startsWith(item.path),
                      onTap: () => context.go(item.path),
                    ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 10, color: polling ? AppColors.success : AppColors.lineStrong),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            polling ? (readerName.value ?? 'Läsare ansluten') : 'Ingen USB-läsare',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.ink3),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  if (locked)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                      child: _NavTile(
                        item: const _NavItem('', 'Lås upp', Icons.lock_outline),
                        active: false,
                        onTap: () => showUnlockDialog(context, kiosk),
                      ),
                    )
                  else if (user != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primaryLight,
                            child: Text(
                              user.name.isEmpty ? '?' : user.name.characters.first.toUpperCase(),
                              style: const TextStyle(color: AppColors.onPrimaryLight, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(user.name,
                                overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          IconButton(
                            tooltip: 'Logga ut',
                            icon: const Icon(Icons.logout, size: 20),
                            onPressed: auth.signOut,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: props.value.child),
          ],
        ),
      );
    };
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.active, required this.onTap});

  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.onPrimaryLight : AppColors.ink2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: Material(
        color: active ? AppColors.primaryLight : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(item.icon, size: 22, color: color),
                const SizedBox(width: 14),
                Text(
                  item.label,
                  style: TextStyle(fontSize: 14.5, color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
