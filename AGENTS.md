# AGENTS.md - LPU Live Flutter Application

This file contains essential information for agentic coding assistants working on this Flutter project.

## Build/Lint/Test Commands

### Flutter Commands
- **Build for development**: `flutter build apk --debug` or `flutter build ios --debug`
- **Build for production**: `flutter build apk --release` or `flutter build ios --release`
- **Run on connected device**: `flutter run`
- **Clean build**: `flutter clean && flutter pub get`

### Testing
- **Run all tests**: `flutter test`
- **Run single test**: `flutter test test/widget_test.dart`
- **Run tests with coverage**: `flutter test --coverage`

### Code Analysis & Linting
- **Analyze code**: `flutter analyze`
- **Format code**: `flutter format lib/`
- **Fix linting issues**: `flutter fix --apply`

### Dependencies
- **Install dependencies**: `flutter pub get`
- **Update dependencies**: `flutter pub upgrade`
- **Add dependency**: `flutter pub add <package_name>`
- **Remove dependency**: `flutter pub remove <package_name>`

## Code Style Guidelines

### Dart/Flutter Conventions

#### Imports
- **Organize imports**: Group imports in this order:
  1. Dart standard library imports
  2. Third-party package imports
  3. Relative imports (use relative paths for files in the same package)
- **Example**:
  ```dart
  import 'dart:convert';
  import 'dart:io';

  import 'package:flutter/material.dart';
  import 'package:http/http.dart' as http;

  import '../models/user.dart';
  import 'api_service.dart';
  ```

#### Naming Conventions
- **Classes**: PascalCase (e.g., `User`, `ChatMessage`, `TokenStorage`)
- **Variables/Fields**: camelCase (e.g., `chatToken`, `userName`, `isLoading`)
- **Constants**: SCREAMING_SNAKE_CASE (e.g., `_tokenKey`, `_baseUrl`)
- **Methods**: camelCase (e.g., `fetchChatMessages()`, `sendMessage()`)
- **Private members**: Prefix with underscore (e.g., `_tokenController`, `_processToken()`)

#### Code Structure
- **Widget classes**: Extend `StatelessWidget` or `StatefulWidget`
- **State classes**: Use pattern `_WidgetNameState`
- **Services**: Create separate classes for API calls, WebSocket handling, etc.
- **Models**: Use factory constructors with `fromJson()` methods for API data

#### Error Handling
- **Use try-catch blocks** for async operations
- **Show user-friendly error messages** using `ScaffoldMessenger`
- **Log errors** for debugging with descriptive messages
- **Handle null values** safely using null-aware operators (`?.`, `??`)

#### State Management
- **Use Provider pattern** for state management (already implemented)
- **Separate business logic** from UI components
- **Use `setState()` appropriately** in StatefulWidget
- **Handle loading states** with boolean flags

#### Async Programming
- **Use `async/await`** for asynchronous operations
- **Handle Futures properly** with error handling
- **Use `StreamSubscription`** for WebSocket connections
- **Clean up subscriptions** in `dispose()` method

#### UI/UX Guidelines
- **Consistent spacing**: Use `const SizedBox(height: X)` or `const EdgeInsets.all(X)`
- **Material Design**: Follow Material 3 guidelines with `useMaterial3: true`
- **Theme consistency**: Use `Theme.of(context)` for colors and styles
- **Responsive design**: Use `MediaQuery` for screen size adaptation
- **Accessibility**: Add semantic labels and tooltips where appropriate

#### Security Best Practices
- **Store sensitive data** using `flutter_secure_storage` (already implemented)
- **Validate tokens** before making API calls
- **Handle SSL certificates** appropriately for development
- **Never log sensitive information** like tokens or passwords

#### Performance
- **Use `const` constructors** where possible
- **Implement proper image loading** with error handling
- **Optimize list views** with proper key usage
- **Handle memory leaks** by disposing controllers and subscriptions

### Testing Guidelines
- **Write widget tests** for UI components
- **Test error scenarios** and edge cases
- **Mock external dependencies** (API calls, WebSocket)
- **Use descriptive test names** that explain the expected behavior

### File Organization
- **lib/**: Main application code
  - `main.dart`: Application entry point
  - `services/`: API services, WebSocket handling
  - `models/`: Data models (User, ChatMessage, etc.)
  - `widgets/`: Reusable UI components
- **test/**: Test files
- **assets/**: Static assets (images, fonts, etc.)

### Git Workflow
- **Commit messages**: Use imperative mood, e.g., "Add user authentication", "Fix WebSocket connection"
- **Branch naming**: Use descriptive names like `feature/user-auth`, `bugfix/websocket-reconnect`
- **Pull requests**: Include description of changes and testing done

This guide ensures consistency across the codebase and helps maintain high code quality for the LPU Live Flutter application.