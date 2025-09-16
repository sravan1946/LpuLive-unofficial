/// Delivery state of an outgoing chat message.
enum MessageStatus {
  /// Message queued locally, awaiting server acknowledgment.
  sending,

  /// Server acknowledged the message.
  sent,

  /// Message delivered to recipient (reserved for future use).
  delivered,
}
