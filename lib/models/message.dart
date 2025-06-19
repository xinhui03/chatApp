import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore for Timestamp

class Message {
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final String senderId;
  final String? senderName;

  Message({
    required this.text,
    required this.isMe,
    required this.timestamp,
    required this.senderId,
    this.senderName,
  });

  factory Message.fromDocument(Map<String, dynamic> data, String currentUserId) {
    return Message(
      text: data['text'] ?? '',
      isMe: data['senderId'] == currentUserId,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
    );
  }
} 