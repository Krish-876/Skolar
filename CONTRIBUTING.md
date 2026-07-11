## Skolar - Code Standards & Contributing Guide

### Git Workflow & Merging

#### Branching

- Never commit directly to `master`. Always branch off it.
- Branch naming: `feature/short-description`, `fix/short-description`, `refactor/short-description`
- Keep branches short-lived — aim to merge within 1–2 days. Long-lived branches are where conflicts pile up.
- One feature/branch should map to one architectural seam where possible (e.g. one person on `feed` domain/data, another on `feed` presentation) — this avoids two people editing the same files entirely.

#### Daily rebase workflow

```bash
# Start of any new work
git checkout master
git pull origin master
git checkout -b feature/short-description

# Before pushing, and at least once a day on longer branches
git fetch origin
git rebase origin/master
# resolve any conflicts, then:
git push --force-with-lease origin feature/short-description
```

**Rebase, don't merge, onto master.** Pulling `master` into your branch with a regular merge delays conflicts and produces messy merge commits. Rebasing keeps history linear and surfaces conflicts early, in small pieces, while the context is still fresh.

**Always use `--force-with-lease`, never plain `--force`.** It safely fails if someone else has pushed to your branch since your last fetch, instead of silently overwriting their work.

#### Generated files (`.freezed.dart`, `.g.dart`)

These are the most common source of ugly, unreadable merge conflicts since they're large and machine-generated.

- Preferred: keep them out of version control (add to `.gitignore`) and require `build_runner build` locally and in CI. Zero generated-file conflicts, ever.
- If they must stay committed: on conflict, don't hand-resolve — discard and regenerate.
  ```bash
  git checkout --ours path/to/file.freezed.dart
  dart run build_runner build --delete-conflicting-outputs
  ```

#### Pull requests

- PR branches merge directly into `master` — no long-lived `develop` branch.
- One PR = one logical change. Don't bundle unrelated fixes.
- PR description should state: what changed, why, and how it was tested.
- At least one reviewer approval required before merge. Reviewer checks architecture/layer rules below, not just correctness.
- Squash-merge into `master` on every PR (no merge commits, no manual rebase-merge). For a team this size, squash gives a clean linear history and removes the risk of a half-rebased PR polluting `master`. This is the default — don't rebase-merge instead.
- If your branch touches a file someone else is actively working on, say so in standup/Slack before you start — a 30-second heads-up avoids a conflict git can't.

#### Amending commits

- Don't amend commits already pushed to a shared branch. Once a commit exists on `origin/master` (or any shared branch), amending it locally rewrites its hash — pushing then requires `--force-with-lease` and can strand anyone who already pulled it.
- Prefer a new commit for fixes after pushing:
```bash
  git commit -m "docs: fix typo in CI section"
```
- `--amend` is safe only for commits still local/unpushed.

#### Handling conflicts when they do happen

```bash
git fetch origin
git rebase origin/master
# git will pause at each conflicting commit
# fix the conflict markers in the file, then:
git add <resolved-file>
git rebase --continue
# once all commits are replayed cleanly:
git push --force-with-lease origin feature/short-description
```

If a rebase turns into a mess (conflicts on conflicts), it's fine to abort and ask for help rather than force through it:
```bash
git rebase --abort
```

---

### Code Style

#### Naming Conventions

```dart
// Classes: PascalCase
class UserRepository {}
class LoginPage {}

// Variables/Functions: camelCase
String userName = 'John';
void handleLogin() {}

// Constants: lowerCamelCase (Dart's own style guide default — no SCREAMING_SNAKE_CASE)
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

```dart
// 1. Dart imports
import 'dart:async';

// 2. Package imports (alphabetized)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 3. Relative imports (alphabetized)
import '../domain/entities/feed_post_entity.dart';
import 'feed_state.dart';

// 4. Constants
const int _pageSize = 20;

// 5. Classes/Types
class FeedNotifier extends AsyncNotifier<List<FeedPostEntity>> { ... }

