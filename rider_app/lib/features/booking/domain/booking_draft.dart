enum VehicleType { escalade, navigator, bestAvailable }
enum FuelTier { twoPct, fivePct, tenPct }

class BookingDraft {
  final String pickup;
  final String dropoff;

  final String? pickupPlaceId;
  final String? dropoffPlaceId;

  final double? pickupLat;
  final double? pickupLng;

  final double? dropoffLat;
  final double? dropoffLng;

  final DateTime? scheduledStart;
  final double durationHours;

  final int passengers;
  final VehicleType vehicleType;
  final FuelTier fuelTier;

  final double taxRate;

  final bool includeParkingFee;
  final bool includeTollsFee;
  final bool includeVenueFee;

  final bool acceptedTerms;
  final bool acceptedSurveillanceConsent;
  final bool acknowledgedNoSmoking;

  const BookingDraft({
    this.pickup = '',
    this.dropoff = '',
    this.pickupPlaceId,
    this.dropoffPlaceId,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    this.scheduledStart,
    this.durationHours = 2,
    this.passengers = 2,
    this.vehicleType = VehicleType.bestAvailable,
    this.fuelTier = FuelTier.twoPct,
    this.taxRate = 0.095,
    this.includeParkingFee = false,
    this.includeTollsFee = false,
    this.includeVenueFee = false,
    this.acceptedTerms = false,
    this.acceptedSurveillanceConsent = false,
    this.acknowledgedNoSmoking = false,
  });

  BookingDraft copyWith({
    String? pickup,
    String? dropoff,
    String? pickupPlaceId,
    String? dropoffPlaceId,
    double? pickupLat,
    double? pickupLng,
    double? dropoffLat,
    double? dropoffLng,
    DateTime? scheduledStart,
    double? durationHours,
    int? passengers,
    VehicleType? vehicleType,
    FuelTier? fuelTier,
    double? taxRate,
    bool? includeParkingFee,
    bool? includeTollsFee,
    bool? includeVenueFee,
    bool? acceptedTerms,
    bool? acceptedSurveillanceConsent,
    bool? acknowledgedNoSmoking,
  }) {
    return BookingDraft(
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      pickupPlaceId: pickupPlaceId ?? this.pickupPlaceId,
      dropoffPlaceId: dropoffPlaceId ?? this.dropoffPlaceId,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      dropoffLat: dropoffLat ?? this.dropoffLat,
      dropoffLng: dropoffLng ?? this.dropoffLng,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      durationHours: durationHours ?? this.durationHours,
      passengers: passengers ?? this.passengers,
      vehicleType: vehicleType ?? this.vehicleType,
      fuelTier: fuelTier ?? this.fuelTier,
      taxRate: taxRate ?? this.taxRate,
      includeParkingFee: includeParkingFee ?? this.includeParkingFee,
      includeTollsFee: includeTollsFee ?? this.includeTollsFee,
      includeVenueFee: includeVenueFee ?? this.includeVenueFee,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
      acceptedSurveillanceConsent: acceptedSurveillanceConsent ?? this.acceptedSurveillanceConsent,
      acknowledgedNoSmoking: acknowledgedNoSmoking ?? this.acknowledgedNoSmoking,
    );
  }
}