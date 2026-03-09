import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../shared/fcm_token_service.dart';
import '../../theme/driver_theme.dart';

class IncomingOfferScreen extends StatefulWidget {
  final String bookingId;
  final String offerId;

  const IncomingOfferScreen({
    super.key,
    required this.bookingId,
    required this.offerId,
  });

  @override
  State<IncomingOfferScreen> createState() => _IncomingOfferScreenState();
}

class _IncomingOfferScreenState extends State<IncomingOfferScreen> {
  static const int offerSeconds = 60;

  Timer? _timer;
  int _remaining = offerSeconds;
  bool _loading = false;
  bool _expired = false;
  String? _error;

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _lockDriverOffer();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _unlockDriverOffer(); // safe cleanup
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    _remaining = offerSeconds;
    _expired = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _remaining -= 1;
        if (_remaining <= 0) {
          _remaining = 0;
          _expired = true;
          t.cancel();
        }
      });
    });
  }

  Future<void> _lockDriverOffer() async {
    // Locks availability toggle while offer is shown
    await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
      'activeOffer': {
        'bookingId': widget.bookingId,
        'offerId': widget.offerId,
        'startedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _unlockDriverOffer() async {
    await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
      'activeOffer': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _respond(String decision) async {
    if (_expired) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await FcmTokenService.respondToOffer(
        bookingId: widget.bookingId,
        offerId: widget.offerId,
        decision: decision, // accept | decline
      );

      final ok = res['ok'] == true;

      if (!mounted) return;

      if (!ok) {
        setState(() {
          _loading = false;
          _error = (res['reason'] ?? 'Failed').toString();
        });
        return;
      }

      await _unlockDriverOffer();

      Navigator.pop(context, decision);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = _remaining / offerSeconds;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Incoming Ride Offer',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Booking: ${widget.bookingId}',
                style: const TextStyle(color: PFColors.muted),
              ),
              const SizedBox(height: 18),

              // Countdown card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: PFColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: PFColors.border),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: pct.clamp(0.0, 1.0),
                            strokeWidth: 5,
                            color: PFColors.primary,
                            backgroundColor: PFColors.primarySoft,
                          ),
                          Center(
                            child: Text(
                              '$_remaining',
                              style: const TextStyle(
                                color: PFColors.ink,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _expired
                            ? 'Offer expired'
                            : 'Respond within 60 seconds to accept this trip.',
                        style: TextStyle(
                          color: _expired
                              ? PFColors.danger
                              : PFColors.muted,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PFColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: PFColors.border),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: PFColors.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],

              const Spacer(),

              ElevatedButton(
                onPressed: (_loading || _expired) ? null : () => _respond('accept'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('ACCEPT', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: (_loading || _expired) ? null : () => _respond('decline'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  side: const BorderSide(color: PFColors.border),
                ),
                child: const Text('DECLINE', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}