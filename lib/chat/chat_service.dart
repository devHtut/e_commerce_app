import 'dart:async';
import 'dart:typed_data';

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
  final DateTime? otherLastReadAt;
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
    this.otherLastReadAt,
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
      otherLastReadAt: otherLastReadAt,
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
  final DateTime? editedAt;
  final bool isDeleted;
  final List<ChatReactionSummary> reactions;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    required this.text,
    required this.createdAt,
    this.imagePath,
    this.editedAt,
    this.isDeleted = false,
    this.reactions = const <ChatReactionSummary>[],
  });

  bool isMine(String currentUserId) => senderId == currentUserId;

  factory ChatMessage.fromRow(
    Map<String, dynamic> row, {
    List<ChatReactionSummary> reactions = const <ChatReactionSummary>[],
  }) {
    final createdAtText = row['created_at']?.toString();
    final editedAtText = row['edited_at']?.toString();
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
      editedAt: editedAtText != null
          ? DateTime.parse(editedAtText).toLocal()
          : null,
      isDeleted: row['is_deleted'] as bool? ?? false,
      reactions: reactions,
    );
  }
}

class ChatReactionSummary {
  final String emoji;
  final int count;
  final bool reactedByMe;

  const ChatReactionSummary({
    required this.emoji,
    required this.count,
    required this.reactedByMe,
  });
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

  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  RealtimeChannel? _unreadCountChannel;
  Timer? _unreadCountPollTimer;
  Set<String>? _unreadChatIds;

  SupabaseClient get _client => Supabase.instance.client;

  Set<String> get _trackedUnreadChatIds {
    return _unreadChatIds ??= <String>{};
  }

