current streak feature is complex and using multiple unnecessery db calls.
my solution approach - check this and test it, if this will work we will implement it.
Critical action - first check the working.

for streak feature we need to calculate these things.
1- streak
2- grace days
3- pieces
4 calculate everything.



so we will create a local table inside the app using local db feature that we are already using.

that will store all 4 task cmplitation status true or false.

## Things tracked for pieces

- Affirmations (`filled_affirmations`) — 0.5 pieces
- Gratitude (`filled_gratitude`) — 0.5 pieces
- Diary entry (`wrote_entry`) — 0.5 pieces
- Self-care (`self_care_completed_count > 0`) — 0.5 pieces

**Total:** Max 2.0 pieces/day (4 tasks × 0.5)  
**Conversion:** 10 pieces = 1 grace day (max 5 grace days)


local tables have feilds 
- Affirmations
-Gratitude
-Diary entry
-Self-care 
-Streak count
- Grace days
-pieces
-fetch date

when user will open the app first of all it will check that is this local table is empty?
it will check a local variable, at first installation the default value of that variable will be no.

lets say variable is is_streak_data_availabe = false;

on app startup on splash screen we will check this and if no then fetch the streak details from db and make it true after fetching, or we can amak it yes when we will put data on supabase.

now the thing is that when we will put the data to database.

it will check like this,

if (today = chnage in streak detail day +1) then streak ++

if not then we will check the number of gap days bwtween today and change in streak detail,

if number of days < available grace days
	then streak will be safe 
	
	available grace will be 
	available grace days = available grace days - total number of days.
	

then it will be synced to supabase.

also if total number of days is greater then available number of grace days.
then streak =0;
grace days will also be 0
and sync o supabase.


in supabase one user will have one table.
like 
number of streak, grace days available, pieces, 
maximum grace days will be 5.

if piece is less then 50 keep adding , if reaches to 50 stop adding.

now lets talk about some thing.

next time the app will open it will check for streak data is aailable locally or not?
if no then fetch, if yes then no fetch.
but the catch is in above discussion we are updating supabase but here the table will not be empty so it will never fetch the latest data.
in app first time open it will fetch the data.
soooooooooooooooo what we can do is, is iss iss, let me think.

i think there is no any problem,
bcz we are calculating everything locally and showing it locally,
we are just storing it on cloud in case user delete the app and needs to fetch when install.
so if it dosent sync , i think no problem, we just have all data locally calculating.


suppose a user has a streak of 17 and grace days of 5 days.
and he delets the app and installs after 7 days.

app will check if the data is locally available?
no then fetch all details from supabase.
- note it will fetch the last day data that has been pushed to supabase.
streak - 17
grace days - 5
piece - maybe something.

it will check number of days between last date and today.
if its next day, streak ++,
in thi case its 7 days so 
it will check no of grace days =5.
total no of days> grace days, then streak will be set to 0 and grace days will be 0 and pushed to supabase.


if he installed after 3 days.
here total no of days< grace days.
then streak will be 

grace days = grace days - no of days.
streak = streak + grace days.

we will check smaller days or equal to increase grace days.
as user is opening app after 5 days and if he has 5 days grace , he will not loose streak.







