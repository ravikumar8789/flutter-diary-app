# Notification Messages - Rotation System (Title + Body)

## Message Rotation Logic
- Uses: `DateTime.now().difference(DateTime(1970, 1, 1)).inDays % 10`
- Rotates every 10 days, never repeats pattern
- Each index maps to one Title + Body pair

---

## Morning Reminders (X time) - 10 Pairs

1. Title: "Good morning! 🌅" | Body: "Time to start your day with positive energy and intention ✨"
2. Title: "Rise and shine! ☀️" | Body: "Your daily affirmation is waiting to set a beautiful tone for today 🌸"
3. Title: "Morning sunshine! 🌞" | Body: "Take a moment to fill your heart with gratitude and affirmations 💫"
4. Title: "A fresh new day begins! 🌄" | Body: "Start it right with your daily affirmation practice 🌺"
5. Title: "Good morning, beautiful soul! 💖" | Body: "Time for your morning ritual of self-love and positivity 🌟"
6. Title: "The sun is up, and so should your spirits! ☀️" | Body: "Let us begin with your daily affirmation 🌷"
7. Title: "Morning blessings! 🙏" | Body: "Take a peaceful moment to set your intentions for today 🕊️"
8. Title: "Wake up with purpose! 🌅" | Body: "Your daily affirmation practice awaits to brighten your day ✨"
9. Title: "A brand new day, a fresh start! 🌸" | Body: "Begin with your morning affirmation ritual 💫"
10. Title: "Good morning, sunshine! ☀️" | Body: "Time to nurture your soul with positive affirmations 🌺"

---

## +3 Hours Reminder - 10 Pairs

1. Title: "Your daily affirmation is waiting! ✨" | Body: "Do not let the day rush by without taking a moment for yourself 🌸"
2. Title: "A gentle reminder:" | Body: "Your morning affirmation is still waiting 💫 Take a quick break to fill your heart 🌺"
3. Title: "Pause for a moment! 🌷" | Body: "Your daily affirmation practice is calling - you deserve this time 💖"
4. Title: "Do not forget your daily affirmation! 🌟" | Body: "A few minutes now can transform your entire day ✨"
5. Title: "Your affirmation is waiting patiently! 💫" | Body: "Take a moment to connect with yourself 🌸"
6. Title: "Time for a mindful pause! 🧘" | Body: "Your daily affirmation is here to support your journey 🌺"
7. Title: "A gentle nudge:" | Body: "Your affirmation practice awaits! ✨ You are worth this moment of self-care 💖"
8. Title: "Still time for your affirmation! 🌟" | Body: "Do not let the day slip away without this beautiful ritual 🌸"
9. Title: "Your daily affirmation is calling! 💫" | Body: "Take a peaceful moment to nurture your soul 🌺"
10. Title: "A reminder with love:" | Body: "Your affirmation practice is waiting! ✨ You deserve this time for yourself 🌷"

---

## +6 Hours Reminder - 10 Pairs

1. Title: "Protect your streak! 🛡️" | Body: "A quick affirmation keeps your progress alive and your heart full 💫"
2. Title: "Your streak is precious! 🌟" | Body: "Do not let it slip - a moment now keeps your journey strong 🛡️"
3. Title: "Streak protection time! 💪" | Body: "Your daily affirmation is the key to maintaining your beautiful progress ✨"
4. Title: "Keep your momentum going! 🚀" | Body: "A quick affirmation now protects all the progress you have made 🌟"
5. Title: "Your streak needs you! 💖" | Body: "Take a moment to complete your affirmation and keep your journey alive 🛡️"
6. Title: "Do not break the chain! 🔗" | Body: "Your daily affirmation is the link that keeps your progress strong 💫"
7. Title: "Protect what you have built! 🏆" | Body: "A quick affirmation now maintains your beautiful streak 🌟"
8. Title: "Your progress matters! 💪" | Body: "Complete your affirmation to keep your streak alive and thriving 🛡️"
9. Title: "Streak guardian mode! 🛡️" | Body: "Your daily affirmation is the shield that protects your journey ✨"
10. Title: "Keep the momentum! 🌟" | Body: "Your affirmation practice is the foundation of your beautiful progress 💫"

---

## Bedtime Reminder (Diary NOT Filled) - 10 Pairs

1. Title: "Fill your diary! 📖" | Body: "Capture today's memories before they fade into tomorrow 🌙"
2. Title: "Your diary is waiting! ✍️" | Body: "Do not let today's stories go untold - write them down 📖"
3. Title: "Time to reflect and write! 📝" | Body: "Your diary is ready to hold today's precious moments 🌙"
4. Title: "Capture today's journey! 📖" | Body: "Your diary is calling - preserve these beautiful memories ✨"
5. Title: "Do not forget to write! ✍️" | Body: "Your diary is waiting to hold today's experiences and thoughts 📖"
6. Title: "Bedtime reflection time! 🌙" | Body: "Fill your diary with today's moments before sleep 📝"
7. Title: "Your diary needs you! 📖" | Body: "Take a moment to document today's beautiful journey ✨"
8. Title: "Write it down! ✍️" | Body: "Your diary is ready to capture today's memories and reflections 📖"
9. Title: "Time to journal! 📝" | Body: "Do not let today slip away - fill your diary with your story 🌙"
10. Title: "Your diary awaits! 📖" | Body: "Capture today's moments before they become yesterday's memories ✨"

---

## Bedtime Reminder (Diary Filled) - 10 Pairs

1. Title: "Reflect on your day! ✨" | Body: "Take a moment to appreciate all the beautiful moments you have captured 🌙"
2. Title: "Evening reflection time! 💫" | Body: "Review your day and see how much you have accomplished 🌟"
3. Title: "Time to reflect! 🌙" | Body: "Look back on your day with gratitude and see your growth ✨"
4. Title: "Evening gratitude moment! 🙏" | Body: "Reflect on today's journey and all the blessings it brought 💖"
5. Title: "Bedtime reflection! 🌙" | Body: "Take a peaceful moment to appreciate your day and set intentions for tomorrow ✨"
6. Title: "Evening pause! 💫" | Body: "Reflect on your beautiful day and all the moments you have captured 🌟"
7. Title: "Time for reflection! 🌙" | Body: "Review your day with love and see how much you have grown ✨"
8. Title: "Evening gratitude! 🙏" | Body: "Reflect on today's journey and appreciate all the beautiful moments 💖"
9. Title: "Bedtime reflection moment! 🌙" | Body: "Take time to appreciate your day and all you have accomplished ✨"
10. Title: "Evening pause for reflection! 💫" | Body: "Look back on your day with gratitude and see your beautiful journey 🌟"

---

## Implementation Notes

- Messages rotate based on: `DateTime.now().difference(DateTime(1970, 1, 1)).inDays % 10`
- Each category has 10 Title + Body pairs
- Messages are polite, encouraging, and include beautiful emojis
- Tone is supportive, never pushy or demanding
