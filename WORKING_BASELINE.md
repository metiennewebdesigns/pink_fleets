# Pink Fleets Working Baseline

Do not break these working flows:

1. Rider "Place Booking" button successfully creates a booking
2. Rider booking flow routes correctly to the live booking screen
3. Active booking submit flow must not reintroduce the generic snackbar:
   "Booking failed. Please try again."
4. Do not change the active rider booking submit path without tracing it first
5. Web map fixes must preserve the working rider booking flow
6. Do not replace working submit logic with generic catch blocks
7. Make the smallest safe change only

## Safe edit rules
- Identify the exact active file and code path before patching
- Preserve current working booking behavior
- Do not touch unrelated files
- Patch only the specific failing feature being addressed
