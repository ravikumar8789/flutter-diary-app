/// Service for providing dynamic motivational messages based on user's streak
/// 
/// Messages rotate daily using hash-based selection to ensure:
/// - Same message for entire session (same day)
/// - Different message each day (variety)
/// - All messages in range shown over time
class StreakMotivationService {
  // Message library organized by streak ranges
  static final Map<String, List<String>> _messages = {
    '0': [
      "🌟 Every journey begins with a single step!",
      "✨ Ready to start your streak today?",
      "💫 Your first entry is just a tap away!",
    ],
    '1': [
      "🎉 Great start! Keep the momentum going!",
      "✨ Day one done! You're building something amazing!",
      "🌟 You've taken the first step! Keep it up!",
    ],
    '2-3': [
      "🔥 You're building a habit! Keep going!",
      "💪 Two days strong! You're on the right track!",
      "✨ Consistency is key! You're doing great!",
    ],
    '4-7': [
      "🔥 You're on fire! Keep it going!",
      "💪 A week of reflection! Amazing progress!",
      "🌟 You're building a powerful habit!",
    ],
    '8-14': [
      "🔥 Two weeks strong! You're unstoppable!",
      "💫 Your consistency is inspiring!",
      "✨ You're creating a beautiful routine!",
    ],
    '15-30': [
      "🔥 Three weeks! You're unstoppable!",
      "💪 A month of growth! Incredible dedication!",
      "🌟 You're building something special!",
    ],
    '31-60': [
      "🔥 Over a month! You're a journaling champion!",
      "💫 Your commitment is inspiring!",
      "✨ Two months strong! Keep the fire burning!",
    ],
    '61+': [
      "🔥 You're a journaling master! Keep it going!",
      "💪 Your dedication is incredible!",
      "🌟 You're an inspiration! Keep shining!",
    ],
  };

  /// Get motivational message for current streak
  /// 
  /// Uses hash(streak + day) to select message consistently for the day.
  /// Same streak + same day = same message (stable for session).
  /// Different day = different message (variety over time).
  static String getMotivationalMessage(int currentStreak) {
    // Handle negative streak (safety check)
    final streak = currentStreak < 0 ? 0 : currentStreak;
    
    // Determine range
    final range = _getStreakRange(streak);
    
    // Get messages for this range (fallback to '0' if range not found)
    final messages = _messages[range] ?? _messages['0']!;
    
    // Generate hash from streak + current date
    final today = DateTime.now();
    final dayKey = '${today.year}-${today.month}-${today.day}';
    final hashInput = '$streak-$dayKey';
    final hash = hashInput.hashCode;
    
    // Select message using hash (consistent for the day)
    final index = hash.abs() % messages.length;
    return messages[index];
  }

  /// Determine streak range key based on streak value
  static String _getStreakRange(int streak) {
    if (streak == 0) return '0';
    if (streak == 1) return '1';
    if (streak >= 2 && streak <= 3) return '2-3';
    if (streak >= 4 && streak <= 7) return '4-7';
    if (streak >= 8 && streak <= 14) return '8-14';
    if (streak >= 15 && streak <= 30) return '15-30';
    if (streak >= 31 && streak <= 60) return '31-60';
    return '61+'; // 61 and above
  }
}
