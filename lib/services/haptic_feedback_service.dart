// Flutter imports:
import 'package:flutter/services.dart';

/// Service for managing haptic feedback throughout the app
class HapticFeedbackService {
  /// Light impact for subtle interactions (button taps, tab switches)
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// Medium impact for important actions (long press, selections)
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy impact for significant actions (confirmations, errors)
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  /// Selection feedback for pickers, switches, etc.
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// Vibrate for notifications or alerts
  static void vibrate() {
    HapticFeedback.vibrate();
  }

  /// Feedback for successful actions
  static void success() {
    medium();
  }

  /// Feedback for error states
  static void error() {
    heavy();
  }

  /// Feedback for message sent
  static void messageSent() {
    light();
  }

  /// Feedback for message received
  static void messageReceived() {
    light();
  }

  /// Feedback for tab navigation
  static void tabSwitch() {
    selection();
  }

  /// Feedback for swipe actions
  static void swipe() {
    light();
  }

  /// Feedback for long press
  static void longPress() {
    medium();
  }

  /// Feedback for button press
  static void buttonPress() {
    light();
  }

  /// Feedback for confirmation actions
  static void confirm() {
    medium();
  }

  /// Feedback for cancel actions
  static void cancel() {
    light();
  }
}
