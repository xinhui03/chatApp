import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_auth/firebase_auth.dart' hide User; // Hide User from firebase_auth
import '../models/message.dart';
import 'dart:async';
import 'sign_in_screen.dart'; // Import SignInScreen
import 'user_list_screen.dart'; // Import User class
import 'package:intl/intl.dart'; // Import for timestamp formatting

class ChatScreen extends StatefulWidget {
  final User recipientUser; // Accept recipient user
  const ChatScreen({super.key, required this.recipientUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance
  String? _currentUserName; // State variable for current user's name

  @override
  void initState() {
    super.initState();
    _getCurrentUserName(); // Fetch current user's name on init
  }

  Future<void> _getCurrentUserName() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        setState(() {
          _currentUserName = userDoc.get('name');
        });
      }
    }
  }

  String get _chatRoomId {
    // Create a unique chat room ID by sorting the two user UIDs
    List<String> ids = [_auth.currentUser!.uid, widget.recipientUser.uid];
    ids.sort();
    return ids.join('_');
  }

  void _sendMessage() async {
    if (_textController.text.trim().isEmpty || _currentUserName == null) return; // Ensure name is loaded

    // Get current user info (you might want to store this in a state management solution)
    final currentUser = _auth.currentUser;
    if (currentUser == null) return; // Should not happen if user is logged in

    final messageText = _textController.text.trim();
    _textController.clear();

    try {
      await _firestore
          .collection('chats')
          .doc(_chatRoomId)
          .collection('messages')
          .add({
        'text': messageText,
        'senderId': currentUser.uid,
        'recipientId': widget.recipientUser.uid,
        'timestamp': Timestamp.now(),
        'senderName': _currentUserName, // Save sender's name
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.recipientUser.name}'), // Display recipient name
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(_chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true) // Order by timestamp descending
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs.map((doc) {
                   final data = doc.data() as Map<String, dynamic>;
                   return Message.fromDocument(data, _auth.currentUser!.uid); // Use factory constructor
                 }).toList();

                return ListView.builder(
                  reverse: true, // Keep reverse true for auto-scrolling
                  padding: const EdgeInsets.all(8.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _MessageBubble(
                      message: message,
                    );
                  },
                );
              },
            ),
          ),
          // Improved input area
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(top: BorderSide(color: Colors.grey[200]!, width: 0.5)), // Subtle border
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), // Added padding
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Send a message...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8.0), // Added content padding
                    ),
                    onSubmitted: (value) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).colorScheme.primary, // Color the send icon
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    // Format the timestamp
    final timeFormat = DateFormat('h:mm a');
    final formattedTime = timeFormat.format(message.timestamp);

    // Determine the color and alignment based on message sender
    final bool isMe = message.isMe;
    final Color bubbleColor = isMe
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondaryContainer; // Using secondaryContainer for received
    final Color textColor = isMe ? Colors.white : Colors.black;
    final CrossAxisAlignment alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final MainAxisAlignment rowAlignment = isMe ? MainAxisAlignment.end : MainAxisAlignment.start;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: rowAlignment,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar for received messages
          if (!isMe) ...[
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondary, // Different color for received avatar
              foregroundColor: Colors.white,
              child: Text(message.senderName?.isNotEmpty == true ? message.senderName![0].toUpperCase() : ''),
            ),
            const SizedBox(width: 8.0),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: alignment,
              children: [
                // Sender name for received messages
                 if (!isMe && message.senderName != null) ...[
                   Text(
                     message.senderName!,
                     style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
                   ),
                   const SizedBox(height: 4.0),
                 ],
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                     borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isMe ? 20.0 : 5.0), // Rounded or pointed corner
                      topRight: Radius.circular(isMe ? 5.0 : 20.0), // Pointed or rounded corner
                      bottomLeft: Radius.circular(20.0),
                      bottomRight: Radius.circular(20.0),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4.0),
                // Timestamp
                Text(
                  formattedTime,
                  style: TextStyle(fontSize: 10.0, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
           // Avatar for sent messages (optional, could add if desired)
          if (isMe) ...[
             const SizedBox(width: 8.0),
            // Add sender's avatar here if needed
          ],
        ],
      ),
    );
  }
} 