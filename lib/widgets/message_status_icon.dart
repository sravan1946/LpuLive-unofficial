import 'package:flutter/material.dart';
import '../models/message_status.dart';

class MessageStatusIcon extends StatelessWidget {
  final MessageStatus status;
  final ColorScheme scheme;

  const MessageStatusIcon({
    super.key,
    required this.status,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return Icon(
          Icons.access_time,
          size: 14,
          color: scheme.onPrimary.withValues(alpha: 0.6),
        );
      case MessageStatus.sent:
        return Icon(
          Icons.done,
          size: 14,
          color: scheme.onPrimary.withValues(alpha: 0.8),
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 14,
          color: scheme.onPrimary.withValues(alpha: 0.8),
        );
    }
  }
}
