# Bus Booking

A Flutter app for the conductor of a 20-seat bus. It signs users in with Firebase
Authentication, and each user's data is saved in Cloud Firestore under their own id, so two
accounts never see each other's data, and every change appears live.

## What it does

Twenty seats in a grid. Tap a free seat to sell it, tap a sold one to correct the name or
the cash, long press to cancel the booking. A second tab keeps a waitlist of passengers
who could not get a seat, with priority marks.

## How the data is kept

Two collections under `users/{uid}/`:

- `bookings` — seat, name, cash. The seat number is the document id, which is what makes it
  impossible to sell the same seat twice.
- `waitlist` — name, priority, joinedAt.

Only the facts the conductor typed or chose are saved. Seats sold, money made and the
change broken into notes are worked out from that data every time it arrives, so they can
never disagree with it.

## Privacy

`firestore.rules` allows a read or write only when somebody is signed in and their user id
matches the one in the path:

```
allow read, write: if request.auth != null && request.auth.uid == userId;
```

A second account signing in sees its own empty bus, not the first account's.

## Running it

```bash
flutter pub get
flutter run
```

Needs `android/app/google-services.json` for its own Firebase project, Email/Password
sign-in enabled, and the rules above published.

## Screenshots

![Login](screenshots/login.png)

![My data in Firestore](screenshots/console.png)

![Live update](screenshots/live.png)

![Second account sees nothing of mine](screenshots/denied.png)
