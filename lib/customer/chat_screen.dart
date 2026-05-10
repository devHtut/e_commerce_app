import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../chat/chat_service.dart';
import '../theme_config.dart';
import '../widgets/custom_pop_up.dart';

class ChatScreen extends StatefulWidget {
  final String? initialChatId;

  const ChatScreen({super.key, this.initialChatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  int _selectedFilterIndex = 0;
  bool _isLoadingChats = true;
  bool _isLoadingMessages = false;
  bool _isSending = false;
  String? _errorMessage;
  ChatSummary? _activeChat;
  RealtimeChannel? _chatListChannel;
  RealtimeChannel? _messageChannel;
  List<ChatSummary> _chats = <ChatSummary>[];
  List<ChatMessage> _messages = <ChatMessage>[];

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  List<ChatSummary> get _visibleChats {
    final query = _searchController.text.trim().toLowerCase();
    return _chats.where((chat) {
      final matchesFilter =
          _selectedFilterIndex == 0 ||
          (_selectedFilterIndex == 1 && chat.isUnread) ||
          (_selectedFilterIndex == 2 && chat.isGroup);
      final matchesSearch =
          query.isEmpty ||
          chat.title.toLowerCase().contains(query) ||
          chat.lastMessage.toLowerCase().contains(query);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadChats();
    _chatListChannel = ChatService.instance.subscribeToMyChats(
      onChanged: _refreshChatsFromRealtime,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    ChatService.instance.unsubscribe(_chatListChannel);
    ChatService.instance.unsubscribe(_messageChannel);
    super.dispose();
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoadingChats = true;
      _errorMessage = null;
    });

    try {
      final chats = await ChatService.instance.loadMyChats();
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _activeChat = _syncActiveChat(chats);
      });
      await _openInitialChatIfNeeded(chats);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to load chats right now.');
    } finally {
      if (mounted) setState(() => _isLoadingChats = false);
    }
  }

  Future<void> _refreshChatsFromRealtime() async {
    try {
      final chats = await ChatService.instance.loadMyChats();
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _activeChat = _syncActiveChat(chats);
      });
    } catch (_) {
      // Keep the current UI stable if a background refresh fails.
    }
  }

  ChatSummary? _syncActiveChat(List<ChatSummary> chats) {
    final activeChat = _activeChat;
    if (activeChat == null) return null;
    for (final chat in chats) {
      if (chat.id == activeChat.id) return chat;
    }
    return null;
  }

  Future<void> _openInitialChatIfNeeded(List<ChatSummary> chats) async {
    final initialChatId = widget.initialChatId;
    if (initialChatId == null || initialChatId.isEmpty || _activeChat != null) {
      return;
    }
    for (final chat in chats) {
      if (chat.id == initialChatId) {
        await _openConversation(chat);
        return;
      }
    }
  }

  Future<void> _openConversation(ChatSummary chat) async {
    await ChatService.instance.unsubscribe(_messageChannel);
    if (!mounted) return;

    setState(() {
      _activeChat = chat;
      _isLoadingMessages = true;
      _messages = <ChatMessage>[];
    });

    _messageChannel = ChatService.instance.subscribeToChatMessages(
      chatId: chat.id,
      onChanged: _refreshMessagesFromRealtime,
    );

    await _loadMessages(chat.id);
    await ChatService.instance.markAsRead(chat.id);
    await _refreshChatsFromRealtime();
  }

  Future<void> _loadMessages(String chatId) async {
    try {
      final messages = await ChatService.instance.loadMessages(chatId);
      if (!mounted) return;
      setState(() => _messages = messages);
    } catch (_) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Messages',
        message: 'Unable to load messages right now.',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _refreshMessagesFromRealtime() async {
    final chat = _activeChat;
    if (chat == null) return;
    try {
      final messages = await ChatService.instance.loadMessages(chat.id);
      if (!mounted) return;
      setState(() => _messages = messages);
      await ChatService.instance.markAsRead(chat.id);
      await _refreshChatsFromRealtime();
    } catch (_) {
      // Realtime refresh can retry on the next event or manual reload.
    }
  }

  Future<void> _closeConversation() async {
    await ChatService.instance.unsubscribe(_messageChannel);
    _messageChannel = null;
    if (!mounted) return;
    setState(() {
      _activeChat = null;
      _messages = <ChatMessage>[];
      _messageController.clear();
    });
  }

  Future<void> _sendMessage() async {
    final chat = _activeChat;
    final text = _messageController.text.trim();
    if (chat == null || text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final sent = await ChatService.instance.sendTextMessage(
        chatId: chat.id,
        text: text,
      );
      if (!mounted) return;
      if (sent != null) {
        setState(() => _messages = [..._messages, sent]);
      }
      await ChatService.instance.markAsRead(chat.id);
      await _refreshChatsFromRealtime();
    } catch (_) {
      if (!mounted) return;
      _messageController.text = text;
      await showCustomPopup(
        context,
        title: 'Message not sent',
        message: 'Please try again in a moment.',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _showImageComingSoon() async {
    await showCustomPopup(
      context,
      title: 'Images',
      message: 'Image messages will be connected in the next step.',
      type: PopupType.success,
    );
  }

  Future<void> _showStartChatSheet() async {
    final option = await showModalBottomSheet<ChatStartOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _StartChatSheet(),
    );
    if (option == null || !mounted) return;

    setState(() => _isLoadingChats = true);
    try {
      final chat = await ChatService.instance.createOrGetDirectChat(option);
      await _refreshChatsFromRealtime();
      if (!mounted || chat == null) return;
      await _openConversation(chat);
    } catch (_) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Chat not started',
        message: 'Please try again in a moment.',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoadingChats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeChat = _activeChat;
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        leading: BackButton(
          color: AppColors.darkText,
          onPressed: activeChat == null ? null : _closeConversation,
        ),
        title: Text(
          activeChat?.title ?? 'Messages',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.darkText,
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: activeChat == null
            ? [
                IconButton(
                  onPressed: _showStartChatSheet,
                  tooltip: 'Start new chat',
                  icon: const Icon(
                    Icons.add_comment_outlined,
                    color: AppColors.darkText,
                  ),
                ),
              ]
            : [
                IconButton(
                  onPressed: () {},
                  tooltip: 'Chat info',
                  icon: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.darkText,
                  ),
                ),
              ],
      ),
      floatingActionButton: activeChat == null
          ? FloatingActionButton(
              onPressed: _showStartChatSheet,
              tooltip: 'Start new chat',
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 2,
              child: const Icon(Icons.add_comment_outlined),
            )
          : null,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: activeChat == null
            ? _buildInbox(context)
            : _buildConversation(context, activeChat),
      ),
    );
  }

  Widget _buildInbox(BuildContext context) {
    if (_isLoadingChats) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _ChatEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        message: _errorMessage!,
        action: TextButton(onPressed: _loadChats, child: const Text('Retry')),
      );
    }

    final chats = _visibleChats;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: _SearchField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ChatFilterTabs(
              selectedIndex: _selectedFilterIndex,
              onChanged: (index) =>
                  setState(() => _selectedFilterIndex = index),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadChats,
              child: chats.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.only(top: 120),
                      children: const [
                        _ChatEmptyState(
                          icon: Icons.forum_outlined,
                          message: 'No chats found.',
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                      itemCount: chats.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        return _ChatPreviewTile(
                          chat: chat,
                          onTap: () => _openConversation(chat),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversation(BuildContext context, ChatSummary chat) {
    final currentUserId = _currentUserId ?? '';
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                _ChatAvatar(chat: chat, size: 36),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Tap messages to continue the conversation',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.subtleText,
                      fontFamily: AppFonts.primary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingMessages
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? const _ChatEmptyState(
                    icon: Icons.chat_outlined,
                    message: 'No messages yet.',
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages.reversed.toList()[index];
                      return _MessageBubble(
                        message: message,
                        isMine: message.isMine(currentUserId),
                      );
                    },
                  ),
          ),
          _MessageComposer(
            controller: _messageController,
            isSending: _isSending,
            onAttachImage: _showImageComingSoon,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(
        color: AppColors.darkText,
        fontFamily: AppFonts.primary,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: 'Search...',
        hintStyle: const TextStyle(
          color: AppColors.subtleText,
          fontFamily: AppFonts.primary,
          fontSize: 14,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.subtleText,
          size: 22,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _ChatFilterTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _ChatFilterTabs({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = ['All', 'Unread', 'Groups'];
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = selectedIndex == index;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(index),
              borderRadius: BorderRadius.circular(13),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryGreen.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  labels[index],
                  style: TextStyle(
                    color: selected
                        ? AppColors.primaryGreen
                        : AppColors.subtleText,
                    fontFamily: AppFonts.primary,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ChatPreviewTile extends StatelessWidget {
  final ChatSummary chat;
  final VoidCallback onTap;

  const _ChatPreviewTile({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            _ChatAvatar(chat: chat, size: 50),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontFamily: AppFonts.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chat.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.subtleText,
                      fontFamily: AppFonts.primary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeLabel(chat.lastMessageAt),
                  style: const TextStyle(
                    color: AppColors.subtleText,
                    fontFamily: AppFonts.primary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                if (chat.unreadCount > 0)
                  Container(
                    width: 19,
                    height: 19,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      chat.unreadCount > 9 ? '9+' : '${chat.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.done_all_rounded,
                    color: AppColors.primaryGreen,
                    size: 18,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  final ChatSummary chat;
  final double size;

  const _ChatAvatar({required this.chat, required this.size});

  @override
  Widget build(BuildContext context) {
    final imageUrl = chat.imageUrl?.trim();
    return ClipOval(
      child: imageUrl == null || imageUrl.isEmpty
          ? _AvatarFallback(title: chat.title, size: size)
          : Image.network(
              imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _AvatarFallback(title: chat.title, size: size);
              },
            ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String title;
  final double size;

  const _AvatarFallback({required this.title, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: AppColors.primaryGreen.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        title.isEmpty ? '?' : title[0].toUpperCase(),
        style: const TextStyle(
          color: AppColors.primaryGreen,
          fontFamily: AppFonts.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final alignment = isMine
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final bubbleColor = isMine ? AppColors.primaryGreen : Colors.white;
    final textColor = isMine ? Colors.white : AppColors.darkText;
    final text = message.isDeleted
        ? 'This message was deleted'
        : message.text.trim().isEmpty && message.type == 'image'
        ? 'Photo'
        : message.text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.72,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: textColor,
                    fontFamily: AppFonts.primary,
                    fontSize: 14,
                    height: 1.25,
                    fontStyle: message.isDeleted
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _messageTimeLabel(message.createdAt),
            style: const TextStyle(
              color: AppColors.subtleText,
              fontFamily: AppFonts.primary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onAttachImage;
  final VoidCallback onSend;

  const _MessageComposer({
    required this.controller,
    required this.isSending,
    required this.onAttachImage,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(color: AppColors.lightGrey),
      child: Row(
        children: [
          Tooltip(
            message: 'Attach image',
            child: Material(
              color: AppColors.primaryGreen,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onAttachImage,
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.image_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(
                color: AppColors.darkText,
                fontFamily: AppFonts.primary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Type here...',
                hintStyle: const TextStyle(
                  color: AppColors.subtleText,
                  fontFamily: AppFonts.primary,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Send message',
            child: Material(
              color: AppColors.primaryGreen,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: isSending ? null : onSend,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: isSending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const _ChatEmptyState({
    required this.icon,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primaryGreen, size: 34),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.subtleText,
                fontFamily: AppFonts.primary,
                fontSize: 15,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}

class _StartChatSheet extends StatefulWidget {
  const _StartChatSheet();

  @override
  State<_StartChatSheet> createState() => _StartChatSheetState();
}

class _StartChatSheetState extends State<_StartChatSheet> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<ChatStartOption>> _optionsFuture;

  @override
  void initState() {
    super.initState();
    _optionsFuture = ChatService.instance.loadStartChatOptions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ChatStartOption> _filterOptions(List<ChatStartOption> options) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return options;
    return options.where((option) {
      return option.title.toLowerCase().contains(query) ||
          option.subtitle.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.lightGrey,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD7DCD2),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Start a Chat',
                        style: TextStyle(
                          color: AppColors.darkText,
                          fontFamily: AppFonts.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _SearchField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<ChatStartOption>>(
                  future: _optionsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return _ChatEmptyState(
                        icon: Icons.error_outline_rounded,
                        message: 'Unable to load customers right now.',
                        action: TextButton(
                          onPressed: () {
                            setState(() {
                              _optionsFuture = ChatService.instance
                                  .loadStartChatOptions();
                            });
                          },
                          child: const Text('Retry'),
                        ),
                      );
                    }

                    final options = _filterOptions(
                      snapshot.data ?? <ChatStartOption>[],
                    );
                    if (options.isEmpty) {
                      return const _ChatEmptyState(
                        icon: Icons.alternate_email_rounded,
                        message: 'No customers found.',
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
                      itemCount: options.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        return _StartChatTile(
                          option: option,
                          onTap: () => Navigator.pop(context, option),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StartChatTile extends StatelessWidget {
  final ChatStartOption option;
  final VoidCallback onTap;

  const _StartChatTile({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            ClipOval(
              child: option.imageUrl == null || option.imageUrl!.isEmpty
                  ? _StartChatAvatarFallback(title: option.title)
                  : Image.network(
                      option.imageUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _StartChatAvatarFallback(title: option.title);
                      },
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontFamily: AppFonts.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.subtleText,
                      fontFamily: AppFonts.primary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.subtleText,
            ),
          ],
        ),
      ),
    );
  }
}

class _StartChatAvatarFallback extends StatelessWidget {
  final String title;

  const _StartChatAvatarFallback({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      color: AppColors.primaryGreen.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        title.isEmpty ? '?' : title[0].toUpperCase(),
        style: const TextStyle(
          color: AppColors.primaryGreen,
          fontFamily: AppFonts.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _timeLabel(DateTime? value) {
  if (value == null) return '';
  final now = DateTime.now();
  final local = value.toLocal();
  final difference = now.difference(local);

  if (difference.inMinutes < 1) return 'Now';
  if (difference.inHours < 1) return '${difference.inMinutes} min ago';
  if (difference.inDays == 0) return _clockLabel(local);
  if (difference.inDays == 1) return 'Yesterday';
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String _messageTimeLabel(DateTime value) {
  return _clockLabel(value.toLocal());
}

String _clockLabel(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}
