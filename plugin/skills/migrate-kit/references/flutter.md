# Flutter Migration Reference

## Dart 2 → Dart 3 (Sound Null Safety)

### Breaking Changes
- **Sound null safety** enforced. All types are non-nullable by default:
  ```dart
  // Before (Dart 2, unsound)
  String name;          // nullable
  String? maybeName;    // also nullable

  // After (Dart 3, sound)
  String name;          // non-nullable, MUST be initialized
  String? maybeName;    // nullable (explicit)
  ```
- **Class modifiers:**
  ```dart
  // Dart 3 adds: sealed, final, base, interface, mixin class
  sealed class Shape {}    // can only be extended in same library
  final class Config {}    // cannot be extended
  base class Animal {}     // can be extended but not implemented
  interface class Logger {}// can be implemented but not extended
  ```
- **Switch expressions** and **pattern matching:**
  ```dart
  // Before
  String describe(Shape shape) {
    if (shape is Circle) return 'circle';
    if (shape is Square) return 'square';
    return 'unknown';
  }

  // After
  String describe(Shape shape) => switch (shape) {
    Circle() => 'circle',
    Square() => 'square',
  };
  ```
- **Records:**
  ```dart
  (String, int) getNameAndAge() => ('Alice', 30);
  final (name, age) = getNameAndAge();
  ```
- **`dart:mirrors`** — removed from Flutter (was already unavailable).

### Migration (Null Safety)
```bash
dart fix --apply         # auto-fix many null safety issues
dart analyze             # find remaining issues
```

Key patterns:
```dart
// late initialization (when you know it'll be set before use)
late final String name;

// assertion (when you're sure a nullable value isn't null)
final widget = maybeWidget!;  // throws if null

// null-aware operators
final name = user?.name ?? 'Unknown';
```

---

## Flutter 3.x Upgrades

### Flutter 3.7 → 3.10
- **Material 3** becomes the default design:
  ```dart
  // Before — Material 2 by default
  MaterialApp(theme: ThemeData())

  // After — Material 3 by default, opt out if needed
  MaterialApp(theme: ThemeData(useMaterial3: false))
  ```
- **Impeller** — new rendering engine on iOS (default), Android (opt-in).
- **`NavigationBar`** replaces `BottomNavigationBar` for M3.
- **`DropdownMenu`** replaces `DropdownButton` for M3.

### Flutter 3.10 → 3.13
- **Impeller** default on Android.
- **`ColorScheme.fromSeed()`** — preferred way to generate Material 3 themes:
  ```dart
  ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    useMaterial3: true,
  )
  ```
- **`DecoratedSliver`** — apply decorations to slivers.

### Flutter 3.13 → 3.16
- **Material 3 fully default** — `useMaterial3` defaults to `true`.
- **Impeller** on Android by default with Vulkan.
- **Font asset auto-loading** improvements.

### Flutter 3.16 → 3.19
- **Windows Arm64** support.
- **`AnimationStyle`** widget for customizing animation defaults.
- **Deep linking** improvements on Android/iOS.

### Flutter 3.19 → 3.22+
- **Dart 3.4+** with improved type inference.
- **Wasm** compilation for web (stable).
- **Swift Package Manager** integration for iOS (experimental).
- **GPU rendering improvements** on Android.

---

## Deprecated Widgets & APIs

| Deprecated | Replacement | Since |
|-----------|-------------|-------|
| `FlatButton` | `TextButton` | 2.0 |
| `RaisedButton` | `ElevatedButton` | 2.0 |
| `OutlineButton` | `OutlinedButton` | 2.0 |
| `ButtonTheme` | `TextButtonTheme` / `ElevatedButtonTheme` | 2.0 |
| `Scaffold.resizeToAvoidBottomPadding` | `Scaffold.resizeToAvoidBottomInset` | 1.x |
| `BottomNavigationBar` (M2) | `NavigationBar` (M3) | 3.7 |
| `DropdownButton` (M2) | `DropdownMenu` (M3) | 3.7 |
| `Chip` variants (M2 style) | M3 `Chip` variants | 3.7 |
| `ThemeData(primarySwatch:)` | `ThemeData(colorScheme:)` | 3.10 |
| `MaterialApp.darkTheme` approach | `ColorScheme.fromSeed()` | 3.10 |

### Auto-fix
```bash
dart fix --apply  # fixes most deprecated API usages
flutter analyze   # find remaining warnings
```

---

## State Management Migration

### setState → Riverpod
```dart
// Before (setState)
class CounterPage extends StatefulWidget { ... }
class _CounterPageState extends State<CounterPage> {
  int count = 0;
  Widget build(context) => ElevatedButton(
    onPressed: () => setState(() => count++),
    child: Text('$count'),
  );
}

// After (Riverpod)
final counterProvider = StateProvider<int>((ref) => 0);
class CounterPage extends ConsumerWidget {
  Widget build(context, ref) {
    final count = ref.watch(counterProvider);
    return ElevatedButton(
      onPressed: () => ref.read(counterProvider.notifier).state++,
      child: Text('$count'),
    );
  }
}
```

### Provider → Riverpod
```dart
// Before (Provider package)
ChangeNotifierProvider(create: (_) => CounterModel())
context.watch<CounterModel>().count

// After (Riverpod)
final counterProvider = ChangeNotifierProvider((ref) => CounterModel());
ref.watch(counterProvider).count
```
