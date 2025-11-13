// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

// Project imports:
import '../models/current_user_state.dart';

class BugReportService {
  const BugReportService._();

  static Future<void> sendBugReport({
    required String summary,
    required String description,
    String? appVersion,
  }) async {
    await _ensureEnvLoaded();

    final recipient =
        dotenv.env['BUG_REPORT_RECIPIENT'] ??
        dotenv.env['FEATURE_REQUEST_RECIPIENT'];

    if (recipient == null || recipient.isEmpty) {
      throw StateError(
        'BUG_REPORT_RECIPIENT is not configured in the environment.',
      );
    }

    await _sendEmail(
      recipient: recipient,
      subjectPrefix: '[Bug Report]',
      summary: summary,
      description: description,
      appVersion: appVersion,
      typeLabel: 'Bug report',
    );
  }

  static Future<void> sendFeatureRequest({
    required String summary,
    required String description,
    String? appVersion,
  }) async {
    await _ensureEnvLoaded();

    final recipient =
        dotenv.env['FEATURE_REQUEST_RECIPIENT'] ??
        dotenv.env['BUG_REPORT_RECIPIENT'];

    if (recipient == null || recipient.isEmpty) {
      throw StateError(
        'FEATURE_REQUEST_RECIPIENT is not configured in the environment.',
      );
    }

    await _sendEmail(
      recipient: recipient,
      subjectPrefix: '[Feature Request]',
      summary: summary,
      description: description,
      appVersion: appVersion,
      typeLabel: 'Feature request',
    );
  }

  static Future<void> _ensureEnvLoaded() async {
    if (!dotenv.isInitialized) {
      try {
        await dotenv.load(fileName: '.env');
      } catch (e) {
        throw StateError(
          'Failed to load environment configuration. Please ensure the .env file is present and accessible. ($e)',
        );
      }

      if (!dotenv.isInitialized) {
        throw StateError(
          'Environment configuration is missing. Please ensure the .env file is present.',
        );
      }
    }
  }

  static Future<void> _sendEmail({
    required String recipient,
    required String subjectPrefix,
    required String summary,
    required String description,
    required String typeLabel,
    String? appVersion,
  }) async {
    final host = dotenv.env['SMTP_HOST'];
    final portString = dotenv.env['SMTP_PORT'];
    final username = dotenv.env['SMTP_USERNAME'];
    final password = dotenv.env['SMTP_PASSWORD'];
    final senderEmail = dotenv.env['SMTP_SENDER_EMAIL'];
    final senderName = dotenv.env['SMTP_SENDER_NAME'];

    if (host == null ||
        portString == null ||
        username == null ||
        password == null ||
        senderEmail == null ||
        senderName == null ||
        host.isEmpty ||
        portString.isEmpty ||
        username.isEmpty ||
        password.isEmpty ||
        senderEmail.isEmpty ||
        senderName.isEmpty) {
      throw StateError(
        'SMTP configuration is incomplete. Please check your .env file.',
      );
    }

    final port = int.tryParse(portString);
    if (port == null) {
      throw StateError('Invalid SMTP_PORT value: "$portString".');
    }

    final user = currentUser;
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final buffer = StringBuffer()
      ..writeln('$typeLabel submitted at: $timestamp (UTC)')
      ..writeln()
      ..writeln('Summary:')
      ..writeln(summary)
      ..writeln()
      ..writeln('Details:')
      ..writeln(description)
      ..writeln()
      ..writeln('---')
      ..writeln('Metadata:')
      ..writeln('App version: ${appVersion ?? 'Unknown'}')
      ..writeln(
        'User: ${user != null ? '${user.displayName} (${user.id})' : 'Unknown'}',
      )
      ..writeln('User category: ${user?.category ?? 'Unknown'}')
      ..writeln('User department: ${user?.department ?? 'Unknown'}')
      ..writeln('One-to-one enabled: ${user?.oneToOne ?? 'Unknown'}')
      ..writeln('Create groups: ${user?.createGroups ?? 'Unknown'}')
      ..writeln('Device: ${defaultTargetPlatform.name}')
      ..writeln('Build mode: ${kReleaseMode ? 'release' : 'debug'}');

    final message = Message()
      ..from = Address(senderEmail, senderName)
      ..recipients.add(recipient)
      ..subject = '$subjectPrefix $summary'
      ..text = buffer.toString();

    final isSsl = port == 465;
    final smtpServer = SmtpServer(
      host,
      port: port,
      username: username,
      password: password,
      ssl: isSsl,
      ignoreBadCertificate: false,
    );

    try {
      await send(message, smtpServer);
    } on MailerException catch (e, stackTrace) {
      debugPrint('BugReportService: Failed to send email: $e\n$stackTrace');
      throw Exception('Failed to send feedback. Please try again later.');
    } catch (e, stackTrace) {
      debugPrint(
        'BugReportService: Unexpected error while sending email: $e\n$stackTrace',
      );
      rethrow;
    }
  }
}
