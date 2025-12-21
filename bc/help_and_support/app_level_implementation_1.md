# **HELP & SUPPORT - APP LEVEL IMPLEMENTATION PLAN**

**Status:** Ready for Implementation  
**Date:** 2025-01-XX  
**Purpose:** Implement Help & Support screen with ticket submission functionality

---

## **📋 PREREQUISITES**

✅ **Already Completed:**
- Database changes (ticket_number, category, triggers)
- `SupportTicket` model exists in `lib/models/utility_models.dart`
- `TicketStatus` enum exists
- Button exists on Profile screen (empty callback)

---

## **🎯 OBJECTIVE**

Create a professional, minimalistic Help & Support screen that allows users to:
1. Select ticket category
2. Enter subject and message
3. Submit ticket to database
4. View ticket number after submission
5. Handle errors gracefully

---

## **📝 IMPLEMENTATION STEPS**

### **Step 1: Update SupportTicket Model**

**File:** `lib/models/utility_models.dart`

**Changes Needed:**
- Add `ticketNumber` field (String?)
- Add `category` field (String?)
- Update `fromJson()` to include new fields
- Update `toJson()` to include new fields

**Code to Add:**
```dart
class SupportTicket {
  final String id;
  final String? userId;
  final String? ticketNumber;  // NEW: TKT-000001
  final String? category;        // NEW: bug/feature/question/feedback/other
  final String? subject;
  final String? message;
  final TicketStatus status;
  final DateTime createdAt;
  final DateTime? closedAt;

  SupportTicket({
    required this.id,
    this.userId,
    this.ticketNumber,      // NEW
    this.category,          // NEW
    this.subject,
    this.message,
    this.status = TicketStatus.open,
    required this.createdAt,
    this.closedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      ticketNumber: json['ticket_number'] as String?,  // NEW
      category: json['category'] as String?,              // NEW
      subject: json['subject'] as String?,
      message: json['message'] as String?,
      status: TicketStatus.fromString(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'ticket_number': ticketNumber,  // NEW
      'category': category,            // NEW
      'subject': subject,
      'message': message,
      'status': status.value,
      'created_at': createdAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
    };
  }
}
```

---

### **Step 2: Create SupportTicketService**

**File:** `lib/services/support_ticket_service.dart` (NEW FILE)

**Purpose:** Handle all ticket-related operations (submit, fetch user tickets)

