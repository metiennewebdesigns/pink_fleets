import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../shared/widgets/live_trip_map.dart';
import '../../shared/date_time_format.dart';
import '../../theme/pink_fleets_theme.dart';

/// Router-proof:
/// - Works with direct constructor: BookingLiveScreen(bookingId: 'abc')
/// - Works with named route + args: Navigator.pushNamed('/booking-live', arguments: {'bookingId':'abc'})
/// - Works with query param (if your router supports it): /booking-live?bookingId=abc
class BookingLiveScreen extends StatefulWidget {
  /// If you can pass it directly, do it.
  final String? bookingId;

  const BookingLiveScreen({super.key, this.bookingId});

  /// Named route helper (optional). If you use Navigator routes, add this:
  /// routes: { BookingLiveScreen.routeName: (_) => const BookingLiveScreen() }
  static const routeName = '/booking-live';

  @override
  State<BookingLiveScreen> createState() => _BookingLiveScreenState();
}

class _BookingLiveScreenState extends State<BookingLiveScreen> {
  final _firestore = FirebaseFirestore.instance;

  // >>> ADDED: Real ETA (Distance Matrix via Cloud Function getEta)
  Timer? _etaTimer;
  String? _etaText;
  Map<String, double>? _lastEtaOrigin;
  Map<String, double>? _lastEtaDest;
  bool _etaRunning = false;
  bool _forceTimeout = false;
  bool _bookingLoaded = false;
  bool _bookingMissing = false;
  Timer? _bookingTimeout;
  // <<< END ADDED

  String? _resolveBookingId(BuildContext context) {
    // 1) Constructor param
    if (widget.bookingId != null && widget.bookingId!.trim().isNotEmpty) {
      return widget.bookingId!.trim();
    }

    // 2) Navigator named route arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final v = args['bookingId'] ?? args['id'];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    if (args is String && args.trim().isNotEmpty) return args.trim();

    // 3) Try query params if your router sets RouteSettings.name like: /booking-live?bookingId=abc
    final name = ModalRoute.of(context)?.settings.name ?? '';
    if (name.contains('?')) {
      final uri = Uri.tryParse(name);
      final qp = uri?.queryParameters;
      final v = qp?['bookingId'] ?? qp?['id'];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }

    return null;
  }

  void _startBookingTimeout() {
    debugPrint('[LIVE BOOKING] booking load started');
    _bookingTimeout?.cancel();
    _bookingTimeout = Timer(const Duration(seconds: 6), () async {
      if (!mounted || _bookingLoaded) return;
      final bookingId = _resolveBookingId(context);
      if (bookingId != null && bookingId.trim().isNotEmpty) {
        try {
          final checkSnap =
              await _firestore.collection('bookings').doc(bookingId).get();
          debugPrint(
            '[LIVE BOOKING] timeout check bookings/$bookingId exists=${checkSnap.exists}',
          );
          if (!mounted || _bookingLoaded) return;
          if (!checkSnap.exists) {
            setState(() {
              _bookingMissing = true;
              _bookingLoaded = false;
              _forceTimeout = false;
            });
            return;
          }
        } catch (e) {
          debugPrint('[LIVE BOOKING] timeout check error=$e');
        }
      }
      debugPrint('[LIVE BOOKING] timeout triggered');
      setState(() {
        _forceTimeout = true;
      });
    });
  }

