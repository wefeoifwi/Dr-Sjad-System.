import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bot_toast/bot_toast.dart';
import 'notification_toast.dart';
import '../../core/realtime_service.dart';

class NotificationsProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  StreamSubscription? _realtimeSubscription;
  
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> get notifications => _notifications;
  
  int get unreadCount => _notifications.where((n) => n['is_read'] == false).length;
  
  String? _currentUserId;
  
  void setCurrentUser(String userId) {
    _currentUserId = userId;
    loadNotifications();
    _subscribeToRealtimeUpdates();
  }
  
  void _subscribeToRealtimeUpdates() {
    if (_currentUserId == null) return;
    
    _realtimeSubscription?.cancel();
    
    // الاستماع لـ RealtimeService المركزي
    _realtimeSubscription = RealtimeService().notificationsStream.listen((event) {
      debugPrint('🔔 NotificationsProvider: إشعار جديد!');
      loadNotifications();
      
      // Show Pop-up if new data exists
      if (event.newData != null) {
        _showNotificationPopup(event.newData!);
      }
    });
    
    debugPrint('✅ NotificationsProvider: متصل بـ RealtimeService');
  }
  
  // 1. Navigation Stream for AdminLayoutShell
  final _navigationController = StreamController<String>.broadcast();
  Stream<String> get navigationStream => _navigationController.stream;

  // 2. Show Pop-up Logic
  void _showNotificationPopup(Map<String, dynamic> notification) {
    // Only show if user is still logged in
    if (_currentUserId == null) return;
    
    // Play sound/vibrate (Optional - can be added later)
    
    BotToast.showCustomNotification(
      duration: const Duration(seconds: 5),
      toastBuilder: (cancelFunc) {
        return NotificationToast(
          title: notification['title'] ?? 'إشعار جديد',
          body: notification['message'] ?? '',
          type: notification['type'] ?? 'general',
          onDismiss: cancelFunc,
          onTap: () {
            cancelFunc(); // Close toast
            _handleNotificationTap(notification);
          },
        );
      },
    );
  }

  // 3. Handle Navigation Logic
  void _handleNotificationTap(Map<String, dynamic> notification) {
    if (notification['is_read'] == false) {
      markAsRead(notification['id']);
    }

    final type = notification['type'];
    if (type == 'cancellation_request') {
      _navigationController.add('cancellation_requests');
    } else if (type == 'follow_up_reminder') {
      _navigationController.add('follow_up');
    } else {
      // Default: Open Notifications Screen (if we had a route for it)
      // or just show details
    }
  }

  @override
  void dispose() {
    _navigationController.close();
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  // Pagination State
  bool _isLoadingMore = false;
  bool _hasMore = true;
  static const int _pageSize = 20;

  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;

  Future<void> loadNotifications() async {
    if (_currentUserId == null) return;
    
    try {
      final data = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', _currentUserId!)
          .order('created_at', ascending: false)
          .limit(_pageSize);
      
      _notifications = List<Map<String, dynamic>>.from(data);
      _hasMore = data.length == _pageSize;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      _notifications = [];
    }
  }

  Future<void> loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMore || _currentUserId == null || _notifications.isEmpty) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final lastCreatedAt = _notifications.last['created_at'];
      
      final data = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', _currentUserId!)
          .lt('created_at', lastCreatedAt) // Load older items
          .order('created_at', ascending: false)
          .limit(_pageSize);

      if (data.isNotEmpty) {
        _notifications.addAll(List<Map<String, dynamic>>.from(data));
        _hasMore = data.length == _pageSize;
      } else {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint('Error loading more notifications: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
      
      final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        _notifications[index] = {..._notifications[index], 'is_read': true};
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    if (_currentUserId == null) return;
    
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', _currentUserId!)
          .eq('is_read', false);
      
      for (int i = 0; i < _notifications.length; i++) {
        _notifications[i] = {..._notifications[i], 'is_read': true};
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);
      _notifications.removeWhere((n) => n['id'] == notificationId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  // =============== إرسال الإشعارات ===============

  /// إشعار عند حجز موعد جديد
  Future<void> notifyNewBooking({
    required String patientName,
    required String doctorId,
    required String date,
    required String time,
  }) async {
    await _sendNotification(
      userId: doctorId,
      title: 'حجز جديد',
      message: 'تم حجز موعد للمريض $patientName في $date الساعة $time',
      type: 'new_booking',
    );
  }

  /// إشعار عند وصول المريض (للطبيب)
  Future<void> notifyPatientArrived({
    required String patientName,
    required String doctorId,
  }) async {
    await _sendNotification(
      userId: doctorId,
      title: 'مريض في الانتظار',
      message: 'المريض $patientName وصل وينتظر الدخول',
      type: 'patient_arrived',
    );
  }

  /// إشعار عند إدخال المريض للجلسة (للأدمن)
  Future<void> notifySessionStarted({
    required String patientName,
    required String doctorName,
    required List<String> adminIds,
  }) async {
    for (final adminId in adminIds) {
      await _sendNotification(
        userId: adminId,
        title: 'بدء جلسة',
        message: 'المريض $patientName دخل للجلسة مع د. $doctorName',
        type: 'session_started',
      );
    }
  }

  /// إشعار عند طلب إلغاء موعد (للأدمن)
  Future<void> notifyCancellationRequest({
    required String patientName,
    required String requestedBy,
    required String reason,
    required List<String> adminIds,
    String? referenceId,
  }) async {
    for (final adminId in adminIds) {
      await _sendNotification(
        userId: adminId,
        title: 'طلب إلغاء موعد',
        message: 'طلب إلغاء من $requestedBy للمريض $patientName\nالسبب: $reason',
        type: 'cancellation_request',
        referenceId: referenceId,
      );
    }
  }

  /// إشعار بموافقة/رفض الإلغاء
  Future<void> notifyCancellationResult({
    required String userId,
    required String patientName,
    required bool approved,
  }) async {
    await _sendNotification(
      userId: userId,
      title: approved ? 'تمت الموافقة على الإلغاء' : 'تم رفض الإلغاء',
      message: approved 
          ? 'تمت الموافقة على إلغاء موعد $patientName'
          : 'تم رفض طلب إلغاء موعد $patientName - يرجى التواصل مع المريض',
      type: approved ? 'cancellation_approved' : 'cancellation_rejected',
    );
  }

  /// إشعار تذكير بموعد متابعة (قبل يومين)
  Future<void> notifyFollowUpReminder({
    required String patientName,
    required String patientPhone,
    required String date,
    required List<String> callCenterIds,
    String? referenceId,
  }) async {
    for (final userId in callCenterIds) {
      await _sendNotification(
        userId: userId,
        title: 'تذكير متابعة',
        message: 'اتصل بالمريض $patientName ($patientPhone) لتأكيد موعد $date',
        type: 'follow_up_reminder',
        referenceId: referenceId,
      );
    }
  }

  /// إشعار عام
  Future<void> sendGeneralNotification({
    required String userId,
    required String title,
    required String message,
    String priority = 'normal',
    String? category,
  }) async {
    await _sendNotification(
      userId: userId,
      title: title,
      message: message,
      type: 'general',
      priority: priority,
      category: category,
    );
  }

  /// إشعار عند تعيين الدكتور للمريض (للدكتور)
  Future<void> notifyDoctorAssigned({
    required String patientName,
    required String doctorId,
    required String departmentName,
    bool isVIP = false,
  }) async {
    await _sendNotification(
      userId: doctorId,
      title: isVIP ? '⭐ مريض VIP جاهز' : 'مريض جاهز للدخول',
      message: 'المريض $patientName من قسم $departmentName جاهز للدخول',
      type: 'doctor_assigned',
      priority: isVIP ? 'urgent' : 'high',
      category: 'session',
    );
  }

  /// إشعار للريسبشن عند انتهاء الجلسة
  Future<void> notifySessionCompleted({
    required String patientName,
    required String doctorName,
    required List<String> receptionIds,
  }) async {
    for (final userId in receptionIds) {
      await _sendNotification(
        userId: userId,
        title: 'جلسة منتهية',
        message: 'المريض $patientName انتهى من الجلسة مع د. $doctorName',
        type: 'session_completed',
        priority: 'normal',
        category: 'session',
      );
    }
  }

  /// إشعار عند انتظار طويل (للمدير)
  Future<void> notifyLongWait({
    required String patientName,
    required int waitingMinutes,
    required List<String> adminIds,
  }) async {
    for (final adminId in adminIds) {
      await _sendNotification(
        userId: adminId,
        title: '⚠️ انتظار طويل',
        message: 'المريض $patientName ينتظر منذ $waitingMinutes دقيقة!',
        type: 'long_wait',
        priority: 'high',
        category: 'alert',
      );
    }
  }

  /// إشعار وصول VIP (للجميع)
  Future<void> notifyVIPArrived({
    required String patientName,
    required List<String> staffIds,
  }) async {
    for (final userId in staffIds) {
      await _sendNotification(
        userId: userId,
        title: '⭐ VIP وصل',
        message: 'المريض VIP $patientName وصل للعيادة',
        type: 'vip_arrived',
        priority: 'urgent',
        category: 'vip',
      );
    }
  }

  /// إشعار للمتابعة - الموظف المعين
  Future<void> notifyFollowUpAssigned({
    required String staffId,
    required String patientName,
    required String patientPhone,
    required String followUpDate,
  }) async {
    await _sendNotification(
      userId: staffId,
      title: 'متابعة مطلوبة',
      message: 'اتصل بالمريض $patientName ($patientPhone) في $followUpDate',
      type: 'follow_up_assigned',
      priority: 'normal',
      category: 'follow_up',
    );
  }

  // Get reception IDs helper
  Future<List<String>> getReceptionIds() async {
    try {
      final data = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'reception');
      return List<String>.from(data.map((d) => d['id']));
    } catch (e) {
      return [];
    }
  }

  // Get all staff IDs helper
  Future<List<String>> getAllStaffIds() async {
    try {
      final data = await _supabase
          .from('profiles')
          .select('id')
          .neq('role', 'patient');
      return List<String>.from(data.map((d) => d['id']));
    } catch (e) {
      return [];
    }
  }

  // =============== Helper ===============

  Future<void> _sendNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? referenceId,
    String priority = 'normal',
    String? category,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'reference_id': referenceId,
        'is_read': false,
        'priority': priority,
        'category': category ?? 'general',
        'created_at': DateTime.now().toIso8601String(),
      });
      
      // Refresh if this is for the current user
      if (userId == _currentUserId) {
        await loadNotifications();
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  // Get admin IDs helper
  Future<List<String>> getAdminIds() async {
    try {
      final data = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'admin');
      return List<String>.from(data.map((d) => d['id']));
    } catch (e) {
      return [];
    }
  }

  // Get call center IDs helper
  Future<List<String>> getCallCenterIds() async {
    try {
      final data = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'call_center');
      return List<String>.from(data.map((d) => d['id']));
    } catch (e) {
      return [];
    }
  }
}
