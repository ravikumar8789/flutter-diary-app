import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/entry_models.dart';

class SupabaseSyncService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Sync entry to Supabase
  Future<bool> syncEntry(Entry entry) async {
    try {
      await _supabase.from('entries').upsert(entry.toSupabaseJson());
      return true;
    } catch (e) {
      return false;
    }
  }

  // Sync affirmations to Supabase (JSONB format)
  Future<bool> syncAffirmations(EntryAffirmations affirmations) async {
    try {
      await _supabase.from('entry_affirmations').upsert({
        'entry_id': affirmations.entryId,
        'affirmations': affirmations.affirmations
            .map((a) => a.toJson())
            .toList(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Sync priorities to Supabase (JSONB format)
  Future<bool> syncPriorities(EntryPriorities priorities) async {
    try {
      await _supabase.from('entry_priorities').upsert({
        'entry_id': priorities.entryId,
        'priorities': priorities.priorities.map((p) => p.toJson()).toList(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Sync meals to Supabase
  Future<bool> syncMeals(EntryMeals meals) async {
    try {
      await _supabase.from('entry_meals').upsert(meals.toJson());
      return true;
    } catch (e) {
      return false;
    }
  }

  // Sync gratitude to Supabase (JSONB format)
  Future<bool> syncGratitude(EntryGratitude gratitude) async {
    try {
      await _supabase.from('entry_gratitude').upsert({
        'entry_id': gratitude.entryId,
        'grateful_items': gratitude.gratefulItems
            .map((g) => g.toJson())
            .toList(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Sync self care to Supabase
  Future<bool> syncSelfCare(EntrySelfCare selfCare) async {
    try {
      await _supabase.from('entry_self_care').upsert(selfCare.toJson());
      return true;
    } catch (e) {
      return false;
    }
  }

  // Sync shower bath to Supabase
  Future<bool> syncShowerBath(EntryShowerBath showerBath) async {
    try {
      await _supabase.from('entry_shower_bath').upsert(showerBath.toJson());
      return true;
    } catch (e) {
      return false;
    }
  }

  // Sync tomorrow notes to Supabase (JSONB format)
  Future<bool> syncTomorrowNotes(EntryTomorrowNotes tomorrowNotes) async {
    try {
      await _supabase.from('entry_tomorrow_notes').upsert({
        'entry_id': tomorrowNotes.entryId,
        'tomorrow_notes': tomorrowNotes.tomorrowNotes
            .map((t) => t.toJson())
            .toList(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Pull latest data from Supabase (for multi-device sync)
  Future<Entry?> fetchEntryFromCloud(String userId, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    try {
      final response = await _supabase
          .from('entries')
          .select()
          .eq('user_id', userId)
          .eq('entry_date', dateStr)
          .maybeSingle();

      if (response == null) return null;
      return Entry.fromSupabaseJson(response);
    } catch (e) {
      return null;
    }
  }

  // Fetch affirmations from cloud
  Future<EntryAffirmations?> fetchAffirmationsFromCloud(String entryId) async {
    try {
      final response = await _supabase
          .from('entry_affirmations')
          .select()
          .eq('entry_id', entryId)
          .maybeSingle();

      if (response == null) return null;
      return EntryAffirmations.fromSupabaseJson(response);
    } catch (e) {
      return null;
    }
  }

  // Fetch priorities from cloud
  Future<EntryPriorities?> fetchPrioritiesFromCloud(String entryId) async {
    try {
      final response = await _supabase
          .from('entry_priorities')
          .select()
          .eq('entry_id', entryId)
          .maybeSingle();

      if (response == null) return null;
      return EntryPriorities.fromSupabaseJson(response);
    } catch (e) {
      return null;
    }
  }

  // Fetch meals from cloud
  Future<EntryMeals?> fetchMealsFromCloud(String entryId) async {
    try {
      final response = await _supabase
          .from('entry_meals')
          .select()
          .eq('entry_id', entryId)
          .maybeSingle();

      if (response == null) return null;
      return EntryMeals.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Fetch gratitude from cloud
  Future<EntryGratitude?> fetchGratitudeFromCloud(String entryId) async {
    try {
      final response = await _supabase
          .from('entry_gratitude')
          .select()
          .eq('entry_id', entryId)
          .maybeSingle();

      if (response == null) return null;
      return EntryGratitude.fromSupabaseJson(response);
    } catch (e) {
      return null;
    }
  }

  // Fetch self care from cloud
  Future<EntrySelfCare?> fetchSelfCareFromCloud(String entryId) async {
    try {
      final response = await _supabase
          .from('entry_self_care')
          .select()
          .eq('entry_id', entryId)
          .maybeSingle();

      if (response == null) return null;
      return EntrySelfCare.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Fetch shower bath from cloud
  Future<EntryShowerBath?> fetchShowerBathFromCloud(String entryId) async {
    try {
      final response = await _supabase
          .from('entry_shower_bath')
          .select()
          .eq('entry_id', entryId)
          .maybeSingle();

      if (response == null) return null;
      return EntryShowerBath.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Fetch tomorrow notes from cloud
  Future<EntryTomorrowNotes?> fetchTomorrowNotesFromCloud(
    String entryId,
  ) async {
    try {
      final response = await _supabase
          .from('entry_tomorrow_notes')
          .select()
          .eq('entry_id', entryId)
          .maybeSingle();

      if (response == null) return null;
      return EntryTomorrowNotes.fromSupabaseJson(response);
    } catch (e) {
      return null;
    }
  }

  // Process sync queue (for offline changes)
  Future<void> processSyncQueue() async {
    // This will be implemented in Phase 7 with the sync worker
  }
}
