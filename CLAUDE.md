# Skolpunkten Bibliotek (school_scheduler_flutter_app) — CLAUDE.md

## Project Overview

Windows-appen i skolbiblioteket: låna ut och ta emot böcker genom att blippa RFID-etiketter och lånekort. Byggdes om 2026-11-24 från den gamla närvaroappen (som pekade på borttagna collections). Svenskt UI, samma design som school-scheduler-nuxt-app (Vuetify-temat i nuxt.config.ts → `lib/core/theme/app_theme.dart`, Figtree via google_fonts, ljust läge).

- **Package name**: `school_scheduler_flutter_app`
- **Plattform**: bara Windows. Ingen macOS/Linux/mobil.
- Se README.md för läsare, kioskläge och hur datorn låses (Shell Launcher).

## Backend

- PocketBase (school-scheduler-pb), URL i `lib/core/pocketbase/pocketbase_client.dart`, `--dart-define=PB_URL=...` vid test.
- Inloggning: Microsoft/Google via `authWithOAuth2` (öppnar webbläsaren). Bara lärare/admin släpps in.
- Collections `libraryTitles`, `libraryCopies`, `libraryLoans`, `userCards`. Utlåning/återlämning/kort/scan via `/api/library/*` (pb_hooks/api/library.pb.js). Svarsformatet ligger i `lib/features/library/library_models.dart` och måste hållas i takt med pb_hooks/utils/library.js och nuxt-appens app/types/library.ts.

## Architecture

```
lib/
├── main.dart                      # AppRoot: DI, router, kioskläge följer inloggningen
├── core/
│   ├── di/injection_keys.dart     # pocketBaseKey, authStoreKey, libraryApiKey, readerHubKey, circulationStoreKey, kioskStoreKey
│   ├── pocketbase/                # PocketBaseClient (AsyncAuthStore i shared_preferences)
│   ├── router/app_router.dart     # GoRouter, redirect på inloggning och kioskläge
│   ├── theme/app_theme.dart       # Skolpunktens färger och former
│   └── widgets/                   # AppShell (sidomeny), ui.dart (PageHeader, EmptyState, StatusPill, SectionCard)
└── features/
    ├── auth/                      # AuthStore, LoginPage
    ├── library/                   # LibraryApi (tjänst), CirculationStore (utlåningens flöde), sidor
    ├── reader/                    # PcscReaderService, KeyboardReaderService, ReaderHub (en kodström + ljud + inställningar)
    ├── kiosk/                     # KioskStore (PIN, autostart, kanal skolpunkten/kiosk), PIN-dialog, inställningskort
    └── settings/                  # Inställningssidan
windows/runner/kiosk_mode.cpp      # Helskärm överst, WM_CLOSE stoppas, LL-tangentbordshook (Win, Alt+Tab, Alt+F4, Ctrl+Shift+Esc)
```

## Routing (GoRouter)

- `context.go('/path')` — aldrig `Navigator.pushNamed()`.
- `/login` utan skal; `/`, `/loans`, `/books`, `/cards`, `/settings` i `AppShell`. I kioskläget bara `/`.

## Läsare

- Alla läsare matar `ReaderHub.codes`. Sidor lyssnar i `onMounted` och avslutar i `onUnmounted`.
- `KeyboardReaderService` gör ingenting när ett textfält har fokus — då hamnar koden i fältet.
- PC/SC: UID via APDU FF CA 00 00 00 (fungerar för ISO 15693 och ISO 14443 på t.ex. ACR1552U).

## Testa utan Windows

Det går inte att bygga Windows-delen på Mac. Dart-koden kan provas med `flutter test` och
`debugDefaultTargetPlatformOverride = TargetPlatform.windows`. Kanalen `skolpunkten/kiosk` saknas
då (MissingPluginException fångas i KioskStore).

## Common Gotchas

- `AuthStore` krockar med PocketBase SDK:ns — importera `package:pocketbase/pocketbase.dart` med `show`.
- Don't forget `dart:async` when using `StreamSubscription` type annotations.
- `flutter analyze` from project root.
- AsyncAuthStore sparar `{"token", "model"}` (inte "record").

---

# Flutter Compositions - Development Guidelines

## Core Principle: Always Use CompositionWidget