  void _markBookingLoaded() {
    if (!mounted || _bookingLoaded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _bookingLoaded) return;
      debugPrint('[LIVE BOOKING] booking loaded');
      setState(() {
        _bookingLoaded = true;
        _bookingMissing = false;
        _forceTimeout = false;
      });
    });
  }

  void _markBookingMissing() {
    if (!mounted || _bookingMissing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _bookingMissing) return;
      debugPrint('[LIVE BOOKING] booking missing');
      setState(() {
        _bookingMissing = true;
        _bookingLoaded = false;
        _forceTimeout = false;
      });
    });
  }

  void _retryBookingLoad() {
    debugPrint('[LIVE BOOKING] retry pressed');
    setState(() {
      _forceTimeout = false;
      _bookingLoaded = false;
      _bookingMissing = false;
    });
    _startBookingTimeout();
  }

  String _normStatus(dynamic raw) {
    final s = (raw ?? '').toString().trim().toLowerCase();
    return s.replaceAll(' ', '_'); // "en route" -> "en_route"
  }

  String _titleFromStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'dispatching':
        return 'Finding your driver';
      case 'offered':
        return 'Waiting for driver';
      case 'accepted':
        return 'Driver accepted';
      case 'en_route':
        return 'Driver en route';
      case 'arrived':
        return 'Driver arrived';
      case 'in_progress':
        return 'Trip in progress';
      case 'completed':
        return 'Trip completed';
      case 'cancelled':
        return 'Trip cancelled';
      case 'declined':
        return 'Declined';
      default:
        return status.isEmpty ? 'Live Booking' : status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF1E9E75);
      case 'cancelled':
      case 'declined':
        return const Color(0xFFDE5B5B);
      case 'en_route':
      case 'arrived':
      case 'in_progress':
        return PFColors.pink2;
      case 'accepted':
        return PFColors.pink1;
      default:
        return PFColors.goldBase;
    }
  }

  // Your bookings_private.pricingSnapshot.total = 450.
  // I’m treating it like cents (common). If it’s dollars, change cents=false.
  String _money(num? amount, {bool cents = true}) {
    if (amount == null) return '—';
    final value = cents ? (amount.toInt() / 100.0) : amount.toDouble();
    return '\$${value.toStringAsFixed(2)}';
  }

  String _fmtTs(dynamic v) {
    if (v == null) return '—';
    if (v is Timestamp) {
      final d = v.toDate();
      return formatDateTime(d);
    }
    return v.toString();
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w800,
          color: PFColors.muted,
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              k,
              style: const TextStyle(
                color: PFColors.muted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 7,
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: PFColors.inkSoft,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusDot(Color c) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: c.withValues(alpha: 0.45),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
      ),
    );
  }

  
  // >>> ADDED: Luxury live status UX helpers
  bool _isActiveStatus(String status) {
    return status == 'pending' ||
        status == 'dispatching' ||
        status == 'offered' ||
        status == 'accepted' ||
        status == 'en_route' ||
        status == 'arrived' ||
        status == 'in_progress';
  }

  int _simulatedEtaMinutes(String bookingId, String status) {
    // Stable pseudo-random ETA (no pickup geo in schema yet)
    // Produces 4–14 mins depending on bookingId + status.
    var h = 0;
    for (final code in bookingId.codeUnits) {
      h = (h * 31 + code) & 0x7fffffff;
    }
    final base = 4 + (h % 11); // 4..14
    if (status == 'dispatching' || status == 'offered') return base + 3;
    if (status == 'en_route') return base;
    if (status == 'arrived' || status == 'in_progress') return 0;
    return base;
  }

  Widget _luxStatusBanner({
    required String bookingId,
    required String status,
    required bool isPaid,
    required Color statusColor,
  }) {
    final title = _titleFromStatus(status);
    final eta = _simulatedEtaMinutes(bookingId, status);

    final subtitle = !isPaid
        ? 'Payment required to dispatch.'
        : (status == 'dispatching'
            ? 'Searching for the best available driver…'
            : status == 'offered'
                ? 'Offer sent. Waiting for driver response…'
                : status == 'accepted'
                    ? 'Driver confirmed. Preparing arrival…'
                    : status == 'en_route'
                        ? (_etaText != null ? 'Arriving in $_etaText' : (eta > 0 ? 'Arriving in ~$eta min' : 'Arriving now'))
                        : status == 'arrived'
                            ? 'Driver has arrived.'
                            : status == 'in_progress'
                                ? 'Trip in progress.'
                                : '');

    final badge = !isPaid ? 'UNPAID' : status.toUpperCase().replaceAll('_', ' ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PFColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PFColors.border),
      ),
      child: Row(
        children: [
          _PulseDot(color: !isPaid ? PFColors.danger : statusColor, active: _isActiveStatus(status) && isPaid),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  subtitle.isEmpty ? '—' : subtitle,
                  style: const TextStyle(color: PFColors.inkSoft, fontSize: 12, height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: PFColors.surfaceHigh,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: PFColors.border),
            ),
            child: Text(
              badge,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.3, color: PFColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
  // <<< END ADDED
Widget _glassCard({required Widget child, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PFColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? PFColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Future<void> _cancelBooking(String bookingId) async {
    await _firestore.collection('bookings').doc(bookingId).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Booking cancelled'),
          backgroundColor: PFColors.surfaceHigh,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCancelDialog(
      BuildContext context, String bookingId, String driverId) {
    final hasDriver = driverId.trim().isNotEmpty;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PFColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: PFColors.border),
        ),
        title: const Text(
          'Cancel booking?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          hasDriver
              ? 'A driver has already been assigned to your booking.\n\n'
                  'Cancelling at this stage may incur a cancellation fee. '
                  'Are you sure you want to cancel?'
              : 'No driver has been assigned yet.\n\n'
                  'You can cancel this booking at no charge.',
          style: const TextStyle(
            color: PFColors.inkSoft,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep booking'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PFColors.danger,
              foregroundColor: PFColors.ink,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _cancelBooking(bookingId);
            },
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bookingTimeout?.cancel();
    _etaTimer?.cancel();
    super.dispose();
  }

  // >>> ADDED: fetch ETA from backend
  Future<void> _fetchEta({required double oLat, required double oLng, required double dLat, required double dLng}) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('getEta');
      final res = await callable.call({
        'originLat': oLat,
        'originLng': oLng,
        'destLat': dLat,
        'destLng': dLng,
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      final seconds = (data['durationSeconds'] ?? 0) as int;
      final text = (data['durationText'] ?? '').toString();
      if (!mounted) return;
      setState(() {
        _etaText = text.isNotEmpty ? text : (seconds > 0 ? '${(seconds / 60).round()} min' : null);
      });
    } catch (_) {
      // ignore; we'll try again next tick
    }
  }

  void _ensureEtaLoop({required double oLat, required double oLng, required double dLat, required double dLng}) {
    final origin = {'lat': oLat, 'lng': oLng};
    final dest = {'lat': dLat, 'lng': dLng};

    final same = _lastEtaOrigin != null && _lastEtaDest != null &&
        (_lastEtaOrigin!['lat'] == origin['lat']) && (_lastEtaOrigin!['lng'] == origin['lng']) &&
        (_lastEtaDest!['lat'] == dest['lat']) && (_lastEtaDest!['lng'] == dest['lng']);

    _lastEtaOrigin = origin;
    _lastEtaDest = dest;

    if (!_etaRunning) {
      _etaRunning = true;
      _etaTimer?.cancel();
      // fetch immediately
      _fetchEta(oLat: oLat, oLng: oLng, dLat: dLat, dLng: dLng);
      _etaTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (!mounted) return;
        _fetchEta(oLat: oLat, oLng: oLng, dLat: dLat, dLng: dLng);
      });
    } else if (!same) {
      // coords changed — fetch immediately
      _fetchEta(oLat: oLat, oLng: oLng, dLat: dLat, dLng: dLng);
    }
  }

  void _stopEtaLoop() {
    _etaTimer?.cancel();
    _etaTimer = null;
    _etaRunning = false;
  }
  // <<< END ADDED

  @override
  void initState() {
    super.initState();
    _startBookingTimeout();
  }

  @override
  Widget build(BuildContext context) {
    final bookingId = _resolveBookingId(context);
    final bg = PFColors.canvas;

    if (bookingId == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: const Text('Live Booking'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Text(
              "No bookingId was provided.\n\n"
              "Open this screen with:\n"
              "• BookingLiveScreen(bookingId: 'YOUR_ID')\n"
              "or\n"
              "• Navigator.pushNamed('${BookingLiveScreen.routeName}', arguments: {'bookingId':'YOUR_ID'})",
              textAlign: TextAlign.center,
              style: const TextStyle(color: PFColors.inkSoft),
            ),
          ),
        ),
      );
    }

    final bookingDoc = _firestore.collection('bookings').doc(bookingId);
    final bookingPrivateDoc = _firestore.collection('bookings_private').doc(bookingId);

    return Scaffold(
      backgroundColor: PFColors.canvas,
      appBar: AppBar(
        backgroundColor: PFColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Live Booking',
          style: TextStyle(fontWeight: FontWeight.w800, color: PFColors.ink),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: PFColors.border),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: bookingDoc.snapshots(),
        builder: (context, bookingSnap) {
          debugPrint('[LIVE BOOKING] route bookingId=$bookingId');
          debugPrint('[LIVE BOOKING] reading bookings/$bookingId');
          debugPrint('[LIVE BOOKING] connection=${bookingSnap.connectionState}');
          debugPrint('[LIVE BOOKING] hasData=${bookingSnap.hasData}');
          debugPrint('[LIVE BOOKING] exists=${bookingSnap.data?.exists}');
          debugPrint('[LIVE BOOKING] error=${bookingSnap.error}');

          if (bookingSnap.hasError) {
            return Center(child: Text('Error loading booking: ${bookingSnap.error}'));
          }

          // Only show timeout if data has genuinely not arrived.
          // If the stream has delivered the doc (even after the timer fired),
          // skip the timeout gate so _markBookingLoaded() is reached below.
          final hasLiveData = bookingSnap.hasData && (bookingSnap.data?.exists ?? false);
          if (_bookingMissing && !hasLiveData) {
            return const Center(child: Text('Booking not found'));
          }

          if (_forceTimeout && !_bookingLoaded && !hasLiveData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Loading booking took too long.',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text('Tap below to retry.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _retryBookingLoad,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (bookingSnap.connectionState == ConnectionState.waiting &&
              !_forceTimeout &&
              !_bookingLoaded) {
            debugPrint('[LIVE BOOKING] waiting for booking $bookingId');
            return const Center(child: CircularProgressIndicator());
          }

          if (!bookingSnap.hasData || !bookingSnap.data!.exists) {
            _markBookingMissing();
            return const Center(child: Text('Booking not found'));
          }

          _markBookingLoaded();

          final booking = bookingSnap.data!.data() ?? {};
          final status = _normStatus(booking['status']);

          final assigned = (booking['assigned'] is Map)
              ? (booking['assigned'] as Map).cast<String, dynamic>()
              : <String, dynamic>{};

          final riderInfo = (booking['riderInfo'] is Map)
              ? (booking['riderInfo'] as Map).cast<String, dynamic>()
              : <String, dynamic>{};

          final overtime = (booking['overtime'] is Map)
              ? (booking['overtime'] as Map).cast<String, dynamic>()
              : <String, dynamic>{};

          final driverId = (assigned['driverId'] ?? '').toString();
          final vehicleId = (assigned['vehicleId'] ?? '').toString();
          final adminDecision = (booking['adminDecision'] ?? '').toString();

          final canCancel = status == 'pending' ||
              status == 'dispatching' ||
              status == 'offered';

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: bookingPrivateDoc.snapshots(),
            builder: (context, privSnap) {
              final priv = privSnap.data?.data() ?? {};
              final paymentStatus = (priv['paymentStatus'] ?? 'unknown').toString();
              final pricingSnapshot = (priv['pricingSnapshot'] is Map)
                  ? (priv['pricingSnapshot'] as Map).cast<String, dynamic>()
                  : <String, dynamic>{};
              final total = pricingSnapshot['total'] as num?;

              final isPaid = paymentStatus.toLowerCase() == 'paid';

              // >>> ADDED: start/stop ETA loop (real ETA) when possible
              final pg = priv['pickupGeo'];
              final dg = priv['dropoffGeo'];
              double? oLat;
              double? oLng;
              final ol = assigned['driverLocation'] ?? booking['driverLocation'];
              if (ol is GeoPoint) {
                oLat = ol.latitude;
                oLng = ol.longitude;
              } else if (ol is Map) {
                final m = Map<String, dynamic>.from(ol);
                oLat = (m['lat'] as num?)?.toDouble() ?? (m['latitude'] as num?)?.toDouble();
                oLng = (m['lng'] as num?)?.toDouble() ?? (m['longitude'] as num?)?.toDouble();
              }
              double? dLat;
              double? dLng;
              GeoPoint? pickupGeo;
              GeoPoint? dropoffGeo;
              final bookingPickupLat =
                  (booking['pickupLat'] as num?)?.toDouble();
              final bookingPickupLng =
                  (booking['pickupLng'] as num?)?.toDouble();
              final bookingDropoffLat =
                  (booking['dropoffLat'] as num?)?.toDouble();
              final bookingDropoffLng =
                  (booking['dropoffLng'] as num?)?.toDouble();
              if (pg is GeoPoint) {
                dLat = pg.latitude;
                dLng = pg.longitude;
                pickupGeo = pg;
              } else if (pg is Map) {
                final m = Map<String, dynamic>.from(pg);
                dLat = (m['lat'] as num?)?.toDouble();
                dLng = (m['lng'] as num?)?.toDouble();
                if (dLat != null && dLng != null) {
                  pickupGeo = GeoPoint(dLat, dLng);
                }
              }

              if (dg is GeoPoint) {
                dropoffGeo = dg;
              } else if (dg is Map) {
                final m = Map<String, dynamic>.from(dg);
                final lat = (m['lat'] as num?)?.toDouble();
                final lng = (m['lng'] as num?)?.toDouble();
                if (lat != null && lng != null) {
                  dropoffGeo = GeoPoint(lat, lng);
                }
              }

              pickupGeo ??= (bookingPickupLat != null &&
                      bookingPickupLng != null)
                  ? GeoPoint(bookingPickupLat, bookingPickupLng)
                  : null;
              dropoffGeo ??= (bookingDropoffLat != null &&
                      bookingDropoffLng != null)
                  ? GeoPoint(bookingDropoffLat, bookingDropoffLng)
                  : null;

              dLat ??= pickupGeo?.latitude;
              dLng ??= pickupGeo?.longitude;

              if (isPaid && (status == 'accepted' || status == 'en_route')) {
                final oLatVal = oLat;
                final oLngVal = oLng;
                final dLatVal = dLat;
                final dLngVal = dLng;
                if (oLatVal != null && oLngVal != null && dLatVal != null && dLngVal != null) {
                  _ensureEtaLoop(oLat: oLatVal, oLng: oLngVal, dLat: dLatVal, dLng: dLngVal);
                } else {
                  _stopEtaLoop();
                }
              } else {
                _stopEtaLoop();
              }
              // <<< END ADDED

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (!isPaid)
                    _glassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment required',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: PFColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Complete payment to release dispatch and enable full live tracking.',
                            style: TextStyle(color: PFColors.inkSoft, height: 1.25),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Pay Now is coming soon.')),
                                );
                              },
                              child: const Text('Pay Now'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!isPaid) const SizedBox(height: 10),
                  _luxStatusBanner(
                    bookingId: bookingId,
                    status: status,
                    isPaid: isPaid,
                    statusColor: _statusColor(status),
                  ),
                  const SizedBox(height: 10),
                  _glassCard(
                    child: Row(
                      children: [
                        _statusDot(_statusColor(status)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _titleFromStatus(status),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Booking ID: $bookingId',
                                style: const TextStyle(
                                  color: PFColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canCancel)
                          TextButton(
                            onPressed: () => _showCancelDialog(
                                context, bookingId, driverId),
                            style: TextButton.styleFrom(
                              foregroundColor: PFColors.danger,
                            ),
                            child: const Text('Cancel booking'),
                          ),
                      ],
                    ),
                  ),

                  _sectionTitle('Assignment'),
                  _glassCard(
                    child: Column(
                      children: [
                        _kv('Driver ID', driverId.isEmpty ? '—' : driverId),
                        _kv('Vehicle ID', vehicleId.isEmpty ? '—' : vehicleId),
                        _kv('Admin Decision', adminDecision.isEmpty ? '—' : adminDecision),

                        // >>> ADDED: Driver details (live lookup)
                        if (driverId.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Divider(color: PFColors.border),
                          const SizedBox(height: 10),
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: _firestore.collection('drivers').doc(driverId).snapshots(),
                            builder: (context, snap) {
                              final d = snap.data?.data() ?? {};
                              final first = (d['firstName'] ?? d['name'] ?? '').toString().trim();
                              final last = (d['lastName'] ?? '').toString().trim();
                              final phone = (d['phone'] ?? '').toString().trim();
                              final name = ('$first $last').trim();
                              return Column(
                                children: [
                                  _kv('Driver Name', name.isEmpty ? '—' : name),
                                  _kv('Driver Phone', phone.isEmpty ? '—' : phone),
                                ],
                              );
                            },
                          ),
                        ],
                        // <<< END ADDED

                        // >>> ADDED: Vehicle details (live lookup)
                        if (vehicleId.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Divider(color: PFColors.border),
                          const SizedBox(height: 10),
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: _firestore.collection('vehicles').doc(vehicleId).snapshots(),
                            builder: (context, snap) {
                              final v = snap.data?.data() ?? {};
                              final year = (v['year'] ?? '').toString().trim();
                              final make = (v['make'] ?? '').toString().trim();
                              final model = (v['model'] ?? '').toString().trim();
                              final plate = (v['plate'] ?? '').toString().trim();
                              final label = [year, make, model].where((x) => x.isNotEmpty).join(' ').trim();
                              return Column(
                                children: [
                                  _kv('Vehicle', label.isEmpty ? '—' : label),
                                  _kv('Plate', plate.isEmpty ? '—' : plate),
                                ],
                              );
                            },
                          ),
                        ],
                        // <<< END ADDED

                      ],
                    ),
                  ),

                  _sectionTitle('Rider'),
                  _glassCard(
                    child: Column(
                      children: [
                        _kv('Name', (riderInfo['name'] ?? '—').toString()),
                        _kv('Email', (riderInfo['email'] ?? '—').toString()),
                        _kv('Phone', (riderInfo['phone'] ?? '—').toString()),
                      ],
                    ),
                  ),

                  _sectionTitle('Timing'),
                  _glassCard(
                    child: Column(
                      children: [
                        _kv('Actual Start', _fmtTs(booking['actualStartAt'])),
                        _kv('Actual End', _fmtTs(booking['actualEndAt'])),
                        _kv('Updated', _fmtTs(booking['updatedAt'])),
                        _kv('Created', _fmtTs(booking['createdAt'])),
                      ],
                    ),
                  ),

                  
                  _sectionTitle('Live Map'),
                  PFUberLiveMap(
                    driverId: driverId.isNotEmpty ? driverId : null,
                    initialDriverLatLng: (oLat != null && oLng != null)
                        ? LatLng(oLat, oLng)
                        : null,
                    pickupGeo: pickupGeo,
                    dropoffGeo: dropoffGeo,
                    height: 280,
                    bookingStatus: status,
                    etaText: _etaText,
                  ),
                  _glassCard(
                    child: Column(
                      children: [
                        _kv(
                          'Driver location',
                          oLat != null && oLng != null
                              ? '${oLat.toStringAsFixed(5)}, ${oLng.toStringAsFixed(5)}'
                              : '—',
                        ),
                        _kv(
                          'Pickup location',
                          dLat != null && dLng != null
                              ? '${dLat.toStringAsFixed(5)}, ${dLng.toStringAsFixed(5)}'
                              : '—',
                        ),
                        if (oLat == null && dLat == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Map appears once a pickup location and/or driver location is available.',
                              style: const TextStyle(color: PFColors.muted, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),

                  _sectionTitle('Overtime'),
                  _glassCard(
                    child: Column(
                      children: [
                        _kv('Grace Minutes', (overtime['graceMinutes'] ?? '—').toString()),
                        _kv('Minutes', (overtime['minutes'] ?? '—').toString()),
                        _kv('Rate / Minute', (overtime['ratePerMinute'] ?? '—').toString()),
                        _kv('Amount', (overtime['amount'] ?? '—').toString()),
                        _kv('Computed', _fmtTs(overtime['computedAt'])),
                      ],
                    ),
                  ),

                  _sectionTitle('Payment'),
                  _glassCard(
                    child: Column(
                      children: [
                        _kv('Payment Status', paymentStatus),
                        _kv('Total', _money(total, cents: true)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Support',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  final bool active;

  const _PulseDot({required this.color, required this.active});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final pulse = widget.active ? (0.65 + (0.35 * (1 - (t - 0.5).abs() * 2))) : 0.6;
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: pulse),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}
