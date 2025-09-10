enum MessageStatus {
  sending,    // Clock icon - message sent locally, waiting for server
  sent,       // Single tick - server received the message
  delivered,  // Double tick - message delivered (for future use)
}
