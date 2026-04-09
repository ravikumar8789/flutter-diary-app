# ERRAUTH007 - Unmounted Widget Context Crash (P1 Fix)

## Error
- Code: ERRAUTH007
- Message: "This widget has been unmounted, so the State no longer has a context"
- Location: `login_screen.dart:125` inside `_login()` catch block

## Root Cause
- Login succeeds → auth state listener fires → `Navigator.pushReplacement` to HomeScreen.
- Login screen unmounts during navigation.
- `_login()` async function is still executing (catch block / error logging).
- After screen unmounts, code reaches `SnackbarUtils.show*(context, ...)` → crash.
- Also affects success path: `SnackbarUtils.showLoginSuccess(context, ...)` at line 67 is called after `await signIn(...)` with no mounted check.

## Why It Appeared Now
- Fresh install → no cached data → login + DB setup + notification scheduling all compete.
- Login screen stays visible slightly longer → navigation fires while catch block is still in await chain.
- Existing installs were fast enough that the race window was rarely hit.

## Fix Plan
1. Add `if (!mounted) return;` after `await ErrorLoggingService.logError(...)` in catch block (before snackbar calls).
2. Add `if (!mounted) return;` after `await signIn(...)` in try block (before `showLoginSuccess`).
3. Add `if (!mounted) return;` in `_forgotPassword()` after `await resetPasswordForEmail(...)`.

## Files Changed
- `lib/screens/login_screen.dart`
