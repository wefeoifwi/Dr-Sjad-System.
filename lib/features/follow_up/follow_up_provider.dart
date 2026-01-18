import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/realtime_service.dart';
import '../notifications/notifications_provider.dart';

class FollowUpProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final NotificationsProvider? notificationsProvider;
  StreamSubscription? _realtimeSubscription;
  String? _currentUserId;
  String? _currentUserRole;

  FollowUpProvider({this.notificationsProvider});

  List<Map<String, dynamic>> _followUps = [];
  List<Map<String, dynamic>> get followUps => _followUps;

  List<Map<String, dynamic>> _pendingCancellations = [];
  List<Map<String, dynamic>> get pendingCancellations => _pendingCancellations;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// تعيين المستخدم الحالي
  void setCurrentUser(String userId, String role) {
    _currentUserId = userId;
    _currentUserRole = role;
    loadFollowUps();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REALTIME SUBSCRIPTION - التحديث اللحظي
  // ═══════════════════════════════════════════════════════════════════════════
  
  void subscribeToRealtimeUpdates() {
    _realtimeSubscription?.cancel();
    
    // الاستماع لـ RealtimeService المركزي
    _realtimeSubscription = RealtimeService().followUpsStream.listen((event) {
      debugPrint('🔄 FollowUpProvider: تحديث ${event.type}');
      loadFollowUps();
      loadPendingCancellations();
    });
    
    debugPrint('✅ FollowUpProvider: متصل بـ RealtimeService');
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  /// Load follow-ups - المدير يرى الكل، الموظف يرى متابعاته فقط
  Future<void> loadFollowUps() async {
    _isLoading = true;
    notifyListeners();

    try {
      var query = _supabase
          .from('follow_ups')
          .select('*, patients(name, phone, category), profiles!follow_ups_doctor_id_fkey(name), assigned_staff:profiles!follow_ups_assigned_to_fkey(name)')
          .inFilter('status', ['pending', 'confirmed']);
      
      // الموظف يرى متابعاته فقط (إلا إذا كان مدير)
      if (_currentUserRole != 'admin' && _currentUserId != null) {
        query = query.eq('assigned_to', _currentUserId!);
      }
      
      final data = await query.order('scheduled_date', ascending: true);

      _followUps = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error loading follow-ups: $e');
      _followUps = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load pending cancellation requests for admin
  Future<void> loadPendingCancellations() async {
    try {
      final data = await _supabase
          .from('follow_ups')
          .select('*, patients(name, phone), profiles!follow_ups_created_by_fkey(name)')
          .eq('status', 'pending_cancellation')
          .order('updated_at', ascending: false);

      _pendingCancellations = List<Map<String, dynamic>>.from(data);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading pending cancellations: $e');
    }
  }

  /// Add patient to follow-up list after session
  /// يتم تعيين الموظف الذي أنشأ الحجز تلقائياً
  Future<void> addToFollowUp({
    required String patientId,
    required String doctorId,
    required DateTime scheduledDate,
    required String createdBy,
    String? assignedTo, // الموظف المعين (افتراضي = createdBy)
  }) async {
    try {
      await _supabase.from('follow_ups').insert({
        'patient_id': patientId,
        'doctor_id': doctorId,
        'scheduled_date': scheduledDate.toIso8601String().split('T')[0],
        'status': 'pending',
        'created_by': createdBy,
        'assigned_to': assignedTo ?? createdBy, // تعيين للموظف الذي أنشأ
        'assigned_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      await loadFollowUps();
    } catch (e) {
      debugPrint('Error adding to follow-up: $e');
      rethrow;
    }
  }

  /// إعادة تعيين المتابعة لموظف آخر (للمدير فقط)
  Future<void> reassignFollowUp({
    required String followUpId,
    required String newStaffId,
    required String assignedByUserId,
  }) async {
    try {
      await _supabase.from('follow_ups').update({
        'assigned_to': newStaffId,
        'assigned_by': assignedByUserId,
        'assigned_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', followUpId);

      // إشعار الموظف الجديد
      final followUp = _followUps.firstWhere((f) => f['id'] == followUpId, orElse: () => {});
      if (followUp.isNotEmpty) {
        await notificationsProvider?.notifyFollowUpAssigned(
          staffId: newStaffId,
          patientName: followUp['patients']?['name'] ?? 'مريض',
          patientPhone: followUp['patients']?['phone'] ?? '',
          followUpDate: followUp['scheduled_date'] ?? '',
        );
      }

      await loadFollowUps();
    } catch (e) {
      debugPrint('Error reassigning follow-up: $e');
      rethrow;
    }
  }


  /// Confirm follow-up and set exact time
  Future<void> confirmFollowUp({
    required String followUpId,
    required String time,
    required String patientName,
    required String doctorId,
    required String date,
  }) async {
    try {
      await _supabase.from('follow_ups').update({
        'status': 'confirmed',
        'scheduled_time': time,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', followUpId);

      // Create actual booking in sessions
      final followUp = _followUps.firstWhere((f) => f['id'] == followUpId);
      
      // Parse time (e.g., "09:00") and create start_time
      final startDateTime = DateTime.parse('$date ${time.padLeft(5, '0')}:00');
      final endDateTime = startDateTime.add(const Duration(minutes: 30));
      
      await _supabase.from('sessions').insert({
        'patient_id': followUp['patient_id'],
        'doctor_id': doctorId,
        'start_time': startDateTime.toIso8601String(),
        'end_time': endDateTime.toIso8601String(),
        'status': 'booked',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Notify doctor
      await notificationsProvider?.notifyNewBooking(
        patientName: patientName,
        doctorId: doctorId,
        date: date,
        time: time,
      );

      await loadFollowUps();
    } catch (e) {
      debugPrint('Error confirming follow-up: $e');
      rethrow;
    }
  }

  /// Postpone follow-up with new date
  Future<void> postponeFollowUp({
    required String followUpId,
    required DateTime newDate,
    required String reason,
  }) async {
    try {
      await _supabase.from('follow_ups').update({
        'scheduled_date': newDate.toIso8601String().split('T')[0],
        'status': 'pending',
        'scheduled_time': null,
        'cancellation_reason': 'تأجيل: $reason',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', followUpId);

      await loadFollowUps();
    } catch (e) {
      debugPrint('Error postponing follow-up: $e');
      rethrow;
    }
  }

  /// Request cancellation (needs admin approval)
  Future<void> requestCancellation({
    required String followUpId,
    required String reason,
    required String requestedByName,
    required String patientName,
  }) async {
    try {
      await _supabase.from('follow_ups').update({
        'status': 'pending_cancellation',
        'cancellation_reason': reason,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', followUpId);

      // Notify admins
      final adminIds = await notificationsProvider?.getAdminIds() ?? [];
      await notificationsProvider?.notifyCancellationRequest(
        patientName: patientName,
        requestedBy: requestedByName,
        reason: reason,
        adminIds: adminIds,
        referenceId: followUpId,
      );

      await loadFollowUps();
    } catch (e) {
      debugPrint('Error requesting cancellation: $e');
      rethrow;
    }
  }

  /// Admin approves cancellation
  Future<void> approveCancellation({
    required String followUpId,
    required String requestedByUserId,
    required String patientName,
  }) async {
    try {
      await _supabase.from('follow_ups').update({
        'status': 'cancelled',
        'cancellation_approved': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', followUpId);

      // Notify requester
      await notificationsProvider?.notifyCancellationResult(
        userId: requestedByUserId,
        patientName: patientName,
        approved: true,
      );

      await loadPendingCancellations();
    } catch (e) {
      debugPrint('Error approving cancellation: $e');
      rethrow;
    }
  }

  /// Admin rejects cancellation
  Future<void> rejectCancellation({
    required String followUpId,
    required String requestedByUserId,
    required String patientName,
  }) async {
    try {
      await _supabase.from('follow_ups').update({
        'status': 'pending',
        'cancellation_approved': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', followUpId);

      // Notify requester
      await notificationsProvider?.notifyCancellationResult(
        userId: requestedByUserId,
        patientName: patientName,
        approved: false,
      );

      await loadPendingCancellations();
    } catch (e) {
      debugPrint('Error rejecting cancellation: $e');
      rethrow;
    }
  }

  /// Get follow-ups due for reminder (2 days before)
  List<Map<String, dynamic>> getDueForReminder() {
    final now = DateTime.now();
    final twoDaysFromNow = now.add(const Duration(days: 2));

    return _followUps.where((f) {
      if (f['reminder_sent'] == true) return false;
      final scheduledDate = DateTime.parse(f['scheduled_date']);
      return scheduledDate.isBefore(twoDaysFromNow) && 
             scheduledDate.isAfter(now);
    }).toList();
  }

  /// Send reminder notifications
  Future<void> sendReminders() async {
    final dueFollowUps = getDueForReminder();
    final callCenterIds = await notificationsProvider?.getCallCenterIds() ?? [];

    for (final followUp in dueFollowUps) {
      final patientName = followUp['patients']?['name'] ?? 'مريض';
      final patientPhone = followUp['patients']?['phone'] ?? '';
      final date = followUp['scheduled_date'];

      await notificationsProvider?.notifyFollowUpReminder(
        patientName: patientName,
        patientPhone: patientPhone,
        date: date,
        callCenterIds: callCenterIds,
        referenceId: followUp['id'],
      );

      // Mark reminder as sent
      await _supabase.from('follow_ups').update({
        'reminder_sent': true,
      }).eq('id', followUp['id']);
    }

    await loadFollowUps();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CALL TRACKING - تتبع الاتصالات
  // ═══════════════════════════════════════════════════════════════════════════

  /// Record a call attempt with outcome and notes
  /// [outcome] can be: 'answered', 'no_answer', 'busy', 'voicemail', 'wrong_number'
  Future<void> recordCallAttempt({
    required String followUpId,
    required String outcome,
    String? notes,
  }) async {
    try {
      // Get current call attempts count
      final current = await _supabase
          .from('follow_ups')
          .select('call_attempts')
          .eq('id', followUpId)
          .single();
      
      final currentAttempts = (current['call_attempts'] ?? 0) as int;
      
      await _supabase.from('follow_ups').update({
        'call_attempts': currentAttempts + 1,
        'last_call_at': DateTime.now().toIso8601String(),
        'call_outcome': outcome,
        'call_notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', followUpId);

      await loadFollowUps();
      debugPrint('✅ تم تسجيل محاولة الاتصال: $outcome');
    } catch (e) {
      debugPrint('❌ Error recording call attempt: $e');
      rethrow;
    }
  }

  /// Get call outcome display text
  static String getCallOutcomeText(String? outcome) {
    switch (outcome) {
      case 'answered': return 'تم الرد';
      case 'no_answer': return 'لا يجيب';
      case 'busy': return 'مشغول';
      case 'voicemail': return 'بريد صوتي';
      case 'wrong_number': return 'رقم خاطئ';
      default: return 'غير معروف';
    }
  }

  /// Get call outcome color
  static int getCallOutcomeColor(String? outcome) {
    switch (outcome) {
      case 'answered': return 0xFF4CAF50; // Green
      case 'no_answer': return 0xFFFF9800; // Orange
      case 'busy': return 0xFFFF5722; // Deep Orange
      case 'voicemail': return 0xFF2196F3; // Blue
      case 'wrong_number': return 0xFFF44336; // Red
      default: return 0xFF9E9E9E; // Grey
    }
  }
}
