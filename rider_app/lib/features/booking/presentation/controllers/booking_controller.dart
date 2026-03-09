import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/booking_draft.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class BookingState {
  final BookingDraft draft;
  final String? error;

  const BookingState({required this.draft, this.error});

  BookingState copyWith({BookingDraft? draft, String? error}) =>
      BookingState(draft: draft ?? this.draft, error: error);
}

class BookingController extends StateNotifier<BookingState> {
  BookingController() : super(const BookingState(draft: BookingDraft()));

  double _centerLat = 29.9511;
  double _centerLng = -90.0715;
  double _serviceAreaMiles = 30.0;
  double _minNoticeHours = 2.0;
  double _minBookingHours = 2.0;
  double _hourlyRate = 175.0;
  double _gratuityPct = 20.0;
  double _taxRatePct = 9.2;
  double _bookingFee = 0.0;
  double _fuelSurchargePct = 0.0;
  double _cancelWindowHours = 2.0;
  double _lateCancelFee = 0.0;
  String _defaultCity = 'New Orleans';

  // --- setters ---
  void setPickup(String v, {String? placeId, double? lat, double? lng}) {
    state = state.copyWith(
      draft: state.draft.copyWith(
        pickup: v,
        pickupPlaceId: placeId,
        pickupLat: lat,
        pickupLng: lng,
      ),
      error: null,
    );
  }

  void setDropoff(String v, {String? placeId, double? lat, double? lng}) {
    state = state.copyWith(
      draft: state.draft.copyWith(
        dropoff: v,
        dropoffPlaceId: placeId,
        dropoffLat: lat,
        dropoffLng: lng,
      ),
      error: null,
    );
  }

  void setScheduledStart(DateTime dt) =>
      state = state.copyWith(draft: state.draft.copyWith(scheduledStart: dt), error: null);

  void setDurationHours(double hours) =>
      state = state.copyWith(draft: state.draft.copyWith(durationHours: hours), error: null);

  void setPassengers(int v) =>
      state = state.copyWith(draft: state.draft.copyWith(passengers: v), error: null);

  void setVehicleType(VehicleType t) =>
      state = state.copyWith(draft: state.draft.copyWith(vehicleType: t), error: null);

  void setFuelTier(FuelTier t) =>
      state = state.copyWith(draft: state.draft.copyWith(fuelTier: t), error: null);

  void toggleParking(bool v) =>
      state = state.copyWith(draft: state.draft.copyWith(includeParkingFee: v), error: null);

  void toggleTolls(bool v) =>
      state = state.copyWith(draft: state.draft.copyWith(includeTollsFee: v), error: null);

  void toggleVenue(bool v) =>
      state = state.copyWith(draft: state.draft.copyWith(includeVenueFee: v), error: null);

  void setAcceptedTerms(bool v) =>
      state = state.copyWith(draft: state.draft.copyWith(acceptedTerms: v), error: null);

  void setSurveillanceConsent(bool v) =>
      state = state.copyWith(draft: state.draft.copyWith(acceptedSurveillanceConsent: v), error: null);

  void setNoSmokingAck(bool v) =>
      state = state.copyWith(draft: state.draft.copyWith(acknowledgedNoSmoking: v), error: null);

  void applySettings(Map<String, dynamic> d) {
    _centerLat = (d['defaultLat'] as num?)?.toDouble() ?? 29.9511;
    _centerLng = (d['defaultLng'] as num?)?.toDouble() ?? -90.0715;
    _serviceAreaMiles = (d['serviceAreaMiles'] as num?)?.toDouble() ?? 30.0;
    _minNoticeHours = (d['minNoticeHours'] as num?)?.toDouble() ?? 2.0;
    _minBookingHours = (d['minBookingHours'] as num?)?.toDouble() ?? 2.0;
    _hourlyRate = (d['hourlyRate'] as num?)?.toDouble() ?? 175.0;
    _gratuityPct = (d['gratuityPct'] as num?)?.toDouble() ?? 20.0;
    _taxRatePct = (d['taxRatePct'] as num?)?.toDouble() ?? 9.2;
    _bookingFee = (d['bookingFee'] as num?)?.toDouble() ?? 0.0;
    _fuelSurchargePct = (d['fuelSurchargePct'] as num?)?.toDouble() ?? 0.0;
    _cancelWindowHours = (d['cancelWindowHours'] as num?)?.toDouble() ?? 2.0;
    _lateCancelFee = (d['lateCancelFee'] as num?)?.toDouble() ?? 0.0;
    _defaultCity = (d['defaultCity'] ?? 'New Orleans').toString();

    final nextTaxRate = _taxRatePct / 100.0;
    if (state.draft.taxRate != nextTaxRate) {
      state = state.copyWith(draft: state.draft.copyWith(taxRate: nextTaxRate));
    }
  }

