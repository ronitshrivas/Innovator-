import 'package:flutter/material.dart';

enum MessageStatus { sending, sent, delivered, read, failed }

class ChatMessage {
  final String id;
  final String text;
  final bool isMine;
  final DateTime timestamp;
  MessageStatus status;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isMine,
    required this.timestamp,
    this.status = MessageStatus.sent,
  });

  /// Build from chat-history REST response
  factory ChatMessage.fromHistory(Map<String, dynamic> json, String myId) {
    final senderId = json['sender']?.toString() ?? '';
    final isMine = senderId == myId;
    return ChatMessage(
      id: json['id']?.toString() ?? UniqueKey().toString(),
      text: json['message']?.toString() ?? '',
      isMine: isMine,
      timestamp:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString()) ??
                  DateTime.now()
              : DateTime.now(),
      status:
          isMine
              ? (json['is_read'] == true
                  ? MessageStatus.read
                  : MessageStatus.delivered)
              : MessageStatus.delivered,
    );
  }

  /// Build from incoming WebSocket frame
  factory ChatMessage.fromWs(Map<String, dynamic> json, String myId) {
    final senderId =
        json['sender']?.toString() ??
        json['sender_id']?.toString() ??
        json['from']?.toString() ??
        '';
    final text =
        json['message']?.toString() ??
        json['content']?.toString() ??
        json['text']?.toString() ??
        '';
    return ChatMessage(
      id: json['id']?.toString() ?? UniqueKey().toString(),
      text: text,
      isMine: senderId == myId,
      timestamp:
          json['timestamp'] != null
              ? DateTime.tryParse(json['timestamp'].toString()) ??
                  DateTime.now()
              : DateTime.now(),
      status: MessageStatus.delivered,
    );
  }
}
