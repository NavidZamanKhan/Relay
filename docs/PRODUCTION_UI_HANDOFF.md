# Production handoff

Use the Flutter presentation layer as a design reference while deciding the
production architecture in your IDE. Keep strict Event → BLoC → State flow;
introduce repository interfaces when the corresponding feature is implemented.

| Prototype piece | Production responsibility |
| --- | --- |
| `AuthBloc` | Auth repository; real validation, OTP failures, resend/rate-limit states |
| `ChatBloc.threads` | Message/conversation repositories with immutable stream updates |
| `_deliveryTimers` | Actual acknowledgement and per-recipient receipt states |
| `_replyTimers` / typing IDs | Remote typing/presence events and a write debounce |
| Recording state | Permissions, audio capture, file lifecycle, interrupted recording |
| Playback stopwatch | Audio player's position/duration/playing streams |
| Bundled photo/doc | Media picker, compression, upload progress, download/cache policy |
| Settings/cache display | Persisted preferences, actual cache accounting, auth deletion |
| Local group creation | Persisted participants, member roles, group receipts |

The model's presentation states are useful for design, but the timer simulations
are not persistence, delivery guarantees, or security mechanisms. Do not keep
them behind a feature flag in a production transport implementation.

## Infrastructure assumptions to revisit

The original 10,000 free SMS OTPs/month assumption is outdated. Firebase's
current documentation requires Blaze for verification SMS, with SMS pricing.
Cloud Storage for Firebase also requires Blaze, although some usage allowances
can be free. A strict $0/no-billing production requirement therefore needs a
separate authentication and media-storage decision before integration.

- https://firebase.google.com/docs/auth/limits
- https://firebase.google.com/pricing
- https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024

This prototype uses no Firebase service and creates no infrastructure charges.

## Suggested implementation sequence

1. Transfer tokens, typography, icons, and static reusable components.
2. Bring over the message timeline and composer, retaining stable IDs and the
   persistent recording recognizer. Run the gesture tests.
3. Add auth and conversation/message repositories with explicit errors.
4. Add native audio and on-device media handling with their own lifecycle tests.
5. Add offline persistence and multi-device delivery semantics.
6. Profile on physical iOS and Android phones at both supported refresh rates.

Real networking, security rules, multi-device consistency, accessibility audits,
large-history pagination, and physical-device frame timing remain production work.
