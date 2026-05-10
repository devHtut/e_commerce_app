import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatSummary {
  final String id;
  final String type;
  final String title;
  final String? imageUrl;
  final String lastMessage;
  final String? lastMessageType;
  final DateTime? lastMessageAt;
  final DateTime? lastReadAt;
  final bool isGroup;
  final int unreadCount;
  final List<String> memberIds;

  const ChatSummary({
    required this.id,
    required this.type,
    required this.title,
    required this.lastMessage,
    required this.memberIds,
    this.imageUrl,
    this.lastMessageType,
    this.lastMessageAt,
    this.lastReadAt,
    this.isGroup = false,
    this.unreadCount = 0,
  });

  bool get isUnread => unreadCount > 0;

  ChatSummary copyWith({int? unreadCount}) {
    return ChatSummary(
      id: id,
      type: type,
      title: title,
      imageUrl: imageUrl,
      lastMessage: lastMessage,
      lastMessageType: lastMessageType,
      lastMessageAt: lastMessageAt,
      lastReadAt: lastReadAt,
      isGroup: isGroup,
      unreadCount: unreadCount ?? this.unreadCount,
      memberIds: memberIds,
    );
  }
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String type;
  final String text;
  final String? imagePath;
  final DateTime createdAt;
  final bool isDeleted;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    required this.text,
    required this.createdAt,
    this.imagePath,
    this.isDeleted = false,
  });

  bool isMine(String currentUserId) => senderId == currentUserId;

  factory ChatMessage.fromRow(Map<String, dynamic> row) {
    final createdAtText = row['created_at']?.toString();
    return ChatMessage(
      id: row['id']?.toString() ?? '',
      chatId: row['chat_id']?.toString() ?? '',
      senderId: row['sender_id']?.toString() ?? '',
      type: row['type']?.toString() ?? 'text',
      text: row['text']?.toString() ?? '',
      imagePath: row['image_path']?.toString(),
      createdAt: createdAtText != null
          ? DateTime.parse(createdAtText).toLocal()
          : DateTime.now(),
      isDeleted: row['is_deleted'] as bool? ?? false,
    );
  }
}

class ChatStartOption {
  final String userId;
  final String title;
  final String? imageUrl;
  final String subtitle;

  const ChatStartOption({
    required this.userId,
    required this.title,
    required this.subtitle,
    this.imageUrl,
  });
}

class ChatService {
  ChatService._();

