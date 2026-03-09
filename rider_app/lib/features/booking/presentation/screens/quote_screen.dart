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
    final ctrl = ref.read(bookingControllerProvider.notifier);
    final state = ref.watch(bookingControllerProvider);
    final d = state.draft;

    final settingsRef = FirebaseFirestore.instance.collection('admin_settings').doc('app');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: settingsRef.snapshots(),
      builder: (context, settingsSnap) {
        final settings = settingsSnap.data?.data() ?? {};
        ctrl.applySettings(settings);
        final q = ctrl.computeQuoteBreakdown();

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

                        _row('Billable Hours', q['billableHours']!.toStringAsFixed(2)),
                        _row('Rate', '${money(q['hourlyRate']!)} / hour'),
                        const Divider(height: 24),

                        _row('Base', money(q['base']!)),
                        _row('Gratuity (${ctrl.gratuityPct.toStringAsFixed(0)}%)', money(q['gratuity']!)),
                        _row('Fuel Surcharge', money(q['fuel']!)),
                        const Divider(height: 24),

                        if ((q['parking'] ?? 0) > 0) _row('Parking Fee', money(q['parking']!)),
                        if ((q['tolls'] ?? 0) > 0) _row('Tolls', money(q['tolls']!)),
                        if ((q['venue'] ?? 0) > 0) _row('Venue/Staging Fee', money(q['venue']!)),
                        if ((q['fees'] ?? 0) > 0) _row('Fees Total', money(q['fees']!)),
                        _row('Tax', money(q['tax']!)),
                        const SizedBox(height: 10),

                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: PFColors.blush,
                            border: Border.all(color: PFColors.pink1.withValues(alpha: 0.25)),
                          ),
                          child: _row('Total Due Now', money(q['total']!), bold: true),
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