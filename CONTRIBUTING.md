## Skolar - Code Standards & Contributing Guide

### Code Style

#### Naming Conventions

```dart
// Classes: PascalCase
class UserRepository {}
class LoginPage {}

// Variables/Functions: camelCase
String userName = 'John';
void handleLogin() {}

// Constants: camelCase or SCREAMING_SNAKE_CASE
const int maxRetries = 3;
const String apiBaseUrl = 'https://api.example.com';

// Private: Leading underscore
String _privateVariable;
void _privateMethod() {}

// Files: snake_case
user_repository.dart
login_page.dart
```

#### File Organization

```
1. Imports (organized by: dart, package, relative)
2. Constants
3. Classes/Types
4. Functions (if any)
```

#### Class Organization

```dart
class ClassName {
  // 1. Constants
  static const String _constant = 'value';

  // 2. Static variables
  static late SomeClass _instance;

  // 3. Instance variables
  final String name;
  late String data;
  String? optional;

  // 4. Constructors
  const ClassName(this.name);

  factory ClassName.empty() => ClassName('');

  // 5. Getters
  String get fullData => '$name: $data';

  // 6. Methods (public first, then private)
  void publicMethod() {}
  void _privateMethod() {}
}
```

---

### Architecture Guidelines

#### Domain Layer (Pure Dart)

- No Flutter imports
- No external dependencies except `freezed_annotation`
- Contains only business logic and entity definitions
- Always use `Either` for error handling in repositories

```dart
// ✓ Good
class GetFeedUseCase {
  final FeedRepository repository;
  GetFeedUseCase(this.repository);

  Future<Either<Failure, List<FeedPostEntity>>> call() =>
      repository.getFeed();
}

// ✗ Bad - skipping Either, throwing raw exceptions
Future<List<FeedPostEntity>> call() async {
  return await repository.getFeed(); // Either ignored
}
```

#### Data Layer

- Implement repository interfaces defined in domain
- Catch all exceptions, convert to `Failure` types, return `Either`
- Use DTOs (`@JsonSerializable`) for JSON parsing - never parse directly into domain entities
- Convert DTOs to domain entities via `.toDomain()`

```dart
// ✓ Good
class FeedRepositoryImpl implements FeedRepository {
  final FeedLocalDataSource _dataSource;
  FeedRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, List<FeedPostEntity>>> getFeed() async {
    try {
      final dtos = await _dataSource.getFeed();
      return Right(dtos.map((d) => d.toDomain()).toList());
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}

// ✗ Bad - throwing instead of returning Either
@override
Future<List<FeedPostEntity>> getFeed() async {
  return (await _dataSource.getFeed()).map((d) => d.toDomain()).toList();
}
```

#### Presentation Layer

- Riverpod only for state management - no `setState` outside of animation controllers
- No business logic in widgets - all logic lives in `AsyncNotifier` / `Notifier`
- Use `AsyncNotifier` for async state (API calls, file reads); use `Notifier` for sync state
- Keep widgets pure: they watch providers and render, nothing else

```dart
// ✓ Good - ConsumerWidget watching an AsyncNotifier
class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);
    return feedAsync.when(
      data: (posts) => PostList(posts: posts),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => ErrorView(message: e.toString()),
    );
  }
}

// ✗ Bad - FutureBuilder with logic in widget
@override
Widget build(BuildContext context) {
  return FutureBuilder(
    future: fetchPosts(),
    builder: (context, snapshot) {
      // business logic here - wrong layer
      return Container();
    },
  );
}
```

#### State Management Pattern

Use `AsyncNotifier` (not the older `StateNotifier`) for all async state. This is the Riverpod 2.x standard used throughout this codebase.

```dart
// ✓ Correct - AsyncNotifier (Riverpod 2.x)
class FeedNotifier extends AsyncNotifier<List<FeedPostEntity>> {
  @override
  Future<List<FeedPostEntity>> build() async {
    final useCase = ref.watch(getFeedUseCaseProvider);
    final result = await useCase();
    return result.fold(
      (failure) => throw Exception(failure.message),
      (posts) => posts,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final feedProvider =
    AsyncNotifierProvider<FeedNotifier, List<FeedPostEntity>>(
  FeedNotifier.new,
);

// ✗ Outdated - StateNotifier (Riverpod 1.x, not used in this codebase)
class FeedNotifier extends StateNotifier<FeedState> {
  FeedNotifier() : super(const FeedState.initial());
  // ...
}
```

