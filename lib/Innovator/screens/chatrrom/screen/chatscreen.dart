import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/Innovator/App_data/App_data.dart';
import 'package:http/http.dart' as http;
import 'package:innovator/Innovator/models/Chat/chat_model.dart';
import 'package:innovator/Innovator/provider/chat_state.dart';
import 'package:innovator/Innovator/provider/global_chat_listener.dart';
import 'package:innovator/Innovator/provider/unread_count_provider.dart';
import 'package:innovator/Innovator/screens/SHow_Specific_Profile/Show_Specific_Profile.dart';
import 'package:innovator/Innovator/screens/chatrrom/screen/chatlistscreen.dart';
import 'package:innovator/Innovator/screens/chatrrom/sound/soundplayer.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme constants
// ─────────────────────────────────────────────────────────────────────────────

const _kOrange = Color.fromRGBO(244, 135, 6, 1);
const _kOrangeLight = Color.fromRGBO(244, 135, 6, 0.12);
const _kBg = Color(0xFFF5F6FA);
const _kReceivedBubble = Color(0xFFFFFFFF);
const _kBaseUrl = 'ws://36.253.137.34:8005';
const _kHttpBase = 'http://36.253.137.34:8005';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// ChatState
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// ChatNotifier
// ─────────────────────────────────────────────────────────────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  final String otherUserId;
  final Ref _ref;

  ChatNotifier(this.otherUserId, this._ref) : super(const ChatState()) {
    _init();
  }

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const _maxReconnects = 5;

  String get _myId => AppData().currentUserId ?? '';
  String get _token => AppData().accessToken ?? '';

  // ── Init: load history first, then open WS ─────────────────────────────────

  Future<void> _init() async {
    await _fetchHistory();
    _connect(); // WS connects first; mark-as-read sent after connection is up
  }

  // ── REST: Chat History ─────────────────────────────────────────────────────

  Future<void> _fetchHistory() async {
    if (_token.isEmpty) return;
    state = state.copyWith(isLoadingHistory: true, error: null);

    try {
      final uri = Uri.parse('$_kHttpBase/api/chats/?with_user=$otherUserId');
      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $_token',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final list = json.decode(response.body) as List<dynamic>;
        final messages =
            list
                .whereType<Map<String, dynamic>>()
                .map((m) => ChatMessage.fromHistory(m, _myId))
                .toList();

        developer.log('[Chat] Loaded ${messages.length} history messages');
        state = state.copyWith(messages: messages, isLoadingHistory: false);
      } else {
        developer.log('[Chat] History error: ${response.statusCode}');
        state = state.copyWith(isLoadingHistory: false);
      }
    } catch (e) {
      developer.log('[Chat] fetchHistory error: $e');
      state = state.copyWith(isLoadingHistory: false);
    }
  }

  // ── REST: Mark as Read ─────────────────────────────────────────────────────

  void _markAsRead() {
    if (state.wsStatus != WsStatus.connected) return;
    try {
      _channel!.sink.add(json.encode({'type': 'mark_as_read'}));
      _ref.read(perFriendUnreadProvider.notifier).reset(otherUserId);
      developer.log('[WS] Sent mark_as_read');
    } catch (e) {
      developer.log('[WS] markAsRead error: $e');
    }
  }

  /// Called externally (e.g. when screen regains focus)
  void markAsRead() => _markAsRead();

  /// Refresh history + re-mark read (pull-to-refresh)
  Future<void> refresh() async {
    await _fetchHistory();
    _markAsRead();
  }

  // ── WebSocket ──────────────────────────────────────────────────────────────

  void _connect() {
    if (_token.isEmpty || otherUserId.isEmpty) {
      state = state.copyWith(
        wsStatus: WsStatus.error,
        error: 'Authentication required',
      );
      return;
    }

    state = state.copyWith(wsStatus: WsStatus.connecting, error: null);
    developer.log('[WS] Connecting to $otherUserId...');

    try {
      final uri = Uri.parse('$_kBaseUrl/ws/chat/$otherUserId/?token=$_token');
      _channel = IOWebSocketChannel.connect(
        uri,
        pingInterval: const Duration(seconds: 20),
      );

      state = state.copyWith(wsStatus: WsStatus.connected);
      _reconnectAttempts = 0;
      developer.log('[WS] Connected ✓');
      _markAsRead();

      _sub = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      developer.log('[WS] Connect error: $e');
      state = state.copyWith(
        wsStatus: WsStatus.error,
        error: 'Connection failed',
      );
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final data = json.decode(raw.toString()) as Map<String, dynamic>;
      developer.log('[WS] Received: $data');
      if (data['type'] == 'messages_read') {
        final senderId = data['sender_id']?.toString() ?? '';
        if (senderId == otherUserId) {
          final updated =
              state.messages.map((m) {
                if (m.isMine && m.status != MessageStatus.read) {
                  return ChatMessage(
                    id: m.id,
                    text: m.text,
                    isMine: true,
                    timestamp: m.timestamp,
                    status: MessageStatus.read,
                  );
                }
                return m;
              }).toList();
          state = state.copyWith(messages: updated);
          developer.log(
            '[WS] messages_read from $senderId — ticked all sent msgs read',
          );
        }
        return;
      }
      // Typing indicator
      if (data['type'] == 'typing') {
        state = state.copyWith(isTyping: data['is_typing'] == true);
        return;
      }

      final msgText =
          data['message']?.toString() ??
          data['content']?.toString() ??
          data['text']?.toString() ??
          '';
      if (msgText.isEmpty) return;

      final senderId =
          data['sender']?.toString() ??
          data['sender_id']?.toString() ??
          data['from']?.toString() ??
          '';
      final isMine = senderId == _myId;
      final serverId = data['id']?.toString();

      if (!isMine && senderId != otherUserId) {
        developer.log(
          '[WS] Ignored stray msg from $senderId in chat with $otherUserId',
        );
        return;
      }

      // ── Deduplicate: already in list by server id ──────────────────────
      if (serverId != null && state.messages.any((m) => m.id == serverId)) {
        return;
      }

      // ── Own message echo: replace optimistic temp bubble ───────────────
      if (isMine) {
        final tempIndex = state.messages.lastIndexWhere(
          (m) => m.isMine && m.id.startsWith('temp_') && m.text == msgText,
        );
        if (tempIndex != -1) {
          final updated = [...state.messages];
          updated[tempIndex] = ChatMessage(
            id: serverId ?? updated[tempIndex].id,
            text: msgText,
            isMine: true,
            timestamp:
                data['timestamp'] != null
                    ? DateTime.tryParse(data['timestamp'].toString()) ??
                        DateTime.now()
                    : DateTime.now(),
            status: MessageStatus.delivered,
          );
          state = state.copyWith(messages: updated, isTyping: false);
          return;
        }
      }

      // ── New incoming message ───────────────────────────────────────────
      final msg = ChatMessage.fromWs(data, _myId);
      state = state.copyWith(
        messages: [...state.messages, msg],
        isTyping: false,
      );

      if (!isMine) {
        SoundPlayer().playsendreceivesound();
        _ref.read(friendActivityProvider.notifier).markActivity(otherUserId);
        _markAsRead();
        _ref.read(mutualFriendsProvider.notifier).bumpToTop(otherUserId);
        _ref.read(lastActiveFriendProvider.notifier).state = otherUserId;
      }

      // Mark as read immediately if it's from the other person
      // if (!isMine) _markAsRead();
    } catch (e) {
      developer.log('[WS] Parse error: $e  raw=$raw');
    }
  }

  void _onError(dynamic error) {
    developer.log('[WS] Error: $error');
    state = state.copyWith(wsStatus: WsStatus.error, error: 'Connection error');
    _scheduleReconnect();
  }

  void _onDone() {
    developer.log('[WS] Connection closed');
    if (state.wsStatus == WsStatus.connected) {
      state = state.copyWith(wsStatus: WsStatus.disconnected);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnects) {
      state = state.copyWith(error: 'Could not reconnect. Pull to retry.');
      return;
    }
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);
    developer.log(
      '[WS] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)...',
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connect);
  }

  void sendMessage(String text) {
    if (text.trim().isEmpty) return;
    if (state.wsStatus != WsStatus.connected) {
      _connect();
      return;
    }

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final mine = ChatMessage(
      id: tempId,
      text: text.trim(),
      isMine: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    // Clear reply immediately so the UI snaps back
    state = state.copyWith(
      messages: [...state.messages, mine],
      isSending: true,
    );

    try {
      // ← include reply_to id in WS payload if present
      final payload = <String, dynamic>{'message': text.trim()};
      _channel!.sink.add(json.encode(payload));

      _ref.read(friendActivityProvider.notifier).markActivity(otherUserId);
      _ref.read(lastActiveFriendProvider.notifier).state = otherUserId;
      _ref.read(mutualFriendsProvider.notifier).bumpToTop(otherUserId);

      final updated =
          state.messages.map((m) {
            if (m.id == tempId) m.status = MessageStatus.sent;
            return m;
          }).toList();
      state = state.copyWith(messages: updated, isSending: false);
    } catch (e) {
      developer.log('[WS] Send error: $e');
      final updated =
          state.messages.map((m) {
            if (m.id == tempId) m.status = MessageStatus.failed;
            return m;
          }).toList();
      state = state.copyWith(messages: updated, isSending: false);
    }
  }

  void sendTyping(bool isTyping) {
    if (state.wsStatus != WsStatus.connected) return;
    try {
      _channel!.sink.add(
        json.encode({'type': 'typing', 'is_typing': isTyping}),
      );
    } catch (_) {}
  }

  Future<bool> deleteMessage({
    required String messageId,
    required String deleteType, // 'for_me' or 'for_everyone'
  }) async {
    try {
      final uri = Uri.parse('$_kHttpBase/api/chats/$messageId/delete-message/');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
            },
            body: json.encode({'delete_type': deleteType}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final updated = state.messages.where((m) => m.id != messageId).toList();
        state = state.copyWith(messages: updated);
        developer.log('[Chat] Message $messageId deleted ($deleteType)');
        return true;
      }
      developer.log('[Chat] deleteMessage failed: ${response.statusCode}');
      return false;
    } catch (e) {
      developer.log('[Chat] deleteMessage error: $e');
      return false;
    }
  }

  void reconnect() {
    _reconnectAttempts = 0;
    _connect();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

final chatProvider =
    AutoDisposeStateNotifierProviderFamily<ChatNotifier, ChatState, String>(
      (ref, otherUserId) => ChatNotifier(otherUserId, ref),
    );

// ─────────────────────────────────────────────────────────────────────────────
// ChatScreen
// ─────────────────────────────────────────────────────────────────────────────

class ChatScreen extends ConsumerStatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String otherUserAvatar;
  final bool isOnline;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserAvatar,
    this.isOnline = false,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isComposing = false;
  Timer? _typingTimer;
  late final GlobalChatListener _globalListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inputCtrl.addListener(_onInputChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      //  Store reference so dispose can use it safely
      _globalListener = ref.read(globalChatListenerProvider);
      _globalListener.activeChatUserId = widget.otherUserId;
      ref.read(activeChatUserIdProvider.notifier).state = widget.otherUserId;
    });
  }

  @override
  void dispose() {
    _globalListener.activeChatUserId = null;

    WidgetsBinding.instance.removeObserver(this);
    _inputCtrl.removeListener(_onInputChanged);
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  // Re-mark as read when app comes back to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(chatProvider(widget.otherUserId).notifier).markAsRead();
    }
  }

  void _onInputChanged() {
    final composing = _inputCtrl.text.trim().isNotEmpty;
    if (composing != _isComposing) {
      setState(() => _isComposing = composing);
    }
    ref.read(chatProvider(widget.otherUserId).notifier).sendTyping(composing);
    _typingTimer?.cancel();
    if (composing) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        ref.read(chatProvider(widget.otherUserId).notifier).sendTyping(false);
      });
    }
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollCtrl.hasClients) return;
      // Use jumpTo by default (not animated) for initial load
      if (animated) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  void _sendMessage() {
    SoundPlayer().playsendreceivesound();
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    ref.read(chatProvider(widget.otherUserId).notifier).sendMessage(text);
    _inputCtrl.clear();
    setState(() => _isComposing = false);
    _scrollToBottom();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider(widget.otherUserId));

    ref.listen<ChatState>(chatProvider(widget.otherUserId), (prev, next) {
      // New message arrived — scroll with animation
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom(animated: true);
      }

      if ((prev?.isLoadingHistory ?? false) && !next.isLoadingHistory) {
        // Double post-frame to ensure ListView is fully laid out
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_scrollCtrl.hasClients) {
              _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
            }
          });
        });
      }
    });

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(state),
      body: Column(
        children: [
          _buildStatusBanner(state),
          Expanded(child: _buildMessageList(state)),
          if (state.isTyping) _buildTypingIndicator(),
          _buildInputBar(state),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(ChatState state) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.black12,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: Colors.black87,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 0,
      title: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      SpecificUserProfilePage(userId: widget.otherUserId),
            ),
          );
        },
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [_kOrange, Color(0xFFFFCC00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: ClipOval(
                    child:
                        widget.otherUserAvatar.isNotEmpty
                            ? CachedNetworkImage(
                              imageUrl: widget.otherUserAvatar,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _avatarFallback(),
                            )
                            : _avatarFallback(),
                  ),
                ),
                if (widget.isOnline)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: -0.2,
                  ),
                ),
                _buildConnectionStatus(state),
              ],
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey.shade100),
      ),
    );
  }

  Widget _avatarFallback() {
    final initial =
        widget.otherUserName.isNotEmpty
            ? widget.otherUserName[0].toUpperCase()
            : '?';
    return Container(
      color: _kOrangeLight,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: _kOrange,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(ChatState state) {
    switch (state.wsStatus) {
      case WsStatus.connected:
        return Text(
          widget.isOnline ? 'Active now' : 'Online',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF2ECC71),
            fontWeight: FontWeight.w500,
          ),
        );
      case WsStatus.connecting:
        return const Text(
          'Connecting...',
          style: TextStyle(fontSize: 12, color: Colors.orange),
        );
      case WsStatus.disconnected:
      case WsStatus.error:
        return const Text(
          'Reconnecting...',
          style: TextStyle(fontSize: 12, color: Colors.red),
        );
    }
  }

  // ── Status banner ──────────────────────────────────────────────────────────

  Widget _buildStatusBanner(ChatState state) {
    if (state.wsStatus == WsStatus.connected) return const SizedBox.shrink();

    Color color;
    String label;
    IconData icon;
    switch (state.wsStatus) {
      case WsStatus.connecting:
        color = Colors.orange;
        label = 'Connecting...';
        icon = Icons.wifi_find_rounded;
        break;
      case WsStatus.error:
        color = Colors.red.shade600;
        label = state.error ?? 'Connection error';
        icon = Icons.wifi_off_rounded;
        break;
      default:
        color = Colors.grey.shade600;
        label = 'Disconnected';
        icon = Icons.wifi_off_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: color.withOpacity(0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (state.wsStatus == WsStatus.error)
            GestureDetector(
              onTap:
                  () =>
                      ref
                          .read(chatProvider(widget.otherUserId).notifier)
                          .reconnect(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Message list ───────────────────────────────────────────────────────────

  Widget _buildMessageList(ChatState state) {
    // Loading history skeleton
    if (state.isLoadingHistory) {
      return _buildHistorySkeleton();
    }

    if (state.messages.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh:
          () => ref.read(chatProvider(widget.otherUserId).notifier).refresh(),
      color: _kOrange,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: state.messages.length,
        itemBuilder: (context, i) {
          final msg = state.messages[i];
          final prev = i > 0 ? state.messages[i - 1] : null;
          final next =
              i < state.messages.length - 1 ? state.messages[i + 1] : null;

          final showTime =
              prev == null ||
              msg.timestamp.difference(prev.timestamp).inMinutes > 5;
          final isFirstInGroup = prev == null || prev.isMine != msg.isMine;
          final isLastInGroup = next == null || next.isMine != msg.isMine;

          return Column(
            children: [
              if (showTime) _buildTimeLabel(msg.timestamp),
              _MessageBubble(
                message: msg,
                isFirstInGroup: isFirstInGroup,
                isLastInGroup: isLastInGroup,
                otherAvatar: widget.otherUserAvatar,
                otherName: widget.otherUserName,
                onDelete:
                    (messageId, deleteType) => ref
                        .read(chatProvider(widget.otherUserId).notifier)
                        .deleteMessage(
                          messageId: messageId,
                          deleteType: deleteType,
                        ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Skeleton shimmer while history loads
  Widget _buildHistorySkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: 6,
      itemBuilder: (_, i) {
        final isMine = i % 3 != 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment:
                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMine) ...[
                _ShimmerBox(width: 30, height: 30, radius: 15),
                const SizedBox(width: 8),
              ],
              _ShimmerBox(width: isMine ? 160 : 130, height: 44, radius: 18),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: _kOrangeLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: _kOrange,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Start a conversation',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Say hi to ${widget.otherUserName}! 👋',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeLabel(DateTime dt) {
    final now = DateTime.now();
    String label;
    if (now.difference(dt).inDays == 0) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      label = '$h:$m';
    } else {
      label = '${dt.day}/${dt.month}/${dt.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // ── Typing indicator ───────────────────────────────────────────────────────

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 6),
      child: Row(
        children: [
          _MiniAvatar(
            avatar: widget.otherUserAvatar,
            name: widget.otherUserName,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  // ── Input bar ──────────────────────────────────────────────────────────────

  Widget _buildInputBar(ChatState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _kOrangeLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.attach_file_rounded,
                  color: _kOrange,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color:
                      _isComposing
                          ? _kOrange.withOpacity(0.4)
                          : Colors.grey.shade200,
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _inputCtrl,
                focusNode: _focusNode,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder:
                (child, anim) => ScaleTransition(scale: anim, child: child),
            child:
                _isComposing
                    ? GestureDetector(
                      key: const ValueKey('send'),
                      onTap: _sendMessage,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_kOrange, Color(0xFFFFAA00)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _kOrange.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    )
                    : GestureDetector(
                      key: const ValueKey('emoji'),
                      onTap: () {},
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _kOrangeLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.emoji_emotions_outlined,
                          color: _kOrange,
                          size: 22,
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ShimmerBox — lightweight skeleton without extra packages
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MessageBubble  (unchanged from original except status icon uses read colour)
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final String otherAvatar;
  final String otherName;
  final Future<bool> Function(String messageId, String deleteType) onDelete;

  const _MessageBubble({
    required this.message,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.otherAvatar,
    required this.otherName,
    required this.onDelete,
  });

  void _showMessageOptions(BuildContext context) {
    final isMine = message.isMine;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (_) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Message preview
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),

                // Delete for me (available to everyone)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Delete for me',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Only removes it from your view',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _confirmAndDelete(context, 'for_me');
                  },
                ),

                // Delete for everyone — only own messages
                if (isMine)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_forever_rounded,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Delete for everyone',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Removes it for all participants',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _confirmAndDelete(context, 'for_everyone');
                    },
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    String deleteType,
  ) async {
    final label = deleteType == 'for_everyone' ? 'everyone' : 'you';

    final confirm =
        await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Delete Message',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                content: Text(
                  'This message will be deleted for $label.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                actionsPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirm || !context.mounted) return;

    final success = await onDelete(message.id, deleteType);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to delete message'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: isFirstInGroup ? 6 : 2,
        bottom: isLastInGroup ? 2 : 1,
      ),
      child: Row(
        mainAxisAlignment:
            message.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children:
            message.isMine
                ? [
                  GestureDetector(
                    onLongPress: () => _showMessageOptions(context),
                    child: _sentBubble(),
                  ),
                  const SizedBox(width: 4),
                ]
                : [
                  const SizedBox(width: 4),
                  _receivedAvatar(),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onLongPress: () => _showMessageOptions(context),
                    child: _receivedBubble(),
                  ),
                ],
      ),
    );
  }

  Widget _receivedAvatar() {
    if (!isLastInGroup) return const SizedBox(width: 30);
    final initial = otherName.isNotEmpty ? otherName[0].toUpperCase() : '?';
    return SizedBox(
      width: 30,
      height: 30,
      child: ClipOval(
        child:
            otherAvatar.isNotEmpty
                ? CachedNetworkImage(
                  imageUrl: otherAvatar,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _fallbackAvatar(initial),
                )
                : _fallbackAvatar(initial),
      ),
    );
  }

  Widget _fallbackAvatar(String initial) => Container(
    color: _kOrangeLight,
    child: Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: _kOrange,
          fontSize: 12,
        ),
      ),
    ),
  );

  Widget _sentBubble() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kOrange, Color(0xFFFFAA00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: Radius.circular(isFirstInGroup ? 18 : 4),
            bottomLeft: const Radius.circular(18),
            bottomRight: Radius.circular(isLastInGroup ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: _kOrange.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeLabel(),
                  style: TextStyle(
                    color: Colors.white.withAlpha(75),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                _statusIcon(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _receivedBubble() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _kReceivedBubble,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isFirstInGroup ? 18 : 4),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isLastInGroup ? 4 : 18),
            bottomRight: const Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _timeLabel(),
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel() {
    final h = message.timestamp.hour.toString().padLeft(2, '0');
    final m = message.timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _statusIcon() {
    switch (message.status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.white70,
          ),
        );
      case MessageStatus.sent:
        return const Icon(Icons.check_rounded, size: 13, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(
          Icons.done_all_rounded,
          size: 13,
          color: Colors.white70,
        );
      case MessageStatus.read:
        return const Icon(
          Icons.done_all_rounded,
          size: 13,
          color: Colors.lightBlueAccent,
        );
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline_rounded,
          size: 13,
          color: Colors.redAccent,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MiniAvatar
// ─────────────────────────────────────────────────────────────────────────────

class _MiniAvatar extends StatelessWidget {
  final String avatar;
  final String name;
  const _MiniAvatar({required this.avatar, required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return SizedBox(
      width: 28,
      height: 28,
      child: ClipOval(
        child:
            avatar.isNotEmpty
                ? CachedNetworkImage(
                  imageUrl: avatar,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _fb(initial),
                )
                : _fb(initial),
      ),
    );
  }

  Widget _fb(String initial) => Container(
    color: _kOrangeLight,
    child: Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: _kOrange,
          fontSize: 11,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _TypingDots
// ─────────────────────────────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
    _anims =
        _ctrls
            .map(
              (c) => Tween<double>(
                begin: 0,
                end: -6,
              ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
            )
            .toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) _ctrls[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _anims[i],
          builder:
              (_, __) => Transform.translate(
                offset: Offset(0, _anims[i].value),
                child: Container(
                  width: 7,
                  height: 7,
                  margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
        );
      }),
    );
  }
}
