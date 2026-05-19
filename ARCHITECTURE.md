// Architecture documentation for Nova app

## Nova - AI-Powered Exam Preparation Platform

### Architecture Overview

Nova follows Clean Architecture with feature-first modular design, optimized for scalability and maintainability.

### Core Principles

1. **Separation of Concerns**: Each layer has distinct responsibilities
2. **Dependency Rule**: Dependencies always point inward (toward domain)
3. **Testability**: All layers are independently testable
4. **Scalability**: Features are completely isolated and can scale to 100+
5. **Extensibility**: New features can be added without modifying existing code

### Folder Structure

```
lib/
├── core/                 # Application-wide infrastructure
│   ├── ai/              # AI orchestration and LLM abstraction
│   ├── config/          # Environment and app configuration
│   ├── constants/       # App constants and magic strings
│   ├── di/              # Dependency injection setup
│   ├── errors/          # Error handling and failures
│   ├── network/         # HTTP client and API configuration
│   ├── routing/         # Navigation and routing setup
│   ├── services/        # Core services (logging, analytics, etc.)
│   ├── storage/         # Local storage abstraction
│   ├── theme/           # Theme configuration
│   └── widgets/         # Reusable core widgets
│
├── shared/              # Shared across features
│   ├── components/      # Reusable UI components
│   ├── extensions/      # Dart extensions
│   ├── models/          # Base classes and common models
│   └── providers/       # Global Riverpod providers
│
├── features/            # Feature modules (10+ implemented)
│   ├── auth/           # Authentication feature (full example)
│   ├── onboarding/     # Onboarding flow
│   ├── dashboard/      # Main dashboard
│   ├── colleges/       # College management
│   ├── subjects/       # Subject management
│   ├── syllabus/       # Syllabus content
│   ├── pyq_upload/     # PYQ upload system
│   ├── exam_prediction/# AI exam predictions
│   ├── analytics/      # User analytics
│   ├── mock_tests/     # Mock test platform
│   └── profile/        # User profile management
│
└── main.dart           # App entry point
```

### Feature Structure

Each feature is fully isolated with three layers:

```
feature/
├── data/
│   ├── datasources/      # Abstract data sources
│   ├── dtos/            # Data transfer objects
│   └── repository_impl/  # Repository implementations
├── domain/
│   ├── entities/        # Business models
│   ├── repositories/    # Repository abstractions
│   └── usecases/        # Business logic
└── presentation/
    ├── pages/           # Full screens
    ├── providers/       # Riverpod state management
    └── widgets/         # Feature-specific widgets
```

### Key Technologies

- **State Management**: Riverpod (functional, type-safe)
- **Navigation**: GoRouter (declarative routing)
- **Networking**: Dio with interceptors
- **Serialization**: Freezed + json_serializable
- **DI**: GetIt service locator
- **Error Handling**: Either type for functional error handling
- **AI Integration**: Abstract AI orchestration layer

### Design Patterns

1. **Repository Pattern**: Data source abstraction
2. **UseCase Pattern**: Business logic encapsulation
3. **Either Type**: Functional error handling
4. **Provider Pattern**: Riverpod state management
5. **Factory Pattern**: Freezed code generation
6. **Singleton Pattern**: Service locator for DI

### Scalability Features

- **AI Layer**: Pluggable LLM providers with fallback
- **Feature Isolation**: Each feature is independent
- **Configuration Management**: Environment-based config
- **Offline Support**: Storage abstraction layer
- **Caching Strategy**: TTL-based cache metadata
- **Error Recovery**: Comprehensive exception handling

### Adding a New Feature

1. Create feature folder structure
2. Define domain entities and repositories
3. Implement data sources and repository_impl
4. Create usecases
5. Build Riverpod providers
6. Develop presentation pages/widgets
7. Register in DI container
8. Update routing

### Dependency Injection Setup

Service locator (GetIt) is configured in `core/di/service_locator.dart`. Features register their dependencies here to maintain control and isolation.

### AI Orchestration

The `core/ai/ai_service.dart` provides:
- Provider-agnostic LLM calls
- Fallback LLM support
- Exam-specific prediction pipelines
- Syllabus analysis workflows
- Study plan generation

### Error Handling Strategy

- **Domain Layer**: Throws exceptions only
- **Data Layer**: Catches exceptions, returns Either
- **Presentation Layer**: Handles Either results with UI feedback

### State Management Flow

```
UI Widget
   ↓
Riverpod Provider (Consumer)
   ↓
StateNotifier (business logic)
   ↓
UseCase (execution)
   ↓
Repository (data abstraction)
   ↓
DataSource (network/storage)
```

### Testing Structure

All layers are independently testable:
- **Domain**: Pure Dart, no dependencies
- **Data**: Mock datasources, test repositories
- **Presentation**: Mock providers, test widgets

### Future Extensibility

This architecture supports:
- Microservices migration
- Feature module separation
- Multiple backend providers
- Plugin system
- A/B testing framework
- Advanced caching strategies

---

For detailed implementation examples, see the `auth` feature module.
