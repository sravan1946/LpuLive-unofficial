import 'package:flutter/material.dart';

class PersonalGroupsPage extends StatelessWidget {
  final dynamic wsService; // Placeholder for future use

  const PersonalGroupsPage({super.key, required this.wsService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Personal Groups'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_add, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Personal Groups',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Create and manage your own groups',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            SizedBox(height: 24),
            Text(
              'Coming Soon!',
              style: TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Create group feature coming soon!')),
          );
        },
        tooltip: 'Create New Group',
        child: const Icon(Icons.add),
      ),
    );
  }
}