  Future<List<ChatSummary>> loadMyChats() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _syncUnreadCount(const <ChatSummary>[]);
      return <ChatSummary>[];
    }

    final memberRows = await _client
        .from('chat_members')
        .select(
          'chat_id,last_read_at,chats(id,type,name,image_url,last_message_text,last_message_type,last_message_at,created_at)',
        )
        .eq('user_id', user.id);

    final rows = (memberRows as List<dynamic>).cast<Map<String, dynamic>>();
    if (rows.isEmpty) {
      _syncUnreadCount(const <ChatSummary>[]);
      return <ChatSummary>[];
    }

    final chatIds = rows
        .map((row) => row['chat_id']?.toString())
        .whereType<String>()
        .toList();

    final membersByChat = await _loadMembersByChat(chatIds);
    final profileByUser = await _loadProfiles(
      membersByChat.values
          .expand((members) => members.map((member) => member.userId))
          .toSet()
          .toList(),
    );
    final brandByOwner = await _loadBrandProfiles(
      membersByChat.values
          .expand((members) => members.map((member) => member.userId))
          .toSet()
          .toList(),
    );

    final chats = <ChatSummary>[];
    for (final row in rows) {
      final chatRow = row['chats'];
      if (chatRow is! Map<String, dynamic>) continue;

      final chatId = chatRow['id']?.toString() ?? row['chat_id']?.toString();
      if (chatId == null || chatId.isEmpty) continue;

      final memberInfos = membersByChat[chatId] ?? <_ChatMemberInfo>[];
      final memberIds = memberInfos.map((member) => member.userId).toList();
      final otherMemberIds = memberIds.where((id) => id != user.id).toList();
      final otherLastReadAt = _latestOtherReadAt(memberInfos, user.id);
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
          otherLastReadAt: otherLastReadAt,
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
    _syncUnreadCount(chats);
    return chats;
  }

  Future<void> refreshUnreadCount() async {
    final chats = await loadMyChats();
    _syncUnreadCount(chats);
  }

  void startUnreadCountSubscription() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty || _unreadCountChannel != null) {
      return;
    }

    _unreadCountChannel = _client
        .channel('chat-unread-count-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: _handleUnreadMessageChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chats',
          callback: (_) => _refreshUnreadCountSafely(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_members',
          callback: (_) => _refreshUnreadCountSafely(),
        )
        .subscribe();

    _unreadCountPollTimer?.cancel();
    _unreadCountPollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshUnreadCountSafely(),
    );
  }

  Future<void> stopUnreadCountSubscription() async {
    _unreadCountPollTimer?.cancel();
    _unreadCountPollTimer = null;
    final channel = _unreadCountChannel;
    _unreadCountChannel = null;
    await unsubscribe(channel);
  }

  Future<void> _refreshUnreadCountSafely() async {
    try {
      await refreshUnreadCount();
    } catch (_) {
      // Realtime can fire while auth/session state is changing; the next event
      // or screen refresh will reconcile the unread count.
    }
  }

  void _handleUnreadMessageChange(dynamic payload) {
    final record = payload.newRecord;
    if (record is! Map) {
      _refreshUnreadCountSafely();
      return;
    }

    final userId = _client.auth.currentUser?.id;
    final chatId = record['chat_id']?.toString();
    final senderId = record['sender_id']?.toString();
    if (userId == null ||
        chatId == null ||
        chatId.isEmpty ||
        senderId == null ||
        senderId == userId) {
      _refreshUnreadCountSafely();
      return;
    }

    final unreadChatIds = _trackedUnreadChatIds;
    if (unreadChatIds.add(chatId)) {
      unreadCountNotifier.value = unreadChatIds.length;
    }
    Future<void>.delayed(
      const Duration(milliseconds: 600),
      _refreshUnreadCountSafely,
    );
  }

  void _syncUnreadCount(List<ChatSummary> chats) {
    final unreadChatIds = _trackedUnreadChatIds;
    unreadChatIds
      ..clear()
      ..addAll(chats.where((chat) => chat.isUnread).map((chat) => chat.id));
    unreadCountNotifier.value = unreadChatIds.length;
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
          'id,chat_id,sender_id,type,text,image_path,is_deleted,created_at,edited_at',
        )
        .eq('chat_id', chatId)
        .order('created_at', ascending: true);

    final messageRows = (rows as List<dynamic>).cast<Map<String, dynamic>>();
    final messageIds = messageRows
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .toList();
    final reactionsByMessage = await _loadReactionSummaries(messageIds);

    return messageRows
        .map(
          (row) => ChatMessage.fromRow(
            row,
            reactions:
                reactionsByMessage[row['id']?.toString()] ??
                const <ChatReactionSummary>[],
          ),
        )
        .toList();
  }

  Future<void> toggleReaction({
    required String messageId,
    required String emoji,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || messageId.isEmpty || emoji.isEmpty) return;

    final existing = await _client
        .from('message_reactions')
        .select('id,emoji')
        .eq('message_id', messageId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing != null && existing['emoji']?.toString() == emoji) {
      await _client
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', user.id);
      return;
    }

    await _client.from('message_reactions').upsert({
      'message_id': messageId,
      'user_id': user.id,
      'emoji': emoji,
    }, onConflict: 'message_id,user_id');
  }

  Future<Map<String, List<ChatReactionSummary>>> _loadReactionSummaries(
    List<String> messageIds,
  ) async {
    final user = _client.auth.currentUser;
    if (messageIds.isEmpty || user == null) {
      return <String, List<ChatReactionSummary>>{};
    }

    final rows = await _client
        .from('message_reactions')
        .select('message_id,user_id,emoji')
        .inFilter('message_id', messageIds);

    final grouped = <String, Map<String, _ReactionAccumulator>>{};
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .fold<Map<String, List<ChatReactionSummary>>>(
          <String, List<ChatReactionSummary>>{},
          (summaryByMessage, row) {
            final messageId = row['message_id']?.toString();
            final emoji = row['emoji']?.toString();
            final reactionUserId = row['user_id']?.toString();
            if (messageId == null ||
                messageId.isEmpty ||
                emoji == null ||
                emoji.isEmpty) {
              return summaryByMessage;
            }

            final byEmoji = grouped.putIfAbsent(
              messageId,
              () => <String, _ReactionAccumulator>{},
            );
            final accumulator = byEmoji.putIfAbsent(
              emoji,
              () => _ReactionAccumulator(),
            );
            accumulator.count += 1;
            if (reactionUserId == user.id) {
              accumulator.reactedByMe = true;
            }

            summaryByMessage[messageId] =
                byEmoji.entries
                    .map(
                      (entry) => ChatReactionSummary(
                        emoji: entry.key,
                        count: entry.value.count,
                        reactedByMe: entry.value.reactedByMe,
                      ),
                    )
                    .toList()
                  ..sort((a, b) => b.count.compareTo(a.count));
            return summaryByMessage;
          },
        );
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
          'id,chat_id,sender_id,type,text,image_path,is_deleted,created_at,edited_at',
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

  Future<ChatMessage?> sendImageMessage({
    required String chatId,
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || chatId.isEmpty || bytes.isEmpty) return null;

    final extension = _safeFileExtension(fileName, contentType);
    final path =
        'chat images/$chatId/${DateTime.now().millisecondsSinceEpoch}_${user.id}.$extension';
    await _client.storage
        .from('media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: false, contentType: contentType),
        );

    late final Map<String, dynamic> inserted;
    try {
      inserted = await _client
          .from('messages')
          .insert({
            'chat_id': chatId,
            'sender_id': user.id,
            'type': 'image',
            'text': '',
            'image_path': path,
          })
          .select(
            'id,chat_id,sender_id,type,text,image_path,is_deleted,created_at,edited_at',
          )
          .single();
    } catch (_) {
      await _client.storage.from('media').remove([path]);
      rethrow;
    }

    await _client
        .from('chats')
        .update({
          'last_message_text': 'Sent a photo',
          'last_message_type': 'image',
          'last_message_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', chatId);

    return ChatMessage.fromRow(inserted);
  }

  String? messageImageUrl(String? imagePath) {
    final cleanPath = imagePath?.trim();
    if (cleanPath == null || cleanPath.isEmpty) return null;
    final uri = Uri.tryParse(cleanPath);
    if (uri != null && uri.hasScheme) return cleanPath;
    return _client.storage.from('media').getPublicUrl(cleanPath);
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

  Future<void> editMessage({
    required String messageId,
    required String chatId,
    required String text,
  }) async {
    final user = _client.auth.currentUser;
    final cleanText = text.trim();
    if (user == null ||
        messageId.isEmpty ||
        chatId.isEmpty ||
        cleanText.isEmpty) {
      return;
    }

    await _client
        .from('messages')
        .update({
          'text': cleanText,
          'edited_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', messageId)
        .eq('sender_id', user.id);

    await _refreshChatLastMessage(chatId);
  }

  Future<void> deleteMessage({
    required String messageId,
    required String chatId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || messageId.isEmpty || chatId.isEmpty) return;

    final messageRow = await _client
        .from('messages')
        .select('type,image_path')
        .eq('id', messageId)
        .eq('sender_id', user.id)
        .maybeSingle();

    await _client
        .from('messages')
        .update({'is_deleted': true})
        .eq('id', messageId)
        .eq('sender_id', user.id);

    final imagePath = messageRow?['image_path']?.toString().trim();
    if (messageRow?['type']?.toString() == 'image' &&
        imagePath != null &&
        imagePath.isNotEmpty &&
        Uri.tryParse(imagePath)?.hasScheme != true) {
      try {
        await _client.storage.from('media').remove([imagePath]);
      } catch (e) {
        debugPrint('Unable to delete chat image: $e');
      }
    }

    await _refreshChatLastMessage(chatId);
  }

  Future<void> deleteChat(String chatId) async {
    final user = _client.auth.currentUser;
    if (user == null || chatId.isEmpty) return;

    try {
      await _client.rpc<void>(
        'delete_chat_for_me',
        params: {'target_chat_id': chatId},
      );
      await refreshUnreadCount();
      return;
    } catch (e) {
      debugPrint('delete_chat_for_me RPC failed: $e');
    }

    final messageRows = await _client
        .from('messages')
        .select('id')
        .eq('chat_id', chatId);
    final messageIds = (messageRows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    if (messageIds.isNotEmpty) {
      await _client
          .from('message_reactions')
          .delete()
          .inFilter('message_id', messageIds);
    }

    await _client.from('messages').delete().eq('chat_id', chatId);
    await _client.from('chat_members').delete().eq('chat_id', chatId);
    await _client.from('chats').delete().eq('id', chatId);
    await refreshUnreadCount();
  }

  Future<void> _refreshChatLastMessage(String chatId) async {
    final row = await _client
        .from('messages')
        .select('text,type,is_deleted,created_at')
        .eq('chat_id', chatId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return;

    final isDeleted = row['is_deleted'] as bool? ?? false;
    final type = row['type']?.toString() ?? 'text';
    final text = isDeleted
        ? 'This message was deleted'
        : _lastMessagePreview(row['text']?.toString(), type);

    await _client
        .from('chats')
        .update({
          'last_message_text': text,
          'last_message_type': type,
          'last_message_at': row['created_at']?.toString(),
        })
        .eq('id', chatId);
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
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_reactions',
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

  Future<Map<String, List<_ChatMemberInfo>>> _loadMembersByChat(
    List<String> chatIds,
  ) async {
    if (chatIds.isEmpty) return <String, List<_ChatMemberInfo>>{};

    final rows = await _client
        .from('chat_members')
        .select('chat_id,user_id,last_read_at')
        .inFilter('chat_id', chatIds);

    final membersByChat = <String, List<_ChatMemberInfo>>{};
    for (final row in (rows as List<dynamic>).cast<Map<String, dynamic>>()) {
      final chatId = row['chat_id']?.toString();
      final userId = row['user_id']?.toString();
      if (chatId == null || userId == null) continue;
      membersByChat
          .putIfAbsent(chatId, () => <_ChatMemberInfo>[])
          .add(
            _ChatMemberInfo(
              userId: userId,
              lastReadAt: _parseDate(row['last_read_at']),
            ),
          );
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

  DateTime? _latestOtherReadAt(
    List<_ChatMemberInfo> members,
    String currentUserId,
  ) {
    DateTime? latest;
    for (final member in members) {
      if (member.userId == currentUserId || member.lastReadAt == null) {
        continue;
      }
      if (latest == null || member.lastReadAt!.isAfter(latest)) {
        latest = member.lastReadAt;
      }
    }
    return latest;
  }

  DateTime? _parseDate(dynamic value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }

  String _safeFileExtension(String fileName, String? contentType) {
    final rawExtension = fileName.split('.').last.toLowerCase();
    switch (rawExtension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
        return rawExtension == 'jpeg' ? 'jpg' : rawExtension;
    }

    switch (contentType) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      default:
        return 'jpg';
    }
  }
}

class _ChatProfile {
  final String? name;
  final String? avatarUrl;

  const _ChatProfile({this.name, this.avatarUrl});
}

class _ChatMemberInfo {
  final String userId;
  final DateTime? lastReadAt;

  const _ChatMemberInfo({required this.userId, this.lastReadAt});
}

class _ReactionAccumulator {
  int count = 0;
  bool reactedByMe = false;
}
