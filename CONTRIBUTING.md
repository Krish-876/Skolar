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

### Architecture Guidelines

#### Domain Layer (Pure Dart)
- No Flutter imports
- No external dependencies except Freezed
- Contains only business logic and entity definitions
- Always use Either for error handling

```dart
// ✓ Good
class GetUserUseCase extends UseCase<User, String> {
  final UserRepository repository;
  
  GetUserUseCase(this.repository);
  
  @override
  Future<User> call(String userId) async {
    final result = await repository.getUser(userId);
    return result.fold(
      (failure) => throw failure,
      (user) => user,
    );
  }
}

// ✗ Bad - using Either without folding
@override
Future<User> call(String userId) async {
  return await repository.getUser(userId);
}
```

#### Data Layer
- Implement repositories defined in domain
- Handle exceptions and convert to failures
- Use DTOs for data transfer
- Abstract external dependencies

```dart
// ✓ Good
class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource remote;
  final UserLocalDataSource local;
  
  UserRepositoryImpl({
    required this.remote,
    required this.local,
  });
  
  @override
  Future<Either<Failure, User>> getUser(String id) async {
    try {
      final dto = await remote.getUser(id);
      final user = dto.toEntity();
      await local.saveUser(user);
      return Right(user);
    } catch (e) {
      return Left(ServerError(message: e.toString()));
    }
  }
}

// ✗ Bad - throwing exceptions instead of returning Either
@override
Future<User> getUser(String id) async {
  final dto = await remote.getUser(id);
  return dto.toEntity();
}
```

#### Presentation Layer
- Only Riverpod for state management
- No business logic in widgets
- Use providers for all state
- Keep widgets pure and simple

```dart
// ✓ Good
class UserPage extends ConsumerWidget {
  const UserPage({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    
    return userAsync.when(
      data: (user) => UserView(user: user),
      loading: () => const LoadingWidget(),
      error: (err, st) => ErrorWidget(error: err.toString()),
    );
  }
}

// ✗ Bad - business logic in widget
@override
Widget build(BuildContext context) {
  return FutureBuilder(
    future: getUserData(),
    builder: (context, snapshot) {
      // Complex business logic here
      return Container();
    },
  );
}
```

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
- Minimum 80% coverage for domain/data layers
- Unit test all usecases
- Mock all external dependencies

```dart
// ✓ Good test
test('LoginUseCase returns user on successful login', () async {
  // Arrange
  final mockRepo = MockAuthRepository();
  final usecase = LoginUseCase(mockRepo);
  
  // Act
  final result = await usecase(LoginParams(
    email: 'test@test.com',
    password: 'password',
  ));
  
  // Assert
  expect(result, isA<AuthCredentials>());
});
```

### Best Practices

1. **Always use const** constructors when possible
2. **Prefer immutability** - use Freezed for data classes
3. **Keep functions small** - max 50 lines
4. **Document complex logic** with comments
5. **Use meaningful names** - avoid abbreviations
6. **Handle errors explicitly** - no silent failures
7. **Avoid nested futures** - use async/await
8. **Test edge cases** - not just happy path
9. **Keep dependencies explicit** - no global state
10. **Use sealed classes** - for well-defined types

### Common Patterns

#### Provider Pattern
```dart
final userProvider = FutureProvider<User>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  final result = await repository.getUser('123');
  return result.fold(
    (failure) => throw failure,
    (user) => user,
  );
});
```

#### StateNotifier Pattern
```dart
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(
    repository: ref.watch(authRepositoryProvider),
  ),
);

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository repository;
  
  AuthNotifier({required this.repository})
    : super(const AuthState.initial());
  
  Future<void> login(String email, String password) async {
    state = const AuthState.loading();
    final result = await repository.login(email, password);
    state = result.fold(
      (failure) => AuthState.error(failure),
      (credentials) => AuthState.authenticated(credentials),
    );
  }
}
```

### Commit Message Format

```
<type>: <subject>

<body>

<footer>
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `style`

Example:
```
feat: add exam prediction feature

- Implemented AI-powered exam prediction
- Added prediction confidence scoring
- Integrated with syllabus analysis

Closes #123
```

---

**Key Rule**: Dependency rule always points inward. Never violate this.
