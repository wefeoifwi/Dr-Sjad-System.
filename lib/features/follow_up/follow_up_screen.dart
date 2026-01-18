import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import 'follow_up_provider.dart';

class FollowUpScreen extends StatefulWidget {
  final String userRole;
  
  const FollowUpScreen({super.key, this.userRole = 'employee'});

  @override
  State<FollowUpScreen> createState() => _FollowUpScreenState();
}

class _FollowUpScreenState extends State<FollowUpScreen> {
  String _selectedPeriod = 'all'; // 'today', 'week', 'month', 'all'
  String _filterStatus = 'all'; // 'all', 'pending', 'confirmed', 'cancelled'
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FollowUpProvider>();
      provider.loadFollowUps();
      provider.subscribeToRealtimeUpdates();
    });
  }

  List<Map<String, dynamic>> _getFilteredFollowUps(List<Map<String, dynamic>> followUps) {
    var filtered = List<Map<String, dynamic>>.from(followUps);
    
    // Date filter
    if (_selectedPeriod != 'all') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      filtered = filtered.where((f) {
        final date = f['scheduled_date'];
        if (date == null) return true;
        final scheduledDate = DateTime.tryParse(date.toString());
        if (scheduledDate == null) return true;
        
        switch (_selectedPeriod) {
          case 'today':
            return scheduledDate.year == today.year && 
                   scheduledDate.month == today.month && 
                   scheduledDate.day == today.day;
          case 'week':
            return scheduledDate.isAfter(today.subtract(const Duration(days: 7)));
          case 'month':
            return scheduledDate.isAfter(DateTime(today.year, today.month - 1, today.day));
          default:
            return true;
        }
      }).toList();
    }
    
    // Status filter
    if (_filterStatus != 'all') {
      filtered = filtered.where((f) => f['status'] == _filterStatus).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('متابعة المواعيد القادمة'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<FollowUpProvider>().loadFollowUps(),
          ),
        ],
      ),
      body: Consumer<FollowUpProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final allFollowUps = provider.followUps;
          final filtered = _getFilteredFollowUps(allFollowUps);

          // Group by status for display
          final pending = filtered.where((f) => f['status'] == 'pending').toList();
          final confirmed = filtered.where((f) => f['status'] == 'confirmed').toList();

          return Column(
            children: [
              // Filter Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.surface,
                child: Column(
                  children: [
                    // Period Filter
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPeriodChip('الكل', 'all'),
                          _buildPeriodChip('اليوم', 'today'),
                          _buildPeriodChip('أسبوع', 'week'),
                          _buildPeriodChip('شهر', 'month'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Status Filter
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStatusChip('الكل', 'all', Colors.grey),
                          _buildStatusChip('معلقة', 'pending', Colors.orange),
                          _buildStatusChip('مؤكدة', 'confirmed', Colors.green),
                          _buildStatusChip('ملغية', 'cancelled', Colors.red),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_available, size: 64, color: Colors.white24),
                            SizedBox(height: 16),
                            Text('لا توجد مواعيد متابعة', style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Stats
                          _buildStats(pending.length, confirmed.length),
                          const SizedBox(height: 24),

                          // Pending (need to call)
                          if (pending.isNotEmpty) ...[
                            _buildSectionHeader('بحاجة للاتصال', pending.length, Colors.orange),
                            ...pending.map((f) => _buildFollowUpCard(f, isPending: true)),
                            const SizedBox(height: 24),
                          ],

                          // Confirmed
                          if (confirmed.isNotEmpty) ...[
                            _buildSectionHeader('مؤكدة', confirmed.length, Colors.green),
                            ...confirmed.map((f) => _buildFollowUpCard(f, isPending: false)),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.primary.withAlpha(51),
        onSelected: (_) => setState(() => _selectedPeriod = value),
      ),
    );
  }

  Widget _buildStatusChip(String label, String value, Color color) {
    final isSelected = _filterStatus == value;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: color.withAlpha(51),
        avatar: isSelected ? Icon(Icons.check, size: 16, color: color) : null,
        onSelected: (_) => setState(() => _filterStatus = value),
      ),
    );
  }

  Widget _buildStats(int pending, int confirmed) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withAlpha(77)),
            ),
            child: Column(
              children: [
                const Icon(Icons.phone_callback, color: Colors.orange, size: 32),
                const SizedBox(height: 8),
                Text('$pending', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
                const Text('بحاجة للاتصال', style: TextStyle(color: Colors.orange)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withAlpha(77)),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 32),
                const SizedBox(height: 8),
                Text('$confirmed', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                const Text('مؤكدة', style: TextStyle(color: Colors.green)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(width: 4, height: 20, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withAlpha(51), borderRadius: BorderRadius.circular(12)),
            child: Text('$count', style: TextStyle(color: color, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpCard(Map<String, dynamic> followUp, {required bool isPending}) {
    final patientName = followUp['patients']?['name'] ?? 'مريض';
    final patientPhone = followUp['patients']?['phone'] ?? '';
    final patientCategory = followUp['patients']?['category'] ?? 'regular';
    final doctorName = followUp['profiles']?['name'] ?? '';
    final assignedStaffName = followUp['assigned_staff']?['name'] ?? '';
    final scheduledDate = followUp['scheduled_date'] ?? '';
    final scheduledTime = followUp['scheduled_time'];

    // Check if due for reminder (within 2 days)
    final now = DateTime.now();
    DateTime? dateObj;
    bool isDueSoon = false;
    try {
      dateObj = DateTime.parse(scheduledDate);
      isDueSoon = dateObj.difference(now).inDays <= 2;
    } catch (_) {}
    
    // تصنيف المريض - used in future features
    // ignore: unused_local_variable
    final categoryInfo = _getCategoryInfo(patientCategory);

    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDueSoon && isPending ? const BorderSide(color: Colors.orange, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isPending ? Colors.orange.withAlpha(51) : Colors.green.withAlpha(51),
                  child: Icon(isPending ? Icons.phone : Icons.check, color: isPending ? Colors.orange : Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                          if (patientCategory == 'vip') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                              child: const Text('VIP', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      if (patientPhone.isNotEmpty)
                        InkWell(
                          onTap: () => _makePhoneCall(patientPhone),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.phone, size: 14, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(patientPhone, style: const TextStyle(color: Colors.green, decoration: TextDecoration.underline)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isDueSoon && isPending)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                        child: const Text('عاجل', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    if (assignedStaffName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('📋 $assignedStaffName', style: const TextStyle(color: Colors.cyan, fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),

            const Divider(height: 24),

            // Details
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.white54),
                    const SizedBox(width: 8),
                    Text(scheduledDate, style: const TextStyle(color: Colors.white70)),
                  ],
                ),
                if (scheduledTime != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.white54),
                      const SizedBox(width: 8),
                      Text(scheduledTime, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                if (doctorName.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.white54),
                      const SizedBox(width: 8),
                      Text('د. $doctorName', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
              ],
            ),

            // Call Tracking Info
            if (followUp['call_attempts'] != null && (followUp['call_attempts'] as int) > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(FollowUpProvider.getCallOutcomeColor(followUp['call_outcome'])).withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(FollowUpProvider.getCallOutcomeColor(followUp['call_outcome'])).withAlpha(77)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone_callback, size: 18, color: Color(FollowUpProvider.getCallOutcomeColor(followUp['call_outcome']))),
                    const SizedBox(width: 8),
                    Text('${followUp['call_attempts']} محاولة', style: TextStyle(color: Color(FollowUpProvider.getCallOutcomeColor(followUp['call_outcome'])), fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(FollowUpProvider.getCallOutcomeColor(followUp['call_outcome'])),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(FollowUpProvider.getCallOutcomeText(followUp['call_outcome']), style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                    if (followUp['call_notes'] != null && (followUp['call_notes'] as String).isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Expanded(child: Text(followUp['call_notes'], style: const TextStyle(color: Colors.white54, fontSize: 12), overflow: TextOverflow.ellipsis)),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Actions
            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () => _showConfirmDialog(followUp),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('تأكيد الموعد'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // NEW: Call Tracking Button
                  IconButton(
                    icon: const Icon(Icons.phone_callback, color: Colors.cyan),
                    tooltip: 'تسجيل اتصال',
                    onPressed: () => _showRecordCallDialog(followUp),
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone, color: Colors.blue),
                    tooltip: 'اتصال / واتساب',
                    onPressed: () => _showContactOptions(patientPhone, patientName, scheduledDate),
                  ),
                  IconButton(
                    icon: const Icon(Icons.update, color: Colors.orange),
                    tooltip: 'تأجيل',
                    onPressed: () => _showPostponeDialog(followUp),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    tooltip: 'طلب إلغاء',
                    onPressed: () => _showCancelDialog(followUp),
                  ),
                  // زر إعادة التعيين للمدير فقط
                  if (widget.userRole == 'admin')
                    IconButton(
                      icon: const Icon(Icons.swap_horiz, color: Colors.purple),
                      tooltip: 'إعادة تعيين',
                      onPressed: () => _showReassignDialog(followUp),
                    ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  const Text('تم التأكيد', style: TextStyle(color: Colors.green)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _showCancelDialog(followUp),
                    child: const Text('طلب إلغاء', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getCategoryInfo(String category) {
    switch (category) {
      case 'vip':
        return {'label': 'VIP', 'color': Colors.amber, 'icon': Icons.star};
      case 'new':
        return {'label': 'جديد', 'color': Colors.blue, 'icon': Icons.fiber_new};
      case 'blacklist':
        return {'label': 'محظور', 'color': Colors.red, 'icon': Icons.block};
      default:
        return {'label': 'عادي', 'color': Colors.grey, 'icon': Icons.person};
    }
  }

  /// الاتصال الهاتفي المباشر
  Future<void> _makePhoneCall(String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد رقم هاتف'), backgroundColor: Colors.red),
      );
      return;
    }
    
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri phoneUri = Uri(scheme: 'tel', path: cleanPhone);
    
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الاتصال بـ $phone'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// عرض نافذة تسجيل محاولة الاتصال
  void _showRecordCallDialog(Map<String, dynamic> followUp) {
    String selectedOutcome = 'answered';
    final notesController = TextEditingController();
    final patientName = followUp['patients']?['name'] ?? 'مريض';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Row(
            children: [
              const Icon(Icons.phone_callback, color: Colors.cyan),
              const SizedBox(width: 8),
              Expanded(child: Text('تسجيل اتصال - $patientName', style: const TextStyle(fontSize: 16))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('نتيجة الاتصال:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildOutcomeChip('answered', 'تم الرد', Icons.check_circle, Colors.green, selectedOutcome, (v) => setDialogState(() => selectedOutcome = v)),
                    _buildOutcomeChip('no_answer', 'لا يجيب', Icons.phone_missed, Colors.orange, selectedOutcome, (v) => setDialogState(() => selectedOutcome = v)),
                    _buildOutcomeChip('busy', 'مشغول', Icons.phone_locked, Colors.deepOrange, selectedOutcome, (v) => setDialogState(() => selectedOutcome = v)),
                    _buildOutcomeChip('voicemail', 'بريد صوتي', Icons.voicemail, Colors.blue, selectedOutcome, (v) => setDialogState(() => selectedOutcome = v)),
                    _buildOutcomeChip('wrong_number', 'رقم خاطئ', Icons.wrong_location, Colors.red, selectedOutcome, (v) => setDialogState(() => selectedOutcome = v)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('ملاحظات:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'أي ملاحظات من المكالمة...',
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await context.read<FollowUpProvider>().recordCallAttempt(
                    followUpId: followUp['id'],
                    outcome: selectedOutcome,
                    notes: notesController.text.isNotEmpty ? notesController.text : null,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ تم تسجيل الاتصال'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutcomeChip(String value, String label, IconData icon, Color color, String selected, Function(String) onSelect) {
    final isSelected = selected == value;
    return InkWell(
      onTap: () => onSelect(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(51) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : Colors.white54),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: isSelected ? color : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  /// عرض خيارات الاتصال (هاتف أو قوالب واتساب)
  void _showContactOptions(String phone, String patientName, String date) async {
    // جلب القوالب والإعدادات من قاعدة البيانات
    List<Map<String, dynamic>> templates = [];
    Map<String, String> settings = {};
    
    try {
      final templatesData = await Supabase.instance.client
          .from('message_templates')
          .select()
          .eq('is_active', true);
      templates = List<Map<String, dynamic>>.from(templatesData);
      
      final settingsData = await Supabase.instance.client.from('clinic_settings').select();
      for (var s in settingsData) {
        settings[s['setting_key'] as String] = s['setting_value'] as String;
      }
    } catch (e) {
      debugPrint('Error loading templates: $e');
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Text('التواصل مع $patientName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            const SizedBox(height: 16),
            
            // اتصال هاتفي
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.phone, color: Colors.white)),
              title: const Text('اتصال هاتفي'),
              subtitle: Text(phone),
              onTap: () {
                Navigator.pop(ctx);
                _makePhoneCall(phone);
              },
            ),
            
            const Divider(),
            const Text('📱 رسائل واتساب', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 8),
            
            // قوالب الواتساب
            ...templates.map((t) => _buildTemplateOption(ctx, t, phone, patientName, date, settings)),
            
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateOption(BuildContext ctx, Map<String, dynamic> template, String phone, String patientName, String date, Map<String, String> settings) {
    final typeInfo = _getTemplateTypeInfo(template['template_type']);
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (typeInfo['color'] as Color).withAlpha(51),
        child: Icon(typeInfo['icon'], color: typeInfo['color'], size: 20),
      ),
      title: Text(template['template_name'] ?? ''),
      subtitle: Text(typeInfo['label'], style: TextStyle(color: typeInfo['color'], fontSize: 11)),
      onTap: () {
        Navigator.pop(ctx);
        _sendTemplateMessage(phone, template['template_content'], patientName, date, settings);
      },
    );
  }

  Map<String, dynamic> _getTemplateTypeInfo(String type) {
    switch (type) {
      case 'reminder':
        return {'label': 'تذكير بالموعد', 'color': Colors.orange, 'icon': Icons.alarm};
      case 'confirmation':
        return {'label': 'تأكيد الحجز', 'color': Colors.green, 'icon': Icons.check_circle};
      case 'cancellation':
        return {'label': 'إلغاء الموعد', 'color': Colors.red, 'icon': Icons.cancel};
      case 'thank_you':
        return {'label': 'شكر بعد الزيارة', 'color': Colors.purple, 'icon': Icons.favorite};
      default:
        return {'label': type, 'color': Colors.grey, 'icon': Icons.message};
    }
  }

  /// إرسال رسالة قالب عبر واتساب
  Future<void> _sendTemplateMessage(String phone, String template, String patientName, String date, Map<String, String> settings) async {
    // استبدال المتغيرات
    String message = template
        .replaceAll('{patient_name}', patientName)
        .replaceAll('{date}', date)
        .replaceAll('{time}', '---')
        .replaceAll('{clinic_name}', settings['clinic_name'] ?? 'العيادة')
        .replaceAll('{doctor_name}', settings['doctor_name'] ?? '')
        .replaceAll('{clinic_address}', settings['clinic_address'] ?? '')
        .replaceAll('{clinic_phone}', settings['clinic_phone'] ?? '');

    // تنظيف الرقم وتحويله للصيغة الدولية
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '964${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('964')) {
      cleanPhone = '964$cleanPhone';
    }

    final url = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح واتساب'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// حوار إعادة تعيين المتابعة لموظف آخر (للمدير فقط)
  void _showReassignDialog(Map<String, dynamic> followUp) async {
    // جلب قائمة الموظفين
    List<Map<String, dynamic>> staff = [];
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('id, name')
          .inFilter('role', ['call_center', 'reception', 'employee']);
      staff = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error loading staff: $e');
    }

    if (!mounted) return;
    
    String? selectedStaffId;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('إعادة تعيين المتابعة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('المريض: ${followUp['patients']?['name'] ?? 'مريض'}'),
              const SizedBox(height: 16),
              const Text('اختر الموظف الجديد:'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(border: OutlineInputBorder()),
                hint: const Text('اختر موظف'),
                items: staff.map((s) => DropdownMenuItem(
                  value: s['id'] as String,
                  child: Text(s['name'] ?? 'موظف'),
                )).toList(),
                onChanged: (v) => setState(() => selectedStaffId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              onPressed: selectedStaffId == null ? null : () async {
                Navigator.pop(ctx);
                try {
                  await context.read<FollowUpProvider>().reassignFollowUp(
                    followUpId: followUp['id'],
                    newStaffId: selectedStaffId!,
                    assignedByUserId: Supabase.instance.client.auth.currentUser?.id ?? '',
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إعادة التعيين بنجاح'), backgroundColor: Colors.purple),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('تعيين'),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(Map<String, dynamic> followUp) {
    String selectedTime = '09:00';
    final times = List.generate(12, (i) => '${(i + 9).toString().padLeft(2, '0')}:00');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('تأكيد الموعد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('المريض: ${followUp['patients']?['name'] ?? 'مريض'}'),
              Text('التاريخ: ${followUp['scheduled_date']}'),
              const SizedBox(height: 16),
              const Text('اختر ساعة الحضور:'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedTime,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: times.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => selectedTime = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await context.read<FollowUpProvider>().confirmFollowUp(
                    followUpId: followUp['id'],
                    time: selectedTime,
                    patientName: followUp['patients']?['name'] ?? '',
                    doctorId: followUp['doctor_id'] ?? '',
                    date: followUp['scheduled_date'],
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تأكيد الموعد وإنشاء الحجز'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPostponeDialog(Map<String, dynamic> followUp) {
    final reasonController = TextEditingController();
    DateTime? newDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('تأجيل الموعد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(newDate != null ? DateFormat('yyyy-MM-dd').format(newDate!) : 'اختر التاريخ الجديد'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => newDate = picked);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'سبب التأجيل (مطلوب)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                if (newDate == null || reasonController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى اختيار التاريخ وكتابة السبب')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await context.read<FollowUpProvider>().postponeFollowUp(
                    followUpId: followUp['id'],
                    newDate: newDate!,
                    reason: reasonController.text,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تأجيل الموعد'), backgroundColor: Colors.orange),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('تأجيل'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(Map<String, dynamic> followUp) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طلب إلغاء الموعد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withAlpha(77)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(child: Text('الإلغاء يتطلب موافقة المدير', style: TextStyle(color: Colors.red))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'سبب الإلغاء (مطلوب)', border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('رجوع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (reasonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى كتابة السبب')));
                return;
              }
              Navigator.pop(ctx);
              try {
                await context.read<FollowUpProvider>().requestCancellation(
                  followUpId: followUp['id'],
                  reason: reasonController.text,
                  requestedByName: 'موظف', // TODO: Get from auth
                  patientName: followUp['patients']?['name'] ?? '',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إرسال طلب الإلغاء للمدير'), backgroundColor: Colors.blueGrey),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('إرسال الطلب'),
          ),
        ],
      ),
    );
  }
}
