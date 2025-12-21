import 'settings_models.dart';

/// Prompt model matching the prompts table
class Prompt {
  final String id;
  final String text;
  final String? category;
  final String? locale;
  final bool active;

  Prompt({
    required this.id,
    required this.text,
    this.category,
    this.locale,
    this.active = true,
  });

  factory Prompt.fromJson(Map<String, dynamic> json) {
    return Prompt(
      id: json['id'] as String,
      text: json['text'] as String,
      category: json['category'] as String?,
      locale: json['locale'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'category': category,
      'locale': locale,
      'active': active,
    };
  }
}

/// Prompt assignment model matching the prompt_assignments table
class PromptAssignment {
  final String id;
  final String userId;
  final String promptId;
  final DateTime assignedForDate;
  final bool completed;

  PromptAssignment({
    required this.id,
    required this.userId,
    required this.promptId,
    required this.assignedForDate,
    this.completed = false,
  });

  factory PromptAssignment.fromJson(Map<String, dynamic> json) {
    return PromptAssignment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      promptId: json['prompt_id'] as String,
      assignedForDate: DateTime.parse(json['assigned_for_date'] as String),
      completed: json['completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'prompt_id': promptId,
      'assigned_for_date': assignedForDate.toIso8601String().split(
        'T',
      )[0], // Date only
      'completed': completed,
    };
  }
}

/// Attachment model matching the attachments table
class Attachment {
  final String id;
  final String userId;
  final String? entryId;
  final String fileUrl;
  final AttachmentKind kind;
  final int? bytes;
  final DateTime createdAt;

  Attachment({
    required this.id,
    required this.userId,
    this.entryId,
    required this.fileUrl,
    required this.kind,
    this.bytes,
    required this.createdAt,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      entryId: json['entry_id'] as String?,
      fileUrl: json['file_url'] as String,
      kind: AttachmentKind.fromString(json['kind'] as String),
      bytes: json['bytes'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'entry_id': entryId,
      'file_url': fileUrl,
      'kind': kind.value,
      'bytes': bytes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Data export model matching the data_exports table
class DataExport {
  final String id;
  final String userId;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final String? downloadUrl;
  final ExportFormat format;

  DataExport({
    required this.id,
    required this.userId,
    required this.requestedAt,
    this.completedAt,
    this.downloadUrl,
    this.format = ExportFormat.json,
  });

  factory DataExport.fromJson(Map<String, dynamic> json) {
    return DataExport(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      requestedAt: DateTime.parse(json['requested_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      downloadUrl: json['download_url'] as String?,
      format: ExportFormat.fromString(json['format'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'requested_at': requestedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'download_url': downloadUrl,
      'format': format.value,
    };
  }
}

/// Data deletion model matching the data_deletions table
class DataDeletion {
  final String id;
  final String userId;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final DeletionStatus status;

  DataDeletion({
    required this.id,
    required this.userId,
    required this.requestedAt,
    this.processedAt,
    this.status = DeletionStatus.pending,
  });

  factory DataDeletion.fromJson(Map<String, dynamic> json) {
    return DataDeletion(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      requestedAt: DateTime.parse(json['requested_at'] as String),
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'] as String)
          : null,
      status: DeletionStatus.fromString(json['status'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'requested_at': requestedAt.toIso8601String(),
      'processed_at': processedAt?.toIso8601String(),
      'status': status.value,
    };
  }
}

/// Support ticket model matching the support_tickets table
class SupportTicket {
  final String id;
  final String? userId;
  final String? ticketNumber;
  final String? category;
  final String? subject;
  final String? message;
  final String? email;
  final String? appVersion;
  final Map<String, dynamic>? deviceInfo;
  final String? closureNote;
  final TicketStatus status;
  final DateTime createdAt;
  final DateTime? closedAt;

  SupportTicket({
    required this.id,
    this.userId,
    this.ticketNumber,
    this.category,
    this.subject,
    this.message,
    this.email,
    this.appVersion,
    this.deviceInfo,
    this.closureNote,
    this.status = TicketStatus.open,
    required this.createdAt,
    this.closedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      ticketNumber: json['ticket_number'] as String?,
      category: json['category'] as String?,
      subject: json['subject'] as String?,
      message: json['message'] as String?,
      email: json['email'] as String?,
      appVersion: json['app_version'] as String?,
      deviceInfo: json['device_info'] as Map<String, dynamic>?,
      closureNote: json['closure_note'] as String?,
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
      'ticket_number': ticketNumber,
      'category': category,
      'subject': subject,
      'message': message,
      'email': email,
      'app_version': appVersion,
      'device_info': deviceInfo,
      'closure_note': closureNote,
      'status': status.value,
      'created_at': createdAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
    };
  }
}

/// Attachment kind enum
enum AttachmentKind {
  image('image'),
  audio('audio'),
  pdf('pdf');

  const AttachmentKind(this.value);
  final String value;

  static AttachmentKind fromString(String value) {
    switch (value) {
      case 'image':
        return AttachmentKind.image;
      case 'audio':
        return AttachmentKind.audio;
      case 'pdf':
        return AttachmentKind.pdf;
      default:
        return AttachmentKind.image;
    }
  }
}

/// Deletion status enum
enum DeletionStatus {
  pending('pending'),
  completed('completed'),
  failed('failed');

  const DeletionStatus(this.value);
  final String value;

  static DeletionStatus fromString(String? value) {
    switch (value) {
      case 'completed':
        return DeletionStatus.completed;
      case 'failed':
        return DeletionStatus.failed;
      default:
        return DeletionStatus.pending;
    }
  }
}

/// Ticket status enum
enum TicketStatus {
  open('open'),
  closed('closed');

  const TicketStatus(this.value);
  final String value;

  static TicketStatus fromString(String? value) {
    switch (value) {
      case 'closed':
        return TicketStatus.closed;
      default:
        return TicketStatus.open;
    }
  }
}
