# Title/Body Split Plan (Short)

1. Update the message doc to explicit Title/Body pairs (10 per category).
2. In `notification_service.dart`, replace single message arrays with title/body arrays for each category.
3. Update `_pickMessage()` to return `titles[index]` + `bodies[index]`, and log if lengths mismatch.
4. Remove old hardcoded body constants to avoid duplication.
5. Update top-level callbacks to use the new title/body arrays (no stale hardcoded text).
6. Verify reschedule and metadata store the new title/body; old alarms update after next reschedule.