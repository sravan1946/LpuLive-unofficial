// Global state holder for the currently authenticated user.
import 'user_model.dart';
import 'package:flutter/foundation.dart';

// The current authenticated user, if any. Avoid relying on globals in
// business logic; prefer injection or state management where possible.
User? currentUser;

/// Notifier that emits whenever currentUser changes.
final ValueNotifier<User?> currentUserNotifier = ValueNotifier<User?>(null);

/// Sets the current user and notifies listeners.
void setCurrentUser(User? user) {
  currentUser = user;
  currentUserNotifier.value = user;
}
