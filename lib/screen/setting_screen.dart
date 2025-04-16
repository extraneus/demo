// lib/screen/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  bool _isLoading = false;
  File? _profileImage;
  Map<String, dynamic>? _userData;
  bool _darkMode = false;
  bool _notifications = true;
  String _selectedLanguage = 'English';
  String _selectedFontSize = 'Medium';

  final List<String> _languages = ['English', 'Bangla', 'Hindi'];

  final List<String> _fontSizes = ['Small', 'Medium', 'Large', 'Extra Large'];

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _bioController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.currentUser != null) {
        final firebaseService = Provider.of<FirebaseService>(
          context,
          listen: false,
        );
        final userData = await firebaseService.getUserData(
          authService.currentUser!.uid,
        );

        setState(() {
          _userData = userData;
          _displayNameController.text = userData['displayName'] ?? '';
          _bioController.text = userData['bio'] ?? '';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading user data: $e')));
    }
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final firebaseService = Provider.of<FirebaseService>(
          context,
          listen: false,
        );

        Map<String, dynamic> updateData = {
          'displayName': _displayNameController.text,
          'bio': _bioController.text,
        };

        // Upload profile image if selected

        await firebaseService.updateUserProfile(
          authService.currentUser!.uid,
          updateData,
        );

        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    if (authService.currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: Text('Please log in to access settings')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile section
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Profile Settings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  Center(
                                    child: Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 50,
                                          backgroundImage:
                                              _profileImage != null
                                                  ? FileImage(_profileImage!)
                                                  : _userData?['profileImageUrl'] !=
                                                      null
                                                  ? NetworkImage(
                                                    _userData!['profileImageUrl'],
                                                  )
                                                  : null,
                                          child:
                                              _profileImage == null &&
                                                      _userData?['profileImageUrl'] ==
                                                          null
                                                  ? Icon(
                                                    Icons.person,
                                                    size: 50,
                                                    color: Colors.grey[400],
                                                  )
                                                  : null,
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: CircleAvatar(
                                            backgroundColor: Colors.deepPurple,
                                            radius: 20,
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.camera_alt,
                                                color: Colors.white,
                                              ),
                                              onPressed: _pickImage,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _displayNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Display Name',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a display name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _bioController,
                                    decoration: const InputDecoration(
                                      labelText: 'Bio',
                                      border: OutlineInputBorder(),
                                      alignLabelWithHint: true,
                                    ),
                                    maxLines: 3,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _updateProfile,
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(
                                        double.infinity,
                                        50,
                                      ),
                                    ),
                                    child: const Text('Save Profile'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // App Settings Section
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'App Settings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              title: const Text('Dark Mode'),
                              trailing: Switch(
                                value: _darkMode,
                                onChanged: (value) {
                                  setState(() {
                                    _darkMode = value;
                                  });
                                },
                                activeColor: Colors.deepPurple,
                              ),
                            ),
                            const Divider(),
                            ListTile(
                              title: const Text('Notifications'),
                              trailing: Switch(
                                value: _notifications,
                                onChanged: (value) {
                                  setState(() {
                                    _notifications = value;
                                  });
                                },
                                activeColor: Colors.deepPurple,
                              ),
                            ),
                            const Divider(),
                            ListTile(
                              title: const Text('Language'),
                              trailing: DropdownButton<String>(
                                value: _selectedLanguage,
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedLanguage = newValue;
                                    });
                                  }
                                },
                                items:
                                    _languages.map<DropdownMenuItem<String>>((
                                      String value,
                                    ) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                              ),
                            ),
                            const Divider(),
                            ListTile(
                              title: const Text('Font Size'),
                              trailing: DropdownButton<String>(
                                value: _selectedFontSize,
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedFontSize = newValue;
                                    });
                                  }
                                },
                                items:
                                    _fontSizes.map<DropdownMenuItem<String>>((
                                      String value,
                                    ) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Account Settings
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Account Settings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              leading: const Icon(
                                Icons.lock,
                                color: Colors.deepPurple,
                              ),
                              title: const Text('Change Password'),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () {
                                // Navigate to change password screen
                              },
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(
                                Icons.data_usage,
                                color: Colors.deepPurple,
                              ),
                              title: const Text('Data Usage'),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () {
                                // Navigate to data usage screen
                              },
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(
                                Icons.delete,
                                color: Colors.red,
                              ),
                              title: const Text(
                                'Delete Account',
                                style: TextStyle(color: Colors.red),
                              ),
                              onTap: () {
                                _showDeleteAccountConfirmation();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // About & Support
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'About & Support',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              leading: const Icon(
                                Icons.info,
                                color: Colors.deepPurple,
                              ),
                              title: const Text('About BanglaLit'),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () {
                                // Show about dialog
                                _showAboutDialog();
                              },
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(
                                Icons.help,
                                color: Colors.deepPurple,
                              ),
                              title: const Text('Help & Support'),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () {
                                // Navigate to help screen
                              },
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(
                                Icons.privacy_tip,
                                color: Colors.deepPurple,
                              ),
                              title: const Text('Privacy Policy'),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () {
                                // Show privacy policy
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Sign Out Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await authService.signOut();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Sign Out',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  void _showDeleteAccountConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Implement account deletion
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('About BanglaLit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('BanglaLit v1.0.0'),
              SizedBox(height: 8),
              Text(
                'BanglaLit is a platform for Bangla literature lovers to read and publish stories, light novels, and comics.',
              ),
              SizedBox(height: 16),
              Text('© 2025 BanglaLit. All rights reserved.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
