import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_routes.dart';
import '../../providers/chat_provider.dart';
import '../../providers/unblock_request_provider.dart';
import '../../services/relationship_service.dart';
import '../../widgets/app_page_scaffold.dart';
import '../../widgets/mood_indicator.dart';
import '../../widgets/relationship_tag_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final RelationshipService _relationshipService = RelationshipService();
  String? _relationTag;
  bool _isMuted = false;
  bool _isPinned = false;
  bool _isArchived = false;

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
    if (widget.userId == null) return;
    _relationTag = await _relationshipService.getRelationship(widget.userId!);
    if (mounted) setState(() {});
  }

  String _statusText(bool isOnline, DateTime? lastSeen) {
    if (isOnline) return 'Online';
    if (lastSeen == null) return 'Last seen recently';
    return 'Last seen ${lastSeen.hour}:${lastSeen.minute.toString().padLeft(2, '0')}';
  }

  void _showBlockUserDialog() {
    final reasonController = TextEditingController();
    showDialog<void>(
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
              if (reason.isEmpty || widget.userId == null) return;
              await _relationshipService.blockUser(widget.userId!, reason);
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User blocked')),
              );
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
      return AppPageScaffold(
        appBar: AppBar(title: const Text('Profile')),
        child: const Center(child: Text('User not found')),
      );
    }

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: isOwnProfile
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit profile',
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.editProfile);
                  },
                ),
              ]
            : null,
      ),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(profileUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('User not found'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final privacySettings =
              Map<String, String>.from(userData['privacySettings'] ?? {});
          final profilePhotoPrivacy =
              privacySettings['profilePhoto'] ?? 'everyone';
          final aboutPrivacy = privacySettings['about'] ?? 'everyone';
          final canShowProfilePhoto = profilePhotoPrivacy == 'everyone' ||
              profilePhotoPrivacy == 'myContacts';
          final canShowAbout =
              aboutPrivacy == 'everyone' || aboutPrivacy == 'myContacts';

          final profilePicUrl = canShowProfilePhoto &&
                  (userData['profileImage']?.toString().isNotEmpty ?? false)
              ? userData['profileImage'].toString()
              : '';
          final fullName = userData['fullName']?.toString() ?? 'Not set';
          final username = userData['username']?.toString() ?? 'Not set';
          final bio =
              canShowAbout && (userData['bio']?.toString().isNotEmpty ?? false)
                  ? userData['bio'].toString()
                  : 'Hey there! I am using Chatly.';
          final mood = userData['mood']?.toString() ?? '';
          final isOnline = userData['status'] == 'online';
          final lastSeen = (userData['lastSeen'] as Timestamp?)?.toDate();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppSectionCard(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 54,
                          backgroundImage: profilePicUrl.isNotEmpty
                              ? NetworkImage(profilePicUrl)
                              : null,
                          child: profilePicUrl.isEmpty
                              ? Text(
                                  username.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(fontSize: 36),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: MoodIndicator(userId: profileUserId, size: 30),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      fullName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusText(isOnline, lastSeen),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (mood.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Chip(
                        avatar: const Icon(Icons.emoji_emotions_outlined),
                        label: Text('Mood: $mood'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppSectionCard(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.people_alt_outlined),
                      title: const Text('Relation'),
                      subtitle: Text(
                        _relationTag?.isNotEmpty == true
                            ? _relationTag!
                            : 'Not tagged',
                      ),
                      onTap: () {
                        showDialog<void>(
                          context: context,
                          builder: (context) => RelationshipTagDialog(
                            initialTag: _relationTag,
                            onTagSelected: (tag) async {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null || widget.userId == null) return;
                              await _relationshipService.setRelationshipTag(
                                user.uid,
                                widget.userId!,
                                tag,
                              );
                              _fetchRelationTag();
                            },
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded),
                      title: const Text('About'),
                      subtitle: Text(bio),
                    ),
                    ListTile(
                      leading: const Icon(Icons.alternate_email_rounded),
                      title: const Text('Username'),
                      subtitle: Text(username),
                    ),
                  ],
                ),
              ),
              if (isOwnProfile && unblockRequests.isNotEmpty) ...[
                const SizedBox(height: 12),
                AppSectionCard(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Text(
                          'Unblock Requests',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      ...unblockRequests.map((request) {
                        return ListTile(
                          title: Text('Request from ${request.fromUserId}'),
                          subtitle: Text(request.message ?? 'No message'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green,
                                ),
                                onPressed: () {
                                  ref
                                      .read(unblockRequestProvider.notifier)
                                      .acceptUnblockRequest(request.id);
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  ref
                                      .read(unblockRequestProvider.notifier)
                                      .rejectUnblockRequest(request.id);
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
              if (!isOwnProfile) ...[
                const SizedBox(height: 12),
                AppSectionCard(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        title: const Text('Mute Notifications'),
                        secondary: const Icon(Icons.volume_off_outlined),
                        value: _isMuted,
                        onChanged: (value) => setState(() => _isMuted = value),
                      ),
                      ListTile(
                        leading: const Icon(Icons.push_pin_outlined),
                        title: Text(_isPinned ? 'Unpin Chat' : 'Pin Chat'),
                        onTap: () => setState(() => _isPinned = !_isPinned),
                      ),
                      ListTile(
                        leading: const Icon(Icons.archive_outlined),
                        title: Text(
                            _isArchived ? 'Unarchive Chat' : 'Archive Chat'),
                        onTap: () => setState(() => _isArchived = !_isArchived),
                      ),
                      ListTile(
                        leading:
                            const Icon(Icons.block_rounded, color: Colors.red),
                        title: const Text('Block Contact'),
                        onTap: _showBlockUserDialog,
                      ),
                      Consumer(
                        builder: (context, ref, _) {
                          final blockedUsers = ref.watch(blockedUsersProvider);
                          final isBlocked =
                              blockedUsers.contains(widget.userId);
                          if (!isBlocked || widget.userId == null) {
                            return const SizedBox.shrink();
                          }
                          return ListTile(
                            leading: const Icon(
                              Icons.lock_open_rounded,
                              color: Colors.green,
                            ),
                            title: const Text('Unblock Contact'),
                            onTap: () async {
                              await ref
                                  .read(blockedUsersProvider.notifier)
                                  .unblockUser(widget.userId!);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('User unblocked')),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
              if (isOwnProfile) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Logout'),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!mounted) return;
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
