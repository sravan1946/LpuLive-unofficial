// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Package imports:
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// Project imports:
import '../services/bug_report_service.dart';

class BugReportPage extends StatefulWidget {
  const BugReportPage({super.key});

  @override
  State<BugReportPage> createState() => _BugReportPageState();
}

class _BugReportPageState extends State<BugReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _summaryController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  String? _appVersion;
  String? _platformSummary;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
    _platformSummary = _resolvePlatformSummary();
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;
      setState(() {
        _appVersion = buildNumber.isNotEmpty
            ? '$version+$buildNumber'
            : version;
      });
    } catch (_) {
      // Ignore version errors; leave null.
    }
  }

  String? _resolvePlatformSummary() {
    if (kIsWeb) {
      return 'Web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await BugReportService.sendBugReport(
        summary: _summaryController.text.trim(),
        description: _buildDescription(),
        appVersion: _appVersion,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bug report sent. Thank you!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _buildDescription() {
    final buffer = StringBuffer()
      ..writeln(_descriptionController.text.trim())
      ..writeln()
      ..writeln('---')
      ..writeln('Client context:')
      ..writeln('Platform: ${_platformSummary ?? defaultTargetPlatform.name}')
      ..writeln('App version: ${_appVersion ?? 'Unknown'}');

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report a Bug')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Need a faster response?',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'GitHub issues let us collaborate publicly with more context. '
                        'If you\'re comfortable, consider opening an issue instead.',
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () => _openIssues(),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open GitHub Issues'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _summaryController,
                decoration: const InputDecoration(
                  labelText: 'Summary',
                  hintText: 'Short title for the problem',
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide a summary.';
                  }
                  if (value.trim().length < 8) {
                    return 'Summary should be at least 8 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'What happened?',
                  hintText:
                      'Include steps to reproduce, what you expected, and any screenshots or logs.',
                  alignLabelWithHint: true,
                ),
                textInputAction: TextInputAction.newline,
                minLines: 6,
                maxLines: 12,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please describe the issue.';
                  }
                  if (value.trim().length < 20) {
                    return 'Description should be at least 20 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send Bug Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openIssues() async {
    const githubIssuesUrl =
        'https://github.com/sravan1946/LpuLive-unofficial/issues/new/choose';

    final uri = Uri.parse(githubIssuesUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open GitHub in your browser.')),
      );
    }
  }
}