**CRITICAL**: All stateful widgets in this project MUST use `CompositionWidget` from `flutter_compositions` instead of `StatefulWidget` or `StatelessWidget` when state management is needed.

## Documentation Location

The Flutter Compositions documentation is located in:

- **Local path**: `../flutter_compositions/docs/`
- **Online**: https://yoyo930021.github.io/flutter_compositions/

## Key Rules

1. **Widget Creation**:

   - Use `CompositionWidget` for all widgets that need state, reactivity, or lifecycle management
   - Use `StatelessWidget` ONLY for pure presentational widgets with no state or side effects
   - NEVER use `StatefulWidget` - always prefer `CompositionWidget`

2. **State Management**:

   - Use `ref()` for reactive state variables - creates mutable reactive references
     - Example: `final count = ref(0);` then `count.value = 1;` to update
     - Access values with `.value` - this creates reactive dependencies
   - Use `computed()` for derived/reactive values - automatically recalculates when dependencies change
     - Example: `final double = computed(() => count.value * 2);`
     - Use for values derived from other refs - enables fine-grained reactivity
   - Use `watch()` for side effects when you need both old and new values
     - Example: `watch(() => count.value, (newVal, oldVal) { /* side effect */ });`
   - Use `watchEffect()` for side effects that run automatically when dependencies change
     - Example: `watchEffect(() { if (count.value > 10) { /* do something */ } });`
     - Runs synchronously during setup and whenever dependencies change
   - Use built-in composables like `useTextEditingController()`, `useGeolocation()`, etc.
   - **Fine-grained reactivity**: Only widgets using `.value` on a ref/computed will rebuild when that specific value changes

3. **Dependency Injection**:

   - Use `provide()` and `inject()` with `InjectionKey` for dependency injection
   - Store keys in `lib/core/di/injection_keys.dart`
   - Access dependencies via `inject(key)` in the `setup()` method

