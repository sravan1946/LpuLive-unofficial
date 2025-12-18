// Flutter imports:
import 'package:flutter/material.dart';

/// Base empty state widget with consistent styling
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.iconSize = 80,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with gradient background
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: 0.15),
                    scheme.primary.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: scheme.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            // Title
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state for no groups
class EmptyGroupsState extends StatelessWidget {
  final String title;
  final String? subtitle;

  const EmptyGroupsState({
    super.key,
    this.title = 'No groups yet',
    this.subtitle = 'Start a conversation or join a group to get started',
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.group_outlined,
      title: title,
      subtitle: subtitle,
    );
  }
}

/// Empty state for no direct messages
class EmptyDMsState extends StatelessWidget {
  final VoidCallback? onNewDM;

  const EmptyDMsState({super.key, this.onNewDM});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.forum_outlined,
      title: 'No conversations yet',
      subtitle: 'Start a new conversation to connect with others',
      action: onNewDM != null
          ? FilledButton.icon(
              onPressed: onNewDM,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Start Conversation'),
            )
          : null,
    );
  }
}

/// Empty state for no search results
class EmptySearchState extends StatelessWidget {
  final String query;

  const EmptySearchState({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off_outlined,
      title: 'No results found',
      subtitle: 'Try searching with a different term',
      iconSize: 64,
    );
  }
}

/// Empty state for no messages in chat
class EmptyChatState extends StatelessWidget {
  const EmptyChatState({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.chat_bubble_outline,
      title: 'No messages yet',
      subtitle: 'Be the first to send a message!',
      iconSize: 64,
    );
  }
}

/// Empty state for no media
class EmptyMediaState extends StatelessWidget {
  const EmptyMediaState({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.image_outlined,
      title: 'No media yet',
      subtitle: 'Shared images and files will appear here',
      iconSize: 64,
    );
  }
}

/// Empty state for loading error
class EmptyErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const EmptyErrorState({
    super.key,
    this.message = 'Something went wrong',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: 'Oops!',
      subtitle: message,
      action: onRetry != null
          ? OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            )
          : null,
    );
  }
}