// 6. Functions (if any)
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
- No external dependencies except `freezed_annotation` and `fpdart`
- Contains only business logic and entity definitions
- Always use `Either` (from `fpdart`) for error handling in repositories. `fpdart` is the standard FP package for this codebase — don't introduce `dartz` or a hand-rolled alternative; consistency across the team matters more than which FP library is "correct."

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

#### Failure Taxonomy

All `Failure` subtypes live in `lib/core/error/failures.dart`. Never construct a raw `Exception` and let it escape the data layer — always convert to one of these:

```dart
sealed class Failure {
  final String message;
  const Failure({required this.message});
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message});
}

class NetworkFailure extends Failure {
  const NetworkFailure({required super.message});
}

class CacheFailure extends Failure {
  const CacheFailure({required super.message});
}

class AuthFailure extends Failure {
  const AuthFailure({required super.message});
}

class ValidationFailure extends Failure {
  const ValidationFailure({required super.message});
}
```

Adding a new failure type? Add it here, not inline in a repository file.

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

#### Provider Organization

- One provider file per feature: `lib/features/<feature>/presentation/providers/<feature>_providers.dart`
- Cross-feature/shared providers (e.g. Supabase client, current user) live in `lib/core/providers/`
- Naming: `<noun>Provider` for data (`feedProvider`), `<noun>NotifierProvider` is redundant — just name the notifier class `FeedNotifier` and the provider `feedProvider`
- Use `ref.watch` inside `build()` methods and other providers (reactive). Use `ref.read` inside callbacks/event handlers (one-off actions) — never `ref.watch` inside a button's `onPressed`.
- Prefer `.select()` for widgets that only care about part of a state object, to avoid unnecessary rebuilds (see example below).

---

### Supabase Conventions

