import 'package:flutter/foundation.dart';

class Group {
  final String name;
  final String groupLastMessage;
  final String lastMessageTime;
  final bool isActive;
  final bool isAdmin;
  final String inviteStatus;
  final bool isTwoWay;
  final bool isOneToOne;

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

  /// Create Group from array data (used by authorize endpoint)
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
}
