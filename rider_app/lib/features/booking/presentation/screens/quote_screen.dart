import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../shared/date_time_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/pink_fleets_theme.dart';
import '../controllers/booking_controller.dart';
import '../../domain/booking_draft.dart';

class QuoteScreen extends ConsumerWidget {
  const QuoteScreen({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final ctrl = ref.read(bookingControllerProvider.notifier);
      final state = ref.watch(bookingControllerProvider);
      final d = state.draft;

      final settingsRef = FirebaseFirestore.instance.collection('admin_settings').doc('app');

      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: settingsRef.snapshots(),
        builder: (context, settingsSnap) {
          if (settingsSnap.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Quote')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load quote settings: ${settingsSnap.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          if (!settingsSnap.hasData) {
            return Scaffold(
              appBar: AppBar(title: const Text('Quote')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          final settings = settingsSnap.data?.data() ?? {};
          ctrl.applySettings(settings);
          final q = ctrl.computeQuoteBreakdown();
          final billableHours = (q['billableHours'] as num?)?.toDouble() ?? 0;
          final hourlyRate = (q['hourlyRate'] as num?)?.toDouble() ?? 0;
          final base = (q['base'] as num?)?.toDouble() ?? 0;
          final gratuity = (q['gratuity'] as num?)?.toDouble() ?? 0;
          final fuel = (q['fuel'] as num?)?.toDouble() ?? 0;
          final parking = (q['parking'] as num?)?.toDouble() ?? 0;
          final tolls = (q['tolls'] as num?)?.toDouble() ?? 0;
          final venue = (q['venue'] as num?)?.toDouble() ?? 0;
          final fees = (q['fees'] as num?)?.toDouble() ?? 0;
          final tax = (q['tax'] as num?)?.toDouble() ?? 0;
          final total = (q['total'] as num?)?.toDouble() ?? 0;

          return Scaffold(
          appBar: AppBar(title: const Text('Quote')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                        Text('Your Quote', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 10),

                        Text('Vehicle: ${vehicleLabel(d.vehicleType)}',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text('Pickup: ${d.pickup}'),
                        Text('Dropoff: ${d.dropoff}'),
                        Text('Start: ${formatDateTime(d.scheduledStart)}'),
                        const SizedBox(height: 16),

                        _row('Billable Hours', billableHours.toStringAsFixed(2)),
                        _row('Rate', '${money(hourlyRate)} / hour'),
                        const Divider(height: 24),

                        _row('Base', money(base)),
                        _row('Gratuity (${ctrl.gratuityPct.toStringAsFixed(0)}%)', money(gratuity)),
                        _row('Fuel Surcharge', money(fuel)),
                        const Divider(height: 24),

                        if (parking > 0) _row('Parking Fee', money(parking)),
                        if (tolls > 0) _row('Tolls', money(tolls)),
                        if (venue > 0) _row('Venue/Staging Fee', money(venue)),
                        if (fees > 0) _row('Fees Total', money(fees)),
                        _row('Tax', money(tax)),
                        const SizedBox(height: 10),

                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: PFColors.blush,
                            border: Border.all(color: PFColors.pink1.withValues(alpha: 0.25)),
                          ),
                          child: _row('Total Due Now', money(total), bold: true),
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
                              Text('• Minimum booking: ${ctrl.minBookingHours.toStringAsFixed(0)} hours'),
                              Text('• Minimum notice: ${ctrl.minNoticeHours.toStringAsFixed(0)} hours'),
                              Text('• Service area: ${ctrl.serviceAreaMiles.toStringAsFixed(0)} miles from ${ctrl.defaultCity}'),
                              Text('• Gratuity: ${ctrl.gratuityPct.toStringAsFixed(0)}%'),
                              Text('• Tax rate: ${ctrl.taxRatePct.toStringAsFixed(2)}%'),
                              Text('• Booking fee: ${money(ctrl.bookingFee)}'),
                              Text('• Fuel surcharge: ${ctrl.fuelSurchargePct.toStringAsFixed(2)}%'),
                              Text('• Cancel window: ${ctrl.cancelWindowHours.toStringAsFixed(0)} hours'),
                              Text('• Late cancel fee: ${money(ctrl.lateCancelFee)}'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        PFButtonPrimary(
                          label: 'Continue (Stripe later)',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Stripe will be connected later.')),
                            );
                          },
                          fullWidth: true,
                        ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          );
        },
      );
    } catch (e, st) {
      debugPrint('[QUOTE SCREEN] build crash: $e');
      debugPrint('[QUOTE SCREEN] stack: $st');
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Something went wrong loading the quote.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
  }

  Widget _row(String left, String right, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(left, style: style),
        Text(right, style: style),
      ],
    );
  }
}
