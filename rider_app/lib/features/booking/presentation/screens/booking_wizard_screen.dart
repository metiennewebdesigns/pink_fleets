import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// >>> ADDED (Pink Fleets Enterprise): Firestore/Auth/Router for resume + analytics
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
// <<< END ADDED

import '../../../../theme/pink_fleets_theme.dart';
import '../../../../shared/address_autocomplete_field.dart';
import '../../../../shared/date_time_format.dart';
import '../../domain/booking_draft.dart';
import '../controllers/booking_controller.dart';

class BookingWizardScreen extends ConsumerStatefulWidget {
  final bool embedMode;
  const BookingWizardScreen({super.key, required this.embedMode});

  @override
  ConsumerState<BookingWizardScreen> createState() => _BookingWizardScreenState();
}

class _BookingWizardScreenState extends ConsumerState<BookingWizardScreen> {
  int _step = 0; // 0 Details -> 1 Quote -> 2 Pay

  // >>> ADDED (Pink Fleets Enterprise): Auto-resume + lightweight analytics
  bool _resumeChecking = true;
  String? _activeBookingId;
  bool _isSubmitting = false;
  final bool _useFirestoreBookingCreate = false;
  String? _submitErrorMessage;
  String? _submitErrorRoute;
  String? _submitErrorBookingId;

  // >>> ADDED: Add-Stop UI state
  final List<String> _stops = [];

  static const List<String> _activeStatuses = [
    'pending',
    'dispatching',
    'offered',
    'accepted',
    'en_route',
    'en route',
    'arrived',
    'in_progress',
    'in progress',
  ];

  // ── Analytics: Firestore client writes DISABLED (Firestore Web SDK 11.9.1
  // internal assertion crash on FieldValue.serverTimestamp() writes on web).
  // Events are logged to the console only. Move to a server-side CF later.
  Future<void> _trackEvent(String name, {Map<String, dynamic>? props}) async {
    // ignore: avoid_print
    debugPrint('[PF TRACK] $name ${props ?? {}}');
  }

  Future<void> _checkActiveTripAndResume() async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      final email = (u?.email ?? '').trim().toLowerCase();
      if (email.isEmpty) {
        if (mounted) setState(() => _resumeChecking = false);
        return;
      }

      final qs = await FirebaseFirestore.instance
          .collection('bookings')
          .where('riderInfo.email', isEqualTo: email)
          .where('status', whereIn: _activeStatuses)
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      if (!mounted) return;

      if (qs.docs.isNotEmpty) {
        final id = qs.docs.first.id;
        setState(() {
          _activeBookingId = id;
          _resumeChecking = false;
        });

        if (widget.embedMode == false && _step == 0) {
          _trackEvent('booking_resume_auto', props: {'bookingId': id});
          context.go('/booking/live/$id');
        }
      } else {
        setState(() {
          _activeBookingId = null;
          _resumeChecking = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _resumeChecking = false);
    }
  }
  // <<< END ADDED

  // ✅ Put your real business phone here
  static const String callPhoneNumber = "CALL_PHONE_NUMBER";

