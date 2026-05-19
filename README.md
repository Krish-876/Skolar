# Skolar

An AI-powered exam preparation platform built with Flutter. Helps students track syllabus progress, attempt mock tests, get AI-driven predictions, and visualize their performance — all in one place.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Folder Structure](#folder-structure)
- [Tech Stack](#tech-stack)
- [Features](#features)
- [Dashboard — How It Works](#dashboard--how-it-works)
- [Running the App](#running-the-app)
- [Adding a New Feature](#adding-a-new-feature)
- [Roadmap](#roadmap)

---

## Project Overview

Skolar is built for students preparing for competitive exams. The app combines:

- A scrollable analytics dashboard showing task progress, weekly performance, and recent activity
- AI-generated exam predictions based on syllabus coverage and mock test scores
- PYQ (Previous Year Question) upload and analysis
- College and subject management
- A mock test platform (in progress)

The app is currently in active development. The dashboard and analytics modules are fully functional. Mock tests and AI prediction pipelines are planned next.

---

## Architecture

Skolar follows **Clean Architecture** with a **feature-first** folder structure. Every feature is fully isolated across three layers.

```
Presentation  →  Domain  →  Data
```

- **Presentation**: Riverpod providers, pages, widgets. Knows nothing about data sources.
- **Domain**: Pure Dart. Entities, repository interfaces, use cases. No Flutter imports.
- **Data**: DTOs, data sources, repository implementations. Talks to JSON files, APIs, or storage.

Dependencies always point **inward** — data depends on domain, presentation depends on domain, nothing depends on presentation or data directly.

### State Management Flow

```
UI Widget
   ↓  watches
Riverpod Provider (AsyncNotifierProvider)
   ↓  calls
UseCase
   ↓  calls
Repository (abstract interface)
   ↓  implemented by
RepositoryImpl
   ↓  calls
DataSource (local file / API / storage)
```

### Error Handling

- Data layer catches exceptions, returns `Either<Failure, Data>`
- Domain layer defines `Failure` types
- Presentation layer handles `Either` results with `state.when(loading, error, data)`

---

## Folder Structure

```
lib/
├── core/                        # App-wide infrastructure
│   ├── ai/                      # AI service abstraction (pluggable LLM providers)
│   ├── config/                  # Environment config, app constants
│   ├── di/                      # Dependency injection (GetIt service locator)
│   ├── errors/                  # Failure types and exception classes
│   ├── network/                 # Dio HTTP client with interceptors
│   ├── routing/                 # GoRouter configuration
│   ├── services/                # Logging, analytics services
│   ├── storage/                 # Local storage abstraction (Hive/SharedPrefs)
│   ├── theme/                   # AppTheme — colors, typography, gradients
│   └── widgets/                 # Reusable core widgets
│
├── shared/                      # Shared across features
│   ├── components/              # LoadingButton, AppTextField etc.
│   ├── extensions/              # String, List, Num extensions
│   ├── models/                  # Base entity and DTO classes
│   └── providers/               # Global Riverpod providers (e.g. userProvider)
│
├── features/
│   ├── analytics/               # Data analysis layer for the dashboard
│   │   ├── data/
│   │   │   ├── datasources/     # Reads analytics.json via rootBundle
│   │   │   ├── dtos/            # JSON serialization models
│   │   │   └── repository_impl/
│   │   ├── domain/
│   │   │   ├── entities/        # AnalyticsData, TaskItem, RecentActivity, WeeklyDataPoint
│   │   │   ├── repositories/    # AnalyticsRepository (abstract)
│   │   │   └── usecases/        # GetAnalyticsUseCase
│   │   └── presentation/
│   │
│   ├── dashboard/               # Main dashboard screen
│   │   └── presentation/
│   │       ├── pages/           # DashboardPage (CustomScrollView)
│   │       ├── providers/       # DashboardNotifier (AsyncNotifier)
│   │       └── widgets/         # DonutProgressChart, WeeklyLineChart,
│   │                            # TaskListTile, RecentActivityTile,
│   │                            # DashboardSectionHeader
│   │
│   ├── auth/                    # Authentication (login, register)
│   ├── onboarding/              # Onboarding flow
│   ├── colleges/                # College search and management
│   ├── subjects/                # Subject management
│   ├── syllabus/                # Syllabus content and progress
│   ├── pyq_upload/              # Previous Year Question upload
│   ├── exam_prediction/         # AI exam score predictions
│   ├── mock_tests/              # Mock test platform (in progress)
│   └── profile/                 # User profile
│
└── main.dart                    # App entry point, routes, ProviderScope
```

---

## Tech Stack

| Purpose | Package |
|---|---|
| State management | `flutter_riverpod` |
| Navigation | `go_router` |
| Immutable models | `freezed` + `freezed_annotation` |
| JSON serialization | `json_serializable` + `json_annotation` |
| Functional error handling | `dartz` (Either type) |
| HTTP client | `dio` |
| Dependency injection | `get_it` |
| Local storage | `hive` + `shared_preferences` |
| Charts | `fl_chart` |
| Code generation | `build_runner` |

---

## Features

###   Built
- Scrollable analytics dashboard
  - Donut ring chart (task progress breakdown)
  - Weekly line chart (performance over 7 days)
  - Task list with assignee avatars and due dates
  - Recent activity feed
- Dark theme with custom color palette
- Clean Architecture scaffold for all 11 features
- Dev menu for navigating between pages during development

### Planned
- Syllabus progress tracking
- PYQ upload and analysis
- College comparison
- Authentication flow
- Backend/Firebase integration

---

## Dashboard — How It Works

The dashboard is the most complete feature. Understanding it explains how every other feature will work too.

### Data Source

All dashboard data lives in a single JSON file:

```
assets/data/analytics.json
```

To change what appears on screen, edit this file and hot-restart the app.

### What Each Field Controls

| Field in JSON | What changes on screen |
|---|---|
| `total_tasks_completed` | Big number in the center of the ring chart |
| `todo_percent` | Blue segment of ring + "To Do" percentage label |
| `in_progress_percent` | Teal segment + "In Progress" label |
| `completed_percent` | Grey segment + "Completed" label |
| `weekly_progress` | Points on the line chart (label = day, value = 0–100) |
| `tasks` | Rows in the Tasks list (title, due date, avatar initials) |
| `recent_activities` | Rows in Recent Activity (time, title, subtitle, date) |

### Data Flow

```
assets/data/analytics.json
        ↓
AnalyticsLocalDataSourceImpl     reads file with rootBundle.loadString()
        ↓
AnalyticsDataDto.fromJson()      converts JSON → Dart DTO objects
        ↓
dto.toDomain()                   converts DTO → clean domain entity (AnalyticsData)
        ↓
AnalyticsRepositoryImpl          wraps result in Either<Failure, AnalyticsData>
        ↓
GetAnalyticsUseCase              single callable entry point
        ↓
DashboardNotifier                AsyncNotifier — holds loading/error/data state
        ↓
dashboardProvider                widgets that watch this rebuild when data changes
        ↓
DashboardPage                    state.when(loading, error, data)
        ↓
DonutProgressChart               reads todoPercent, inProgressPercent, completedPercent
WeeklyLineChart                  reads weeklyProgress list
TaskListTile                     reads tasks list
RecentActivityTile               reads recentActivities list
```

### How It Will Connect to AI Later

Right now the datasource reads from the JSON file manually. When the mock test AI is built:

1. The AI processes test results and writes scores to `StorageService`
2. The datasource is swapped to read from `StorageService` instead of the JSON file
3. After writing, the mock test feature calls `ref.invalidate(dashboardProvider)`
4. The dashboard automatically rebuilds with the new data

**No dashboard code changes needed.** Only the datasource implementation changes.

---

## Running the App

```bash
# Install dependencies
flutter pub get

# Generate Freezed and JSON serialization code (required after any model change)
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

The app opens to a Dev Menu listing all features. Tap any feature to navigate to it directly.

> **Note**: Run build_runner every time you add or modify a `@freezed` class or `@JsonSerializable` class. The generated `.freezed.dart` and `.g.dart` files must exist for the app to compile.

---

## Adding a New Feature

Order to stay consistent with the architecture:

1. Create the folder structure under `lib/features/your_feature/`
2. Define domain entities in `domain/entities/` using `@freezed`
3. Define the repository interface in `domain/repositories/`
4. Write use cases in `domain/usecases/`
5. Create the DTO in `data/dtos/` using `@JsonSerializable`
6. Implement the datasource in `data/datasources/`
7. Implement the repository in `data/repository_impl/`
8. Create a Riverpod `AsyncNotifierProvider` in `presentation/providers/`
9. Build the page and widgets in `presentation/pages/` and `presentation/widgets/`
10. Add a route in `main.dart`
11. Run `dart run build_runner build --delete-conflicting-outputs`

Use the `analytics` feature as the reference implementation — it is the most complete example in the codebase.

---

## Roadmap

```
Phase 1 — Foundation (current)
    Project scaffold and architecture
    Theme system
    Analytics dashboard with charts
    Dev navigation menu

Phase 2 — Core Features
    Mock test platform
    Syllabus tracker
     PYQ upload and parsing

Phase 3 — AI Integration
     AI service abstraction layer
     Exam score prediction pipeline
     Dashboard auto-refresh from AI output
     Personalized study plan generation

Phase 4 — Backend
     Firebase or custom backend
     Authentication
     Cloud sync
     Push notifications
```

---

*Built by Krishna - BITS Pilani Hyderabad, B.Tech CSE 2024–2028*