# flutter_local_notifications 20.x Upgrade Plan

## Root Cause
v20.0.0 converted positional params → named params for `initialize()`, `show()`, `cancel()`.

## Fix Plan

| File | Method | Change |
|------|--------|--------|
| main.dart | initialize | `(initSettings)` → `(settings: initSettings)` |
| notification_service.dart | initialize | `(initSettings, ...)` → `(settings: initSettings, ...)` |
| notification_service.dart | show (2 places) | `(id, title, body, details)` → `(id:, title:, body:, notificationDetails:)` |
| notification_service.dart | cancel (5 places) | `(id)` → `(id: id)` |

## Steps
1. main.dart: add `settings:` to initialize call
2. notification_service.dart: update initialize, _showNotification, testImmediateNotification, all cancel calls
