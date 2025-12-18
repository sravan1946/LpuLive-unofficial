/// Utility functions for determining group types based on naming patterns.
///
/// Group naming schemes:
/// - Direct messages: "<regA> : <regB>" (both sides are numeric IDs)
/// - University groups: "<section> : <courseCode>"
/// - Personal groups: "<group name> : <regNo>"

// Project imports:
import '../models/group_model.dart';

final RegExp _dmNamePattern = RegExp(r'^\d+\s*:\s*\d+$');
final RegExp _sectionPattern = RegExp(r'^(\d[A-Z]\d{3}|[A-Z]{2}\d{3})$');
final RegExp _courseCodePattern = RegExp(r'^[A-Z]{2,4}\d{2,3}$');
final RegExp _regNoPattern = RegExp(r'^\d{5,}$');

bool hasUniversityCourseCode(String groupName) {
  return _courseCodePattern.hasMatch(groupName.trim());
}

String? extractCourseCode(String groupName) {
  final parts = groupName.split(':');
  if (parts.length != 2) return null;
  final right = parts[1].trim();
  if (_courseCodePattern.hasMatch(right)) {
    return right;
  }
  return null;
}

bool isUniversityGroupByName(String groupName) {
  final parts = groupName.split(':');
  if (parts.length != 2) return false;
  final left = parts[0].trim();
  final right = parts[1].trim();
  return _sectionPattern.hasMatch(left) && _courseCodePattern.hasMatch(right);
}

bool isDirectMessageByFlags(Group group) {
  return group.isOneToOne;
}

bool isDirectMessageByName(String groupName) {
  return _dmNamePattern.hasMatch(groupName.trim());
}

bool isPersonalGroup(String groupName, Group group) {
  if (isDirectMessageByFlags(group) || isDirectMessageByName(group.name)) {
    return false;
  }

  if (isUniversityGroupByName(groupName)) return false;

  if (!groupName.contains(':')) return false;
  final parts = groupName.split(':');
  if (parts.length != 2) return false;

  final left = parts[0].trim();
  final right = parts[1].trim();

  if (!_regNoPattern.hasMatch(right)) return false;

  final isLeftPureNumeric = RegExp(r'^\d+$').hasMatch(left);
  if (isLeftPureNumeric) return false;

  return true;
}

bool isPersonalGroupByName(String groupName, bool isOneToOne) {
  if (isOneToOne) return false;
  if (isUniversityGroupByName(groupName)) return false;

  if (!groupName.contains(':')) return false;
  final parts = groupName.split(':');
  if (parts.length != 2) return false;

  final left = parts[0].trim();
  final right = parts[1].trim();

  if (!_regNoPattern.hasMatch(right)) return false;
  final isLeftPureNumeric = RegExp(r'^\d+$').hasMatch(left);
  if (isLeftPureNumeric) return false;

  return true;
}

String getGroupType(Group group) {
  if (isDirectMessageByFlags(group) || isDirectMessageByName(group.name)) {
    return 'DirectMessage';
  } else if (isUniversityGroupByName(group.name)) {
    return 'UniversityGroup';
  } else if (isPersonalGroup(group.name, group)) {
    return 'PersonalGroup';
  }
  return 'Unknown';
}
