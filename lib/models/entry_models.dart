import 'dart:convert';

// Main Entry model
class Entry {
  final String id;
  final String userId;
  final DateTime entryDate;
  final String? diaryText;
  final int? moodScore;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final DateTime? lastSyncAt;

  Entry({
    required this.id,
    required this.userId,
    required this.entryDate,
    this.diaryText,
    this.moodScore,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.lastSyncAt,
  });

  // Convert to JSON for local SQLite storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'entry_date': entryDate.toIso8601String().split(
        'T',
      )[0], // YYYY-MM-DD format
      'diary_text': diaryText,
      'mood_score': moodScore,
      'tags': jsonEncode(tags),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'last_sync_at': lastSyncAt?.toIso8601String(),
    };
  }

  // Convert from JSON (local SQLite)
  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      id: json['id'],
      userId: json['user_id'],
      entryDate: DateTime.parse(json['entry_date']),
      diaryText: json['diary_text'],
      moodScore: json['mood_score'],
      tags: json['tags'] != null
          ? List<String>.from(jsonDecode(json['tags']))
          : [],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      isSynced: json['is_synced'] == 1,
      lastSyncAt: json['last_sync_at'] != null
          ? DateTime.parse(json['last_sync_at'])
          : null,
    );
  }

  // Convert to Supabase JSON format
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'user_id': userId,
      'entry_date': entryDate.toIso8601String().split('T')[0],
      'diary_text': diaryText,
      'mood_score': moodScore,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Convert from Supabase JSON
  factory Entry.fromSupabaseJson(Map<String, dynamic> json) {
    return Entry(
      id: json['id'],
      userId: json['user_id'],
      entryDate: DateTime.parse(json['entry_date']),
      diaryText: json['diary_text'],
      moodScore: json['mood_score'],
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      isSynced: true, // Data from Supabase is always synced
      lastSyncAt: DateTime.now(),
    );
  }

  // Copy with method for updates
  Entry copyWith({
    String? id,
    String? userId,
    DateTime? entryDate,
    String? diaryText,
    int? moodScore,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    DateTime? lastSyncAt,
  }) {
    return Entry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      entryDate: entryDate ?? this.entryDate,
      diaryText: diaryText ?? this.diaryText,
      moodScore: moodScore ?? this.moodScore,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}

// Affirmation Item model
class AffirmationItem {
  final String text;
  final int order;

  AffirmationItem({required this.text, required this.order});

  Map<String, dynamic> toJson() => {'text': text, 'order': order};

  factory AffirmationItem.fromJson(Map<String, dynamic> json) {
    return AffirmationItem(text: json['text'] ?? '', order: json['order'] ?? 0);
  }
}

// Entry Affirmations model
class EntryAffirmations {
  final String entryId;
  final List<AffirmationItem> affirmations;

  EntryAffirmations({required this.entryId, required this.affirmations});

  Map<String, dynamic> toJson() => {
    'entry_id': entryId,
    'affirmations': jsonEncode(affirmations.map((a) => a.toJson()).toList()),
  };

  factory EntryAffirmations.fromJson(Map<String, dynamic> json) {
    final affirmationsList = json['affirmations'] != null
        ? (jsonDecode(json['affirmations']) as List)
              .map((item) => AffirmationItem.fromJson(item))
              .toList()
        : <AffirmationItem>[];

    return EntryAffirmations(
      entryId: json['entry_id'],
      affirmations: affirmationsList,
    );
  }

  // For Supabase JSONB format
  Map<String, dynamic> toSupabaseJson() => {
    'entry_id': entryId,
    'affirmations': affirmations.map((a) => a.toJson()).toList(),
  };

  factory EntryAffirmations.fromSupabaseJson(Map<String, dynamic> json) {
    final affirmationsList =
        (json['affirmations'] as List?)
            ?.map((item) => AffirmationItem.fromJson(item))
            .toList() ??
        <AffirmationItem>[];

    return EntryAffirmations(
      entryId: json['entry_id'],
      affirmations: affirmationsList,
    );
  }
}

// Priority Item model
class PriorityItem {
  final String text;
  final int order;

  PriorityItem({required this.text, required this.order});

  Map<String, dynamic> toJson() => {'text': text, 'order': order};

