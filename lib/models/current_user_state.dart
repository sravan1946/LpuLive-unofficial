/// Global state holder for the currently authenticated user.
import 'user_model.dart';

/// The current authenticated user, if any. Avoid relying on globals in
/// business logic; prefer injection or state management where possible.
User? currentUser;