  @override
  void initState() {
    super.initState();

    Future.microtask(_checkActiveTripAndResume);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _goNext() {
    setState(() => _step = (_step + 1).clamp(0, 2));
    _trackEvent('booking_step_next', props: {'step': _step});
  }

  void _goBack() {
    setState(() => _step = (_step - 1).clamp(0, 2));
    _trackEvent('booking_step_back', props: {'step': _step});
  }

  void _showCallDialog(BuildContext context, {String? overrideMessage, required String phone}) {
    final msg = overrideMessage ??
        'Online checkout is disabled for bookings under 2 hours notice '
            'or outside our 30-mile service area from New Orleans.\n\n'
            'Please call Pink Fleets to book.\n\n'
            'Phone: $phone';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Call to Book'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<bool> _ensureLoggedIn(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in or create an account to complete your booking.'),
        ),
      );
      context.go('/login');
      return false;
    }
    return true;
  }

  Future<String> _createBooking(Map<String, dynamic> payload) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to create a booking.');
    }
    if (payload.isEmpty) {
      throw Exception('Booking payload is empty.');
    }

    final pickup = (payload['pickup'] ?? '').toString().trim();
    final dropoff = (payload['dropoff'] ?? '').toString().trim();
    final vehicleType = (payload['vehicle_type'] ?? '').toString().trim();
    final date = payload['date'];
    final time = payload['time'];
    final durationHours = (payload['duration_hours'] as num?)?.toDouble();
    final pickupLat = (payload['pickupLat'] as num?)?.toDouble();
    final pickupLng = (payload['pickupLng'] as num?)?.toDouble();
    final dropoffLat = (payload['dropoffLat'] as num?)?.toDouble();
    final dropoffLng = (payload['dropoffLng'] as num?)?.toDouble();

    if (pickup.isEmpty) {
      throw Exception('Pickup is required.');
    }
    if (dropoff.isEmpty) {
      throw Exception('Dropoff is required.');
    }
    if (vehicleType.isEmpty) {
      throw Exception('Vehicle type is required.');
    }
    if (date == null || time == null) {
      throw Exception('Pickup date and time are required.');
    }
    if (durationHours == null || durationHours <= 0) {
      throw Exception('Duration must be greater than 0.');
    }
    if (pickupLat == null || pickupLng == null || dropoffLat == null || dropoffLng == null) {
      throw Exception('Pickup/dropoff coordinates are required.');
    }

    final firestore = FirebaseFirestore.instance;

    final ref = firestore.collection('bookings').doc();

    // FieldValue.serverTimestamp() triggers a Firestore Web SDK 11.9.1
    // JS assertion crash on web writes. Use Timestamp.now() on web instead.
    final ts = kIsWeb ? Timestamp.now() : FieldValue.serverTimestamp();

    final bookingData = {
      ...payload,
      'pickup': pickup,
      'dropoff': dropoff,
      'vehicle_type': vehicleType,
      'vehicleType': vehicleType,
      'requestedVehicle': vehicleType,
      'requested_vehicle': vehicleType,
      'date': date,
      'time': time,
      'duration_hours': durationHours,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
      'riderUid': (payload['riderUid'] ?? user.uid).toString(),
      'rider_id': (payload['rider_id'] ?? user.uid).toString(),
      'riderInfo': {
        'uid': user.uid,
        'name': user.displayName,
        'email': user.email,
        'phone': user.phoneNumber,
        ...((payload['riderInfo'] is Map)
            ? Map<String, dynamic>.from(payload['riderInfo'] as Map)
            : <String, dynamic>{}),
      },
      'assigned': (payload['assigned'] is Map)
          ? Map<String, dynamic>.from(payload['assigned'] as Map)
          : <String, dynamic>{},
      'created_at': ts,
      'updated_at': ts,
      'createdAt': ts,
      'updatedAt': ts,
      'status': 'pending',
    };

    debugPrint('[BOOKING] firestore ref=${ref.path}');
    debugPrint('[BOOKING] firestore data=$bookingData');
    debugPrint('[BOOKING] Firestore write to ${ref.path}');
    await ref.set(bookingData);

    return ref.id;
  }

  @override
  Widget build(BuildContext context) {
    try {
      return _buildContent(context);
    } catch (e, st) {
      debugPrint('[BOOKING SCREEN] build crash: $e');
      debugPrint('[BOOKING SCREEN] stack: $st');
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Something went wrong loading the booking screen.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildContent(BuildContext context) {
    final state = ref.watch(bookingControllerProvider);
    final ctrl = ref.read(bookingControllerProvider.notifier);
    final d = state.draft;
    final settingsRef = FirebaseFirestore.instance.collection('admin_settings').doc('app');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: settingsRef.snapshots(),
      builder: (context, settingsSnap) {
        if (settingsSnap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load booking settings: ${settingsSnap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        if (!settingsSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final settings = settingsSnap.data?.data() ?? {};
        ctrl.applySettings(settings);
        final supportPhone = (settings['supportPhone'] ?? callPhoneNumber).toString();

        final requiresCall = ctrl.requiresCallToBook;
        final errorText = state.error ?? '';
        final outsideServiceArea = errorText.toLowerCase().contains('service area');
        final requiresCallEffective = requiresCall || outsideServiceArea;

        Widget stepView() {
          switch (_step) {
            case 0:
              return _DetailsCard(
                draft: d,
                errorText: state.error,
                requiresCall: requiresCallEffective,
                onPrimaryPressed: () async {
                  if (requiresCallEffective) {
                    _showCallDialog(context, overrideMessage: state.error, phone: supportPhone);
                    return;
                  }

                  final ok = ctrl.validateForQuote();
                  if (!ok) {
                    final msg = ref.read(bookingControllerProvider).error ?? '';
                    if (msg.toLowerCase().contains('service area')) {
                      _showCallDialog(context, overrideMessage: msg, phone: supportPhone);
                    }
                    return;
                  }

                  _goNext();
                },
                onPickupChanged: (text, placeId, latLng) =>
                    ctrl.setPickup(text, placeId: placeId, lat: latLng?.lat, lng: latLng?.lng),
                onDropoffChanged: (text, placeId, latLng) =>
                    ctrl.setDropoff(text, placeId: placeId, lat: latLng?.lat, lng: latLng?.lng),
                onPickDateTime: () async {
                  final now = DateTime.now();
                  final date = await showDatePicker(
                    context: context,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                    initialDate: now,
                  );
                  if (date == null) return;
                  if (!context.mounted) return;

                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 2))),
                  );
                  if (time == null) return;

                  final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                  ctrl.setScheduledStart(dt);
                },
                onDurationChanged: (v) {
                  final parsed = double.tryParse(v);
                  if (parsed != null) ctrl.setDurationHours(parsed);
                },
                onVehicleSelected: ctrl.setVehicleType,
                onPassengersChanged: (v) {
                  if (v != null) ctrl.setPassengers(v);
                },
                onAcceptedTerms: (v) => ctrl.setAcceptedTerms(v ?? false),
                onSurveillanceConsent: (v) => ctrl.setSurveillanceConsent(v ?? false),
                onNoSmokingAck: (v) => ctrl.setNoSmokingAck(v ?? false),
                stops: _stops,
                onAddStop: () => setState(() => _stops.add('')),
                onRemoveStop: (i) => setState(() => _stops.removeAt(i)),
                onStopChanged: (i, addr) => setState(() => _stops[i] = addr),
              );
            case 1:
              final q = ctrl.computeQuoteBreakdown();
              return _QuoteCard(
                draft: d,
                quote: q,
                minBookingHours: ctrl.minBookingHours,
                minNoticeHours: ctrl.minNoticeHours,
                gratuityPct: ctrl.gratuityPct,
                taxRatePct: ctrl.taxRatePct,
                bookingFee: ctrl.bookingFee,
                fuelSurchargePct: ctrl.fuelSurchargePct,
                cancelWindowHours: ctrl.cancelWindowHours,
                lateCancelFee: ctrl.lateCancelFee,
                serviceAreaMiles: ctrl.serviceAreaMiles,
                defaultCity: ctrl.defaultCity,
                onBack: _goBack,
                onContinue: _goNext,
              );
            case 2:
            default:
              return _PayCard(
                onBack: _goBack,
                minBookingHours: ctrl.minBookingHours,
                minNoticeHours: ctrl.minNoticeHours,
                gratuityPct: ctrl.gratuityPct,
                taxRatePct: ctrl.taxRatePct,
                bookingFee: ctrl.bookingFee,
                fuelSurchargePct: ctrl.fuelSurchargePct,
                cancelWindowHours: ctrl.cancelWindowHours,
                lateCancelFee: ctrl.lateCancelFee,
                onPlaceBooking: () async {
                  if (_useFirestoreBookingCreate) {
                    if (_isSubmitting) return;

                    final pickupLocation = d.pickup;
                    final dropoffLocation = d.dropoff;
                    final selectedVehicle = d.vehicleType.name;
                    final selectedDate = d.scheduledStart == null
                        ? null
                        : DateTime(
                            d.scheduledStart!.year,
                            d.scheduledStart!.month,
                            d.scheduledStart!.day,
                          );
                    final selectedTime = d.scheduledStart == null
                        ? null
                        : '${d.scheduledStart!.hour.toString().padLeft(2, '0')}:${d.scheduledStart!.minute.toString().padLeft(2, '0')}';
                    final durationHours = d.durationHours;
                    final rider = FirebaseAuth.instance.currentUser;

                    try {
                      final okLogin = await _ensureLoggedIn(context);
                      if (!okLogin) return;
                      if (!context.mounted) return;

                      final validForQuote = ctrl.validateForQuote();
                      if (!validForQuote) {
                        final validationError =
                            ref.read(bookingControllerProvider).error ??
                                'Booking validation failed.';
                        throw Exception(validationError);
                      }

                      setState(() {
                        _isSubmitting = true;
                      });

                      final bookingPayload = {
                        'pickup': pickupLocation,
                        'dropoff': dropoffLocation,
                        'vehicle_type': selectedVehicle,
                        'date': selectedDate,
                        'time': selectedTime,
                        'duration_hours': durationHours,
                        'rider_id': FirebaseAuth.instance.currentUser?.uid,
                        'riderUid': FirebaseAuth.instance.currentUser?.uid,
                        'pickupLat': d.pickupLat,
                        'pickupLng': d.pickupLng,
                        'dropoffLat': d.dropoffLat,
                        'dropoffLng': d.dropoffLng,
                        'riderInfo': {
                          'name': rider?.displayName,
                          'email': rider?.email,
                          'phone': rider?.phoneNumber,
                        },
                      };

                      debugPrint('[BOOKING] submit start');
                      debugPrint('[BOOKING] pickup=$pickupLocation');
                      debugPrint('[BOOKING] dropoff=$dropoffLocation');
                      debugPrint('[BOOKING] vehicle=$selectedVehicle');
                      debugPrint('[BOOKING] date=$selectedDate');
                      debugPrint('[BOOKING] time=$selectedTime');
                      debugPrint('[BOOKING] durationHours=$durationHours');
                      debugPrint('[BOOKING] riderUid=${rider?.uid}');
                      debugPrint('[BOOKING] payload=$bookingPayload');
                      final bookingId = await _createBooking(bookingPayload);

                      if (!context.mounted) return;

                      context.go('/booking/live/$bookingId');
                    } catch (e, st) {
                      debugPrint('[BOOKING] submit failed: $e');
                      debugPrint('[BOOKING] stack: $st');

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Booking failed: $e'),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isSubmitting = false;
                        });
                      }
                    }

                    return;
                  }

                  // ── Hard guard: NO Firestore client writes allowed here ──────
                  // If this method ever tries to write Firestore directly, throw
                  // immediately so the bug is impossible to miss.
                  // All booking creation goes through createBookingHttp (HTTP).
                  // ────────────────────────────────────────────────────────────
                  debugPrint('[BOOKING] submit pressed');
                  debugPrint('[PF] onPlaceBooking: HTTP path active — Firestore client writes DISABLED');
                  if (mounted) {
                    setState(() {
                      _submitErrorMessage = null;
                      _submitErrorRoute = null;
                      _submitErrorBookingId = null;
                    });
                  }

                  if (!context.mounted) return;

                  final okLogin = await _ensureLoggedIn(context);
                  if (!okLogin) return;
                  if (!context.mounted) return;
                  debugPrint('[BOOKING] validation passed');

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const AlertDialog(
                      title: Text('Placing booking…'),
                      content: Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    ),
                  );

                  try {
                    debugPrint('[BOOKING] submit start');
                    debugPrint('[BOOKING] pickup=${d.pickup}');
                    debugPrint('[BOOKING] dropoff=${d.dropoff}');
                    debugPrint('[BOOKING] vehicle=${d.vehicleType.name}');
                    debugPrint('[BOOKING] date=${d.scheduledStart}');
                    debugPrint('[BOOKING] durationHours=${d.durationHours}');
                    debugPrint('[BOOKING] starting create booking');
                    // HTTP POST → createBookingHttp Cloud Function.
                    // booking_controller.createBooking() uses http.post with
                    // Authorization: Bearer <ID token>. Zero Firestore client writes.
                    final id = await ctrl.createBooking(markPaid: true);
                    debugPrint('[BOOKING] create booking response=$id');

                    if (!context.mounted) return;
                    Navigator.of(context, rootNavigator: true).pop();

                    if (id == null || id.trim().isEmpty) {
                      debugPrint('[BOOKING] bookingId invalid response=$id');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to create booking.')),
                      );
                      return;
                    }

                    final docRef = FirebaseFirestore.instance.collection('bookings').doc(id);
                    debugPrint('[BOOKING] created bookingId=$id');
                    debugPrint('[BOOKING] waiting for bookings/$id to exist');
                    var bookingExists = false;
                    for (var i = 0; i < 10; i++) {
                      final snap = await docRef.get();
                      debugPrint('[BOOKING] poll[$i] bookings/$id exists=${snap.exists}');
                      if (snap.exists) {
                        bookingExists = true;
                        break;
                      }
                      await Future.delayed(const Duration(milliseconds: 300));
                    }
                    if (!bookingExists) {
                      throw Exception('Booking document not found after create: $id');
                    }

                    debugPrint('[BOOKING] navigating to /booking/live/$id');
                    if (!context.mounted) return;
                    final targetRoute = '/booking/live/$id';
                    try {
                      context.go(targetRoute);
                    } catch (e, st) {
                      debugPrint('[BOOKING] navigation error=$e');
                      debugPrint('[BOOKING] navigation stack=$st');
                      if (mounted) {
                        setState(() {
                          _submitErrorMessage = 'Navigation failed: $e';
                          _submitErrorRoute = targetRoute;
                          _submitErrorBookingId = id;
                        });
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Navigation failed: $e')),
                      );
                    }
                  } catch (e, st) {
                    debugPrint('[BOOKING] submit error=$e');
                    debugPrint('[BOOKING] submit stack=$st');

                    if (!context.mounted) return;
                    Navigator.of(context, rootNavigator: true).pop();

                    if (mounted) {
                      setState(() {
                        _submitErrorMessage = e.toString();
                        _submitErrorRoute = '/booking/live';
                        _submitErrorBookingId = null;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Booking failed: $e'),
                        ),
                      );
                    }
                  }
                },
              );
          }
        }

        return Scaffold(
          appBar: null,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 720;
                final pad = EdgeInsets.symmetric(horizontal: isNarrow ? 14 : 18, vertical: 18);
                return Padding(
                  padding: pad,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: ListView(
                        children: [
                          StreamBuilder<User?>(
                            stream: FirebaseAuth.instance.userChanges(),
                            builder: (context, snap) {
                              final user = snap.data;
                              final isLoggedIn = user != null;
                              final display = (user?.displayName ?? '').trim();
                              final email = (user?.email ?? '').trim();
                              final name = display.isNotEmpty
                                  ? display
                                  : (email.isNotEmpty ? email.split('@').first : null);
                              final label = isLoggedIn ? 'Sign out' : 'Log in / Sign up';

                              return PFHeroHeader(
                                welcomeName: name,
                                action: Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  alignment: WrapAlignment.end,
                                  children: [
                                    SizedBox(
                                      height: 44,
                                      child: OutlinedButton(
                                        onPressed: () => context.go('/portal'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: PFColors.ink,
                                          side: const BorderSide(color: PFColors.border),
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                        ),
                                        child: const Text('Customer Portal', style: TextStyle(fontWeight: FontWeight.w800)),
                                      ),
                                    ),
                                    SizedBox(
                                      height: 44,
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          if (isLoggedIn) {
                                            await FirebaseAuth.instance.signOut();
                                            if (context.mounted) context.go('/login');
                                          } else {
                                            context.go('/login');
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: PFColors.pink1,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                        ),
                                        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 14),

                          if (_resumeChecking)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: PFColors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: PFColors.pink1.withValues(alpha: 0.25)),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Checking for an active trip…',
                                      style: TextStyle(fontWeight: FontWeight.w800, color: PFColors.ink),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (_activeBookingId != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: PFColors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: PFColors.goldBase.withValues(alpha: 0.55)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.directions_car, size: 18, color: PFColors.ink),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Active trip detected.',
                                      style: TextStyle(fontWeight: FontWeight.w900, color: PFColors.ink),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _trackEvent('booking_resume_tap', props: {'bookingId': _activeBookingId});
                                      context.go('/booking/live/$_activeBookingId');
                                    },
                                    child: const Text('Resume'),
                                  ),
                                ],
                              ),
                            ),

                          if (_submitErrorMessage != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: PFColors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: PFColors.danger.withValues(alpha: 0.55),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Booking flow error',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: PFColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _submitErrorMessage!,
                                    style: const TextStyle(color: PFColors.inkSoft),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Route: ${_submitErrorRoute ?? '—'}',
                                    style: const TextStyle(
                                      color: PFColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Booking ID: ${_submitErrorBookingId ?? '—'}',
                                    style: const TextStyle(
                                      color: PFColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          _StepPills(
                      step: _step,
                      onTap: (i) {
                        if (i <= _step) {
                          setState(() => _step = i);
                          return;
                        }

                        if (requiresCallEffective) {
                          _showCallDialog(context, overrideMessage: state.error, phone: supportPhone);
                          return;
                        }

                        final ok = ctrl.validateForQuote();
                        if (!ok) {
                          final msg = ref.read(bookingControllerProvider).error ?? '';
                          if (msg.toLowerCase().contains('service area')) {
                            _showCallDialog(context, overrideMessage: msg, phone: supportPhone);
                          }
                          return;
                        }

                        setState(() => _step = i);
                      },
                    ),

                    const SizedBox(height: 12),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) {
                        final offset = Tween<Offset>(
                          begin: const Offset(0.02, 0),
                          end: Offset.zero,
                        ).animate(anim);
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(position: offset, child: child),
                        );
                      },
                      child: Container(
                        key: ValueKey(_step),
                        child: stepView(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _LegalFooter(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class PFHeroHeader extends StatelessWidget {
  final Widget? action;
  final String? welcomeName;
  const PFHeroHeader({super.key, this.action, this.welcomeName});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: PFColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PFColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 6),
            color: Colors.black.withValues(alpha: 0.07),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Pink-to-gold top accent stripe
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Container(
                height: 3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [PFColors.pink2, PFColors.goldBase, PFColors.pink1],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 21, 18, 18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 520;
                final logoWidth = narrow ? 160.0 : 210.0;
                final logoHeight = narrow ? 52.0 : 72.0;
                final titleSize = narrow ? 17.0 : 21.0;

                final badge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: PFColors.pink1.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: PFColors.pink1.withValues(alpha: 0.30)),
                  ),
                  child: const Text(
                    'Premium',
                    style: TextStyle(
                      color: PFColors.pink1,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                );

                final welcomeBlock = (welcomeName != null && welcomeName!.trim().isNotEmpty)
                    ? Text(
                        'Welcome, ${welcomeName!.trim()}',
                        style: TextStyle(
                          color: PFColors.pink1,
                          fontSize: narrow ? 12 : 13,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null;

                final titleBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (welcomeBlock != null) ...[
                      welcomeBlock,
                      const SizedBox(height: 5),
                    ],
                    SizedBox(
                      height: titleSize + 4,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Luxury Chauffeured Booking',
                          style: TextStyle(
                            color: PFColors.ink,
                            fontSize: titleSize,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: (narrow ? 12 : 13) + 4,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Escalade • Navigator • Premium Experience',
                          style: TextStyle(
                            color: PFColors.muted,
                            fontSize: narrow ? 12 : 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                );

                final logoWidget = SizedBox(
                  height: logoHeight,
                  width: logoWidth,
                  child: Image.asset(
                    'assets/logo/pink_fleets_logo.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, _, _) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'PINK FLEETS',
                        style: TextStyle(
                          color: PFColors.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: narrow ? 18 : 20,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ),
                  ),
                );

                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          logoWidget,
                          const Spacer(),
                          badge,
                        ],
                      ),
                      const SizedBox(height: 12),
                      titleBlock,
                      if (action != null) ...[
                        const SizedBox(height: 12),
                        SizedBox(width: double.infinity, child: action!),
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    logoWidget,
                    const SizedBox(width: 16),
                    Expanded(child: titleBlock),
                    badge,
                    if (action != null) ...[
                      const SizedBox(width: 12),
                      action!,
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter();

  Future<void> _open(BuildContext ctx, String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open link — please allow popups for this site.',
            ),
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Could not open link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: PFColors.ink.withValues(alpha: 0.65),
    );
    final linkStyle = baseStyle?.copyWith(
      color: PFColors.pink1,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    );

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Text('By continuing, you agree to our', style: baseStyle),
          InkWell(
            onTap: () => _open(context, 'https://www.pinkfleets.com/terms-and-conditions'),
            child: Text('Terms & Conditions', style: linkStyle),
          ),
          Text('and', style: baseStyle),
          InkWell(
            onTap: () => _open(context, 'https://www.pinkfleets.com/privacy-policy'),
            child: Text('Privacy Policy', style: linkStyle),
          ),
          Text('.', style: baseStyle),
        ],
      ),
    );
  }
}

class _StepPills extends StatelessWidget {
  final int step;
  final void Function(int) onTap;

  const _StepPills({required this.step, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget pill(String text, int i) {
      final active = step == i;
      final done = step > i;

      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onTap(i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: active ? pfGoldGradient() : null,
            color: active ? null : PFColors.white,
            border: Border.all(
              color: (active || done)
                  ? PFColors.goldBase.withValues(alpha: 0.55)
                  : PFColors.pink1.withValues(alpha: 0.25),
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w900, color: PFColors.ink),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 520;
        if (narrow) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(width: double.infinity, child: pill('1. Details', 0)),
              SizedBox(width: double.infinity, child: pill('2. Quote', 1)),
              SizedBox(width: double.infinity, child: pill('3. Pay', 2)),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: pill('1. Details', 0)),
            const SizedBox(width: 10),
            Expanded(child: pill('2. Quote', 1)),
            const SizedBox(width: 10),
            Expanded(child: pill('3. Pay', 2)),
          ],
        );
      },
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final BookingDraft draft;
  final String? errorText;
  final bool requiresCall;

  final VoidCallback onPrimaryPressed;

  final void Function(String text, String? placeId, PlaceLatLng? latLng) onPickupChanged;
  final void Function(String text, String? placeId, PlaceLatLng? latLng) onDropoffChanged;

  // >>> ADDED: Add-Stop callbacks
  final List<String> stops;
  final VoidCallback onAddStop;
  final void Function(int index) onRemoveStop;
  final void Function(int index, String address) onStopChanged;
  // <<< END ADDED

  final Future<void> Function() onPickDateTime;
  final void Function(String v) onDurationChanged;

  final void Function(VehicleType) onVehicleSelected;
  final void Function(int? v) onPassengersChanged;

  final void Function(bool? v) onAcceptedTerms;
  final void Function(bool? v) onSurveillanceConsent;
  final void Function(bool? v) onNoSmokingAck;

  const _DetailsCard({
    required this.draft,
    required this.errorText,
    required this.requiresCall,
    required this.onPrimaryPressed,
    required this.onPickupChanged,
    required this.onDropoffChanged,
    required this.stops,
    required this.onAddStop,
    required this.onRemoveStop,
    required this.onStopChanged,
    required this.onPickDateTime,
    required this.onDurationChanged,
    required this.onVehicleSelected,
    required this.onPassengersChanged,
    required this.onAcceptedTerms,
    required this.onSurveillanceConsent,
    required this.onNoSmokingAck,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (errorText != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PFColors.blush,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: PFColors.pink1.withValues(alpha: 0.25)),
                ),
                child: Text(errorText!, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 12),
            ],

            AddressAutocompleteField(
              label: 'Pickup Location',
              hint: 'Start typing an address',
              onChangedOrSelected: onPickupChanged,
            ),
            const SizedBox(height: 12),
            AddressAutocompleteField(
              label: 'Dropoff Location',
              hint: 'Start typing an address',
              onChangedOrSelected: onDropoffChanged,
            ),

            // >>> ADDED: Intermediate stops
            ...stops.asMap().entries.map((e) {
              final i = e.key;
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AddressAutocompleteField(
                        label: 'Stop ${i + 1}',
                        hint: 'Start typing an address',
                        onChangedOrSelected: (text, placeId, latLng) =>
                            onStopChanged(i, text),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: IconButton(
                        onPressed: () => onRemoveStop(i),
                        icon: const Icon(Icons.remove_circle_outline),
                        color: PFColors.danger,
                        tooltip: 'Remove stop',
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddStop,
                icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                label: const Text('Add Stop'),
                style: TextButton.styleFrom(
                  foregroundColor: PFColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            // <<< END ADDED

            const SizedBox(height: 12),

            _ScheduleRideCard(
              draft: draft,
              onPickDateTime: onPickDateTime,
              onDurationChanged: onDurationChanged,
            ),

            const SizedBox(height: 12),

            _VehicleCards(selected: draft.vehicleType, onSelected: onVehicleSelected),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: draft.passengers,
                    items: [1, 2, 3, 4, 5, 6]
                        .map((n) => DropdownMenuItem(value: n, child: Text('$n passengers')))
                        .toList(),
                    onChanged: onPassengersChanged,
                    decoration: const InputDecoration(labelText: 'Passengers'),
                  ),
                ),
              ],
            ),
            const Divider(height: 22),

            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: draft.acceptedTerms,
              onChanged: onAcceptedTerms,
              title: const Text('I agree to the Terms & Conditions'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: draft.acceptedSurveillanceConsent,
              onChanged: onSurveillanceConsent,
              title: const Text('I consent to video/audio surveillance policy'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: draft.acknowledgedNoSmoking,
              onChanged: onNoSmokingAck,
              title: const Text('No smoking or vaping in the vehicle'),
            ),

            const SizedBox(height: 12),

            PFButtonPrimary(
              label: requiresCall ? 'Call to Book' : 'Get Quote',
              onPressed: onPrimaryPressed,
              fullWidth: true,
            ),

            const SizedBox(height: 12),
            const Text(
              'All reservations are charged in full at time of booking.\n'
              '2-hour minimum • \$175/hr • 20% gratuity.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleCards extends StatelessWidget {
  final VehicleType selected;
  final void Function(VehicleType) onSelected;

  const _VehicleCards({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _VehicleCard(
            title: 'Escalade',
            subtitle: 'Cadillac • Luxury SUV',
            assetPath: 'assets/logo/cadillac_escalade.png',
            selected: selected == VehicleType.escalade,
            onTap: () => onSelected(VehicleType.escalade),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _VehicleCard(
            title: 'Navigator',
            subtitle: 'Lincoln • Luxury SUV',
            assetPath: 'assets/logo/lincoln_navigator.png',
            selected: selected == VehicleType.navigator,
            onTap: () => onSelected(VehicleType.navigator),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _VehicleCard(
            title: 'Best Available',
            subtitle: 'We choose the best fit',
            assetPath: null,
            selected: selected == VehicleType.bestAvailable,
            onTap: () => onSelected(VehicleType.bestAvailable),
          ),
        ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? assetPath;
  final bool selected;
  final VoidCallback onTap;

  const _VehicleCard({
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? PFColors.goldBase.withValues(alpha: 0.95) : PFColors.pink1.withValues(alpha: 0.25);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: PFColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              offset: const Offset(0, 10),
              color: Colors.black.withValues(alpha: 0.06),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: assetPath != null
                      ? Image.asset(
                          assetPath!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: PFColors.subtle,
                            child: const Center(child: Text('Image missing')),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(gradient: pfGoldGradient()),
                          child: Center(
                            child: Icon(Icons.auto_awesome,
                                size: 34, color: PFColors.ink.withValues(alpha: 0.85)),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(subtitle, style: TextStyle(color: PFColors.ink.withValues(alpha: 0.65))),
              const SizedBox(height: 6),
              if (selected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: pfGoldGradient(),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Selected',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w900, color: PFColors.ink),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final BookingDraft draft;
  final Map<String, double> quote;
  final double minBookingHours;
  final double minNoticeHours;
  final double gratuityPct;
  final double taxRatePct;
  final double bookingFee;
  final double fuelSurchargePct;
  final double cancelWindowHours;
  final double lateCancelFee;
  final double serviceAreaMiles;
  final String defaultCity;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  const _QuoteCard({
    required this.draft,
    required this.quote,
    required this.minBookingHours,
    required this.minNoticeHours,
    required this.gratuityPct,
    required this.taxRatePct,
    required this.bookingFee,
    required this.fuelSurchargePct,
    required this.cancelWindowHours,
    required this.lateCancelFee,
    required this.serviceAreaMiles,
    required this.defaultCity,
    required this.onBack,
    required this.onContinue,
  });

  String money(double v) => '\$${v.toStringAsFixed(2)}';

  String vehicleLabel(VehicleType t) {
    switch (t) {
      case VehicleType.escalade:
        return 'Cadillac Escalade';
      case VehicleType.navigator:
        return 'Lincoln Navigator';
      case VehicleType.bestAvailable:
        return 'Best Available';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Your Quote', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 10),
            Text('Vehicle: ${vehicleLabel(draft.vehicleType)}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('Pickup: ${draft.pickup}'),
            Text('Dropoff: ${draft.dropoff}'),
            Text('Start: ${formatDateTime(draft.scheduledStart)}'),
            const SizedBox(height: 14),

            _row('Billable Hours', quote['billableHours']!.toStringAsFixed(2)),
            _row('Rate', '${money(quote['hourlyRate']!)} / hour'),
            const Divider(height: 24),

            _row('Base', money(quote['base']!)),
            _row('Gratuity (20%)', money(quote['gratuity']!)),
            _row('Fuel Surcharge', money(quote['fuel']!)),
            const Divider(height: 24),

            if ((quote['parking'] ?? 0) > 0) _row('Parking', money(quote['parking']!)),
            if ((quote['tolls'] ?? 0) > 0) _row('Tolls', money(quote['tolls']!)),
            if ((quote['venue'] ?? 0) > 0) _row('Venue/Staging', money(quote['venue']!)),
            if ((quote['fees'] ?? 0) > 0) _row('Fees Total', money(quote['fees']!)),
            _row('Tax', money(quote['tax']!)),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: PFColors.blush,
                border: Border.all(color: PFColors.pink1.withValues(alpha: 0.25)),
              ),
              child: _row('Total Due Now', money(quote['total']!), bold: true),
            ),

            const SizedBox(height: 6),
            const Text(
              'Additional fees (parking/tolls/venue) may be added if incurred.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PFColors.muted,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                border: Border.all(color: PFColors.pink1.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Policies', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('• Minimum booking: ${minBookingHours.toStringAsFixed(0)} hours'),
                  Text('• Minimum notice: ${minNoticeHours.toStringAsFixed(0)} hours'),
                  Text('• Service area: ${serviceAreaMiles.toStringAsFixed(0)} miles from $defaultCity'),
                  Text('• Gratuity: ${gratuityPct.toStringAsFixed(0)}%'),
                  Text('• Tax rate: ${taxRatePct.toStringAsFixed(2)}%'),
                  Text('• Booking fee: ${money(bookingFee)}'),
                  Text('• Fuel surcharge: ${fuelSurchargePct.toStringAsFixed(2)}%'),
                  Text('• Cancel window: ${cancelWindowHours.toStringAsFixed(0)} hours'),
                  Text('• Late cancel fee: ${money(lateCancelFee)}'),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: onBack, child: const Text('Back'))),
                const SizedBox(width: 12),
                Expanded(child: PFButtonPrimary(label: 'Continue', onPressed: onContinue)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String left, String right, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(left, style: style),
        Text(right, style: style),
      ],
    );
  }
}

class _PayCard extends StatelessWidget {
  final VoidCallback onBack;
  final double minBookingHours;
  final double minNoticeHours;
  final double gratuityPct;
  final double taxRatePct;
  final double bookingFee;
  final double fuelSurchargePct;
  final double cancelWindowHours;
  final double lateCancelFee;

  // >>> ADDED: prototype booking placement (until Stripe checkout is wired)
  final Future<void> Function() onPlaceBooking;
  // <<< END ADDED

  const _PayCard({
    required this.onBack,
    required this.minBookingHours,
    required this.minNoticeHours,
    required this.gratuityPct,
    required this.taxRatePct,
    required this.bookingFee,
    required this.fuelSurchargePct,
    required this.cancelWindowHours,
    required this.lateCancelFee,
    required this.onPlaceBooking,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Payment', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 10),
            const Text(
              'Stripe checkout will be connected later.\n'
              'Right now we are finalizing UX + operational logic.',
            ),

            const SizedBox(height: 14),

            // >>> ADDED: Place Booking button for dispatch testing
            PFButtonPrimary(
              label: 'Place Booking',
              onPressed: () async => onPlaceBooking(),
              fullWidth: true,
            ),
            const SizedBox(height: 10),
            Text(
              'This creates the booking + pricing snapshot and starts dispatch. '
              'Replace this button with Stripe Checkout when ready.',
              textAlign: TextAlign.center,
              style: TextStyle(color: PFColors.ink.withValues(alpha: 0.65)),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'BOOKING HTTP BUILD: 2026-03-04',
                style: TextStyle(
                  color: PFColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            // <<< END ADDED

            const SizedBox(height: 16),
            OutlinedButton(onPressed: onBack, child: const Text('Back')),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                border: Border.all(color: PFColors.pink1.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Policy Summary', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('• Minimum booking: ${minBookingHours.toStringAsFixed(0)} hours'),
                  Text('• Minimum notice: ${minNoticeHours.toStringAsFixed(0)} hours'),
                  Text('• Gratuity: ${gratuityPct.toStringAsFixed(0)}%'),
                  Text('• Tax rate: ${taxRatePct.toStringAsFixed(2)}%'),
                  Text('• Booking fee: \$${bookingFee.toStringAsFixed(2)}'),
                  Text('• Fuel surcharge: ${fuelSurchargePct.toStringAsFixed(2)}%'),
                  Text('• Cancel window: ${cancelWindowHours.toStringAsFixed(0)} hours'),
                  Text('• Late cancel fee: \$${lateCancelFee.toStringAsFixed(2)}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Luxury Schedule Ride card ─────────────────────────────────────────────────
class _ScheduleRideCard extends StatelessWidget {
  final BookingDraft draft;
  final Future<void> Function() onPickDateTime;
  final void Function(String) onDurationChanged;

  const _ScheduleRideCard({
    required this.draft,
    required this.onPickDateTime,
    required this.onDurationChanged,
  });

  String _fmtDate(DateTime? dt) {
    if (dt == null) return 'Select Date';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return 'Select Time';
    var h = dt.hour % 12;
    if (h == 0) h = 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final hasDate = draft.scheduledStart != null;
    return Container(
      decoration: BoxDecoration(
        color: PFColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PFColors.border),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: PFColors.pink1.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_month_rounded, size: 16, color: PFColors.pink1),
              ),
              const SizedBox(width: 10),
              const Text(
                'Schedule Ride',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 380;
              final dateChip = _DTChip(
                icon: Icons.today_rounded,
                label: 'Date',
                value: _fmtDate(draft.scheduledStart),
                filled: hasDate,
                onTap: onPickDateTime,
              );
              final timeChip = _DTChip(
                icon: Icons.schedule_rounded,
                label: 'Time',
                value: _fmtTime(draft.scheduledStart),
                filled: hasDate,
                onTap: onPickDateTime,
              );
              if (narrow) {
                return Column(
                  children: [
                    SizedBox(width: double.infinity, child: dateChip),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: timeChip),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: dateChip),
                  const SizedBox(width: 10),
                  Expanded(child: timeChip),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Duration (Hours)',
              hintText: 'Minimum 2',
              prefixIcon: Icon(Icons.timelapse_rounded),
            ),
            onChanged: onDurationChanged,
          ),
          const SizedBox(height: 8),
          const Text(
            'Minimum booking notice applies.',
            style: TextStyle(color: PFColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DTChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool filled;
  final Future<void> Function() onTap;

  const _DTChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async => onTap(),
      child: SizedBox(
        height: 52,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: filled
                ? PFColors.pink1.withValues(alpha: 0.08)
                : PFColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: filled
                  ? PFColors.pink1.withValues(alpha: 0.40)
                  : PFColors.border,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: filled ? PFColors.pink1 : PFColors.muted),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: PFColors.muted,
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: filled ? PFColors.ink : PFColors.muted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
