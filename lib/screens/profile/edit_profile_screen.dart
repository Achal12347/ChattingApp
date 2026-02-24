import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _moodController = TextEditingController();

  File? _pickedImage;
  bool _loading = false;
  String? _currentUsername;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = _auth.currentUser!.uid;

    // find user document by uid
    final userDoc = await _firestore
        .collection("users")
        .where("uid", isEqualTo: uid)
        .limit(1)
        .get();

    if (userDoc.docs.isNotEmpty) {
      final data = userDoc.docs.first.data();
      setState(() {
        _currentUsername = data["username"];
        _nameController.text = data["fullName"] ?? "";
        _usernameController.text = data["username"] ?? "";
        _bioController.text = data["bio"] ?? "";
        _moodController.text = data["mood"] ?? "";
        _profileImageUrl = data["profileImage"];
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
              toolbarTitle: 'Cropper',
              toolbarColor: Colors.deepOrange,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
              aspectRatioPresets: [
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9
              ]),
          IOSUiSettings(
            title: 'Cropper',
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9
            ],
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _pickedImage = File(croppedFile.path);
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Full name must be at least 3 characters")),
      );
      return;
    }

    if (_nameController.text.trim().length > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Full name cannot exceed 50 characters")),
      );
      return;
    }

    if (_usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Username cannot be empty")),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Changes'),
        content: const Text('Are you sure you want to save the changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);

    try {
      String? imageUrl = _profileImageUrl;

      // If a new profile image is picked, upload to Firebase Storage
      if (_pickedImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child("profile_images")
            .child("${_auth.currentUser!.uid}.jpg");

        await ref.putFile(_pickedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      final newUsername = _usernameController.text.trim();

      // If username is changed
      if (newUsername != _currentUsername) {
        final usernameCheck = await _firestore
            .collection("users")
            .doc(newUsername)
            .get();

        if (usernameCheck.exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Username already taken")),
            );
          }
          setState(() => _loading = false);
          return;
        }

        final uid = _auth.currentUser!.uid;
        final userQuery = await _firestore
            .collection("users")
            .where("uid", isEqualTo: uid)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final oldDocRef = userQuery.docs.first.reference;
          final oldData = userQuery.docs.first.data();

          final newData = {
            ...oldData,
            "fullName": _nameController.text.trim(),
            "username": newUsername,
            "bio": _bioController.text.trim(),
            "mood": _moodController.text.trim(),
            "profileImage": imageUrl,
          };

          await _firestore.collection("users").doc(newUsername).set(newData);
          await oldDocRef.delete();
        }
      } else {
        // update user data in Firestore
        final uid = _auth.currentUser!.uid;
        final userQuery = await _firestore
            .collection("users")
            .where("uid", isEqualTo: uid)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final docRef = userQuery.docs.first.reference;
          await docRef.update({
            "fullName": _nameController.text.trim(),
            "bio": _bioController.text.trim(),
            "mood": _moodController.text.trim(),
            "profileImage": imageUrl,
          });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully")),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: _pickedImage != null
                          ? FileImage(_pickedImage!)
                          : (_profileImageUrl != null
                              ? NetworkImage(_profileImageUrl!) as ImageProvider
                              : const AssetImage("assets/icons/icon.png")),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 18,
                          child: const Icon(Icons.edit, size: 20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Full Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: "Username",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bioController,
                    decoration: const InputDecoration(
                      labelText: "About",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _moodController,
                    decoration: const InputDecoration(
                      labelText: "Mood",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Save",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
