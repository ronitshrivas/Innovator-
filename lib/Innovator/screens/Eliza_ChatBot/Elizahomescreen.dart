import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Message class remains the same
class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;
  final String? messageId;
  bool isReported;
  final String? media;

  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
    this.messageId,
    this.isReported = false,
    this.media,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'isLoading': isLoading,
    'messageId': messageId,
    'isReported': isReported,
    'media': media,
  };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    text: json['text'],
    isUser: json['isUser'],
    timestamp: DateTime.parse(json['timestamp']),
    isLoading: json['isLoading'] ?? false,
    messageId: json['messageId'],
    isReported: json['isReported'] ?? false,
    media: json['media'],
  );

  Message copyWith({
    String? text,
    bool? isUser,
    DateTime? timestamp,
    bool? isLoading,
    String? messageId,
    bool? isReported,
    String? media,
  }) {
    return Message(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
      messageId: messageId ?? this.messageId,
      isReported: isReported ?? this.isReported,
      media: media ?? this.media,
    );
  }
}

class ReportCategory {
  final String id;
  final String title;
  final String description;
  final IconData icon;

  const ReportCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class ElizaChatScreen extends StatefulWidget {
  @override
  _ElizaChatScreenState createState() => _ElizaChatScreenState();
}

class _ElizaChatScreenState extends State<ElizaChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  bool _isLoading = false;
  bool _initialLoading = true;

  // GROQ API Configuration - Use environment variable or secure storage
  static const String _groqApiKey =
      ''; // Replace with your actual API key from environment variable
  static const String _groqApiUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  // Orange color theme
  static const Color primaryOrange = Color.fromRGBO(244, 135, 6, 1);
  static const Color lightOrange = Color.fromRGBO(251, 146, 60, 1);
  static const Color darkOrange = Color.fromRGBO(194, 65, 12, 1);
  static const Color orangeAccent = Color.fromRGBO(255, 159, 28, 1);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _backgroundController;

