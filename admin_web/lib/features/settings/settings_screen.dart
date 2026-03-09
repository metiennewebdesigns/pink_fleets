import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/firebase_providers.dart';
import '../../theme/pink_fleets_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const String _buildStamp = String.fromEnvironment(
    'APP_BUILD',
    defaultValue: '2026-03-03.3',
  );

  final supportPhoneCtrl = TextEditingController();
  final serviceAreaMilesCtrl = TextEditingController();
  final minNoticeHoursCtrl = TextEditingController();
  final minBookingHoursCtrl = TextEditingController();
  final hourlyRateCtrl = TextEditingController();
  final gratuityPctCtrl = TextEditingController();
  final taxRatePctCtrl = TextEditingController();
  final bookingFeeCtrl = TextEditingController();
  final fuelSurchargePctCtrl = TextEditingController();
  final overtimeGraceMinutesCtrl = TextEditingController();
  final overtimeRatePerMinuteCtrl = TextEditingController();
  final serviceStartHourCtrl = TextEditingController();
  final serviceEndHourCtrl = TextEditingController();
  final cancelWindowHoursCtrl = TextEditingController();
  final lateCancelFeeCtrl = TextEditingController();
  final defaultCityCtrl = TextEditingController();
  final defaultLatCtrl = TextEditingController();
  final defaultLngCtrl = TextEditingController();

  bool requirePaymentBeforeDispatch = false;

  bool _initialized = false;
  bool _saving = false;
  String? _status;

  @override
  void dispose() {
    supportPhoneCtrl.dispose();
    serviceAreaMilesCtrl.dispose();
    minNoticeHoursCtrl.dispose();
    minBookingHoursCtrl.dispose();
    hourlyRateCtrl.dispose();
    gratuityPctCtrl.dispose();
    taxRatePctCtrl.dispose();
    bookingFeeCtrl.dispose();
    fuelSurchargePctCtrl.dispose();
    overtimeGraceMinutesCtrl.dispose();
    overtimeRatePerMinuteCtrl.dispose();
    serviceStartHourCtrl.dispose();
    serviceEndHourCtrl.dispose();
    cancelWindowHoursCtrl.dispose();
    lateCancelFeeCtrl.dispose();
    defaultCityCtrl.dispose();
    defaultLatCtrl.dispose();
    defaultLngCtrl.dispose();
    super.dispose();
  }

  void _seedControllers(Map<String, dynamic> d) {
    if (_initialized) return;
    supportPhoneCtrl.text = (d['supportPhone'] ?? '').toString();
    serviceAreaMilesCtrl.text = (d['serviceAreaMiles'] ?? 30).toString();
    minNoticeHoursCtrl.text = (d['minNoticeHours'] ?? 2).toString();
    minBookingHoursCtrl.text = (d['minBookingHours'] ?? 2).toString();
    hourlyRateCtrl.text = (d['hourlyRate'] ?? 175).toString();
    gratuityPctCtrl.text = (d['gratuityPct'] ?? 20).toString();
    taxRatePctCtrl.text = (d['taxRatePct'] ?? 9.2).toString();
    bookingFeeCtrl.text = (d['bookingFee'] ?? 0).toString();
    fuelSurchargePctCtrl.text = (d['fuelSurchargePct'] ?? 0).toString();
    overtimeGraceMinutesCtrl.text = (d['overtimeGraceMinutes'] ?? 15).toString();
    overtimeRatePerMinuteCtrl.text = (d['overtimeRatePerMinute'] ?? 2).toString();
    serviceStartHourCtrl.text = (d['serviceStartHour'] ?? 6).toString();
    serviceEndHourCtrl.text = (d['serviceEndHour'] ?? 23).toString();
    cancelWindowHoursCtrl.text = (d['cancelWindowHours'] ?? 2).toString();
    lateCancelFeeCtrl.text = (d['lateCancelFee'] ?? 0).toString();
    defaultCityCtrl.text = (d['defaultCity'] ?? 'New Orleans').toString();
    defaultLatCtrl.text = (d['defaultLat'] ?? 29.9511).toString();
    defaultLngCtrl.text = (d['defaultLng'] ?? -90.0715).toString();
    requirePaymentBeforeDispatch = (d['requirePaymentBeforeDispatch'] ?? false) == true;
    _initialized = true;
  }

  Future<void> _save(DocumentReference<Map<String, dynamic>> ref) async {
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      await ref.set({
        'supportPhone': supportPhoneCtrl.text.trim(),
        'serviceAreaMiles': num.tryParse(serviceAreaMilesCtrl.text.trim()) ?? 30,
        'minNoticeHours': num.tryParse(minNoticeHoursCtrl.text.trim()) ?? 2,
        'minBookingHours': num.tryParse(minBookingHoursCtrl.text.trim()) ?? 2,
        'hourlyRate': num.tryParse(hourlyRateCtrl.text.trim()) ?? 175,
        'gratuityPct': num.tryParse(gratuityPctCtrl.text.trim()) ?? 20,
        'taxRatePct': num.tryParse(taxRatePctCtrl.text.trim()) ?? 9.2,
        'bookingFee': num.tryParse(bookingFeeCtrl.text.trim()) ?? 0,
        'fuelSurchargePct': num.tryParse(fuelSurchargePctCtrl.text.trim()) ?? 0,
        'overtimeGraceMinutes': num.tryParse(overtimeGraceMinutesCtrl.text.trim()) ?? 15,
        'overtimeRatePerMinute': num.tryParse(overtimeRatePerMinuteCtrl.text.trim()) ?? 2,
        'serviceStartHour': num.tryParse(serviceStartHourCtrl.text.trim()) ?? 6,
        'serviceEndHour': num.tryParse(serviceEndHourCtrl.text.trim()) ?? 23,
        'cancelWindowHours': num.tryParse(cancelWindowHoursCtrl.text.trim()) ?? 2,
        'lateCancelFee': num.tryParse(lateCancelFeeCtrl.text.trim()) ?? 0,
        'defaultCity': defaultCityCtrl.text.trim(),
        'defaultLat': num.tryParse(defaultLatCtrl.text.trim()) ?? 29.9511,
        'defaultLng': num.tryParse(defaultLngCtrl.text.trim()) ?? -90.0715,
        'requirePaymentBeforeDispatch': requirePaymentBeforeDispatch,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      setState(() => _status = 'Saved');
    } catch (e) {
      setState(() => _status = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _twoFieldRow(bool isNarrow, Widget left, Widget right) {
    if (isNarrow) {
      return Column(
        children: [
          left,
          const SizedBox(height: 12),
          right,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  String _friendlySettingsError(Object? error) {
    final raw = (error ?? '').toString().toLowerCase();
    if (raw.contains('permission-denied') || raw.contains('insufficient permissions')) {
      return 'Settings are currently read-protected for this account.\n'
          'Local/default values are shown below.';
    }
    return 'Live settings are temporarily unavailable.\n'
        'Local/default values are shown below.';
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(firestoreProvider);
    final refDoc = db.collection('admin_settings').doc('app');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 860;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: refDoc.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snap.hasError && snap.data != null && snap.data!.exists == false) {
              _seedControllers({});
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Settings not initialized yet.'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _saving ? null : () => _save(refDoc),
                        child: Text(_saving ? 'Creating…' : 'Create Default Settings'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = snap.data?.data() ?? {};
            _seedControllers(data);

            return ListView(
              children: [
                if (snap.hasError)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD8A8)),
                    ),
                    child: Text(
                      _friendlySettingsError(snap.error),
                      style: const TextStyle(color: Color(0xFF8A4B08)),
                    ),
                  ),
                Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                _section(
                  title: 'Contact',
                  child: Column(
                    children: [
                      TextField(
                        controller: supportPhoneCtrl,
                        decoration: const InputDecoration(labelText: 'Support Phone'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _section(
                  title: 'Service Rules',
                  child: Column(
                    children: [
                      _twoFieldRow(
                        isNarrow,
                        TextField(
                          controller: serviceAreaMilesCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Service Area Miles'),
                        ),
                        TextField(
                          controller: minNoticeHoursCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Min Notice (hours)'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _twoFieldRow(
                        isNarrow,
                        TextField(
                          controller: minBookingHoursCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Min Booking Hours'),
                        ),
                        TextField(
                          controller: hourlyRateCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Hourly Rate'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: gratuityPctCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Gratuity %'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _section(
                  title: 'Taxes & Fees',
                  child: Column(
                    children: [
                      _twoFieldRow(
                        isNarrow,
                        TextField(
                          controller: taxRatePctCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Tax Rate %'),
                        ),
                        TextField(
                          controller: bookingFeeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Booking Fee'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: fuelSurchargePctCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Fuel Surcharge %'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _section(
                  title: 'Overtime Policy',
                  child: Column(
                    children: [
                      _twoFieldRow(
                        isNarrow,
                        TextField(
                          controller: overtimeGraceMinutesCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Grace Minutes'),
                        ),
                        TextField(
                          controller: overtimeRatePerMinuteCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Rate per Minute'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _section(
                  title: 'Operating Hours',
                  child: Column(
                    children: [
                      _twoFieldRow(
                        isNarrow,
                        TextField(
                          controller: serviceStartHourCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Start Hour (0–23)'),
                        ),
                        TextField(
                          controller: serviceEndHourCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'End Hour (0–23)'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _section(
                  title: 'Cancellation Policy',
                  child: Column(
                    children: [
                      _twoFieldRow(
                        isNarrow,
                        TextField(
                          controller: cancelWindowHoursCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Cancel Window (hours)'),
                        ),
                        TextField(
                          controller: lateCancelFeeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Late Cancel Fee'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _section(
                  title: 'Defaults & Geo',
                  child: Column(
                    children: [
                      TextField(
                        controller: defaultCityCtrl,
                        decoration: const InputDecoration(labelText: 'Default City'),
                      ),
                      const SizedBox(height: 12),
                      _twoFieldRow(
                        isNarrow,
                        TextField(
                          controller: defaultLatCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Default Lat'),
                        ),
                        TextField(
                          controller: defaultLngCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Default Lng'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _section(
                  title: 'Payments',
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Require payment before dispatch'),
                        value: requirePaymentBeforeDispatch,
                        onChanged: (v) => setState(() => requirePaymentBeforeDispatch = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    ElevatedButton(
                      onPressed: _saving ? null : () => _save(refDoc),
                      child: Text(_saving ? 'Saving…' : 'Save Settings'),
                    ),
                    if (_status != null)
                      Text(
                        _status!,
                        style: TextStyle(color: _status == 'Saved' ? Colors.green : Colors.red),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: Opacity(
                    opacity: 0.45,
                    child: Text(
                      'Build $_buildStamp',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: PFColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PFColors.white,
        borderRadius: BorderRadius.circular(16),
        border: const Border.fromBorderSide(BorderSide(color: PFColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