4. **Stores, Services, and Composables Pattern**:

   **CRITICAL**: Services should NOT use `ref()` variables. They should be plain classes.

   **IMPORTANT**: Both **Stores** and **Composables** are valid patterns in this codebase. Choose based on your needs:

   - **Stores**: Use when you need shared state across multiple screens or want to inject a stateful class
   - **Composables**: Use when you need widget-scoped reactive state or want to encapsulate logic with lifecycle management

   **Service Pattern (No Refs):**

   ```dart
   class PolarConnectionService {
     ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
     String? _deviceId;
     late final StreamController<ConnectionStatus> _connectionStatusController =
         StreamController<ConnectionStatus>.broadcast();
     late final StreamController<String?> _deviceIdController =
         StreamController<String?>.broadcast();

     ConnectionStatus get connectionStatus => _connectionStatus;
     String? get deviceId => _deviceId;
     Stream<ConnectionStatus> get connectionStatusStream => _connectionStatusController.stream;
     Stream<String?> get deviceIdStream => _deviceIdController.stream;

     void _updateConnectionStatus(ConnectionStatus status) {
       if (_connectionStatus != status) {
         _connectionStatus = status;
         _connectionStatusController.add(status);
       }
     }

     void _updateDeviceId(String? id) {
       if (_deviceId != id) {
         _deviceId = id;
         _deviceIdController.add(id);
       }
     }

     Future<void> connect(String deviceId) async {
       _updateConnectionStatus(ConnectionStatus.connecting);
       _updateDeviceId(deviceId);
       // ... connection logic ...
       _updateConnectionStatus(ConnectionStatus.connected);
     }
   }
   ```

   **Composable Pattern (Manages Refs):**

   ```dart
   ({
     ReadonlyRef<ConnectionStatus> connectionStatus,
     ReadonlyRef<String?> deviceId,
     ReadonlyRef<bool> isConnected,
     Future<void> Function(String) connect,
     Future<void> Function() disconnect,
   }) usePolarConnection() {
     final service = inject(polarConnectionServiceKey);

     // Create refs in composable, initialize with current service values
     final connectionStatus = ref<ConnectionStatus>(service.connectionStatus);
     final deviceId = ref<String?>(service.deviceId);

     StreamSubscription<ConnectionStatus>? connectionStatusSub;
     StreamSubscription<String?>? deviceIdSub;

     // Subscribe to service streams in onMounted
     onMounted(() {
       connectionStatusSub = service.connectionStatusStream.listen((status) {
         connectionStatus.value = status;
       });
       deviceIdSub = service.deviceIdStream.listen((id) {
         deviceId.value = id;
       });
     });

     // Cleanup subscriptions in onUnmounted
     onUnmounted(() {
       connectionStatusSub?.cancel();
       deviceIdSub?.cancel();
     });

     // Create computed values from refs
     final isConnected = computed(() => connectionStatus.value == ConnectionStatus.connected);

     // Expose methods that call service methods
     Future<void> connect(String deviceId) async {
       await service.connect(deviceId);
     }

     Future<void> disconnect() async {
       await service.disconnect();
     }

     return (
       connectionStatus: connectionStatus,
       deviceId: deviceId,
       isConnected: isConnected,
       connect: connect,
       disconnect: disconnect,
     );
   }
   ```

   **Widget Usage:**

   ```dart
   class ConnectionWidget extends CompositionWidget {
     @override
     Widget Function(BuildContext) setup() {
       final polarConnection = usePolarConnection();

       return (context) => Column(
         children: [
           Text('Status: ${polarConnection.connectionStatus.value}'),
           Text('Device: ${polarConnection.deviceId.value ?? "None"}'),
           if (polarConnection.isConnected.value)
             ElevatedButton(
               onPressed: () => polarConnection.disconnect(),
               child: Text('Disconnect'),
             ),
         ],
       );
     }
   }
   ```

   **Store Pattern (Can Use Refs):**

   ```dart
   class TodosStore {
     TodosStore(this._graphQLClient);

     final GraphQLClient _graphQLClient;

     // Stores CAN use ref() variables
     final Ref<List<Todo>> todos = ref<List<Todo>>([]);
     final Ref<TopMeny?> topMeny = ref<TopMeny?>(null);

     Future<void> fetchTodos() async {
       // ... fetch logic ...
       todos.value = data.todos;
     }

     // Use getters for computed values (can't use computed() in field initializers)
     int get totalCount => todos.value.length;
     int get completedCount =>
         todos.value.where((todo) => todo.status == TodoStatus.DONE).length;
   }
   ```

   **Widget Usage with Store:**

   ```dart
   class TodosScreen extends CompositionWidget {
     @override
     Widget Function(BuildContext) setup() {
       final todosStore = inject(todosStoreKey);

       onMounted(() {
         todosStore.fetchTodos();
       });

       return (context) => Column(
         children: [
           Text('Total: ${todosStore.totalCount}'),
           Text('Completed: ${todosStore.completedCount}'),
           // Access reactive state via .value
           ...todosStore.todos.value.map((todo) => TodoItem(todo)),
         ],
       );
     }
   }
   ```

   **Key Points:**

   - **Services**: Plain classes with regular variables and StreamControllers (NO refs)
   - **Stores**: Can use `ref()` variables, injected via DI, shared across screens
   - **Composables**: Create refs, subscribe to service streams, expose reactive state, widget-scoped
   - **Widgets**: Can use either stores (via `inject()`) or composables (via `useXxx()`)
   - Stores are useful for shared state that persists across navigation
   - Composables are useful for widget-scoped state and lifecycle management
   - Services expose current state via getters and streams for reactive updates
   - Composables manage the lifecycle of stream subscriptions
   - This pattern matches Vue/Quasar composable architecture where services don't use refs

5. **Code Structure**:

   ```dart
   class MyPage extends CompositionWidget {
     const MyPage({super.key});

     @override
     Widget Function(BuildContext) setup() {
       // 1. Inject dependencies
       final store = inject(storeKey);
       final contextRef = useContext();

       // 2. Create reactive state
       final count = ref(0);
       final loading = ref<bool>(false);

       // 3. Create computed values (derived state - calculated from other refs)
       final doubleCount = computed(() => count.value * 2);

       // 4. Setup lifecycle hooks
       onMounted(() async {
         loading.value = true;
         await store.fetchData();
         loading.value = false;
       });

       onUnmounted(() {
         // Cleanup subscriptions, timers, etc.
       });

       // 5. Setup watchers for side effects
       watchEffect(() {
         if (count.value > 10) {
           debugPrint('Count is greater than 10');
         }
       });

       // 6. Return builder function
       return (context) => Scaffold(
         body: loading.value
           ? CircularProgressIndicator()
           : Text('Count: ${count.value}, Double: ${doubleCount.value}'),
       );
     }
   }
   ```

