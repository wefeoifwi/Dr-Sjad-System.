import 'package:flutter/material.dart';

class Doctor {
  final String id;
  final String name;
  final String departmentId;
  final Color color;

  Doctor({
    required this.id,
    required this.name,
    required this.departmentId,
    required this.color,
  });

  // Factory to create from Supabase JSON
  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id'],
      name: json['full_name'] ?? 'Unknown',
      departmentId: json['department_id'] ?? '',
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

class Booking {
  final String id;
  final String patientId; // Added
  final String patientName;
  final String doctorId;
  final DateTime startTime;
  final DateTime endTime;
  final String status; 
  final String? notes;

  Booking({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.notes,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'],
      patientId: json['patient_id'] ?? '', // Added
      patientName: json['patient']?['name'] ?? 'Guest', // Fixed key from 'patients' to 'patient' based on typical join
      doctorId: json['doctor_id'],
      startTime: DateTime.parse(json['start_time']).toLocal(),
      endTime: DateTime.parse(json['end_time']).toLocal(),
      status: json['status'],
      notes: json['notes'],
    );
  }
}
