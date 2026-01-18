import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import 'notifications_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('الإشعارات'),
        backgroundColor: AppTheme.surface,
        actions: [
          Consumer<NotificationsProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount > 0) {
                return TextButton.icon(
                  onPressed: () => provider.markAllAsRead(),
                  icon: const Icon(Icons.done_all, color: Colors.white70),
                  label: const Text('قراءة الكل', style: TextStyle(color: Colors.white70)),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<NotificationsProvider>(
        builder: (context, provider, _) {
          if (provider.notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text('لا توجد إشعارات', style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (scrollInfo) {
              if (!provider.isLoadingMore && provider.hasMore &&
                  scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                provider.loadMoreNotifications();
              }
              return false;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.notifications.length + (provider.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == provider.notifications.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final notification = provider.notifications[index];
                return _NotificationCard(
                  notification: notification,
                  onTap: () => _handleNotificationTap(context, notification, provider),
                  onDismiss: () => provider.deleteNotification(notification['id']),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _handleNotificationTap(BuildContext context, Map<String, dynamic> notification, NotificationsProvider provider) {
    // Mark as read
    if (notification['is_read'] == false) {
      provider.markAsRead(notification['id']);
    }

    final type = notification['type'];
    
    // Handle different notification types
    switch (type) {
      case 'cancellation_request':
        // Navigate to cancellation requests if admin
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('انتقل لصفحة طلبات الإلغاء')),
        );
        break;
      case 'follow_up_reminder':
        // Navigate to follow-up screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('انتقل لصفحة المتابعة')),
        );
        break;
      default:
        // Show notification details
        _showNotificationDetails(context, notification);
    }
  }

  void _showNotificationDetails(BuildContext context, Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(notification['title'] ?? 'إشعار'),
        content: Text(notification['message'] ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isRead = notification['is_read'] ?? false;
    final type = notification['type'] ?? 'general';
    final createdAt = notification['created_at'] != null
        ? DateTime.parse(notification['created_at'])
        : DateTime.now();

    return Dismissible(
      key: Key(notification['id'] ?? ''),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(77),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        color: isRead ? AppTheme.surface : AppTheme.surface.withAlpha(230),
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isRead ? Colors.transparent : _getTypeColor(type),
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getTypeColor(type).withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getTypeIcon(type), color: _getTypeColor(type)),
                ),
                const SizedBox(width: 12),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification['title'] ?? 'إشعار',
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification['message'] ?? '',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDate(createdAt),
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'new_booking': return Icons.calendar_today;
      case 'patient_arrived': return Icons.person_pin_circle;
      case 'session_started': return Icons.play_circle;
      case 'cancellation_request': return Icons.cancel;
      case 'cancellation_approved': return Icons.check_circle;
      case 'cancellation_rejected': return Icons.block;
      case 'follow_up_reminder': return Icons.notifications_active;
      default: return Icons.notifications;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'new_booking': return Colors.blue;
      case 'patient_arrived': return Colors.green;
      case 'session_started': return Colors.purple;
      case 'cancellation_request': return Colors.orange;
      case 'cancellation_approved': return Colors.green;
      case 'cancellation_rejected': return Colors.red;
      case 'follow_up_reminder': return Colors.amber;
      default: return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'الآن';
    } else if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} دقيقة';
    } else if (diff.inHours < 24) {
      return 'منذ ${diff.inHours} ساعة';
    } else if (diff.inDays < 7) {
      return 'منذ ${diff.inDays} يوم';
    } else {
      return DateFormat('yyyy-MM-dd').format(date);
    }
  }
}
