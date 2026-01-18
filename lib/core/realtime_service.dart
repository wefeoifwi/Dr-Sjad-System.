import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// خدمة Realtime مركزية - تدير جميع الاتصالات اللحظية
class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  final _supabase = Supabase.instance.client;
  
  // Channels
  RealtimeChannel? _sessionsChannel;
  RealtimeChannel? _notificationsChannel;
  RealtimeChannel? _followUpsChannel;
  
  // Stream Controllers
  final _sessionsController = StreamController<RealtimeEvent>.broadcast();
  final _notificationsController = StreamController<RealtimeEvent>.broadcast();
  final _followUpsController = StreamController<RealtimeEvent>.broadcast();
  
  // Streams العامة
  Stream<RealtimeEvent> get sessionsStream => _sessionsController.stream;
  Stream<RealtimeEvent> get notificationsStream => _notificationsController.stream;
  Stream<RealtimeEvent> get followUpsStream => _followUpsController.stream;
  
  String? _currentUserId;
  bool _isConnected = false;
  
  /// تهيئة الخدمة عند تسجيل الدخول
  void initialize(String userId) {
    if (_isConnected && _currentUserId == userId) return;
    
    _currentUserId = userId;
    _disconnect(); // قطع أي اتصال قديم
    _connect();
  }
  
  /// الاتصال بجميع القنوات
  void _connect() {
    if (_currentUserId == null) return;
    
    debugPrint('🔌 RealtimeService: جاري الاتصال...');
    
    // 1. قناة الجلسات (sessions)
    _sessionsChannel = _supabase
        .channel('global_sessions_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sessions',
          callback: (payload) {
            debugPrint('📨 Session Event: ${payload.eventType}');
            _sessionsController.add(RealtimeEvent(
              type: payload.eventType.name,
              table: 'sessions',
              newData: payload.newRecord,
              oldData: payload.oldRecord,
            ));
          },
        )
        .subscribe((status, error) {
          debugPrint('📡 Sessions Channel: $status');
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ Sessions متصل!');
          }
        });
    
    // 2. قناة الإشعارات (notifications) - مفلترة للمستخدم الحالي
    _notificationsChannel = _supabase
        .channel('user_notifications_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _currentUserId!,
          ),
          callback: (payload) {
            debugPrint('🔔 New Notification!');
            _notificationsController.add(RealtimeEvent(
              type: 'insert',
              table: 'notifications',
              newData: payload.newRecord,
            ));
          },
        )
        .subscribe((status, error) {
          debugPrint('📡 Notifications Channel: $status');
        });
    
    // 3. قناة المتابعات (follow_ups)
    _followUpsChannel = _supabase
        .channel('global_followups_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'follow_ups',
          callback: (payload) {
            debugPrint('📋 FollowUp Event: ${payload.eventType}');
            _followUpsController.add(RealtimeEvent(
              type: payload.eventType.name,
              table: 'follow_ups',
              newData: payload.newRecord,
              oldData: payload.oldRecord,
            ));
          },
        )
        .subscribe((status, error) {
          debugPrint('📡 FollowUps Channel: $status');
        });
    
    _isConnected = true;
    debugPrint('✅ RealtimeService: متصل بنجاح!');
  }
  
  /// قطع الاتصال
  void _disconnect() {
    _sessionsChannel?.unsubscribe();
    _notificationsChannel?.unsubscribe();
    _followUpsChannel?.unsubscribe();
    _sessionsChannel = null;
    _notificationsChannel = null;
    _followUpsChannel = null;
    _isConnected = false;
  }
  
  /// تسجيل الخروج
  void logout() {
    _disconnect();
    _currentUserId = null;
    debugPrint('🔌 RealtimeService: تم قطع الاتصال');
  }
  
  /// إعادة الاتصال (في حالة فقدان الاتصال)
  void reconnect() {
    if (_currentUserId != null) {
      _disconnect();
      _connect();
    }
  }
  
  void dispose() {
    _disconnect();
    _sessionsController.close();
    _notificationsController.close();
    _followUpsController.close();
  }
}

/// حدث Realtime موحد
class RealtimeEvent {
  final String type; // insert, update, delete
  final String table;
  final Map<String, dynamic>? newData;
  final Map<String, dynamic>? oldData;
  
  RealtimeEvent({
    required this.type,
    required this.table,
    this.newData,
    this.oldData,
  });
  
  String? get recordId => newData?['id'] ?? oldData?['id'];
  
  bool get isInsert => type == 'insert';
  bool get isUpdate => type == 'update';
  bool get isDelete => type == 'delete';
}
