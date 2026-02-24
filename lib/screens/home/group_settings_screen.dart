import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/group_service.dart';
import '../../models/group_model.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  final String groupId;
  final bool isProfileMode; // New parameter to distinguish profile mode

  const GroupSettingsScreen({
    super.key,
    required this.groupId,
    this.isProfileMode = false, // Default to settings mode
  });

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  GroupModel? _group;
  Map<String, Map<String, dynamic>> _members = {};
  bool _isLoading = true;
  final _inviteCodeController = TextEditingController();
  bool _isGeneratingInvite = false;

  @override
  void initState() {
    super.initState();
    _loadGroupAndMembers();
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupAndMembers() async {
    try {
      final groupService = ref.read(groupServiceProvider);
      final group = await groupService.getGroupById(widget.groupId);
      if (group != null) {
        final memberIds = group.participants;
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: memberIds)
            .get();
        final members = {
          for (var doc in usersSnapshot.docs) doc.id: doc.data(),
        };
        if (mounted) {
          setState(() {
            _group = group;
            _members = members;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load group: $e')),
        );
      }
    }
  }

  Future<void> _generateInviteLink() async {
    if (_group == null) return;

    setState(() {
      _isGeneratingInvite = true;
    });

    try {
      final groupService = ref.read(groupServiceProvider);
      final inviteCode = await groupService.generateInviteLink(widget.groupId);
      if (mounted) {
        setState(() {
          _inviteCodeController.text = inviteCode;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite link generated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate invite: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingInvite = false;
        });
      }
    }
  }

  Future<void> _addMember(String memberId) async {
    if (_group == null) return;

    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) return;

    try {
      final groupService = ref.read(groupServiceProvider);
      await groupService.addMemberToGroup(
          widget.groupId, currentUser.uid, memberId);
      await _loadGroupAndMembers(); // Refresh group data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add member: $e')),
        );
      }
    }
  }

  Future<void> _removeMember(String memberId) async {
    if (_group == null) return;

    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) return;

    try {
      final groupService = ref.read(groupServiceProvider);
      await groupService.removeMemberFromGroup(
          widget.groupId, currentUser.uid, memberId);
      await _loadGroupAndMembers(); // Refresh group data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member removed successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove member: $e')),
        );
      }
    }
  }

  Future<void> _makeAdmin(String memberId) async {
    if (_group == null) return;

    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) return;

    try {
      final groupService = ref.read(groupServiceProvider);
      await groupService.makeAdmin(widget.groupId, currentUser.uid, memberId);
      await _loadGroupAndMembers(); // Refresh group data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin privileges granted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to grant admin: $e')),
        );
      }
    }
  }

  Future<void> _removeAdmin(String adminId) async {
    if (_group == null) return;

    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) return;

    try {
      final groupService = ref.read(groupServiceProvider);
      await groupService.removeAdmin(widget.groupId, currentUser.uid, adminId);
      await _loadGroupAndMembers(); // Refresh group data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin privileges removed!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove admin: $e')),
        );
      }
    }
  }

  Future<void> _leaveGroup() async {
    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final groupService = ref.read(groupServiceProvider);
        await groupService.leaveGroup(widget.groupId, currentUser.uid);
        if (mounted) {
          Navigator.of(context).pop(); // Go back to previous screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have left the group')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to leave group: $e')),
          );
        }
      }
    }
  }

  Future<void> _updateGroupName(String name) async {
    if (_group == null || name.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({'name': name.trim()});
      setState(() {
        _group = _group!.copyWith(name: name.trim());
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group name updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update group name: $e')),
        );
      }
    }
  }

  Future<void> _updateGroupDescription(String description) async {
    if (_group == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({'description': description.trim()});
      setState(() {
        _group = _group!.copyWith(description: description.trim());
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group description updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update group description: $e')),
        );
      }
    }
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
            'Are you sure you want to delete this group? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final currentUser = ref.read(authStateProvider).value;
        if (currentUser == null) return;

        final groupService = ref.read(groupServiceProvider);
        await groupService.deleteGroup(widget.groupId, currentUser.uid);
        if (mounted) {
          Navigator.of(context).pop(); // Go back to home screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete group: $e')),
          );
        }
      }
    }
  }

  bool _isCurrentUserAdmin() {
    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null || _group == null) return false;
    return _group!.admins.contains(currentUser.uid);
  }

  bool _isCurrentUserCreator() {
    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null || _group == null) return false;
    return _group!.adminId == currentUser.uid;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).value;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group Settings')),
        body: const Center(child: Text('Group not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isProfileMode ? 'Group Profile' : 'Group Settings'),
        automaticallyImplyLeading:
            !widget.isProfileMode, // Hide back button in profile mode
        actions: [
          if (_isCurrentUserCreator() && !widget.isProfileMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteGroup,
              tooltip: 'Delete Group',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Group Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isCurrentUserCreator()) ...[
                    TextFormField(
                      initialValue: _group!.name,
                      decoration: const InputDecoration(
                        labelText: 'Group Name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        // Update group name
                        _updateGroupName(value);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _group!.description ?? '',
                      decoration: const InputDecoration(
                        labelText: 'Group Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        // Update group description
                        _updateGroupDescription(value);
                      },
                    ),
                  ] else ...[
                    Text(
                      _group!.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _group!.description?.isNotEmpty == true
                          ? _group!.description!
                          : 'No description',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${_group!.participants.length} members',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Invite Link Section
          if (_isCurrentUserAdmin())
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invite Members',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _inviteCodeController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Invite Code',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            // Copy to clipboard functionality would go here
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _isGeneratingInvite ? null : _generateInviteLink,
                        child: _isGeneratingInvite
                            ? const CircularProgressIndicator()
                            : const Text('Generate New Invite Link'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Members List
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Members',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._group!.participants.map((memberId) {
                    final isAdmin = _group!.admins.contains(memberId);
                    final isCreator = _group!.adminId == memberId;
                    final isCurrentUser = currentUser?.uid == memberId;
                    final member = _members[memberId];

                    return ListTile(
                      title: Text(member?['username'] ?? 'Unknown User'),
                      subtitle: Text(
                        isCreator
                            ? 'Creator'
                            : isAdmin
                                ? 'Admin'
                                : 'Member',
                      ),
                      trailing: _isCurrentUserAdmin() && !isCurrentUser
                          ? PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'make_admin':
                                    _makeAdmin(memberId);
                                    break;
                                  case 'remove_admin':
                                    _removeAdmin(memberId);
                                    break;
                                  case 'remove_member':
                                    _removeMember(memberId);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                if (!isAdmin && _isCurrentUserCreator())
                                  const PopupMenuItem(
                                    value: 'make_admin',
                                    child: Text('Make Admin'),
                                  ),
                                if (isAdmin &&
                                    _isCurrentUserCreator() &&
                                    !isCreator)
                                  const PopupMenuItem(
                                    value: 'remove_admin',
                                    child: Text('Remove Admin'),
                                  ),
                                if (!isCreator)
                                  const PopupMenuItem(
                                    value: 'remove_member',
                                    child: Text('Remove Member'),
                                  ),
                              ],
                            )
                          : null,
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Leave Group Button
          if (!_isCurrentUserCreator())
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _leaveGroup,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                ),
                child: const Text('Leave Group'),
              ),
            ),
        ],
      ),
    );
  }
}