Use `Notifier` (sync) when state doesn't involve async operations:

```dart
// ✓ Correct - Notifier for sync state
class MockTestNotifier extends Notifier<MockTestState> {
  @override
  MockTestState build() => const MockTestState();

  void reset() => state = const MockTestState();
}
```

---

### Code Generation

This project uses `build_runner` to generate `.freezed.dart` and `.g.dart` files.

```bash
# Standard build (use this normally)
dart run build_runner build --delete-conflicting-outputs

# Watch mode (use during active model work)
dart run build_runner watch --delete-conflicting-outputs

# Full clean + rebuild (use when things are broken)
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

**When to run it:** after adding/modifying any `@freezed` class or `@JsonSerializable` DTO, and after any `git pull` that touched model files.

**Rule:** domain entities use `@freezed`. DTOs use `@JsonSerializable` only. Never put `@freezed` on a DTO.

---

### Code Quality

#### Formatting

```bash
dart format lib/
```

#### Linting

```bash
dart analyze lib/
```

#### Testing

- Minimum 80% coverage for domain and data layers
- Unit test all use cases
- Mock all external dependencies

```dart
// ✓ Good test structure
test('GetFeedUseCase returns posts on success', () async {
  // Arrange
  final mockRepo = MockFeedRepository();
  final usecase = GetFeedUseCase(mockRepo);
  when(mockRepo.getFeed()).thenAnswer((_) async => Right(fakePosts));

  // Act
  final result = await usecase();

  // Assert
  expect(result.isRight(), true);
  expect(result.getOrElse(() => []).length, fakePosts.length);
});
```

---

### Best Practices

1. **Always use `const`** constructors where possible
2. **Prefer immutability** - use `@freezed` for domain entities
3. **Keep functions small** - max ~50 lines
4. **Document complex logic** with inline comments
5. **Use meaningful names** - no abbreviations
6. **Handle errors explicitly** - no silent failures, no empty `catch` blocks
7. **Avoid nested futures** - use `async`/`await`
8. **Test edge cases** - not just the happy path
9. **Keep dependencies explicit** - inject via constructor, not global access
10. **Dependency rule** - never import from a layer that's further out

---

### Common Patterns

#### AsyncNotifier with use case

```dart
final exampleProvider =
    AsyncNotifierProvider<ExampleNotifier, SomeEntity>(
  ExampleNotifier.new,
);

class ExampleNotifier extends AsyncNotifier<SomeEntity> {
  @override
  Future<SomeEntity> build() async {
    final result = await ref.watch(someUseCaseProvider)();
    return result.fold(
      (failure) => throw Exception(failure.message),
      (data) => data,
    );
  }
}
```

#### Derived provider (cached, no recompute on rebuild)

```dart
final sortedFeedProvider = Provider<List<FeedPostEntity>>((ref) {
  final feedAsync = ref.watch(feedProvider);
  final sort = ref.watch(feedSortProvider);
  return feedAsync.maybeWhen(
    data: (posts) => _sort(posts, sort),
    orElse: () => [],
  );
});
```

#### Selective rebuild (only affected widget rebuilds)

```dart
// Only rebuilds when THIS post's vote state changes, not the whole list
final upvoted = ref.watch(
  upvotedPostsProvider.select((s) => s.contains(post.id)),
);
```

---

### Commit Message Format

```
<type>: <subject>

<body>

<footer>
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `style`

Example:

```
feat: add mock test generation via DICL pipeline

- POST /generate-batch endpoint with parallel MCQ generation
- MockTestNotifier with loading/error/publishing states
- Auto-publish to community feed for college subjects

Closes #42
```

---

**Key Rule:** The dependency rule always points inward. Data depends on domain. Presentation depends on domain. Nothing depends on presentation or data directly. Never violate this.