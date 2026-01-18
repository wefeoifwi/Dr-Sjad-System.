import 'package:flutter/material.dart';

// =====================================================
// تصنيف الزبائن
// =====================================================
enum PatientCategory {
  vip,      // أكثر من 5 زيارات
  regular,  // 2-4 زيارات
  newPatient, // زيارة واحدة أو جديد
  blacklist,  // محظور
}

extension PatientCategoryExt on PatientCategory {
  String get label {
    switch (this) {
      case PatientCategory.vip: return 'VIP';
      case PatientCategory.regular: return 'عادي';
      case PatientCategory.newPatient: return 'جديد';
      case PatientCategory.blacklist: return 'محظور';
    }
  }
  
  Color get color {
    switch (this) {
      case PatientCategory.vip: return Colors.amber;
      case PatientCategory.regular: return Colors.teal;
      case PatientCategory.newPatient: return Colors.blue;
      case PatientCategory.blacklist: return Colors.red;
    }
  }
  
  IconData get icon {
    switch (this) {
      case PatientCategory.vip: return Icons.star;
      case PatientCategory.regular: return Icons.person;
      case PatientCategory.newPatient: return Icons.person_add;
      case PatientCategory.blacklist: return Icons.block;
    }
  }
  
  static PatientCategory fromString(String? value) {
    switch (value) {
      case 'vip': return PatientCategory.vip;
      case 'regular': return PatientCategory.regular;
      case 'blacklist': return PatientCategory.blacklist;
      default: return PatientCategory.newPatient;
    }
  }
}

// =====================================================
// نموذج الدكتور
// =====================================================
class Doctor {
  final String id;
  final String name;
  final String departmentId;
  final String? departmentName;
  final Color color;

  Doctor({
    required this.id,
    required this.name,
    required this.departmentId,
    this.departmentName,
    required this.color,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id'],
      name: json['full_name'] ?? 'Unknown',
      departmentId: json['department_id'] ?? '',
      departmentName: json['departments']?['name'],
      color: _parseColor(json['color_code']),
    );
  }

  static Color _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Colors.blue;
    try {
      return Color(int.parse(hexString.replaceAll('#', '0xFF')));
    } catch (_) {
      return Colors.blue;
    }
  }
}

// =====================================================
// نموذج القسم
// =====================================================
class Department {
  final String id;
  final String name;
  final Color color;
  
  Department({
    required this.id,
    required this.name,
    this.color = Colors.blue,
  });
  
  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'],
      name: json['name'] ?? 'Unknown',
      color: _parseColor(json['color_code']),
    );
  }
  
  static Color _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Colors.blue;
    try {
      return Color(int.parse(hexString.replaceAll('#', '0xFF')));
    } catch (_) {
      return Colors.blue;
    }
  }
}

// =====================================================
// نموذج الحجز (محدث)
// =====================================================
class Booking {
  final String id;
  final String patientId;
  final String patientName;
  final String? patientCategory; // تصنيف الزبون
  final String? doctorId; // قد يكون null عند الحجز الأولي
  final String? doctorName;
  final String? departmentId; // القسم (جديد)
  final String? departmentName;
  final String? assignedDoctorId; // الدكتور المعين عند الدفع
  final String? assignedDoctorName;
  final DateTime startTime;
  final DateTime endTime;
  final String status; 
  final String? notes;
  final String serviceType;
  final DateTime? sessionStartTime;
  final DateTime? sessionEndTime;
  final DateTime? paymentTime; // وقت الدفع (جديد)
  final DateTime? assignedAt; // وقت تعيين الدكتور
  final String? createdById;
  final String? createdByName;

  Booking({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.patientCategory,
    this.doctorId,
    this.doctorName,
    this.departmentId,
    this.departmentName,
    this.assignedDoctorId,
    this.assignedDoctorName,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.notes,
    this.serviceType = 'General',
    this.sessionStartTime,
    this.sessionEndTime,
    this.paymentTime,
    this.assignedAt,
    this.createdById,
    this.createdByName,
  });

  /// حساب وقت الانتظار (من الدفع إلى بدء الجلسة)
  int? get waitingTimeMinutes {
    if (paymentTime == null) return null;
    final end = sessionStartTime ?? DateTime.now();
    return end.difference(paymentTime!).inMinutes;
  }

  /// تنسيق وقت الانتظار
  String get waitingTimeText {
    final minutes = waitingTimeMinutes;
    if (minutes == null) return '-';
    if (minutes < 0) return '0 دقيقة';
    if (minutes < 60) return '$minutes دقيقة';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '$hours ساعة و $remainingMinutes دقيقة';
  }

  /// هل الانتظار طويل (أكثر من 15 دقيقة)؟
  bool get isLongWait => (waitingTimeMinutes ?? 0) > 15;

  /// حساب مدة الجلسة
  int? get sessionDurationMinutes {
    if (sessionStartTime == null) return null;
    final end = sessionEndTime ?? DateTime.now();
    return end.difference(sessionStartTime!).inMinutes;
  }

  /// تنسيق مدة الجلسة
  String get sessionDurationText {
    final minutes = sessionDurationMinutes;
    if (minutes == null) return '-';
    if (minutes < 60) return '$minutes دقيقة';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '$hours ساعة و $remainingMinutes دقيقة';
  }

  /// الدكتور الفعلي (المعين أو الأصلي)
  String? get effectiveDoctorId => assignedDoctorId ?? doctorId;
  String? get effectiveDoctorName => assignedDoctorName ?? doctorName;

  /// هل الدكتور معين؟
  bool get hasDoctorAssigned => assignedDoctorId != null || doctorId != null;

  /// تصنيف الزبون كـ enum
  PatientCategory get categoryEnum => PatientCategoryExt.fromString(patientCategory);

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'],
      patientId: json['patient_id'] ?? '',
      patientName: json['patient']?['name'] ?? json['patients']?['name'] ?? 'Guest',
      patientCategory: json['patient']?['category'] ?? json['patients']?['category'],
      doctorId: json['doctor_id'],
      doctorName: json['doctor']?['name'] ?? json['profiles']?['full_name'],
      departmentId: json['department_id'],
      departmentName: json['departments']?['name'],
      assignedDoctorId: json['assigned_doctor_id'],
      assignedDoctorName: json['assigned_doctor']?['full_name'],
      startTime: DateTime.parse(json['start_time']).toLocal(),
      endTime: DateTime.parse(json['end_time']).toLocal(),
      status: json['status'],
      notes: json['notes'],
      serviceType: json['service_type'] ?? 'General',
      sessionStartTime: json['session_start_time'] != null 
          ? DateTime.parse(json['session_start_time']).toLocal() 
          : null,
      sessionEndTime: json['session_end_time'] != null 
          ? DateTime.parse(json['session_end_time']).toLocal() 
          : null,
      paymentTime: json['payment_time'] != null 
          ? DateTime.parse(json['payment_time']).toLocal() 
          : null,
      assignedAt: json['assigned_at'] != null 
          ? DateTime.parse(json['assigned_at']).toLocal() 
          : null,
      createdById: json['created_by'],
      createdByName: json['creator']?['full_name'],
    );
  }
}
