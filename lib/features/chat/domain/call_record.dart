import '../../auth/domain/user_model.dart';

class CallRecord {
  final int id;
  final int callerId;
  final int receiverId;
  final String type; // 'audio' or 'video'
  final String status;
  final DateTime startedAt;
  final int durationSeconds;

  // Included from API relationship
  final User? caller;
  final User? receiver;

  CallRecord({
    required this.id,
    required this.callerId,
    required this.receiverId,
    required this.type,
    required this.status,
    required this.startedAt,
    required this.durationSeconds,
    this.caller,
    this.receiver,
  });

  factory CallRecord.fromJson(Map<String, dynamic> json) {
    return CallRecord(
      id: json['id'],
      callerId: json['caller_id'],
      receiverId: json['receiver_id'],
      type: json['type'] ?? 'audio',
      status: json['status'] ?? 'completed',
      startedAt: DateTime.parse(json['started_at']).toLocal(),
      durationSeconds: json['duration_seconds'] ?? 0,
      caller: json['caller'] != null ? User.fromJson(json['caller']) : null,
      receiver: json['receiver'] != null
          ? User.fromJson(json['receiver'])
          : null,
    );
  }
}