  factory PriorityItem.fromJson(Map<String, dynamic> json) {
    return PriorityItem(text: json['text'] ?? '', order: json['order'] ?? 0);
  }
}

// Entry Priorities model
class EntryPriorities {
  final String entryId;
  final List<PriorityItem> priorities;

  EntryPriorities({required this.entryId, required this.priorities});

  Map<String, dynamic> toJson() => {
    'entry_id': entryId,
    'priorities': jsonEncode(priorities.map((p) => p.toJson()).toList()),
  };

  factory EntryPriorities.fromJson(Map<String, dynamic> json) {
    final prioritiesList = json['priorities'] != null
        ? (jsonDecode(json['priorities']) as List)
              .map((item) => PriorityItem.fromJson(item))
              .toList()
        : <PriorityItem>[];

    return EntryPriorities(
      entryId: json['entry_id'],
      priorities: prioritiesList,
    );
  }

  Map<String, dynamic> toSupabaseJson() => {
    'entry_id': entryId,
    'priorities': priorities.map((p) => p.toJson()).toList(),
  };

  factory EntryPriorities.fromSupabaseJson(Map<String, dynamic> json) {
    final prioritiesList =
        (json['priorities'] as List?)
            ?.map((item) => PriorityItem.fromJson(item))
            .toList() ??
        <PriorityItem>[];

    return EntryPriorities(
      entryId: json['entry_id'],
      priorities: prioritiesList,
    );
  }
}

// Entry Meals model
class EntryMeals {
  final String entryId;
  final String? breakfast;
  final String? lunch;
  final String? dinner;
  final int waterCups;

  EntryMeals({
    required this.entryId,
    this.breakfast,
    this.lunch,
    this.dinner,
    this.waterCups = 0,
  });

  Map<String, dynamic> toJson() => {
    'entry_id': entryId,
    'breakfast': breakfast,
    'lunch': lunch,
    'dinner': dinner,
    'water_cups': waterCups,
  };

  factory EntryMeals.fromJson(Map<String, dynamic> json) {
    return EntryMeals(
      entryId: json['entry_id'],
      breakfast: json['breakfast'],
      lunch: json['lunch'],
      dinner: json['dinner'],
      waterCups: json['water_cups'] ?? 0,
    );
  }
}

// Gratitude Item model
class GratitudeItem {
  final String text;
  final int order;

  GratitudeItem({required this.text, required this.order});

  Map<String, dynamic> toJson() => {'text': text, 'order': order};

  factory GratitudeItem.fromJson(Map<String, dynamic> json) {
    return GratitudeItem(text: json['text'] ?? '', order: json['order'] ?? 0);
  }
}

// Entry Gratitude model
class EntryGratitude {
  final String entryId;
  final List<GratitudeItem> gratefulItems;

  EntryGratitude({required this.entryId, required this.gratefulItems});

  Map<String, dynamic> toJson() => {
    'entry_id': entryId,
    'grateful_items': jsonEncode(gratefulItems.map((g) => g.toJson()).toList()),
  };

  factory EntryGratitude.fromJson(Map<String, dynamic> json) {
    final gratefulItemsList = json['grateful_items'] != null
        ? (jsonDecode(json['grateful_items']) as List)
              .map((item) => GratitudeItem.fromJson(item))
              .toList()
        : <GratitudeItem>[];

    return EntryGratitude(
      entryId: json['entry_id'],
      gratefulItems: gratefulItemsList,
    );
  }

  Map<String, dynamic> toSupabaseJson() => {
    'entry_id': entryId,
    'grateful_items': gratefulItems.map((g) => g.toJson()).toList(),
  };

  factory EntryGratitude.fromSupabaseJson(Map<String, dynamic> json) {
    final gratefulItemsList =
        (json['grateful_items'] as List?)
            ?.map((item) => GratitudeItem.fromJson(item))
            .toList() ??
        <GratitudeItem>[];

    return EntryGratitude(
      entryId: json['entry_id'],
      gratefulItems: gratefulItemsList,
    );
  }
}

// Entry Self Care model
class EntrySelfCare {
  final String entryId;
  final bool sleep;
  final bool getUpEarly;
  final bool freshAir;
  final bool learnNew;
  final bool balancedDiet;
  final bool podcast;
  final bool meMoment;
  final bool hydrated;
  final bool readBook;
  final bool exercise;