6. **Lifecycle Management**:

   - Use `onMounted()` for initialization that should run when the widget is first built
     - Example: `onMounted(() async { await fetchData(); });`
     - Runs once after the widget is inserted into the tree
   - Use `onUnmounted()` for cleanup (cancel subscriptions, timers, etc.)
     - Example: `onUnmounted(() { subscription?.cancel(); });`
     - Runs when the widget is removed from the tree
   - Use `useContext()` to get a reactive BuildContext reference for use in async operations
     - Example: `final contextRef = useContext();` then `contextRef.value?.pop();`
     - Always check `contextRef.value?.mounted` before using context in async code

7. **Best Practices**:
   - Keep the `setup()` method focused - extract complex logic into custom composables
   - **Props and Reactivity**:
     - `widget()` returns a reactive ComputedRef that tracks the current widget instance
     - `props.value` gives you the actual widget instance - storing it in variables is fine
     - ✅ Good: `final currentProps = props.value; final name = currentProps.name;`
     - ✅ Good: Access `props.value.name` directly in computed/watch for reactivity
     - ❌ Bad: Avoid creating new object instances unnecessarily (e.g., `.toList()` on every build)
   - Access `.value` on refs/computed directly in the widget tree for fine-grained reactivity
   - Use `computed()` for derived values - it automatically tracks dependencies
   - Prefer `watchEffect()` over `watch()` when you don't need old values
   - Keep `setup()` synchronous - use `onMounted()` for async initialization
   - The `setup()` method is hot-reload friendly - ref state order is preserved
   - Follow the patterns established in existing pages
   - Extract complex logic into reusable composable functions

## Stores, Services, and Composables

**Important**: All three patterns are valid and can coexist:

- **Services** (`lib/services/`, `lib/sensors/`): Plain classes, no refs, use StreamControllers for reactive updates
- **Stores** (`lib/features/*/stores/`): Can use `ref()` variables, injected via DI, shared state across screens
- **Composables** (`lib/core/composables/`): Create refs, subscribe to service streams, expose reactive state, widget-scoped
- **Widgets**: Can use stores (via `inject()`) or composables (via `useXxx()`) based on needs
  - Use stores for shared state that should persist across navigation
  - Use composables for widget-scoped state and lifecycle management

## Migration from Riverpod

When migrating from Riverpod:

- Replace `Provider` with dependency injection using `provide()` and `inject()`
- Replace `StateProvider` with `ref()` for simple state
- Replace `StateNotifierProvider` with stores using `ref()` and methods
- Replace `StreamProvider` with `watch()` on streams
- Replace `FutureProvider` with `ref()` and async initialization
- Replace `ConsumerWidget` with `CompositionWidget`
- Replace `Consumer` with direct access to injected dependencies
- Replace `ref.watch()` with direct access to injected stores/refs
- Replace `ref.read()` with direct method calls on injected dependencies

## Props and Widget Parameters

- Access widget parameters via `final props = widget();` at the start of `setup()`
- Props are reactive - accessing `props.value.*` creates reactive dependencies
- For complex prop types, define them as class properties:

  ```dart
  class MyWidget extends CompositionWidget {
    const MyWidget({super.key, required this.data});
    final SomeType data;

    @override
    Widget Function(BuildContext) setup() {
      final props = widget();
      // props.value.data is available
    }
  }
  ```

## When NOT to Use CompositionWidget

Only use `StatelessWidget` for:

- Pure presentational components with no state
- Simple widgets that only receive props and render UI
- Widgets that don't need reactivity, lifecycle hooks, or side effects

## Migration from StatefulWidget

If you encounter a `StatefulWidget`, convert it to `CompositionWidget`:

1. Replace `StatefulWidget` with `CompositionWidget`
2. Move state variables to `ref()` calls in `setup()`
3. Move lifecycle methods to `watch()` or `watchEffect()`
4. Return a builder function from `setup()`
