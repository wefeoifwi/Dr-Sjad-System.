import 'package:flutter/material.dart';
import '../../core/theme.dart';

class NotificationToast extends StatelessWidget {
  final String title;
  final String body;
  final String type;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const NotificationToast({
    super.key,
    required this.title,
    required this.body,
    required this.type,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _getTypeColor(type).withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getTypeColor(type).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getTypeIcon(type), color: _getTypeColor(type), size: 24),
              ),
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Action
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.white38),
                    onPressed: onDismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(height: 8),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'new_booking': return Icons.calendar_today_rounded;
      case 'patient_arrived': return Icons.person_pin_circle_rounded;
      case 'session_started': return Icons.play_circle_fill_rounded;
      case 'cancellation_request': return Icons.cancel_outlined;
      case 'cancellation_approved': return Icons.check_circle_rounded;
      case 'cancellation_rejected': return Icons.block_rounded;
      case 'follow_up_reminder': return Icons.notifications_active_rounded;
      default: return Icons.notifications_rounded;
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
}
