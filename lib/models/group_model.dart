// Group listing item with last message metadata and flags.
import 'package:flutter/foundation.dart';

class Group {
  /// Group name (unique identifier from backend).
  final String name;

  /// Preview of the most recent message in the group.
  final String groupLastMessage;

  /// Timestamp of the most recent message.
  final String lastMessageTime;

  /// Whether the group is active for the current user.
  final bool isActive;

  /// Whether the current user is an admin of the group.
  final bool isAdmin;

  /// Invite state for the current user.
  final String inviteStatus;

  /// True if the group allows two-way communication.
  final bool isTwoWay;

  /// True if the group is a 1:1 conversation.
  final bool isOneToOne;

  /// Creates a [Group].
  Group({
    required this.name,
    required this.groupLastMessage,
    required this.lastMessageTime,
    required this.isActive,
    required this.isAdmin,
    required this.inviteStatus,
    required this.isTwoWay,
    required this.isOneToOne,
  });

  /// Parses a [Group] from JSON.
  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      name: json['name'] ?? '',
      groupLastMessage: json['groupLastMessage'] ?? json['lastMessage'] ?? '',
      lastMessageTime: json['lastMessageTime'] ?? json['timestamp'] ?? '',
      isActive: json['isActive'] ?? false,
      isAdmin: json['isAdmin'] ?? false,
      inviteStatus: json['inviteStatus'] ?? '',
      isTwoWay: json['isTwoWay'] ?? false,
      isOneToOne: json['isOneToOne'] ?? false,
    );
  }

  /// Creates a [Group] from array data (authorize endpoint response).
  /// Array format: [name, lastMessage, lastMessageTime, isActive, isAdmin, inviteStatus, isTwoWay, isOneToOne]
  factory Group.fromArray(List<dynamic> array) {
    debugPrint('🔍 [Group.fromArray] Processing array: $array');
    if (array.length < 8) {
      // Handle incomplete arrays by padding with defaults
      final paddedArray = List<dynamic>.from(array);
      while (paddedArray.length < 8) {
        paddedArray.add(null);
      }
      array = paddedArray;
      debugPrint('🔍 [Group.fromArray] Padded array to length 8: $array');
    }
    
    try {
      final group = Group(
        name: array[0]?.toString() ?? '',
        groupLastMessage: array[1]?.toString() ?? '',
        lastMessageTime: array[2]?.toString() ?? '',
        isActive: array[3] == true,
        isAdmin: array[4] == true,
        inviteStatus: array[5]?.toString() ?? '',
        isTwoWay: array[6] == true,
        isOneToOne: array[7] == true,
      );
      debugPrint('🔍 [Group.fromArray] Created group successfully: ${group.name}');
      return group;
    } catch (e) {
      debugPrint('❌ [Group.fromArray] Error creating group: $e');
      rethrow;
    }
  }

  /// Returns a copy with provided fields replaced.
  Group copyWith({
    String? name,
    String? groupLastMessage,
    String? lastMessageTime,
    bool? isActive,
    bool? isAdmin,
    String? inviteStatus,
    bool? isTwoWay,
    bool? isOneToOne,
  }) {
    return Group(
      name: name ?? this.name,
      groupLastMessage: groupLastMessage ?? this.groupLastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      isActive: isActive ?? this.isActive,
      isAdmin: isAdmin ?? this.isAdmin,
      inviteStatus: inviteStatus ?? this.inviteStatus,
      isTwoWay: isTwoWay ?? this.isTwoWay,
      isOneToOne: isOneToOne ?? this.isOneToOne,
    );
  }

  /// Serializes this [Group] to JSON.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'groupLastMessage': groupLastMessage,
      'lastMessageTime': lastMessageTime,
      'isActive': isActive,
      'isAdmin': isAdmin,
      'inviteStatus': inviteStatus,
      'isTwoWay': isTwoWay,
      'isOneToOne': isOneToOne,
    };
  }

  /// Categorization helpers derived from flags
  bool get isUniversityGroup => !isTwoWay && !isOneToOne;
  bool get isPersonalGroup => isTwoWay && !isOneToOne;
  bool get isDirectMessage => isTwoWay && isOneToOne;
}
