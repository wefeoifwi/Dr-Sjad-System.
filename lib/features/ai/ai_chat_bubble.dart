import 'package:flutter/material.dart';
import 'package:groq/groq.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import '../../core/theme.dart';

class AIChatBubble extends StatefulWidget {
  const AIChatBubble({super.key});

  @override
  State<AIChatBubble> createState() => _AIChatBubbleState();
}

class _AIChatBubbleState extends State<AIChatBubble> with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleChat() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_isOpen)
          Positioned(
            bottom: 80,
            left: 20,
            child: ScaleTransition(
              scale: _scaleAnimation,
              alignment: Alignment.bottomLeft,
              child: const AIChatWindow(),
            ),
          ),
        Positioned(
          bottom: 20,
          left: 20,
          child: GestureDetector(
            onTap: _toggleChat,
            child: AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primary.withBlue(255)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppTheme.primary.withAlpha(128), blurRadius: 15, spreadRadius: 2)],
                  ),
                  child: Center(
                    child: Transform.rotate(
                      angle: _rotationAnimation.value * math.pi / 4,
                      child: Icon(_isOpen ? Icons.close : Icons.auto_awesome, color: Colors.white, size: 28),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class AIChatWindow extends StatefulWidget {
  const AIChatWindow({super.key});
  @override
  State<AIChatWindow> createState() => _AIChatWindowState();
}

class _AIChatWindowState extends State<AIChatWindow> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  // Groq API - Use environment variable to avoid exposing in code
  // Set this via: --dart-define=GROQ_API_KEY=your_key
  static const String _apiKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: 'YOUR_GROQ_API_KEY_HERE');
  late Groq _groq;

  @override
  void initState() {
    super.initState();
    _initializeGroq();
    _messages.add(ChatMessage(
      text: '🚀 مرحباً! أنا مستشار CarePoint الذكي.\n\n'
            'الآن بتقنية Groq فائقة السرعة! ⚡\n\n'
            'قدراتي:\n'
            '📊 تحليل الإيرادات والنمو\n'
            '👥 تحليل المرضى وVIP\n'
            '📈 التوقعات والتنبؤات\n'
            '💡 توصيات استراتيجية\n\n'
            'اسألني أي شيء! 🎯',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  void _initializeGroq() {
    _groq = Groq(
      apiKey: _apiKey,
      configuration: Configuration(
        model: 'llama-3.3-70b-versatile',
        temperature: 0.7,
      ),
    );
    _groq.startChat();
    
    // Set system prompt
    _groq.setCustomInstructionsWith('''
أنت "مستشار CarePoint الذكي" - نظام AI متقدم لإدارة عيادة تجميلية.

🎯 مهامك:
1. محلل بيانات خبير: تحليل الإيرادات، الحجوزات، المرضى، أداء الأطباء
2. مستشار استراتيجي: توصيات لزيادة الأرباح وتحسين الأداء
3. خبير تنبؤات: توقع الاتجاهات والإيرادات
4. محلل مشكلات: تحديد نقاط الضعف وتقديم حلول

🧠 قدراتك:
- مقارنة الإيرادات (يومي/أسبوعي/شهري)
- تحليل نسب النمو
- تحديد الخدمات الأكثر ربحية
- تصنيف المرضى (VIP, عادي, جديد)
- معدل الرجوع والاحتفاظ
- أوقات الذروة
- كفاءة الأطباء
- التنبيهات والتحذيرات

📝 قواعد:
- العربية دائماً
- إيموجي للتوضيح
- أرقام ونسب دقيقة
- توصيات عملية
- العملة: دينار عراقي (د.ع)
- ملخص ثم تفاصيل ثم توصيات
''');
  }

  Future<String> _getClinicData() async {
    try {
      final supabase = Supabase.instance.client;
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final yesterdayStart = todayStart.subtract(const Duration(days: 1));
      final weekStart = todayStart.subtract(Duration(days: today.weekday - 1));
      final lastWeekStart = weekStart.subtract(const Duration(days: 7));
      final monthStart = DateTime(today.year, today.month, 1);
      final lastMonthStart = DateTime(today.year, today.month - 1, 1);

      // المرضى
      final allPatients = await supabase.from('patients').select('id, name, gender, created_at, source, age');
      final newThisMonth = allPatients.where((p) {
        if (p['created_at'] == null) return false;
        return DateTime.parse(p['created_at']).isAfter(monthStart);
      }).length;
      final newLastMonth = allPatients.where((p) {
        if (p['created_at'] == null) return false;
        final d = DateTime.parse(p['created_at']);
        return d.isAfter(lastMonthStart) && d.isBefore(monthStart);
      }).length;
      final patientGrowth = newLastMonth > 0 ? (((newThisMonth - newLastMonth) / newLastMonth) * 100).toStringAsFixed(1) : 'N/A';
      
      // Gender counts - included in output string calculation below
      final maleCount = allPatients.where((p) => p['gender'] == 'male').length;
      final femaleCount = allPatients.where((p) => p['gender'] == 'female').length;
      final walkIn = allPatients.where((p) => p['source'] == 'walk_in').length;
      final callSrc = allPatients.where((p) => p['source'] == 'call').length;
      final online = allPatients.where((p) => p['source'] == 'online').length;

      // الجلسات
      final allSessions = await supabase.from('sessions').select('id, status, price, start_time, service_id, doctor_id, patient_id');
      
      List<dynamic> filterByDate(DateTime start, [DateTime? end]) {
        return allSessions.where((s) {
          if (s['start_time'] == null) return false;
          final t = DateTime.parse(s['start_time']);
          if (end != null) return t.isAfter(start) && t.isBefore(end);
          return t.isAfter(start);
        }).toList();
      }
      
      int calcRevenue(List<dynamic> sessions) => sessions.where((s) => s['status'] == 'completed').fold(0, (sum, s) => sum + ((s['price'] ?? 0) as int));
      
      final todaySessions = allSessions.where((s) {
        if (s['start_time'] == null) return false;
        final t = DateTime.parse(s['start_time']);
        return t.year == today.year && t.month == today.month && t.day == today.day;
      }).toList();
      final yesterdaySessions = allSessions.where((s) {
        if (s['start_time'] == null) return false;
        final t = DateTime.parse(s['start_time']);
        return t.year == yesterdayStart.year && t.month == yesterdayStart.month && t.day == yesterdayStart.day;
      }).toList();
      final weekSessions = filterByDate(weekStart);
      final lastWeekSessions = filterByDate(lastWeekStart, weekStart);
      final monthSessions = filterByDate(monthStart);
      final lastMonthSessions = filterByDate(lastMonthStart, monthStart);

      final todayRev = calcRevenue(todaySessions);
      final yesterdayRev = calcRevenue(yesterdaySessions);
      final weekRev = calcRevenue(weekSessions);
      final lastWeekRev = calcRevenue(lastWeekSessions);
      final monthRev = calcRevenue(monthSessions);
      final lastMonthRev = calcRevenue(lastMonthSessions);
      final totalRev = calcRevenue(allSessions);

      final dailyGrowth = yesterdayRev > 0 ? (((todayRev - yesterdayRev) / yesterdayRev) * 100).toStringAsFixed(1) : 'N/A';
      final weeklyGrowth = lastWeekRev > 0 ? (((weekRev - lastWeekRev) / lastWeekRev) * 100).toStringAsFixed(1) : 'N/A';
      final monthlyGrowth = lastMonthRev > 0 ? (((monthRev - lastMonthRev) / lastMonthRev) * 100).toStringAsFixed(1) : 'N/A';

      final completed = allSessions.where((s) => s['status'] == 'completed').length;
      final avgValue = completed > 0 ? (totalRev / completed).toStringAsFixed(0) : '0';

      // VIP والرجوع
      Map<String, int> visits = {};
      for (var s in allSessions) {
        if (s['patient_id'] != null) {
          final pid = s['patient_id'].toString();
          visits[pid] = (visits[pid] ?? 0) + 1;
        }
      }
      final vip = visits.entries.where((e) => e.value >= 5).length;
      final regular = visits.entries.where((e) => e.value >= 2 && e.value < 5).length;
      final oneTime = visits.entries.where((e) => e.value == 1).length;
      final returnRate = visits.isNotEmpty ? ((visits.entries.where((e) => e.value >= 2).length / visits.length) * 100).toStringAsFixed(1) : '0';

      // أوقات الذروة
      Map<int, int> hourly = {};
      for (var s in allSessions) {
        if (s['start_time'] != null) {
          final h = DateTime.parse(s['start_time']).hour;
          hourly[h] = (hourly[h] ?? 0) + 1;
        }
      }
      final peakHour = hourly.isNotEmpty ? hourly.entries.reduce((a, b) => a.value > b.value ? a : b).key : 0;

      // الخدمات
      final services = await supabase.from('services').select('id, name, default_price');
      Map<String, Map<String, int>> svcStats = {};
      for (var svc in services) {
        final svcSessions = allSessions.where((s) => s['service_id'] == svc['id']).toList();
        svcStats[svc['name'] ?? '?'] = {'count': svcSessions.length, 'revenue': calcRevenue(svcSessions)};
      }
      var sorted = svcStats.entries.toList()..sort((a, b) => b.value['revenue']!.compareTo(a.value['revenue']!));
      final topSvc = sorted.take(5).map((e) => '• ${e.key}: ${e.value['count']} جلسة، ${e.value['revenue']} د.ع').join('\n');

      // الأطباء
      final staff = await supabase.from('profiles').select('id, name, role');
      final doctors = staff.where((s) => s['role'] == 'doctor').toList();
      List<Map<String, dynamic>> docStats = [];
      for (var doc in doctors) {
        final docSessions = allSessions.where((s) => s['doctor_id'] == doc['id']).toList();
        final docRev = calcRevenue(docSessions);
        final cancelled = docSessions.where((s) => s['status'] == 'cancelled').length;
        final rate = docSessions.isNotEmpty ? ((cancelled / docSessions.length) * 100).toStringAsFixed(1) : '0';
        docStats.add({'name': doc['name'], 'sessions': docSessions.length, 'revenue': docRev, 'cancelRate': rate});
      }
      docStats.sort((a, b) => (b['revenue'] as int).compareTo(a['revenue'] as int));
      final docStatsStr = docStats.map((d) => '• ${d['name']}: ${d['sessions']} جلسة | ${d['revenue']} د.ع | إلغاء: ${d['cancelRate']}%').join('\n');
      final bestDoc = docStats.isNotEmpty ? docStats.first['name'] : 'N/A';

      // الأجهزة والمتابعات
      final devices = await supabase.from('devices').select('id, name, status');
      final activeDevices = devices.where((d) => d['status'] == 'active').length;
      
      final followUps = await supabase.from('follow_ups').select('id, status, scheduled_date');
      final pending = followUps.where((f) => f['status'] == 'pending').length;
      final overdue = followUps.where((f) {
        if (f['scheduled_date'] == null || f['status'] != 'pending') return false;
        return DateTime.parse(f['scheduled_date']).isBefore(today);
      }).length;

      // الأداء
      final compRate = allSessions.isNotEmpty ? ((allSessions.where((s) => s['status'] == 'completed').length / allSessions.length) * 100).toStringAsFixed(1) : '0';
      final cancelRate = allSessions.isNotEmpty ? ((allSessions.where((s) => s['status'] == 'cancelled').length / allSessions.length) * 100).toStringAsFixed(1) : '0';

      // التنبيهات
      List<String> alerts = [];
      if (double.tryParse(cancelRate) != null && double.parse(cancelRate) > 15) alerts.add('⚠️ إلغاء مرتفع: $cancelRate%');
      if (overdue > 0) alerts.add('🔴 $overdue متابعة متأخرة!');
      if (pending > 10) alerts.add('⚠️ $pending متابعة معلقة');
      if (oneTime > vip * 3) alerts.add('💡 حسّن معدل الرجوع');
      final alertsStr = alerts.isNotEmpty ? alerts.join('\n') : '✅ الأداء ممتاز!';

      // التوقع
      final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
      final projected = today.day > 0 ? ((monthRev / today.day) * daysInMonth).toInt() : 0;

      return '''
╔══════════════════════════════════════════════════════════════╗
║         📊 تقرير العيادة - ${today.toString().split(' ')[0]}          ║
╚══════════════════════════════════════════════════════════════╝

🚨 التنبيهات:
$alertsStr

💰 الإيرادات:
• اليوم: $todayRev د.ع ($dailyGrowth% عن أمس)
• الأسبوع: $weekRev د.ع ($weeklyGrowth% عن السابق)
• الشهر: $monthRev د.ع ($monthlyGrowth% عن السابق)
• الإجمالي: $totalRev د.ع | متوسط الجلسة: $avgValue د.ع
• 🔮 التوقع الشهري: $projected د.ع

📅 حجوزات اليوم: ${todaySessions.length}
• مكتمل: ${todaySessions.where((s) => s['status'] == 'completed').length}
• ملغي: ${todaySessions.where((s) => s['status'] == 'cancelled').length}
• قيد الانتظار: ${todaySessions.where((s) => s['status'] == 'booked').length}

⏰ وقت الذروة: $peakHour:00

👥 المرضى (${allPatients.length}):
• جدد الشهر: $newThisMonth ($patientGrowth% نمو)
• 👨 ذكور: $maleCount | 👩 إناث: $femaleCount
• 🌟 VIP: $vip | عادي: $regular | جديد: $oneTime
• 🔄 معدل الرجوع: $returnRate%
• مصادر: حضوري($walkIn) | اتصال($callSrc) | أونلاين($online)

🏆 أفضل الخدمات:
$topSvc

👨‍⚕️ الأطباء (الأفضل: $bestDoc):
$docStatsStr

📈 الأداء: إكمال $compRate% | إلغاء $cancelRate%

🔧 الموارد:
• أجهزة نشطة: $activeDevices/${devices.length}
• متابعات معلقة: $pending (متأخرة: $overdue)
''';
    } catch (e) {
      return 'خطأ: $e';
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true, timestamp: DateTime.now()));
      _messageController.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      String data = '';
      if (_needsData(text)) data = await _getClinicData();
      final prompt = data.isNotEmpty ? '$data\n\nسؤال: $text' : text;
      
      final response = await _groq.sendMessage(prompt);
      final responseText = response.choices.first.message.content;
      
      setState(() {
        _messages.add(ChatMessage(text: responseText, isUser: false, timestamp: DateTime.now()));
        _isTyping = false;
      });
    } catch (e) {
      String errorMessage;
      final errorStr = e.toString().toLowerCase();
      
      if (errorStr.contains('rate limit') || errorStr.contains('429')) {
        errorMessage = '⚠️ تجاوز حد الطلبات\n\nانتظر قليلاً وحاول مرة أخرى.';
      } else if (errorStr.contains('api key') || errorStr.contains('invalid') || errorStr.contains('401')) {
        errorMessage = '🔑 مشكلة في مفتاح API\n\nتأكد من صحة مفتاح Groq API.';
      } else if (errorStr.contains('network') || errorStr.contains('connection')) {
        errorMessage = '🌐 خطأ في الاتصال\n\nتأكد من اتصالك بالإنترنت.';
      } else {
        errorMessage = '⚠️ حدث خطأ\n\n$e';
      }
      
      setState(() {
        _messages.add(ChatMessage(text: errorMessage, isUser: false, timestamp: DateTime.now()));
        _isTyping = false;
      });
    }
    _scrollToBottom();
  }

  bool _needsData(String q) {
    final kw = ['إيراد', 'ايراد', 'مبيعات', 'أرباح', 'ارباح', 'مالي', 'ربح', 'دخل', 'حجز', 'حجوزات', 'مواعيد', 'موعد', 'جلس', 'زيار', 'مريض', 'مرضى', 'عملاء', 'زبائن', 'تقرير', 'إحصائيات', 'احصائيات', 'بيانات', 'تحليل', 'ملخص', 'اليوم', 'الشهر', 'الأسبوع', 'أمس', 'سنوي', 'شهري', 'يومي', 'خدمة', 'خدمات', 'طبيب', 'أطباء', 'موظف', 'دكتور', 'أداء', 'إنتاجي', 'كفاء', 'نسب', 'معدل', 'نصيحة', 'نصائح', 'تحسين', 'تطوير', 'توصية', 'توقع', 'تنبؤ', 'كم', 'كيف', 'ماذا', 'أفضل', 'أسوأ', 'أكثر', 'أقل', 'جهاز', 'أجهزة', 'متابع', 'متابعات', 'vip', 'نمو', 'رجوع'];
    return kw.any((k) => q.toLowerCase().contains(k));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      height: 550,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withAlpha(77)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(128), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.primary.withBlue(200)]),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.psychology, color: Colors.white)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مستشار CarePoint الذكي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('⚡ Groq | سريع جداً', style: TextStyle(fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.withAlpha(77), borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, color: Colors.greenAccent, size: 14),
                      SizedBox(width: 4),
                      Text('FAST', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) return const _TypingIndicator();
                return _MessageBubble(message: _messages[index]);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.background, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'اسأل عن أي شيء...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: AppTheme.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.primary.withBlue(200)]), shape: BoxShape.circle),
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _sendMessage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  ChatMessage({required this.text, required this.isUser, required this.timestamp});
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: message.isUser ? AppTheme.primary : AppTheme.background,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
          border: message.isUser ? null : Border.all(color: Colors.white12),
        ),
        child: Text(message.text, style: TextStyle(color: message.isUser ? Colors.white : Colors.white70)),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚡ يفكر ', style: TextStyle(color: Colors.white38, fontSize: 12)),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final v = ((_controller.value + i * 0.2) % 1.0);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: AppTheme.primary.withAlpha((v * 255).toInt()), shape: BoxShape.circle),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
