import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'booking.dart';

class BusScreen extends StatelessWidget {
  const BusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bus Booking'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Log out',
              onPressed: () => FirebaseAuth.instance.signOut(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Seats', icon: Icon(Icons.event_seat)),
              Tab(text: 'Waitlist', icon: Icon(Icons.people_outline)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [SeatsTab(), WaitlistTab()],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- seats

class SeatsTab extends StatelessWidget {
  const SeatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: myBookings().orderBy('seat').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorView(error: snapshot.error.toString());
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookings = snapshot.data!.docs.map(Booking.fromDoc).toList();
        // Worked out from the data every time it arrives, never stored.
        final bySeat = {for (final b in bookings) b.seat: b};
        final sold = bookings.length;
        final moneyMade = sold * fare;

        return Column(
          children: [
            Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat(label: 'Seats sold', value: '$sold / $seatCount'),
                    _Stat(label: 'Money made', value: '$moneyMade RWF'),
                    _Stat(label: 'Fare', value: '$fare RWF'),
                  ],
                ),
              ),
            ),
            if (sold == 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'No seats sold yet. Tap a free seat to book it.',
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.95,
                ),
                itemCount: seatCount,
                itemBuilder: (context, index) {
                  final seat = index + 1;
                  return _SeatTile(seat: seat, booking: bySeat[seat]);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({required this.seat, this.booking});

  final int seat;
  final Booking? booking;

  @override
  Widget build(BuildContext context) {
    final taken = booking != null;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => _openForm(context, seat: seat, existing: booking),
      onLongPress:
          taken ? () => _confirmDelete(context, booking!) : null,
      child: Container(
        decoration: BoxDecoration(
          color: taken ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          border: Border.all(
            color: taken ? scheme.primary : scheme.outlineVariant,
            width: taken ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$seat',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 2),
            Text(
              taken ? booking!.name.split(' ').first : 'Free',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: taken ? scheme.onPrimaryContainer : scheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openForm(BuildContext context,
    {required int seat, Booking? existing}) async {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: existing?.name ?? '');
  final cashController =
      TextEditingController(text: existing == null ? '' : '${existing.cash}');

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(existing == null ? 'Book seat $seat' : 'Edit seat $seat'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Passenger name'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: cashController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Cash given', suffixText: 'RWF'),
              validator: (v) {
                final cash = int.tryParse((v ?? '').trim());
                if (cash == null) return 'Enter the cash given';
                if (cash < fare) return 'The fare is $fare RWF';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(dialogContext, true);
            }
          },
          child: Text(existing == null ? 'Book' : 'Save'),
        ),
      ],
    ),
  );

  final name = nameController.text.trim();
  final cash = int.tryParse(cashController.text.trim()) ?? 0;
  nameController.dispose();
  cashController.dispose();

  if (saved != true) return;

  try {
    if (existing == null) {
      // The seat number is the document id, so one seat can only be sold once.
      await myBookings().doc('$seat').set({
        'seat': seat,
        'name': name,
        'cash': cash,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await myBookings().doc(existing.id).update({
        'seat': seat,
        'name': name,
        'cash': cash,
      });
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seat $seat: ${describeChange(cash - fare)}')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save. $e')));
    }
  }
}

Future<void> _confirmDelete(BuildContext context, Booking booking) async {
  final sure = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Free seat ${booking.seat}?'),
      content: Text('${booking.name} paid ${booking.cash} RWF.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel booking')),
      ],
    ),
  );
  if (sure != true) return;
  try {
    await myBookings().doc(booking.id).delete();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not delete. $e')));
    }
  }
}

// ------------------------------------------------------------- waitlist

class WaitlistTab extends StatelessWidget {
  const WaitlistTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openWaitlistForm(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: myWaitlist().orderBy('joinedAt').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorView(error: snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries =
              snapshot.data!.docs.map(WaitlistEntry.fromDoc).toList();
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nobody is waiting for a seat.',
                    textAlign: TextAlign.center),
              ),
            );
          }

          // Priority passengers first, then whoever joined earliest.
          // Sorted here rather than on the server, so no composite index
          // is needed.
          final ordered = [...entries]
            ..sort((a, b) {
              if (a.priority != b.priority) return a.priority ? -1 : 1;
              final aAt = a.joinedAt;
              final bAt = b.joinedAt;
              if (aAt == null || bAt == null) return 0;
              return aAt.compareTo(bAt);
            });

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: ordered.length,
            itemBuilder: (context, index) {
              final entry = ordered[index];
              return ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(entry.name),
                subtitle: Text(entry.priority ? 'Priority' : 'Normal'),
                trailing: entry.priority
                    ? const Icon(Icons.star, color: Colors.amber)
                    : null,
                onTap: () => _openWaitlistForm(context, existing: entry),
                onLongPress: () => _confirmWaitlistDelete(context, entry),
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> _openWaitlistForm(BuildContext context,
    {WaitlistEntry? existing}) async {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: existing?.name ?? '');
  var priority = existing?.priority ?? false;

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(existing == null ? 'Add to waitlist' : 'Edit waiting passenger'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter a name' : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Priority'),
                value: priority,
                onChanged: (value) =>
                    setDialogState(() => priority = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    ),
  );

  final name = nameController.text.trim();
  nameController.dispose();
  if (saved != true) return;

  try {
    if (existing == null) {
      await myWaitlist().add({
        'name': name,
        'priority': priority,
        'joinedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await myWaitlist().doc(existing.id).update({
        'name': name,
        'priority': priority,
      });
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save. $e')));
    }
  }
}

Future<void> _confirmWaitlistDelete(
    BuildContext context, WaitlistEntry entry) async {
  final sure = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Remove from the waitlist?'),
      content: Text(entry.name),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove')),
      ],
    ),
  );
  if (sure != true) return;
  try {
    await myWaitlist().doc(entry.id).delete();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not delete. $e')));
    }
  }
}

// ---------------------------------------------------------------- bits

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text('Could not load your bookings.\n$error',
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
