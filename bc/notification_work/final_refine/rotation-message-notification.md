# Notification Messages - Rotation System

## Message Rotation Logic
- Uses: `DateTime.now().difference(DateTime(1970, 1, 1)).inDays % 10`
- Rotates every 10 days, never repeats pattern

---

## Morning Reminders (X time) - 10 Messages

1. "Good morning! 🌅 Time to start your day with positive energy and intention ✨"
2. "Rise and shine! ☀️ Your daily affirmation is waiting to set a beautiful tone for today 🌸"
3. "Morning sunshine! 🌞 Take a moment to fill your heart with gratitude and affirmations 💫"
4. "A fresh new day begins! 🌄 Start it right with your daily affirmation practice 🌺"
5. "Good morning, beautiful soul! 💖 Time for your morning ritual of self-love and positivity 🌟"
6. "The sun is up, and so should your spirits! ☀️ Let's begin with your daily affirmation 🌷"
7. "Morning blessings! 🙏 Take a peaceful moment to set your intentions for today 🕊️"
8. "Wake up with purpose! 🌅 Your daily affirmation practice awaits to brighten your day ✨"
9. "A brand new day, a fresh start! 🌸 Begin with your morning affirmation ritual 💫"
10. "Good morning, sunshine! ☀️ Time to nurture your soul with positive affirmations 🌺"

---

## +3 Hours Reminder - 10 Messages

1. "Your daily affirmation is waiting! ✨ Don't let the day rush by without taking a moment for yourself 🌸"
2. "A gentle reminder: your morning affirmation is still waiting 💫 Take a quick break to fill your heart 🌺"
3. "Pause for a moment! 🌷 Your daily affirmation practice is calling - you deserve this time 💖"
4. "Don't forget your daily affirmation! 🌟 A few minutes now can transform your entire day ✨"
5. "Your affirmation is waiting patiently! 💫 Take a moment to connect with yourself 🌸"
6. "Time for a mindful pause! 🧘 Your daily affirmation is here to support your journey 🌺"
7. "A gentle nudge: your affirmation practice awaits! ✨ You're worth this moment of self-care 💖"
8. "Still time for your affirmation! 🌟 Don't let the day slip away without this beautiful ritual 🌸"
9. "Your daily affirmation is calling! 💫 Take a peaceful moment to nurture your soul 🌺"
10. "A reminder with love: your affirmation practice is waiting! ✨ You deserve this time for yourself 🌷"

---

## +6 Hours Reminder - 10 Messages

1. "Protect your streak! 🛡️ A quick affirmation keeps your progress alive and your heart full 💫"
2. "Your streak is precious! 🌟 Don't let it slip - a moment now keeps your journey strong 🛡️"
3. "Streak protection time! 💪 Your daily affirmation is the key to maintaining your beautiful progress ✨"
4. "Keep your momentum going! 🚀 A quick affirmation now protects all the progress you've made 🌟"
5. "Your streak needs you! 💖 Take a moment to complete your affirmation and keep your journey alive 🛡️"
6. "Don't break the chain! 🔗 Your daily affirmation is the link that keeps your progress strong 💫"
7. "Protect what you've built! 🏆 A quick affirmation now maintains your beautiful streak 🌟"
8. "Your progress matters! 💪 Complete your affirmation to keep your streak alive and thriving 🛡️"
9. "Streak guardian mode! 🛡️ Your daily affirmation is the shield that protects your journey ✨"
10. "Keep the momentum! 🌟 Your affirmation practice is the foundation of your beautiful progress 💫"

---

## Bedtime Reminder (Diary NOT Filled) - 10 Messages

1. "Fill your diary! 📖 Capture today's memories before they fade into tomorrow 🌙"
2. "Your diary is waiting! ✍️ Don't let today's stories go untold - write them down 📖"
3. "Time to reflect and write! 📝 Your diary is ready to hold today's precious moments 🌙"
4. "Capture today's journey! 📖 Your diary is calling - preserve these beautiful memories ✨"
5. "Don't forget to write! ✍️ Your diary is waiting to hold today's experiences and thoughts 📖"
6. "Bedtime reflection time! 🌙 Fill your diary with today's moments before sleep 📝"
7. "Your diary needs you! 📖 Take a moment to document today's beautiful journey ✨"
8. "Write it down! ✍️ Your diary is ready to capture today's memories and reflections 📖"
9. "Time to journal! 📝 Don't let today slip away - fill your diary with your story 🌙"
10. "Your diary awaits! 📖 Capture today's moments before they become yesterday's memories ✨"

---

## Bedtime Reminder (Diary Filled) - 10 Messages

1. "Reflect on your day! ✨ Take a moment to appreciate all the beautiful moments you've captured 🌙"
2. "Evening reflection time! 💫 Review your day and see how much you've accomplished 🌟"
3. "Time to reflect! 🌙 Look back on your day with gratitude and see your growth ✨"
4. "Evening gratitude moment! 🙏 Reflect on today's journey and all the blessings it brought 💖"
5. "Bedtime reflection! 🌙 Take a peaceful moment to appreciate your day and set intentions for tomorrow ✨"
6. "Evening pause! 💫 Reflect on your beautiful day and all the moments you've captured 🌟"
7. "Time for reflection! 🌙 Review your day with love and see how much you've grown ✨"
8. "Evening gratitude! 🙏 Reflect on today's journey and appreciate all the beautiful moments 💖"
9. "Bedtime reflection moment! 🌙 Take time to appreciate your day and all you've accomplished ✨"
10. "Evening pause for reflection! 💫 Look back on your day with gratitude and see your beautiful journey 🌟"

---

## Implementation Notes

- Messages rotate based on: `DateTime.now().difference(DateTime(1970, 1, 1)).inDays % 10`
- Each category has 10 unique messages
- Messages are polite, encouraging, and include beautiful emojis
- Tone is supportive, never pushy or demanding
- All messages maintain the gentle, nurturing philosophy of the app
