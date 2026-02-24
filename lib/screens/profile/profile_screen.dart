import '../../providers/unblock_request_provider.dart';
import '../../providers/chat_provider.dart';

import '../../widgets/mood_indicator.dart';
import '../../widgets/relationship_tag_dialog.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app_routes.dart';
import '../../services/relationship_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final RelationshipService _relationshipService = RelationshipService();
  String? _relationTag;
  bool _isMuted = false; // TODO: Fetch from chat settings
  bool _isPinned = false; // TODO: Fetch from chat settings
  bool _isArchived = false; // TODO: Fetch from chat settings

  @override
  void initState() {
    super.initState();
    _fetchRelationTag();
    if (widget.userId == null ||
        widget.userId == FirebaseAuth.instance.currentUser?.uid) {
      ref.read(unblockRequestProvider.notifier).fetchUnblockRequests();
    }
  }

  Future<void> _fetchRelationTag() async {
    if (widget.userId != null) {
      _relationTag = await _relationshipService.getRelationship(widget.userId!);
      if (mounted) setState(() {});
    }
  }

  String _getLastSeenText(bool isOnline, DateTime? lastSeen) {
    if (isOnline) return "Online";
    if (lastSeen != null) {
      return "last seen ${lastSeen.hour}:${lastSeen.minute.toString().padLeft(2, '0')}";
    }
    return "last seen recently";
  }

  void _showBlockUserDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: 'Reason for blocking'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isNotEmpty) {
                await _relationshipService.blockUser(widget.userId!, reason);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("User blocked")),
                );
              }
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final profileUserId = widget.userId ?? currentUser?.uid;
    final isOwnProfile =
        widget.userId == null || widget.userId == currentUser?.uid;
    final unblockRequests = ref.watch(unblockRequestProvider).unblockRequests;

    if (profileUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Profile")),
        body: const Center(child: Text("User not found")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(profileUserId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.exists) {
              final userData = snapshot.data!.data() as Map<String, dynamic>;
              return Text(userData['fullName'] ?? 'Profile');
            }
            return const Text('Profile');
          },
        ),
        backgroundColor: Colors.teal,
        actions: isOwnProfile
            ? [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.editProfile);
                  },
                ),
              ]
            : [],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(profileUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("User not found"));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final privacySettings =
              Map<String, String>.from(userData['privacySettings'] ?? {});
          final profilePhotoPrivacy =
              privacySettings['profilePhoto'] ?? 'everyone';
          final aboutPrivacy = privacySettings['about'] ?? 'everyone';

          final canShowProfilePhoto = profilePhotoPrivacy == 'everyone' ||
              (profilePhotoPrivacy == 'myContacts'); // TODO: check contacts
          final canShowAbout = aboutPrivacy == 'everyone' ||
              (aboutPrivacy == 'myContacts'); // TODO: check contacts

          final profilePicUrl = canShowProfilePhoto &&
                  userData['profileImage'] != null &&
                  userData['profileImage'].isNotEmpty
              ? userData['profileImage']
              : '';
          final fullName = userData['fullName'] ?? 'Not set';
          final username = userData['username'] ?? 'Not set';
          final bio = canShowAbout &&
                  userData['bio'] != null &&
                  userData['bio'].isNotEmpty
              ? userData['bio']
              : "Hey there! I am using Chatly.";
          final mood = userData['mood'] ?? '';
          final isOnline = userData['status'] == 'online';
          final lastSeen = (userData['lastSeen'] as Timestamp?)?.toDate();

          return SingleChildScrollView(
            child: Column(
              children: [
                // Profile Picture
                Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: profilePicUrl.isNotEmpty
                            ? NetworkImage(profilePicUrl)
                            : null,
                        child: profilePicUrl.isEmpty
                            ? Text(
                                username.substring(0, 1).toUpperCase(),
                                style: const TextStyle(fontSize: 40),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: MoodIndicator(
                          userId: profileUserId,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                ),

                // Name & Status
                Text(fullName,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(
                  _getLastSeenText(isOnline, lastSeen),
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 15),

                const Divider(),

                // Mood Status
                ListTile(
                  leading:
                      const Icon(Icons.emoji_emotions, color: Colors.orange),
                  title: const Text("Mood"),
                  subtitle: Text(mood.isNotEmpty ? mood : "No mood set"),
                ),

                // Relation Tag
                ListTile(
                  leading: const Icon(Icons.people, color: Colors.blue),
                  title: const Text("Relation"),
                  subtitle: Text(_relationTag?.isNotEmpty == true
                      ? _relationTag!
                      : "Not tagged"),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => RelationshipTagDialog(
                        initialTag: _relationTag,
                        onTagSelected: (tag) async {
                          final currentUser = FirebaseAuth.instance.currentUser;
                          if (currentUser != null && widget.userId != null) {
                            await _relationshipService.setRelationshipTag(
                              currentUser.uid,
                              widget.userId!,
                              tag,
                            );
                            _fetchRelationTag();
                          }
                        },
                      ),
                    );
                  },
                ),

                // About / Bio
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.teal),
                  title: const Text("About"),
                  subtitle: Text(bio),
                ),

                // Username
                ListTile(
                  leading:
                      const Icon(Icons.person_outline, color: Colors.purple),
                  title: const Text("Username"),
                  subtitle: Text(username),
                ),

                const Divider(),

                // Media / Links / Docs (placeholder)
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.green),
                  title: const Text("Media, Links & Docs"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // TODO: Navigate to media gallery screen
                  },
                ),

                const Divider(),

                // Unblock Requests
                if (isOwnProfile && unblockRequests.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Unblock Requests',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: unblockRequests.length,
                        itemBuilder: (context, index) {
                          final request = unblockRequests[index];
                          return ListTile(
                            title: Text('Request from ${request.fromUserId}'),
                            subtitle: Text(request.message ?? 'No message'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check,
                                      color: Colors.green),
                                  onPressed: () {
                                    ref
                                        .read(unblockRequestProvider.notifier)
                                        .acceptUnblockRequest(request.id);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.red),
                                  onPressed: () {
                                    ref
                                        .read(unblockRequestProvider.notifier)
                                        .rejectUnblockRequest(request.id);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const Divider(),
                    ],
                  ),

                // Actions
                if (!isOwnProfile) ...[
                  ListTile(
                    leading: const Icon(Icons.volume_off, color: Colors.grey),
                    title: const Text("Mute Notifications"),
                    trailing: Switch(
                      value: _isMuted,
                      onChanged: (val) {
                        setState(() {
                          _isMuted = val;
                        });
                        // TODO: Implement mute in chat service
                      },
                    ),
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.push_pin, color: Colors.deepPurple),
                    title: const Text("Pin Chat"),
                    onTap: () {
                      setState(() {
                        _isPinned = !_isPinned;
                      });
                      // TODO: Implement pin chat in chat service
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.archive, color: Colors.blueGrey),
                    title: const Text("Archive Chat"),
                    onTap: () {
                      setState(() {
                        _isArchived = !_isArchived;
                      });
                      // TODO: Implement archive in chat service
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.block, color: Colors.red),
                    title: const Text("Block Contact"),
                    onTap: _showBlockUserDialog,
                  ),
                  // Add direct unblock option if user is blocked
                  Consumer(
                    builder: (context, ref, _) {
                      final blockedUsers = ref.watch(blockedUsersProvider);
                      final isBlocked = blockedUsers.contains(widget.userId);
                      if (isBlocked) {
                        return ListTile(
                          leading:
                              const Icon(Icons.lock_open, color: Colors.green),
                          title: const Text("Unblock Contact"),
                          onTap: () async {
                            await ref
                                .read(blockedUsersProvider.notifier)
                                .unblockUser(widget.userId!);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("User unblocked")),
                            );
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.report, color: Colors.redAccent),
                    title: const Text("Report"),
                    onTap: () {
                      // TODO: Implement report functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Report feature coming soon")),
                      );
                    },
                  ),
                ],

                if (isOwnProfile)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text("Logout"),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(
                              context, AppRoutes.login);
                        }
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
