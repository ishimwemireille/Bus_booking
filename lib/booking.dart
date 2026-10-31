import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// How many seats the bus has, and what one seat costs.
/// Both are fixed facts about the bus, not data the user types.
const int seatCount = 20;
const int fare = 3000;

/// The notes a conductor actually carries, biggest first.
const List<int> noteValues = [5000, 2000, 1000, 500, 100];

class Booking {
  Booking({
    this.id = '',
    required this.seat,
    required this.name,
    required this.cash,
    this.createdAt,
  });

  final String id;
  final int seat;
  final String name;
  final int cash;
  final DateTime? createdAt;

  /// Only the facts the conductor typed. The change is never saved,
  /// because it can always be worked out from the cash and the fare.
  Map<String, dynamic> toMap() => {
        'seat': seat,
        'name': name,
        'cash': cash,
      };

  factory Booking.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Booking(
      id: doc.id,
      seat: (data['seat'] as num).toInt(),
      name: data['name'] as String,
      cash: (data['cash'] as num).toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  int get change => cash - fare;
}

class WaitlistEntry {
  WaitlistEntry({
    this.id = '',
    required this.name,
    required this.priority,
    this.joinedAt,
  });

  final String id;
  final String name;
  final bool priority;
  final DateTime? joinedAt;

  Map<String, dynamic> toMap() => {
        'name': name,
        'priority': priority,
      };

  factory WaitlistEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return WaitlistEntry(
      id: doc.id,
      name: data['name'] as String,
      priority: data['priority'] as bool,
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// The signed-in user's bookings: users/{uid}/bookings
CollectionReference<Map<String, dynamic>> myBookings() {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('bookings');
}

/// The signed-in user's waitlist: users/{uid}/waitlist
CollectionReference<Map<String, dynamic>> myWaitlist() {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('waitlist');
}

/// Breaks an amount into the fewest notes. Worked out every time,
/// never stored, so it can never disagree with the cash and the fare.
Map<int, int> changeInNotes(int amount) {
  final result = <int, int>{};
  var left = amount;
  for (final note in noteValues) {
    final count = left ~/ note;
    if (count > 0) {
      result[note] = count;
      left -= note * count;
    }
  }
  return result;
}

String describeChange(int amount) {
  if (amount < 0) return 'Short by ${-amount} RWF';
  if (amount == 0) return 'No change';
  final notes = changeInNotes(amount);
  final parts =
      notes.entries.map((e) => '${e.value} x ${e.key}').toList();
  return '$amount RWF: ${parts.join(', ')}';
}

/// Sample data, written once when a new account is created.
Future<void> addSampleBookings() async {
  final samples = [
    Booking(seat: 1, name: 'Keza Aline', cash: 5000),
    Booking(seat: 2, name: 'Mugisha Eric', cash: 3000),
    Booking(seat: 7, name: 'Uwase Diane', cash: 10000),
  ];
  final batch = FirebaseFirestore.instance.batch();
  for (final b in samples) {
    batch.set(myBookings().doc('${b.seat}'), {
      ...b.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  batch.set(myWaitlist().doc(), {
    'name': 'Niyonsaba Jean',
    'priority': true,
    'joinedAt': FieldValue.serverTimestamp(),
  });
  await batch.commit();
}
