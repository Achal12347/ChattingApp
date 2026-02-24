import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../app_routes.dart';
import '../../services/group_service.dart';
import '../../providers/chat_provider.dart';

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
        if (uid != currentUser.uid) {
          uids.add(uid);
        }
      }
    }

    if (uids.isNotEmpty) {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: uids.toList())
          .get();

      setState(() {
        _recentUsers = usersSnapshot.docs
            .map((doc) => {'uid': doc.id, ...doc.data()})
            .toList();
      });
    }
  }

  void _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(10)
        .get();

    setState(() {
      _searchResults = usersSnapshot.docs
          .map((doc) => {'uid': doc.id, ...doc.data()})
          .toList();
    });
  }

  void _createGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty || _selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Group name must not be empty and at least 1 user must be selected.')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Add creator to participants
    final participantIds = [
      currentUser.uid,
      ..._selectedUsers.map((user) => user['uid'] as String)
    ];

    final groupService = ref.read(groupServiceProvider);
    final group = await groupService.createGroup(groupName, participantIds);

    if (group != null) {
      ref.invalidate(groupsProvider); // Refresh groups list
      Navigator.pushReplacementNamed(context, AppRoutes.groupChat, arguments: {
        'groupId': group.id,
        'currentUserId': currentUser.uid,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _groupNameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Users',
              ),
              onChanged: _searchUsers,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.isNotEmpty
                    ? _searchResults.length
                    : _recentUsers.length,
                itemBuilder: (context, index) {
                  final user = _searchResults.isNotEmpty
                      ? _searchResults[index]
                      : _recentUsers[index];
                  final isSelected = _selectedUsers.any(
                      (selectedUser) => selectedUser['uid'] == user['uid']);

                  return CheckboxListTile(
                    title: Text(user['username'] ?? 'Unknown'),
                    subtitle: Text(user['email'] ?? ''),
                    value: isSelected,
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedUsers.add(user);
                        } else {
                          _selectedUsers.removeWhere((selectedUser) =>
                              selectedUser['uid'] == user['uid']);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _createGroup,
              child: const Text('Create Group'),
            ),
          ],
        ),
      ),
    );
  }
}