- Table names: `snake_case`, plural (`feed_posts`, `study_sessions`)
- Every table with user-owned rows must have RLS enabled — no exceptions, even for "internal" tables.
- RLS policy naming: `own_<resource>_only` for simple owner-scoped policies, or a descriptive verb phrase for anything more complex (`users_read_own_row`). Consistency within a table matters more than a rigid global pattern.
- Write the RLS policy in the same migration/PR that creates the table — don't ship a table without one, even temporarily.
- DTOs map Supabase JSON responses 1:1 with `@JsonSerializable`; conversion to domain entities happens via `.toDomain()`, same as any other data source.
- Migrations live under `supabase/migrations/`, timestamped and never edited after being merged to `master` — write a new migration to fix a previous one.
- Merging a migration PR does NOT auto-apply it — auto-deploy requires Supabase Pro. Whoever merges must run `supabase db push` immediately after, or note in the PR thread that it's pending.
- Before proposing a new Nova-related table or field, check it against `Spec.md` — several fields are intentionally computed live rather than stored (see spec #2).
- Test RLS changes against a non-owner-authenticated session before merging, not just as the table owner (service role bypasses RLS and will hide bugs).

---

### Environment & Secrets

- Never commit `.env`, API keys, or service role keys. `.env` must be in `.gitignore` from the start of any new project/module.
- Use `.env.example` with placeholder values so teammates know what variables are required.
- If a secret is accidentally committed: rotate the key immediately, then scrub history with `git filter-repo` — don't just delete the file in a new commit, since the secret remains in history.
- Service role / admin Supabase keys are never used client-side, only in backend/server contexts.

---

### CI Pipeline

CI runs via GitHub Actions on every PR into `master` and on every push to `master` (`.github/workflows/ci.yml`). A PR cannot be merged until it passes — branch protection on `master` requires this check plus one reviewer approval.

What it runs, in order:

1. `dart format --output=none --set-exit-if-changed .` — fails if anything isn't formatted
2. `dart run build_runner build --delete-conflicting-outputs` — regenerates `.freezed.dart`/`.g.dart`; if generated files are committed, the run fails if this produces uncommitted diffs (i.e. someone forgot to regenerate before pushing)
3. `dart analyze --fatal-infos` — fails on any lint issue
4. `flutter test --coverage` — runs the full test suite
5. Supabase check — validates migration SQL syntax only. This does NOT deploy to production; see Supabase Conventions above for the required manual `db push` step.

Not yet covered by CI (tracked as gaps, not silently assumed): FastAPI backend tests, Supabase RLS policy tests against non-owner sessions, and any integration test that needs a live/staged backend. These require either a hosted staging Supabase project or a dockerized backend, and aren't set up yet — don't assume CI is catching backend bugs.

---

### FastAPI / Backend Conventions

Owned by Viswaduth (FastAPI backend, Supabase, Nova backend pipeline). Applies to everything under the backend repo/directory, deployed on Railway.

#### Style & structure

- Naming: `snake_case` for functions/variables/modules, `PascalCase` for classes, matching PEP 8 — this is the Python-side equivalent of the Dart naming rules above, don't mix conventions across the stack.
- Route handlers stay thin — validation and request/response shaping only. Business logic lives in a service layer, not inline in the route function (same dependency-inward principle as the Flutter side, just without the formal domain/data/presentation split).
- Pydantic models are the equivalent of DTOs: one model per request shape and one per response shape, don't reuse a single model for both if they diverge even slightly.

#### Error handling

- Equivalent of the Dart `Failure` taxonomy: raise typed exceptions (`class NotFoundError(AppError)`, `class ValidationError(AppError)`, etc.) caught by a single FastAPI exception handler that maps them to HTTP status codes — never let a raw unhandled exception reach the client.
- Every error response uses the same envelope shape (see API contract below) so the Flutter client can parse errors uniformly regardless of which endpoint failed.

#### API contract (Flutter ↔ FastAPI)

- All endpoints versioned under `/api/v1/...` from day one, even with only one version live — avoids a breaking migration later.
- Success response envelope: `{"data": ..., "meta": {...}}`. Error envelope: `{"error": {"code": "...", "message": "..."}}`. Pick one shape and use it everywhere — the Flutter data layer should have exactly one place that parses this envelope, not per-endpoint parsing logic.
- Breaking changes to an existing endpoint's request/response shape require a version bump (`/v2/...`), not an in-place change — the Flutter app and backend won't always deploy in lockstep.

#### Nova / ML pipeline conventions

Owned primarily by Aditya (AI/ML personalization), overlapping with Viswaduth on the Nova backend integration.

- Prompt templates are versioned in code (not edited in place) — e.g. `prompts/mmr_question_gen_v3.py`, with old versions kept until nothing references them. A prompt change is a behavior change and should go through PR review like any other logic change.
- Pin embedding/model versions explicitly (e.g. exact Groq model string, exact sentence-transformer version) in a single config location — never rely on "whatever the latest version resolves to" at call time, since that silently changes output quality and breaks reproducibility.
- Any change to scoring/ranking logic (MMR weights, relevance thresholds) that affects `nova_config` values needs the reasoning noted in the PR description — these are tuned parameters, not obvious code, and the next person touching them needs to know why a value is what it is.
- Log inputs/outputs for generation calls during development (prompt, model, response) somewhere retrievable — not necessarily production logging yet, but enough to debug a bad generation after the fact without reproducing it blind.

---

### Not Yet Defined (stubs)

These areas matter but depend on decisions not yet finalized. Each has a concrete trigger for when it needs to stop being a stub — don't let it slide indefinitely just because Phase 5 timing shifts.

- **Release & versioning** — TBD. Define semantic versioning, build number bumps, and changelog conventions before the first TestFlight/Play internal release.
- **Observability & logging** — TBD. Add Sentry (or equivalent) and a structured logging convention before the first external tester build.
- **Offline / local storage** — TBD. Define what lives in Supabase vs. on-device (Hive/SharedPreferences) and cache invalidation rules once handout caching behavior is finalized.

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
- Presentation layer: widget tests for any screen with conditional rendering (loading/error/empty states) — not required to hit 80%, but no screen ships with zero tests
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

Types: `feat`, `fix`, `schema`, `refactor`, `test`, `docs`, `style`, `chore`, `perf`, `ci`

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