  static const List<ReportCategory> _reportCategories = [
    ReportCategory(
      id: 'inappropriate',
      title: 'Inappropriate Content',
      description: 'Content that is offensive, vulgar, or inappropriate',
      icon: Icons.warning_amber_rounded,
    ),
    ReportCategory(
      id: 'harmful',
      title: 'Harmful Information',
      description: 'Content that could be dangerous or misleading',
      icon: Icons.dangerous_rounded,
    ),
    ReportCategory(
      id: 'hate_speech',
      title: 'Hate Speech',
      description: 'Content promoting hatred or discrimination',
      icon: Icons.block_rounded,
    ),
    ReportCategory(
      id: 'spam',
      title: 'Spam or Repetitive',
      description: 'Unwanted repetitive or spam content',
      icon: Icons.repeat_rounded,
    ),
    ReportCategory(
      id: 'misinformation',
      title: 'Misinformation',
      description: 'False or misleading information',
      icon: Icons.fact_check_rounded,
    ),
    ReportCategory(
      id: 'other',
      title: 'Other',
      description: 'Other concerns not listed above',
      icon: Icons.more_horiz_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _loadMessages();
  }

  String _generateMessageId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        math.Random().nextInt(1000).toString();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _backgroundController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _initialLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMessagesJson = prefs.getStringList('eliza_messages') ?? [];

      if (savedMessagesJson.isEmpty) {
        _addBotMessage(
          "Hello! I'm ELIZA, your personal AI assistant created by Innovator. I'm here to help you with anything you need. How can I assist you today?",
        );
      } else {
        final loadedMessages = <Message>[];

        for (final jsonStr in savedMessagesJson) {
          final Map<String, dynamic> messageMap = jsonDecode(jsonStr);

          String? mediaPath;
          if (messageMap.containsKey('media') && messageMap['media'] != null) {
            final String originalPath = messageMap['media'];
            final File mediaFile = File(originalPath);
            if (await mediaFile.exists()) {
              mediaPath = originalPath;
            }
          }

          loadedMessages.add(
            Message(
              text: messageMap['text'],
              isUser: messageMap['isUser'],
              timestamp: DateTime.parse(messageMap['timestamp']),
              isLoading: messageMap['isLoading'] ?? false,
              messageId: messageMap['messageId'],
              isReported: messageMap['isReported'] ?? false,
              media: mediaPath,
            ),
          );
        }

        setState(() {
          _messages.addAll(loadedMessages);
        });
      }
    } catch (e) {
      print('Error loading messages: $e');
      _addBotMessage(
        "Hello! I'm ELIZA, your personal AI assistant created by Innovator. I'm here to help you with anything you need. How can I assist you today?",
      );
    } finally {
      setState(() {
        _initialLoading = false;
      });
      _scrollToBottom();
      _animationController.forward();
    }
  }

  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final List<String> messagesJson =
          _messages.map((message) {
            final Map<String, dynamic> messageMap = {
              'text': message.text,
              'isUser': message.isUser,
              'timestamp': message.timestamp.toIso8601String(),
              'isLoading': message.isLoading,
              'messageId': message.messageId,
              'isReported': message.isReported,
              'media': message.media,
            };
            return jsonEncode(messageMap);
          }).toList();

      await prefs.setStringList('eliza_messages', messagesJson);
    } catch (e) {
      print('Error saving messages: $e');
    }
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add(
        Message(
          text: text,
          isUser: false,
          timestamp: DateTime.now(),
          messageId: _generateMessageId(),
        ),
      );
    });

    _saveMessages();
  }

  Future<void> _saveReportedContent(
    String messageId,
    String category,
    String? additionalInfo,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final reports = prefs.getStringList('reported_content') ?? [];
    final reportData = {
      'messageId': messageId,
      'category': category,
      'additionalInfo': additionalInfo,
      'timestamp': DateTime.now().toIso8601String(),
    };
    reports.add(jsonEncode(reportData));
    await prefs.setStringList('reported_content', reports);
  }

  Future<void> _clearMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('eliza_messages');
    setState(() {
      _messages.clear();
    });

    _addBotMessage(
      "Hello! I'm ELIZA, your personal AI assistant created by Innovator. I'm here to help you with anything you need. How can I assist you today?",
    );

    _scrollToBottom();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Chat history cleared'),
        backgroundColor: primaryOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showReportDialog(Message message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReportDialog(
          message: message,
          categories: _reportCategories,
          onReport: (category, additionalInfo) async {
            await _handleReport(message, category, additionalInfo);
          },
        );
      },
    );
  }

  Future<void> _handleReport(
    Message message,
    String category,
    String? additionalInfo,
  ) async {
    try {
      await _saveReportedContent(message.messageId!, category, additionalInfo);

      final messageIndex = _messages.indexWhere(
        (m) => m.messageId == message.messageId,
      );
      if (messageIndex != -1) {
        setState(() {
          _messages[messageIndex] = message.copyWith(isReported: true);
        });
        await _saveMessages();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Content reported successfully. Thank you for your feedback.',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  String _processElizaResponse(String response) {
    String processedResponse = response
        .replaceAllMapped(
          RegExp(r'\bGemini\b', caseSensitive: false),
          (match) => 'ELIZA',
        )
        .replaceAllMapped(
          RegExp(r'\bGoogle\b', caseSensitive: false),
          (match) => 'Innovator',
        )
        .replaceAllMapped(
          RegExp(r'\bBard\b', caseSensitive: false),
          (match) => 'ELIZA',
        )
        .replaceAllMapped(
          RegExp(r'\bGroq\b', caseSensitive: false),
          (match) => 'Innovator',
        )
        .replaceAllMapped(
          RegExp(r'\bLlama\b', caseSensitive: false),
          (match) => 'ELIZA',
        )
        .replaceAllMapped(
          RegExp(r'\bMeta\b', caseSensitive: false),
          (match) => 'Innovator',
        );

    return processedResponse;
  }

  void _sendTextMessage() {
    if (_controller.text.trim().isEmpty || _isLoading) return;

    final messageText = _controller.text.trim();
    final message = Message(
      text: messageText,
      isUser: true,
      timestamp: DateTime.now(),
      messageId: _generateMessageId(),
    );

    setState(() {
      _messages.add(message);
      _isLoading = true;
    });

    _saveMessages();
    _controller.clear();
    _scrollToBottom();
    _generateGroqResponse(messageText);
  }

  Future<void> _sendMediaMessage() async {
    if (_isLoading) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Image analysis is not supported with the current Groq model. Text-only mode available.',
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _generateGroqResponse(String question) async {
    try {
      final response = await http
          .post(
            Uri.parse(_groqApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_groqApiKey',
            },
            body: jsonEncode({
              'model': 'llama-3.1-8b-instant',
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are ELIZA, an AI assistant created by Innovator. Always respond as ELIZA and never mention Groq, Llama, Meta, Google, Gemini, or any other AI system. You are helpful, friendly, and professional.',
                },
                {'role': 'user', 'content': question},
              ],
              'temperature': 0.7,
              'max_tokens': 1024,
              'top_p': 1,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botReply = data['choices'][0]['message']['content'];

        setState(() {
          _isLoading = false;
          _addBotMessage(_processElizaResponse(botReply));
        });

        _animationController.reset();
        _animationController.forward();
        _scrollToBottom();
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error generating response: $e');
      setState(() {
        _isLoading = false;
        _addBotMessage(
          "Sorry, I encountered an error. Please check your internet connection and try again.",
        );
      });
      _animationController.reset();
      _animationController.forward();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final timeFormat =
        timestamp.hour > 12
            ? '${timestamp.hour - 12}:${timestamp.minute.toString().padLeft(2, '0')} PM'
            : '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')} AM';

    if (date == today) {
      return timeFormat;
    } else {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year} $timeFormat';
    }
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(width: 52),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const SizedBox(
              width: 40,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(primaryOrange),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: ThemeData(
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        primaryColor: primaryOrange,
        scaffoldBackgroundColor:
            isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        cardColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 16),
          bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 14),
        ),
      ),
      child: Scaffold(
        body:
            _initialLoading
                ? Center(child: CircularProgressIndicator(color: primaryOrange))
                : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors:
                          isDarkMode
                              ? [
                                const Color(0xFF0F172A),
                                const Color(0xFF1E293B),
                                const Color(0xFF334155),
                              ]
                              : [
                                const Color(0xFFF8FAFC),
                                const Color(0xFFE2E8F0),
                                const Color(0xFFCBD5E1),
                              ],
                    ),
                  ),
                  child: AnimatedBuilder(
                    animation: _backgroundController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: BackgroundPainter(
                          _backgroundController.value,
                          isDarkMode,
                        ),
                        child: Column(
                          children: [
                            _buildAppBar(isDarkMode),
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isDarkMode
                                          ? const Color(
                                            0xFF1E293B,
                                          ).withOpacity(0.7)
                                          : Colors.white.withOpacity(0.7),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, -5),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  ),
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.all(16),
                                    itemCount:
                                        _messages.length + (_isLoading ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (index == _messages.length &&
                                          _isLoading) {
                                        return _buildLoadingIndicator();
                                      }
                                      final message = _messages[index];
                                      return FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: _buildMessageBubble(
                                          message,
                                          index,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            _buildInputArea(),
                          ],
                        ),
                      );
                    },
                  ),
                ),
      ),
    );
  }

  Widget _buildAppBar(bool isDarkMode) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryOrange, lightOrange, orangeAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryOrange.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(Icons.psychology_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ELIZA Assistant',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    //fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your Innovator AI Companion',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    //fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.cleaning_services_rounded,
                color: Colors.white,
              ),
              onPressed: _clearMessages,
              tooltip: 'Clear Chat History',
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Reply copied to clipboard'),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildMessageBubble(Message message, int index) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryOrange, lightOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryOrange.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  message.isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient:
                        message.isUser
                            ? LinearGradient(
                              colors: [primaryOrange, lightOrange],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                            : null,
                    color:
                        message.isUser
                            ? null
                            : message.isReported
                            ? (isDarkMode
                                ? const Color(0xFF7F1D1D)
                                : const Color(0xFFFEE2E2))
                            : (isDarkMode
                                ? const Color(0xFF334155)
                                : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(24).copyWith(
                      bottomLeft:
                          message.isUser
                              ? const Radius.circular(24)
                              : const Radius.circular(6),
                      bottomRight:
                          message.isUser
                              ? const Radius.circular(6)
                              : const Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border:
                        message.isReported
                            ? Border.all(
                              color: Colors.red.withOpacity(0.3),
                              width: 1,
                            )
                            : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.isReported) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.flag_rounded,
                              size: 16,
                              color: Colors.red.withOpacity(0.8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Content Reported',
                              style: TextStyle(
                                color: Colors.red.withOpacity(0.8),
                                fontSize: 12,
                                //fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (message.media != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(message.media!),
                              width: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 200,
                                  height: 100,
                                  color: Colors.grey.shade300,
                                  child: const Center(
                                    child: Text("Image not available"),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      SelectableText(
                        message.text,
                        style: TextStyle(
                          color:
                              message.isUser
                                  ? Colors.white
                                  : isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                          fontSize: 16,
                          fontFamily: 'Inter Thin',
                          //fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color:
                              message.isUser
                                  ? const Color.fromARGB(
                                    255,
                                    17,
                                    16,
                                    16,
                                  ).withOpacity(0.7)
                                  : isDarkMode
                                  ? Colors.grey[400]
                                  : const Color(0xFF64748B),
                          fontSize: 12,
                          fontFamily: 'Inter Thin',
                          //fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!message.isUser) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _copyToClipboard(message.text),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isDarkMode
                                      ? const Color(0xFF475569).withOpacity(0.7)
                                      : const Color(
                                        0xFFE2E8F0,
                                      ).withOpacity(0.8),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    isDarkMode
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.black.withOpacity(0.1),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 14,
                                  color:
                                      isDarkMode
                                          ? Colors.white70
                                          : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Copy',
                                  style: TextStyle(
                                    color:
                                        isDarkMode
                                            ? Colors.white70
                                            : const Color(0xFF64748B),
                                    fontSize: 12,
                                    fontFamily: 'Inter Thin',
                                    //fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap:
                              message.isReported
                                  ? null
                                  : () => _showReportDialog(message),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  message.isReported
                                      ? Colors.red.withOpacity(0.1)
                                      : (isDarkMode
                                          ? const Color(
                                            0xFF475569,
                                          ).withOpacity(0.7)
                                          : const Color(
                                            0xFFE2E8F0,
                                          ).withOpacity(0.8)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    message.isReported
                                        ? Colors.red.withOpacity(0.3)
                                        : (isDarkMode
                                            ? Colors.white.withOpacity(0.1)
                                            : Colors.black.withOpacity(0.1)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  message.isReported
                                      ? Icons.flag_rounded
                                      : Icons.flag_outlined,
                                  size: 14,
                                  color:
                                      message.isReported
                                          ? Colors.red
                                          : (isDarkMode
                                              ? Colors.white70
                                              : const Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  message.isReported ? 'Reported' : 'Report',
                                  style: TextStyle(
                                    color:
                                        message.isReported
                                            ? Colors.red
                                            : (isDarkMode
                                                ? Colors.white70
                                                : const Color(0xFF64748B)),
                                    fontSize: 12,
                                    fontFamily: 'Inter Thin',
                                    //fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryOrange,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryOrange.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _isLoading ? null : _sendMediaMessage,
            icon: Icon(
              Icons.image,
              color: _isLoading ? Colors.grey : primaryOrange,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: 4,
              minLines: 1,
              enabled: !_isLoading,
              style: TextStyle(
                color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                fontFamily: 'Inter Thin',
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText:
                    _isLoading
                        ? 'Waiting for response...'
                        : 'Type your message...',
                hintStyle: TextStyle(
                  color:
                      isDarkMode ? Colors.grey[300] : const Color(0xFF94A3B8),
                  fontFamily: 'Inter Thin',
                ),
                filled: true,
                fillColor:
                    _isLoading
                        ? Colors.grey.shade200
                        : (isDarkMode
                            ? const Color(0xFF334155).withOpacity(0.7)
                            : const Color(0xFFF1F5F9)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              onSubmitted: (_) => _isLoading ? null : _sendTextMessage(),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryOrange, lightOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: _isLoading ? null : _sendTextMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class ReportDialog extends StatefulWidget {
  final Message message;
  final List<ReportCategory> categories;
  final Function(String, String?) onReport;

  const ReportDialog({
    required this.message,
    required this.categories,
    required this.onReport,
  });

  @override
  _ReportDialogState createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String? _selectedCategory;
  final TextEditingController _additionalInfoController =
      TextEditingController();

  @override
  void dispose() {
    _additionalInfoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Report Content',
        style: TextStyle(
          color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
          fontFamily: 'Inter Thin',
          //fontWeight: FontWeight.w400,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please select a reason for reporting this content:',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : const Color(0xFF64748B),
                fontFamily: 'Inter Thin',
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ...widget.categories.map((category) {
              return RadioListTile<String>(
                title: Row(
                  children: [
                    Icon(
                      category.icon,
                      size: 20,
                      color:
                          isDarkMode
                              ? Colors.white70
                              : _ElizaChatScreenState.primaryOrange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        category.title,
                        style: TextStyle(
                          color:
                              isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                          fontFamily: 'Inter Thin',
                          //fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  category.description,
                  style: TextStyle(
                    color:
                        isDarkMode ? Colors.white70 : const Color(0xFF64748B),
                    fontFamily: 'Inter Thin',
                    fontSize: 12,
                  ),
                ),
                value: category.id,
                groupValue: _selectedCategory,
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
                activeColor: _ElizaChatScreenState.primaryOrange,
              );
            }).toList(),
            const SizedBox(height: 16),
            TextField(
              controller: _additionalInfoController,
              maxLines: 3,
              style: TextStyle(
                color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                fontFamily: 'Inter Thin',
              ),
              decoration: InputDecoration(
                hintText: 'Additional details (optional)',
                hintStyle: TextStyle(
                  color:
                      isDarkMode ? Colors.grey[500] : const Color(0xFF94A3B8),
                  fontFamily: 'Inter Thin',
                ),
                filled: true,
                fillColor:
                    isDarkMode
                        ? const Color(0xFF334155).withOpacity(0.7)
                        : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : const Color(0xFF64748B),
              fontFamily: 'Inter Thin',
            ),
          ),
        ),
        ElevatedButton(
          onPressed:
              _selectedCategory == null
                  ? null
                  : () {
                    widget.onReport(
                      _selectedCategory!,
                      _additionalInfoController.text.isEmpty
                          ? null
                          : _additionalInfoController.text,
                    );
                    Navigator.pop(context);
                  },
          style: ElevatedButton.styleFrom(
            backgroundColor: _ElizaChatScreenState.primaryOrange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Submit Report',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Inter Thin',
              //fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class BackgroundPainter extends CustomPainter {
  final double animationValue;
  final bool isDarkMode;

  BackgroundPainter(this.animationValue, this.isDarkMode);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..shader = LinearGradient(
            colors:
                isDarkMode
                    ? [
                      const Color(0xFF0F172A).withOpacity(0.2),
                      const Color(0xFF1E293B).withOpacity(0.2),
                      _ElizaChatScreenState.primaryOrange.withOpacity(0.1),
                    ]
                    : [
                      const Color(0xFFF8FAFC).withOpacity(0.2),
                      const Color(0xFFE2E8F0).withOpacity(0.2),
                      const Color(0xFFCBD5E1).withOpacity(0.1),
                    ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            transform: GradientRotation(animationValue * 2 * math.pi),
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    final circlePaint =
        Paint()
          ..color =
              isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : _ElizaChatScreenState.primaryOrange.withOpacity(0.05)
          ..style = PaintingStyle.fill;

    for (int i = 0; i < 3; i++) {
      final offset = Offset(
        size.width *
            (0.2 + 0.3 * i + math.sin(animationValue * 2 * math.pi + i) * 0.1),
        size.height *
            (0.3 + 0.2 * i + math.cos(animationValue * 2 * math.pi + i) * 0.1),
      );
      canvas.drawCircle(offset, 50.0 + 20.0 * i, circlePaint);
    }
  }

  @override
  bool shouldRepaint(BackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}
