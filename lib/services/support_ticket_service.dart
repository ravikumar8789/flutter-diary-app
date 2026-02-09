import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/utility_models.dart';
import 'error_logging_service.dart';
import '../models/error_models.dart';

class SupportTicketService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Submit a new support ticket
  static Future<SupportTicketResult> submitTicket({
    required String category,
    required String subject,
    required String message,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return SupportTicketResult(
          success: false,
          error: 'User not authenticated',
          ticket: null,
        );
      }

      // Validate inputs
      if (category.isEmpty || subject.trim().isEmpty || message.trim().isEmpty) {
        return SupportTicketResult(
          success: false,
          error: 'All fields are required',
          ticket: null,
        );
      }

      // Validate subject length (max 100 chars)
      if (subject.trim().length > 100) {
        return SupportTicketResult(
          success: false,
          error: 'Subject must be 100 characters or less',
          ticket: null,
        );
      }

      // Validate message length (max 2000 chars)
      if (message.trim().length > 2000) {
        return SupportTicketResult(
          success: false,
          error: 'Message must be 2000 characters or less',
          ticket: null,
        );
      }

      // Get email from user
      final email = user.email;

      // Hardcode app version
      const appVersion = '1.0.0';

      // Get device info
      final deviceInfo = {
        'platform': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
        'is_debug': kDebugMode,
      };

      // Insert ticket (trigger will auto-generate ticket_number)
      final response = await _supabase
          .from('support_tickets')
          .insert({
            'user_id': user.id,
            'category': category,
            'subject': subject.trim(),
            'message': message.trim(),
            'email': email,
            'app_version': appVersion,
            'device_info': deviceInfo,
            'status': 'open',
          })
          .select('id, ticket_number, category, subject, message, email, app_version, device_info, status, created_at')
          .single();

      // Parse response to SupportTicket
      final ticket = SupportTicket(
        id: response['id'] as String,
        userId: user.id,
        ticketNumber: response['ticket_number'] as String?,
        category: response['category'] as String?,
        subject: response['subject'] as String?,
        message: response['message'] as String?,
        email: response['email'] as String?,
        appVersion: response['app_version'] as String?,
        deviceInfo: response['device_info'] as Map<String, dynamic>?,
        status: TicketStatus.fromString(response['status'] as String?),
        createdAt: DateTime.parse(response['created_at'] as String),
      );

      return SupportTicketResult(
        success: true,
        ticket: ticket,
      );
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS122',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': _supabase.auth.currentUser?.id,
            'operation': 'submit_ticket',
            'category': category,
          },
        ),
      );

      return SupportTicketResult(
        success: false,
        error: 'Failed to submit ticket. Please try again.',
        ticket: null,
      );
    }
  }

  /// Fetch user's tickets (optional - for future "My Tickets" feature)
  static Future<List<SupportTicket>> getUserTickets() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return [];
      }

      final response = await _supabase
          .from('support_tickets')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (response as List).map((json) => SupportTicket.fromJson(json)).toList();
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS123',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': _supabase.auth.currentUser?.id,
            'operation': 'fetch_user_tickets',
          },
        ),
      );
      return [];
    }
  }
}

/// Result class for ticket submission
class SupportTicketResult {
  final bool success;
  final String? error;
  final SupportTicket? ticket;

  SupportTicketResult({
    required this.success,
    this.error,
    this.ticket,
  });
}

