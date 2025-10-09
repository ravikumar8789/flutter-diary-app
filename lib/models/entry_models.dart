/// Main entry model matching the entries table
class Entry {
  final String id;
  final String userId;
  final DateTime entryDate;
  final String? diaryText;
  final int? moodScore;
  final List<String> tags;
  final EntrySource source;
  final bool isBackdated;
  final DateTime createdAt;
  final DateTime updatedAt;

  Entry({
    required this.id,
    required this.userId,
    required this.entryDate,
    this.diaryText,
    this.moodScore,
    this.tags = const [],
    this.source = EntrySource.mobile,
    this.isBackdated = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      entryDate: DateTime.parse(json['entry_date'] as String),
      diaryText: json['diary_text'] as String?,
      moodScore: json['mood_score'] as int?,
      tags: List<String>.from(json['tags'] as List? ?? []),
      source: EntrySource.fromString(json['source'] as String?),
      isBackdated: json['is_backdated'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'entry_date': entryDate.toIso8601String().split('T')[0], // Date only
      'diary_text': diaryText,
      'mood_score': moodScore,
      'tags': tags,
      'source': source.value,
      'is_backdated': isBackdated,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Entry affirmations model matching the entry_affirmations table
class EntryAffirmations {
  final String entryId;
  final String? a1;
  final String? a2;
  final String? a3;
  final String? a4;
  final String? a5;

  EntryAffirmations({
    required this.entryId,
    this.a1,
    this.a2,
    this.a3,
    this.a4,
    this.a5,
  });

  factory EntryAffirmations.fromJson(Map<String, dynamic> json) {
    return EntryAffirmations(
      entryId: json['entry_id'] as String,
      a1: json['a1'] as String?,
      a2: json['a2'] as String?,
      a3: json['a3'] as String?,
      a4: json['a4'] as String?,
      a5: json['a5'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entry_id': entryId,
      'a1': a1,
      'a2': a2,
      'a3': a3,
      'a4': a4,
      'a5': a5,
    };
  }
}

/// Entry priorities model matching the entry_priorities table
class EntryPriorities {
  final String entryId;
  final String? p1;
  final String? p2;
  final String? p3;
  final String? p4;
  final String? p5;
  final String? p6;

  EntryPriorities({
    required this.entryId,
    this.p1,
    this.p2,
    this.p3,
    this.p4,
    this.p5,
    this.p6,
  });

  factory EntryPriorities.fromJson(Map<String, dynamic> json) {
    return EntryPriorities(
      entryId: json['entry_id'] as String,
      p1: json['p1'] as String?,
      p2: json['p2'] as String?,
      p3: json['p3'] as String?,
      p4: json['p4'] as String?,
      p5: json['p5'] as String?,
      p6: json['p6'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entry_id': entryId,
      'p1': p1,
      'p2': p2,
      'p3': p3,
      'p4': p4,
      'p5': p5,
      'p6': p6,
    };
  }
}

/// Entry meals model matching the entry_meals table
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

  factory EntryMeals.fromJson(Map<String, dynamic> json) {
    return EntryMeals(
      entryId: json['entry_id'] as String,
      breakfast: json['breakfast'] as String?,
      lunch: json['lunch'] as String?,
      dinner: json['dinner'] as String?,
      waterCups: json['water_cups'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entry_id': entryId,
      'breakfast': breakfast,
      'lunch': lunch,
      'dinner': dinner,
      'water_cups': waterCups,
    };
  }
}

/// Entry gratitude model matching the entry_gratitude table
class EntryGratitude {
  final String entryId;
  final String? g1;
  final String? g2;
  final String? g3;
  final String? g4;
  final String? g5;
  final String? g6;

  EntryGratitude({
    required this.entryId,
    this.g1,
    this.g2,
    this.g3,
    this.g4,
    this.g5,
    this.g6,
  });

  factory EntryGratitude.fromJson(Map<String, dynamic> json) {
    return EntryGratitude(
      entryId: json['entry_id'] as String,
      g1: json['g1'] as String?,
      g2: json['g2'] as String?,
      g3: json['g3'] as String?,
      g4: json['g4'] as String?,
      g5: json['g5'] as String?,
      g6: json['g6'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entry_id': entryId,
      'g1': g1,
      'g2': g2,
      'g3': g3,
      'g4': g4,
      'g5': g5,
      'g6': g6,
    };
  }
}

/// Entry self-care model matching the entry_self_care table
class EntrySelfCare {
  final String entryId;
  final bool? sleep;
  final bool? getUpEarly;
  final bool? freshAir;
  final bool? learnNew;
  final bool? balancedDiet;
  final bool? podcast;
  final bool? meMoment;
  final bool? hydrated;
  final bool? readBook;
  final bool? exercise;

  EntrySelfCare({
    required this.entryId,
    this.sleep,
    this.getUpEarly,
    this.freshAir,
    this.learnNew,
    this.balancedDiet,
    this.podcast,
    this.meMoment,
    this.hydrated,
    this.readBook,
    this.exercise,
  });

  factory EntrySelfCare.fromJson(Map<String, dynamic> json) {
    return EntrySelfCare(
      entryId: json['entry_id'] as String,
      sleep: json['sleep'] as bool?,
      getUpEarly: json['get_up_early'] as bool?,
      freshAir: json['fresh_air'] as bool?,
      learnNew: json['learn_new'] as bool?,
      balancedDiet: json['balanced_diet'] as bool?,
      podcast: json['podcast'] as bool?,
      meMoment: json['me_moment'] as bool?,
      hydrated: json['hydrated'] as bool?,
      readBook: json['read_book'] as bool?,
      exercise: json['exercise'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entry_id': entryId,
      'sleep': sleep,
      'get_up_early': getUpEarly,
      'fresh_air': freshAir,
      'learn_new': learnNew,
      'balanced_diet': balancedDiet,
      'podcast': podcast,
      'me_moment': meMoment,
      'hydrated': hydrated,
      'read_book': readBook,
      'exercise': exercise,
    };
  }
}

/// Entry shower/bath model matching the entry_shower_bath table
class EntryShowerBath {
  final String entryId;
  final bool tookShower;
  final String? note;

  EntryShowerBath({required this.entryId, this.tookShower = false, this.note});

  factory EntryShowerBath.fromJson(Map<String, dynamic> json) {
    return EntryShowerBath(
      entryId: json['entry_id'] as String,
      tookShower: json['took_shower'] as bool? ?? false,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'entry_id': entryId, 'took_shower': tookShower, 'note': note};
  }
}

/// Entry tomorrow notes model matching the entry_tomorrow_notes table
class EntryTomorrowNotes {
  final String entryId;
  final String? n1;
  final String? n2;
  final String? n3;
  final String? n4;

  EntryTomorrowNotes({
    required this.entryId,
    this.n1,
    this.n2,
    this.n3,
    this.n4,
  });

  factory EntryTomorrowNotes.fromJson(Map<String, dynamic> json) {
    return EntryTomorrowNotes(
      entryId: json['entry_id'] as String,
      n1: json['n1'] as String?,
      n2: json['n2'] as String?,
      n3: json['n3'] as String?,
      n4: json['n4'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'entry_id': entryId, 'n1': n1, 'n2': n2, 'n3': n3, 'n4': n4};
  }
}

/// Entry source enum
enum EntrySource {
  mobile('mobile'),
  web('web'),
  import('import');

  const EntrySource(this.value);
  final String value;

  static EntrySource fromString(String? value) {
    switch (value) {
      case 'web':
        return EntrySource.web;
      case 'import':
        return EntrySource.import;
      default:
        return EntrySource.mobile;
    }
  }
}
