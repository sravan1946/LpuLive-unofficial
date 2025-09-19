class GroupMediaItem {
  final String mediaId;
  final String mediaName;
  final String mediaType;
  final String entryDate;
  final String sentBy;

  GroupMediaItem({
    required this.mediaId,
    required this.mediaName,
    required this.mediaType,
    required this.entryDate,
    required this.sentBy,
  });

  factory GroupMediaItem.fromJson(Map<String, dynamic> json) {
    return GroupMediaItem(
      mediaId: json['media_id']?.toString() ?? '',
      mediaName: json['media_name']?.toString() ?? '',
      mediaType: json['media_type']?.toString() ?? '',
      entryDate: json['entry_date']?.toString() ?? '',
      sentBy: json['sent_by']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'media_id': mediaId,
      'media_name': mediaName,
      'media_type': mediaType,
      'entry_date': entryDate,
      'sent_by': sentBy,
    };
  }
}