  EntrySelfCare({
    required this.entryId,
    this.sleep = false,
    this.getUpEarly = false,
    this.freshAir = false,
    this.learnNew = false,
    this.balancedDiet = false,
    this.podcast = false,
    this.meMoment = false,
    this.hydrated = false,
    this.readBook = false,
    this.exercise = false,
  });

  Map<String, dynamic> toJson() => {
    'entry_id': entryId,
    'sleep': sleep ? 1 : 0,
    'get_up_early': getUpEarly ? 1 : 0,
    'fresh_air': freshAir ? 1 : 0,
    'learn_new': learnNew ? 1 : 0,
    'balanced_diet': balancedDiet ? 1 : 0,
    'podcast': podcast ? 1 : 0,
    'me_moment': meMoment ? 1 : 0,
    'hydrated': hydrated ? 1 : 0,
    'read_book': readBook ? 1 : 0,
    'exercise': exercise ? 1 : 0,
  };

  factory EntrySelfCare.fromJson(Map<String, dynamic> json) {
    return EntrySelfCare(
      entryId: json['entry_id'],
      sleep: json['sleep'] == 1,
      getUpEarly: json['get_up_early'] == 1,
      freshAir: json['fresh_air'] == 1,
      learnNew: json['learn_new'] == 1,
      balancedDiet: json['balanced_diet'] == 1,
      podcast: json['podcast'] == 1,
      meMoment: json['me_moment'] == 1,
      hydrated: json['hydrated'] == 1,
      readBook: json['read_book'] == 1,
      exercise: json['exercise'] == 1,
    );
  }
}

// Entry Shower Bath model
class EntryShowerBath {
  final String entryId;
  final bool tookShower;
  final String? note;

  EntryShowerBath({required this.entryId, this.tookShower = false, this.note});

  Map<String, dynamic> toJson() => {
    'entry_id': entryId,
    'took_shower': tookShower ? 1 : 0,
    'note': note,
  };

  factory EntryShowerBath.fromJson(Map<String, dynamic> json) {
    return EntryShowerBath(
      entryId: json['entry_id'],
      tookShower: json['took_shower'] == 1,
      note: json['note'],
    );
  }
}

// Tomorrow Note Item model
class TomorrowNoteItem {
  final String text;
  final int order;

  TomorrowNoteItem({required this.text, required this.order});

  Map<String, dynamic> toJson() => {'text': text, 'order': order};

  factory TomorrowNoteItem.fromJson(Map<String, dynamic> json) {
    return TomorrowNoteItem(
      text: json['text'] ?? '',
      order: json['order'] ?? 0,
    );
  }
}

// Entry Tomorrow Notes model
class EntryTomorrowNotes {
  final String entryId;
  final List<TomorrowNoteItem> tomorrowNotes;

  EntryTomorrowNotes({required this.entryId, required this.tomorrowNotes});

  Map<String, dynamic> toJson() => {
    'entry_id': entryId,
    'tomorrow_notes': jsonEncode(tomorrowNotes.map((t) => t.toJson()).toList()),
  };

  factory EntryTomorrowNotes.fromJson(Map<String, dynamic> json) {
    final tomorrowNotesList = json['tomorrow_notes'] != null
        ? (jsonDecode(json['tomorrow_notes']) as List)
              .map((item) => TomorrowNoteItem.fromJson(item))
              .toList()
        : <TomorrowNoteItem>[];

    return EntryTomorrowNotes(
      entryId: json['entry_id'],
      tomorrowNotes: tomorrowNotesList,
    );
  }

  Map<String, dynamic> toSupabaseJson() => {
    'entry_id': entryId,
    'tomorrow_notes': tomorrowNotes.map((t) => t.toJson()).toList(),
  };

  factory EntryTomorrowNotes.fromSupabaseJson(Map<String, dynamic> json) {
    final tomorrowNotesList =
        (json['tomorrow_notes'] as List?)
            ?.map((item) => TomorrowNoteItem.fromJson(item))
            .toList() ??
        <TomorrowNoteItem>[];

    return EntryTomorrowNotes(
      entryId: json['entry_id'],
      tomorrowNotes: tomorrowNotesList,
    );
  }
}