  static final ChatService instance = ChatService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<ChatSummary>> loadMyChats() async {
    final user = _client.auth.currentUser;
    if (user == null) return <ChatSummary>[];

    final memberRows = await _client
        .from('chat_members')
        .select(
          'chat_id,last_read_at,chats(id,type,name,image_url,last_message_text,last_message_type,last_message_at,created_at)',
        )
        .eq('user_id', user.id);

    final rows = (memberRows as List<dynamic>).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return <ChatSummary>[];

    final chatIds = rows
        .map((row) => row['chat_id']?.toString())
        .whereType<String>()
        .toList();

    final membersByChat = await _loadMembersByChat(chatIds);
    final profileByUser = await _loadProfiles(
      membersByChat.values.expand((ids) => ids).toSet().toList(),
    );
    final brandByOwner = await _loadBrandProfiles(
      membersByChat.values.expand((ids) => ids).toSet().toList(),
    );

    final chats = <ChatSummary>[];
    for (final row in rows) {
      final chatRow = row['chats'];
      if (chatRow is! Map<String, dynamic>) continue;

      final chatId = chatRow['id']?.toString() ?? row['chat_id']?.toString();
      if (chatId == null || chatId.isEmpty) continue;

      final memberIds = membersByChat[chatId] ?? <String>[];
      final otherMemberIds = memberIds.where((id) => id != user.id).toList();
      final type = chatRow['type']?.toString() ?? 'direct';
      final isGroup = type == 'group';
      final name = chatRow['name']?.toString().trim();
      final title = (name != null && name.isNotEmpty)
          ? name
          : _fallbackChatTitle(
              otherMemberIds: otherMemberIds,
              profileByUser: profileByUser,
              brandByOwner: brandByOwner,
              isGroup: isGroup,
            );
      final imageUrl = _chatImageUrl(
        chatImageUrl: chatRow['image_url']?.toString(),
        otherMemberIds: otherMemberIds,
        profileByUser: profileByUser,
        brandByOwner: brandByOwner,
      );
      final lastMessageAt = _parseDate(chatRow['last_message_at']);
      final lastReadAt = _parseDate(row['last_read_at']);

      chats.add(
        ChatSummary(
          id: chatId,
          type: type,
          title: title,
          imageUrl: imageUrl,
          lastMessage: _lastMessagePreview(
            chatRow['last_message_text']?.toString(),
            chatRow['last_message_type']?.toString(),
          ),
          lastMessageType: chatRow['last_message_type']?.toString(),
          lastMessageAt: lastMessageAt,
          lastReadAt: lastReadAt,
          isGroup: isGroup,
          unreadCount: _isUnread(lastMessageAt, lastReadAt) ? 1 : 0,
          memberIds: memberIds,
        ),
      );
    }

    chats.sort((a, b) {
      final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return chats;
  }

  Future<List<ChatStartOption>> loadStartChatOptions() async {
    final user = _client.auth.currentUser;
    if (user == null) return <ChatStartOption>[];

    final rows = await _client
        .from('profiles')
        .select('id,full_name,username,avatar_url')
        .neq('id', user.id)
        .not('username', 'is', null)
        .order('username', ascending: true);

    final options = <ChatStartOption>[];
    for (final row in (rows as List<dynamic>).cast<Map<String, dynamic>>()) {
      final userId = row['id']?.toString();
      final username = row['username']?.toString().trim();
      if (userId == null ||
          userId.isEmpty ||
          username == null ||
          username.isEmpty) {
        continue;
      }
      final fullName = row['full_name']?.toString().trim();
      options.add(
        ChatStartOption(
          userId: userId,
          title: fullName == null || fullName.isEmpty ? '@$username' : fullName,
          subtitle: '@$username',
          imageUrl: row['avatar_url']?.toString(),
        ),
      );
    }
    return options;
  }

  Future<ChatStartOption?> loadBrandChatOption(String? brandId) async {
    if (brandId == null || brandId.isEmpty) return null;

    final user = _client.auth.currentUser;
    if (user == null) return null;

    final row = await _client
        .from('brands')
        .select('owner_id,brand_name,logo_url')
        .eq('id', brandId)
        .maybeSingle();
    if (row == null) return null;

    final ownerId = row['owner_id']?.toString();
    if (ownerId == null || ownerId.isEmpty || ownerId == user.id) return null;

    final name = row['brand_name']?.toString().trim();
    return ChatStartOption(
      userId: ownerId,
      title: name == null || name.isEmpty ? 'Vendor' : name,
      subtitle: 'Vendor',
      imageUrl: row['logo_url']?.toString(),
    );
  }

  Future<ChatSummary?> createOrGetDirectChat(ChatStartOption option) async {
    final user = _client.auth.currentUser;
    if (user == null || option.userId.isEmpty || option.userId == user.id) {
      return null;
    }

    final chatId = await _client.rpc<String>(
      'create_or_get_direct_chat',
      params: {'other_user_id': option.userId},
    );
    if (chatId.isEmpty) return null;

    final chats = await loadMyChats();
    for (final chat in chats) {
      if (chat.id == chatId) return chat;
    }
    return ChatSummary(
      id: chatId,
      type: 'direct',
      title: option.title,
      imageUrl: option.imageUrl,
      lastMessage: 'No messages yet',
      memberIds: [user.id, option.userId],
    );
  }

  Future<List<ChatMessage>> loadMessages(String chatId) async {
    if (chatId.isEmpty) return <ChatMessage>[];

    final rows = await _client
        .from('messages')
        .select(
          'id,chat_id,sender_id,type,text,image_path,is_deleted,created_at',
        )
        .eq('chat_id', chatId)
        .order('created_at', ascending: true);

    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ChatMessage.fromRow)
        .toList();
  }

  Future<ChatMessage?> sendTextMessage({
    required String chatId,
    required String text,
  }) async {
    final user = _client.auth.currentUser;
    final cleanText = text.trim();
    if (user == null || chatId.isEmpty || cleanText.isEmpty) return null;

    final inserted = await _client
        .from('messages')
        .insert({
          'chat_id': chatId,
          'sender_id': user.id,
          'type': 'text',
          'text': cleanText,
        })
        .select(
          'id,chat_id,sender_id,type,text,image_path,is_deleted,created_at',
        )
        .single();

    await _client
        .from('chats')
        .update({
          'last_message_text': cleanText,
          'last_message_type': 'text',
          'last_message_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', chatId);

    return ChatMessage.fromRow(inserted);
  }

  Future<void> markAsRead(String chatId) async {
    final user = _client.auth.currentUser;
    if (user == null || chatId.isEmpty) return;

    await _client
        .from('chat_members')
        .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('chat_id', chatId)
        .eq('user_id', user.id);
  }

  RealtimeChannel subscribeToChatMessages({
    required String chatId,
    required VoidCallback onChanged,
  }) {
    return _client
        .channel('chat-messages-$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  RealtimeChannel subscribeToMyChats({required VoidCallback onChanged}) {
    return _client
        .channel('chat-list-${_client.auth.currentUser?.id ?? 'guest'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chats',
          callback: (_) => onChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_members',
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  Future<void> unsubscribe(RealtimeChannel? channel) async {
    if (channel == null) return;
    await _client.removeChannel(channel);
  }

  Future<Map<String, List<String>>> _loadMembersByChat(
    List<String> chatIds,
  ) async {
    if (chatIds.isEmpty) return <String, List<String>>{};

    final rows = await _client
        .from('chat_members')
        .select('chat_id,user_id')
        .inFilter('chat_id', chatIds);

    final membersByChat = <String, List<String>>{};
    for (final row in (rows as List<dynamic>).cast<Map<String, dynamic>>()) {
      final chatId = row['chat_id']?.toString();
      final userId = row['user_id']?.toString();
      if (chatId == null || userId == null) continue;
      membersByChat.putIfAbsent(chatId, () => <String>[]).add(userId);
    }
    return membersByChat;
  }

  Future<Map<String, _ChatProfile>> _loadProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return <String, _ChatProfile>{};

    final rows = await _client
        .from('profiles')
        .select('id,full_name,avatar_url')
        .inFilter('id', userIds);

    return {
      for (final row in (rows as List<dynamic>).cast<Map<String, dynamic>>())
        if (row['id'] != null)
          row['id'].toString(): _ChatProfile(
            name: row['full_name']?.toString(),
            avatarUrl: row['avatar_url']?.toString(),
          ),
    };
  }

  Future<Map<String, _ChatProfile>> _loadBrandProfiles(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return <String, _ChatProfile>{};

    final rows = await _client
        .from('brands')
        .select('owner_id,brand_name,logo_url')
        .inFilter('owner_id', userIds);

    final brandByOwner = <String, _ChatProfile>{};
    for (final row in (rows as List<dynamic>).cast<Map<String, dynamic>>()) {
      final ownerId = row['owner_id']?.toString();
      if (ownerId == null || brandByOwner.containsKey(ownerId)) continue;
      brandByOwner[ownerId] = _ChatProfile(
        name: row['brand_name']?.toString(),
        avatarUrl: row['logo_url']?.toString(),
      );
    }
    return brandByOwner;
  }

  String _fallbackChatTitle({
    required List<String> otherMemberIds,
    required Map<String, _ChatProfile> profileByUser,
    required Map<String, _ChatProfile> brandByOwner,
    required bool isGroup,
  }) {
    final names = otherMemberIds
        .map(
          (id) => (brandByOwner[id]?.name ?? profileByUser[id]?.name)?.trim(),
        )
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toList();

    if (names.isEmpty) return isGroup ? 'Group chat' : 'Chat';
    if (!isGroup) return names.first;
    if (names.length <= 2) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }

  String? _chatImageUrl({
    required String? chatImageUrl,
    required List<String> otherMemberIds,
    required Map<String, _ChatProfile> profileByUser,
    required Map<String, _ChatProfile> brandByOwner,
  }) {
    final cleanChatImage = chatImageUrl?.trim();
    if (cleanChatImage != null && cleanChatImage.isNotEmpty) {
      return cleanChatImage;
    }

    for (final userId in otherMemberIds) {
      final avatarUrl =
          (brandByOwner[userId]?.avatarUrl ?? profileByUser[userId]?.avatarUrl)
              ?.trim();
      if (avatarUrl != null && avatarUrl.isNotEmpty) return avatarUrl;
    }
    return null;
  }

  String _lastMessagePreview(String? text, String? type) {
    final cleanText = text?.trim();
    if (cleanText != null && cleanText.isNotEmpty) return cleanText;
    switch (type) {
      case 'image':
        return 'Sent a photo';
      case 'product':
        return 'Sent a product';
      case 'system':
        return 'Chat update';
      default:
        return 'No messages yet';
    }
  }

  bool _isUnread(DateTime? lastMessageAt, DateTime? lastReadAt) {
    if (lastMessageAt == null) return false;
    if (lastReadAt == null) return true;
    return lastMessageAt.isAfter(lastReadAt);
  }

  DateTime? _parseDate(dynamic value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }
}

class _ChatProfile {
  final String? name;
  final String? avatarUrl;

  const _ChatProfile({this.name, this.avatarUrl});
}
