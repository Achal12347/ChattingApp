import 'package:shared_preferences/shared_preferences.dart';

class ChatPreferences {
  final List<String> pinnedChats;
  final List<String> archivedChats;
  final List<String> mutedChats;

  const ChatPreferences({
    this.pinnedChats = const [],
    this.archivedChats = const [],
    this.mutedChats = const [],
  });

  ChatPreferences copyWith({
    List<String>? pinnedChats,
    List<String>? archivedChats,
    List<String>? mutedChats,
  }) {
    return ChatPreferences(
      pinnedChats: pinnedChats ?? this.pinnedChats,
      archivedChats: archivedChats ?? this.archivedChats,
      mutedChats: mutedChats ?? this.mutedChats,
    );
  }
}

class ChatPreferencesService {
  static const _pinnedKey = 'chatly_pinned_chats';
  static const _archivedKey = 'chatly_archived_chats';
  static const _mutedKey = 'chatly_muted_chats';

  Future<ChatPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ChatPreferences(
      pinnedChats: prefs.getStringList(_pinnedKey) ?? const [],
      archivedChats: prefs.getStringList(_archivedKey) ?? const [],
      mutedChats: prefs.getStringList(_mutedKey) ?? const [],
    );
  }

  Future<void> save(ChatPreferences data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pinnedKey, data.pinnedChats);
    await prefs.setStringList(_archivedKey, data.archivedChats);
    await prefs.setStringList(_mutedKey, data.mutedChats);
  }
}
