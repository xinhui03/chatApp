import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'chat_screen.dart';
import 'sign_in_screen.dart'; // Import SignInScreen
import 'profile_screen.dart'; // Import the ProfileScreen

// Using the same User class structure
class User {
  final String uid;
  final String name;

  User({required this.uid, required this.name});

  // Factory constructor to create a User from a Firestore document
  factory User.fromDocument(DocumentSnapshot doc) {
    return User(
      uid: doc.id,
      name: doc.get('name') ?? '', // Assuming a 'name' field exists
    );
  }
}

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  final FirebaseAuth _auth = FirebaseAuth.instance; // Firebase Auth instance

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      // Navigate to sign-in screen after successful logout
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SignInScreen()),
        );
      }
    } catch (e) {
      // Handle logout errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid; // Get current user's UID

    return Scaffold(
      appBar: AppBar(
        title: const Text('UChat'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.person), // Profile icon
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _signOut,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search users...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(25.0)),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(), // Listen to users collection
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!.docs
                    .map((doc) => User.fromDocument(doc))
                    .where((user) => user.uid != currentUserUid) // Exclude current user
                    .where((user) => // Filter by search text
                        user.name.toLowerCase().contains(_searchText))
                    .toList();

                if (users.isEmpty) {
                   // Show a different message if there are users but none match the search
                   if(snapshot.data!.docs.where((doc) => doc.id != currentUserUid).isEmpty) {
                     return const Center(child: Text('No other users found.'));
                   } else {
                     return const Center(child: Text('No matching users found.'));
                   }
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), // Adjusted padding
                  itemCount: users.length,
                  separatorBuilder: (context, index) => const Divider(height: 8.0), // Adjusted divider height
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Card(
                      elevation: 2.0, // Added subtle elevation
                      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0), // Added margin
                      child: ListTile(
                        leading: CircleAvatar(
                           backgroundColor: Theme.of(context).colorScheme.primary, // Added background color
                           foregroundColor: Colors.white, // Changed text color
                          child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : ''),
                        ),
                        title: Text(user.name, style: TextStyle(fontWeight: FontWeight.bold)), // Made name bold
                        onTap: () {
                          // Navigate to chat screen with selected user
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(recipientUser: user),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 