  double get minNoticeHours => _minNoticeHours;
  double get minBookingHours => _minBookingHours;
  double get gratuityPct => _gratuityPct;
  double get taxRatePct => _taxRatePct;
  double get bookingFee => _bookingFee;
  double get fuelSurchargePct => _fuelSurchargePct;
  double get cancelWindowHours => _cancelWindowHours;
  double get lateCancelFee => _lateCancelFee;
  double get serviceAreaMiles => _serviceAreaMiles;
  String get defaultCity => _defaultCity;

  // --- business rules ---
  bool get requiresCallToBook {
    final start = state.draft.scheduledStart;
    if (start == null) return false;
    final minStart = DateTime.now().add(Duration(minutes: (_minNoticeHours * 60).round()));
    return start.isBefore(minStart);
  }

  // Haversine distance in miles
  double _distanceMiles(double lat1, double lon1, double lat2, double lon2) {
    const R = 3958.7613; // Earth radius in miles
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  bool _isWithinServiceArea(double? lat, double? lng) {
    if (lat == null || lng == null) return false; // treat unknown as not validated
    final miles = _distanceMiles(_centerLat, _centerLng, lat, lng);
    return miles <= _serviceAreaMiles;
  }

  bool validateForQuote() {
    final d = state.draft;

    if (d.pickup.trim().isEmpty || d.dropoff.trim().isEmpty) {
      state = state.copyWith(error: 'Pickup and dropoff are required.');
      return false;
    }
    if (d.scheduledStart == null) {
      state = state.copyWith(error: 'Please select a pickup date/time.');
      return false;
    }
    if (requiresCallToBook) {
      state = state.copyWith(
        error: 'Less than 2 hours notice. Please call to book.',
      );
      return false;
    }
    if (d.durationHours < _minBookingHours) {
      state = state.copyWith(error: 'Minimum booking is ${_minBookingHours.toStringAsFixed(0)} hours.');
      return false;
    }

    // ✅ REQUIRE PICKUP/DROPOFF COORDINATES
    if (d.pickupLat == null || d.pickupLng == null || d.dropoffLat == null || d.dropoffLng == null) {
      state = state.copyWith(
        error: 'Please select pickup and dropoff from the address suggestions so we can capture location.',
      );
      return false;
    }

    // ✅ SERVICE AREA RULE (30-mile radius of New Orleans)
    // We validate both pickup and dropoff. If either is outside, call required.
    final pickupOk = _isWithinServiceArea(d.pickupLat, d.pickupLng);
    final dropoffOk = _isWithinServiceArea(d.dropoffLat, d.dropoffLng);

    if (!pickupOk || !dropoffOk) {
      state = state.copyWith(
        error:
          'This trip appears outside our ${_serviceAreaMiles.toStringAsFixed(0)}-mile service area from $_defaultCity. Please call to book.',
      );
      return false;
    }

    if (!d.acceptedTerms) {
      state = state.copyWith(error: 'Please accept the Terms & Conditions.');
      return false;
    }
    if (!d.acceptedSurveillanceConsent) {
      state = state.copyWith(error: 'Please consent to video/audio surveillance policy.');
      return false;
    }
    if (!d.acknowledgedNoSmoking) {
      state = state.copyWith(error: 'Please acknowledge the no smoking/vaping policy.');
      return false;
    }

    state = state.copyWith(error: null);
    return true;
  }

  /// Compute a simple quote breakdown used by the quote UI.
  /// Returns a map with numeric entries expected by the screens:
  /// billableHours, hourlyRate, base, gratuity, fuel, parking, tolls, venue,
  /// fees, tax, total
  Map<String, double> computeQuoteBreakdown() {
    final d = state.draft;

    final hourlyRate = switch (d.vehicleType) {
      VehicleType.escalade => _hourlyRate + 30.0,
      VehicleType.navigator => _hourlyRate + 15.0,
      VehicleType.bestAvailable => _hourlyRate,
    };

    final billableHours = d.durationHours < _minBookingHours ? _minBookingHours : d.durationHours;

    final base = hourlyRate * billableHours;
    final gratuity = base * (_gratuityPct / 100.0);

    final fuelPct = switch (d.fuelTier) {
      FuelTier.twoPct => 0.02,
      FuelTier.fivePct => 0.05,
      FuelTier.tenPct => 0.10,
    };
    final fuel = base * (fuelPct + (_fuelSurchargePct / 100.0));

    final parking = d.includeParkingFee ? 20.0 : 0.0;
    final tolls = d.includeTollsFee ? 10.0 : 0.0;
    final venue = d.includeVenueFee ? 50.0 : 0.0;

    final fees = _bookingFee;

    final subtotal = base + gratuity + fuel + parking + tolls + venue + fees;
    final tax = subtotal * d.taxRate;

    final total = subtotal + tax;

    return {
      'billableHours': billableHours,
      'hourlyRate': hourlyRate,
      'base': base,
      'gratuity': gratuity,
      'fuel': fuel,
      'parking': parking,
      'tolls': tolls,
      'venue': venue,
      'fees': fees,
      'tax': tax,
      'total': total,
    };
  }
  // ===================================================================
  // ✅ Create Booking via HTTP endpoint (createBookingHttp)
  //
  // Uses an HTTP POST instead of the cloud_functions callable to avoid
  // the Firestore Web SDK v11.x "INTERNAL ASSERTION FAILED: Unexpected
  // state" crash that occurs when the callable response is processed
  // by the Firestore serializer on web.
  //
  // Pricing is computed SERVER-SIDE from admin_settings/app, so the
  // client only sends inputs (vehicle type, duration, fuel tier, flags).
  // GeoPoints are stored only in bookings_private — bookings/ never
  // contains GeoPoint fields, keeping the live-screen subscription safe.
  // ===================================================================
  static const _createBookingUrl =
      'https://us-central1-pink-fleets.cloudfunctions.net/createBookingHttp';

  Future<String?> createBooking({bool markPaid = true}) async {
    final d = state.draft;

    final ok = validateForQuote();
    if (!ok) return null;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      state = state.copyWith(error: 'You must be logged in to book.');
      return null;
    }

    // Get Firebase ID token for Bearer auth
    final token = await user.getIdToken();
    if (token == null) {
      state = state.copyWith(error: 'Authentication token unavailable. Please sign out and back in.');
      return null;
    }

    final payload = jsonEncode({
      'pickupAddress':   d.pickup,
      'dropoffAddress':  d.dropoff,
      'pickupPlaceId':   d.pickupPlaceId ?? '',
      'dropoffPlaceId':  d.dropoffPlaceId ?? '',
      'pickupLat':       d.pickupLat,
      'pickupLng':       d.pickupLng,
      'dropoffLat':      d.dropoffLat,
      'dropoffLng':      d.dropoffLng,
      'scheduledStartMs':  d.scheduledStart?.millisecondsSinceEpoch,
      'durationHours':     d.durationHours,
      'passengers':        d.passengers,
      'vehicleType':       d.vehicleType.name,
      // 'stops':             d.stops, // Removed: BookingDraft has no 'stops' property
    });

    final response = await http.post(
      Uri.parse(_createBookingUrl),
      headers: {
        'Content-Type':  'application/json',
        'Authorization': 'Bearer $token',
      },
      body: payload,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final errBody = jsonDecode(response.body) as Map<String, dynamic>?;
      final errMsg  = errBody?['error']?.toString() ?? 'booking-failed (${response.statusCode})';
      state = state.copyWith(error: errMsg);
      throw Exception(errMsg);
    }

    final respBody  = jsonDecode(response.body) as Map<String, dynamic>;
    final bookingId = respBody['bookingId'] as String?;
    if (bookingId == null || bookingId.isEmpty) return null;

    state = state.copyWith(error: null);
    return bookingId;
  }
}

final bookingControllerProvider =
    StateNotifierProvider<BookingController, BookingState>((ref) => BookingController());
