import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  String? _userEmail;
  String? _selectedGender;
  bool _isLoading = true;
  bool _isEditing = false;

  final List<String> _genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _userEmail = currentUser.email;
      _emailController.text = currentUser.email ?? '';

      try {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          _nameController.text = userData?['name'] ?? '';
          _phoneController.text = userData?['phone'] ?? '';
          _bioController.text = userData?['bio'] ?? '';
          _selectedGender = userData?['gender'] ?? null;
          setState(() {
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching profile: ${e.toString()}')),
        );
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserProfile() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Update email in Firebase Auth if changed
      if (_emailController.text != currentUser.email) {
        await currentUser.updateEmail(_emailController.text);
      }

      // Update other fields in Firestore
      await _firestore.collection('users').doc(currentUser.uid).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'bio': _bioController.text.trim(),
        'gender': _selectedGender,
      });

      setState(() {
        _isEditing = false;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Widget _buildField({
    required String label,
    required String value,
    required TextEditingController controller,
    bool isMultiline = false,
    TextInputType keyboardType = TextInputType.text,
    required IconData icon,
  }) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20.0),
                const SizedBox(width: 12.0),
                Text(
                  '$label:',
                  style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            _isEditing
                ? TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Enter your $label',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 15.0),
                    ),
                    keyboardType: keyboardType,
                    maxLines: isMultiline ? 3 : 1,
                    style: const TextStyle(fontSize: 17.0, color: Colors.black87),
                  )
                : Text(
                    value.isNotEmpty ? value : 'N/A',
                    style: TextStyle(fontSize: 17.0, color: Colors.black87),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderField() {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Theme.of(context).colorScheme.primary, size: 20.0),
                const SizedBox(width: 12.0),
                Text(
                  'Gender:',
                  style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            _isEditing
                ? DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 15.0),
                    ),
                    items: _genderOptions.map((String gender) {
                      return DropdownMenuItem<String>(
                        value: gender,
                        child: Text(gender, style: const TextStyle(fontSize: 17.0, color: Colors.black87)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedGender = newValue;
                      });
                    },
                    style: const TextStyle(color: Colors.black87),
                  )
                : Text(
                    _selectedGender ?? 'N/A',
                    style: TextStyle(fontSize: 17.0, color: Colors.black87),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Profile',
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save Profile',
              onPressed: _updateUserProfile,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  CircleAvatar(
                    radius: 60.0,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                    child: Icon(
                      Icons.person,
                      size: 60.0,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 30.0),
                  _buildField(
                    label: 'Email',
                    value: _emailController.text,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    icon: Icons.email,
                  ),
                  _buildField(
                    label: 'Name',
                    value: _nameController.text,
                    controller: _nameController,
                    icon: Icons.person,
                  ),
                  _buildGenderField(),
                  _buildField(
                    label: 'Phone',
                    value: _phoneController.text,
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    icon: Icons.phone,
                  ),
                  _buildField(
                    label: 'Bio',
                    value: _bioController.text,
                    controller: _bioController,
                    isMultiline: true,
                    icon: Icons.description,
                  ),
                  const SizedBox(height: 20.0),
                ],
              ),
            ),
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
    );
  }
} 