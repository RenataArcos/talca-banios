import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String targetType; // 'bathroom' | 'review'
  final String bathroomId;
  final String? reviewId;
  final String reporterId;
  final String reporterName;
  final String reason; // 'Datos incorrectos', 'Ubicación errónea', etc.
  final String details; // texto libre
  final DateTime? createdAt;
  final String status; // 'open' | 'closed' (futuro)

  ReportModel({
    required this.id,
    required this.targetType,
    required this.bathroomId,
    this.reviewId,
    required this.reporterId,
    required this.reporterName,
    required this.reason,
    required this.details,
    this.createdAt,
    this.status = 'open',
  });

  Map<String, dynamic> toMap() => {
    'targetType': targetType,
    'bathroomId': bathroomId,
    'reviewId': reviewId,
    'reporterId': reporterId,
    'reporterName': reporterName,
    'reason': reason,
    'details': details,
    'status': status,
    'createdAt': FieldValue.serverTimestamp(), // evita problemas de Timestamp
  };

  factory ReportModel.fromMap(String id, Map<String, dynamic> m) {
    final ts = m['createdAt'];
    DateTime? dt;
    if (ts is Timestamp) dt = ts.toDate();

    return ReportModel(
      id: id,
      targetType: (m['targetType'] ?? '') as String,
      bathroomId: (m['bathroomId'] ?? '') as String,
      reviewId: (m['reviewId'] ?? null) as String?,
      reporterId: (m['reporterId'] ?? '') as String,
      reporterName: (m['reporterName'] ?? '') as String,
      reason: (m['reason'] ?? '') as String,
      details: (m['details'] ?? '') as String,
      createdAt: dt,
      status: (m['status'] ?? 'open') as String,
    );
  }
}