**Service Structure:**
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/utility_models.dart';
import 'error_logging_service.dart';

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

      // Insert ticket (trigger will auto-generate ticket_number)
      final response = await _supabase
          .from('support_tickets')
          .insert({
            'user_id': user.id,
            'category': category,
            'subject': subject.trim(),
            'message': message.trim(),
            'status': 'open',
          })
          .select('id, ticket_number, category, subject, message, status, created_at')
          .single();

      // Parse response to SupportTicket
      final ticket = SupportTicket(
        id: response['id'] as String,
        userId: user.id,
        ticketNumber: response['ticket_number'] as String?,
        category: response['category'] as String?,
        subject: response['subject'] as String?,
        message: response['message'] as String?,
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
        errorCode: 'ERRSYS122',
        errorMessage: 'Support ticket submission failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': _supabase.auth.currentUser?.id,
          'operation': 'submit_ticket',
          'category': category,
        },
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
        errorCode: 'ERRSYS123',
        errorMessage: 'Fetch user tickets failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': _supabase.auth.currentUser?.id,
          'operation': 'fetch_user_tickets',
        },
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
```

---

### **Step 3: Create Help & Support Screen**

**File:** `lib/screens/help_support_screen.dart` (NEW FILE)

**UI Design:**
- Clean, minimalistic layout
- Category dropdown
- Subject input (max 100 chars)
- Message textarea (max 2000 chars)
- Character counters
- Submit button
- Loading state
- Success/error feedback

**Screen Structure:**
```dart
import 'package:flutter/material.dart';
import '../services/support_ticket_service.dart';
import '../utils/snackbar_utils.dart';
import '../services/error_logging_service.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  
  String? _selectedCategory;
  bool _isSubmitting = false;

  // Category options
  final List<Map<String, String>> _categories = [
    {'value': 'bug', 'label': 'Bug Report'},
    {'value': 'feature', 'label': 'Feature Request'},
    {'value': 'question', 'label': 'Question'},
    {'value': 'feedback', 'label': 'Feedback'},
    {'value': 'other', 'label': 'Other'},
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      SnackbarUtils.showError(context, 'Please select a category');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await SupportTicketService.submitTicket(
        category: _selectedCategory!,
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
      );

      if (mounted) {
        if (result.success && result.ticket != null) {
          // Show success with ticket number
          _showSuccessDialog(result.ticket!.ticketNumber ?? 'N/A');
          
          // Clear form
          _subjectController.clear();
          _messageController.clear();
          setState(() {
            _selectedCategory = null;
          });
        } else {
          SnackbarUtils.showError(
            context,
            result.error ?? 'Failed to submit ticket',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'An error occurred. Please try again.');
        await ErrorLoggingService.logHighError(
          errorCode: 'ERRSYS124',
          errorMessage: 'Help support screen error: ${e.toString()}',
          stackTrace: StackTrace.current.toString(),
          errorContext: {
            'screen': 'HelpSupportScreen',
            'operation': 'submit_ticket',
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSuccessDialog(String ticketNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Ticket Submitted'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your ticket has been submitted successfully!'),
            const SizedBox(height: 16),
            Text(
              'Ticket Number:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              ticketNumber,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'We will respond within 24-48 hours.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to profile
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isTablet ? 32 : 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 800 : double.infinity,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Info
                _buildInfoSection(context),
                const SizedBox(height: 24),

                // Category Dropdown
                _buildCategoryDropdown(context),
                const SizedBox(height: 20),

                // Subject Input
                _buildSubjectInput(context),
                const SizedBox(height: 20),

                // Message Input
                _buildMessageInput(context),
                const SizedBox(height: 24),

                // Submit Button
                _buildSubmitButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.blue[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Need Help?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'We\'re here to help! Submit your ticket and we\'ll respond within 24-48 hours.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.blue[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category *',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: InputDecoration(
            hintText: 'Select a category',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          items: _categories.map((category) {
            return DropdownMenuItem<String>(
              value: category['value'],
              child: Text(category['label']!),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCategory = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a category';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubjectInput(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subject *',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _subjectController,
          decoration: InputDecoration(
            hintText: 'Brief description of your issue',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          maxLength: 100,
          textCapitalization: TextCapitalization.sentences,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a subject';
            }
            if (value.trim().length < 5) {
              return 'Subject must be at least 5 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildMessageInput(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Message *',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _messageController,
          decoration: InputDecoration(
            hintText: 'Describe your issue or question in detail',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          maxLines: 8,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a message';
            }
            if (value.trim().length < 10) {
              return 'Message must be at least 10 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitTicket,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text(
                'Submit Ticket',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
```

---

### **Step 4: Update Profile Screen Navigation**

**File:** `lib/screens/profile_screen.dart`

**Change:** Update Help & Support button callback to navigate to new screen

**Code Change:**
```dart
// Add import at top
import 'help_support_screen.dart';

// Update button callback (around line 254-259)
_buildActionTile(
  context,
  Icons.help_outline,
  'Help & Support',
  () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HelpSupportScreen(),
      ),
    );
  },
),
```

---

## **✅ IMPLEMENTATION CHECKLIST**

### **Model Updates**
- [ ] Update `SupportTicket` model with `ticketNumber` field
- [ ] Update `SupportTicket` model with `category` field
- [ ] Update `fromJson()` method
- [ ] Update `toJson()` method

### **Service Creation**
- [ ] Create `lib/services/support_ticket_service.dart`
- [ ] Implement `submitTicket()` method
- [ ] Implement `getUserTickets()` method (optional)
- [ ] Add error handling and logging
- [ ] Add input validation

### **Screen Creation**
- [ ] Create `lib/screens/help_support_screen.dart`
- [ ] Implement form with category dropdown
- [ ] Implement subject input with validation
- [ ] Implement message textarea with validation
- [ ] Add character counters
- [ ] Implement submit button with loading state
- [ ] Add success dialog with ticket number
- [ ] Add error handling

### **Navigation**
- [ ] Update Profile screen import
- [ ] Update Help & Support button callback
- [ ] Test navigation flow

### **Testing**
- [ ] Test form validation
- [ ] Test ticket submission
- [ ] Test success dialog
- [ ] Test error handling
- [ ] Test character limits
- [ ] Test empty form submission
- [ ] Test network error scenarios

---

## **🎨 UI DESIGN SPECIFICATIONS**

### **Color Scheme**
- Primary: Theme primary color
- Info Card: Blue background (`Colors.blue[50]`)
- Success: Green
- Error: Red (via SnackbarUtils)

### **Typography**
- Headers: `titleMedium`, `titleSmall` with `FontWeight.w600`
- Body: `bodyMedium`, `bodySmall`
- Input labels: `titleSmall` with `FontWeight.w600`

### **Spacing**
- Screen padding: 16px (mobile), 32px (tablet)
- Section spacing: 20-24px
- Input padding: 16px horizontal, 14px vertical

### **Components**
- Cards: Rounded corners (12px)
- Inputs: Rounded borders (12px)
- Buttons: Full width, rounded (12px)
- Dropdown: Standard Material design

---

## **📱 RESPONSIVE DESIGN**

- **Mobile (< 600px):** Full width, standard padding
- **Tablet (≥ 600px):** Max width 800px, centered, increased padding
- **Form fields:** Adapt to screen size

---

## **🔒 VALIDATION RULES**

### **Category**
- Required
- Must be one of: bug, feature, question, feedback, other

### **Subject**
- Required
- Min length: 5 characters
- Max length: 100 characters
- Trim whitespace

### **Message**
- Required
- Min length: 10 characters
- Max length: 2000 characters
- Trim whitespace

---

## **📊 ERROR HANDLING**

### **Error Codes**
- `ERRSYS122`: Ticket submission failed
- `ERRSYS123`: Fetch user tickets failed
- `ERRSYS124`: Help support screen error

### **Error Scenarios**
1. **User not authenticated:** Show error, prevent submission
2. **Network error:** Show error message, log error
3. **Validation error:** Show inline validation messages
4. **Database error:** Show generic error, log detailed error

---

## **✨ SUCCESS FLOW**

1. User fills form
2. User taps "Submit Ticket"
3. Form validates
4. Loading indicator shows
5. Ticket submitted to database
6. Trigger generates ticket number
7. Success dialog shows with ticket number
8. Form clears
9. User can close dialog and return to profile

---

## **🚀 DEPLOYMENT CHECKLIST**

- [ ] All code implemented
- [ ] All imports added
- [ ] No linter errors
- [ ] Form validation working
- [ ] Error handling working
- [ ] Success flow working
- [ ] UI matches design specifications
- [ ] Responsive design tested
- [ ] Error logging working

---

## **📝 NOTES**

- **Ticket Number:** Auto-generated by database trigger (TKT-000001 format)
- **Category:** Required field, dropdown selection
- **Character Limits:** Enforced in both UI and service
- **Success Dialog:** Shows ticket number for user reference
- **Error Logging:** All errors logged with context
- **Future Enhancement:** "My Tickets" list can be added later

---

**Status:** Ready for Implementation  
**Estimated Time:** 2-3 hours  
**Risk Level:** LOW (new feature, no breaking changes)

