import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_routes.dart';
import '../../providers/chat_provider.dart';
import '../../services/group_service.dart';
import '../../widgets/app_page_scaffold.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _groupNameController = TextEditingController();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  final List<Map<String, dynamic>> _selectedUsers = [];
  List<Map<String, dynamic>> _recentUsers = [];

  @override
  void initState() {
    super.initState();
    _getRecentUsers();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getRecentUsers() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final chatsSnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('lastMessageAt', descending: true)
        .limit(10)
        .get();

    final uids = <String>{};
    for (final doc in chatsSnapshot.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      for (final uid in participants) {
        if (uid != currentUser.uid) uids.add(uid);
      }
    }

    if (uids.isEmpty) return;
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: uids.toList())
        .get();

    if (!mounted) return;
    setState(() {
      _recentUsers = usersSnapshot.docs
          .map((doc) => {'uid': doc.id, ...doc.data()})
          .toList();
    });
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(10)
        .get();

    if (!mounted) return;
    setState(() {
      _searchResults = usersSnapshot.docs
          .map((doc) => {'uid': doc.id, ...doc.data()})
          .toList();
    });
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty || _selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a group name and select at least one member.'),
        ),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final participantIds = [
      currentUser.uid,
      ..._selectedUsers.map((user) => user['uid'] as String),
    ];

    final groupService = ref.read(groupServiceProvider);
    final group = await groupService.createGroup(groupName, participantIds);
    if (group == null || !mounted) return;

    ref.invalidate(groupsProvider);
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.groupChat,
      arguments: {
        'groupId': group.id,
        'currentUserId': currentUser.uid,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _searchResults.isNotEmpty ? _searchResults : _recentUsers;

    return AppPageScaffold(
      appBar: AppBar(title: const Text('Create Group')),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppSectionCard(
            child: Column(
              children: [
                TextField(
                  controller: _groupNameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    prefixIcon: Icon(Icons.groups_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search users',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: _searchUsers,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Selected: ${_selectedUsers.length}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                if (_selectedUsers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _selectedUsers.map((user) {
                      return Chip(
                        label: Text(user['username']?.toString() ?? 'User'),
                        onDeleted: () {
                          setState(() {
                            _selectedUsers.removeWhere(
                              (selectedUser) =>
                                  selectedUser['uid'] == user['uid'],
                            );
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppSectionCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No users found'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final user = list[index];
                      final isSelected = _selectedUsers.any(
                        (selectedUser) => selectedUser['uid'] == user['uid'],
                      );
                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(user['username']?.toString() ?? 'Unknown'),
                        subtitle: Text(user['email']?.toString() ?? ''),
                        onChanged: (selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedUsers.add(user);
                            } else {
                              _selectedUsers.removeWhere(
                                (selectedUser) =>
                                    selectedUser['uid'] == user['uid'],
                              );
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _createGroup,
            icon: const Icon(Icons.group_add_rounded),
            label: const Text('Create Group'),
          ),
        ],
      ),
    );
  }
}
