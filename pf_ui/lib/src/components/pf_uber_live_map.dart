import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../pf_colors.dart';
import 'pf_uber_live_map_platform_view.dart' as pf_platform_view;
import 'pf_live_dot.dart';

// ── Web: check if Google Maps JS SDK is present ───────────────────────────────
@JS('google')
external JSAny? get _jsGoogle;

@JS('google.maps')
external JSAny? get _jsGoogleMaps;

bool _googleJsPresent() {
  if (!kIsWeb) return true;
  try {
    return _jsGoogle != null;
  } catch (_) {
    return true; // assume native always fine
  }
}

bool _mapsJsPresent() {
  if (!kIsWeb) return true;
  try {
    return _jsGoogleMaps != null;
  } catch (_) {
    return false;
  }
}

bool _mapsReadyFlag() {
  if (!kIsWeb) return true;
  try {
    final ready =
        globalContext.getProperty<JSBoolean?>('__pfMapsReady'.toJS);
    return ready?.toDart ?? false;
  } catch (_) {
    return false;
  }
}

bool _initMapJs() {
  if (!kIsWeb) return true;
  try {
    globalContext.callMethod('initMap'.toJS);
    return true;
  } catch (e, st) {
    print('[PF MAP] MAP INIT FAILED — likely browser key / referrer / billing issue');
    print('[PF MAP] initMap bridge threw: $e');
    print(st.toString());
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PFUberLiveMap — single shared Uber-style live map widget
// ─────────────────────────────────────────────────────────────────────────────
//
// Usage (all apps):
//   import 'package:pf_ui/pf_ui.dart';
//
//   PFUberLiveMap(
//     driverId: booking.driverId,               // Firestore subscription
//     initialDriverLatLng: LatLng(lat, lng),    // seed position
//     pickupGeo: booking.pickupGeo,
//     dropoffGeo: booking.dropoffGeo,
//     height: 280,
//     bookingStatus: booking.status,
//     driverName: 'John D.',
//     vehicleLabel: 'Lincoln Navigator',
//     licensePlate: 'ABC 123',
//     etaText: 'Arriving in 8 min',
//   )
//
// Features:
//  • Subscribes to drivers/{driverId} for real-time location (throttled ≤1/s)
//  • Smooth interpolation between position updates (800 ms ease-in-out)
//  • Driver marker: pink car icon + animated glow ring
//  • Pickup marker: green origin pin
//  • Dropoff marker: gold flag pin
//  • Camera follow mode (default ON) → disabled on user pan → Recenter FAB
//  • Bottom overlay: driver name + vehicle + license plate + ETA chip + live dot
//  • Status timeline stepper inside bottom sheet
//  • Fallback card with coordinates + "Retry map" when Maps JS unavailable
// ─────────────────────────────────────────────────────────────────────────────

class PFUberLiveMap extends StatefulWidget {
  /// Firestore driver document ID (drivers/{driverId}).
  /// Widget manages the Firestore subscription internally.
  final String? driverId;

  /// Seed/initial driver position shown immediately before first Firestore hit.
  final LatLng? initialDriverLatLng;

  final GeoPoint? pickupGeo;
  final GeoPoint? dropoffGeo;

  /// Map height in logical pixels. Defaults to 300.
  final double height;

  // ── Bottom overlay info (all optional) ─────────────────────────────────
  final String? driverName;
  final String? vehicleLabel;
  final String? licensePlate;

  /// e.g. "Arriving in 8 min" — shown in the bottom overlay ETA chip.
  final String? etaText;

  /// Booking status string (accepted/en_route/arrived/in_progress/completed).
  /// Drives the live-dot colour + status timeline.
  final String? bookingStatus;

  /// Border radius of the map container. Defaults to 18.
  final double borderRadius;

  const PFUberLiveMap({
    super.key,
    this.driverId,
    this.initialDriverLatLng,
    this.pickupGeo,
    this.dropoffGeo,
    this.height = 300,
    this.driverName,
    this.vehicleLabel,
    this.licensePlate,
    this.etaText,
    this.bookingStatus,
    this.borderRadius = 18,
  });

  @override
  State<PFUberLiveMap> createState() => _PFUberLiveMapState();
}

class _PFUberLiveMapState extends State<PFUberLiveMap>
    with TickerProviderStateMixin {
  // ── Map ────────────────────────────────────────────────────────────────────
  GoogleMapController? _controller;
  bool _mapLoaded = false;
  Timer? _fallbackTimer;
  bool _showFallback = false;
  bool _mapInitStarted = false;
  bool _mapReady = !kIsWeb;
  bool _mapFailed = false;
  bool _mapLoading = true;
  int _mapRetryCount = 0;
  Timer? _mapRecoveryTimer;
  final fm.MapController _webMapController = fm.MapController();
  double _webZoom = 13.5;
  late final String _webViewType =
      'pf-uber-live-map-view-${identityHashCode(this)}';
  late final String _webMapDomId =
      'pf-uber-live-map-dom-${identityHashCode(this)}';
  bool _webViewRegistered = false;
  Object? _webFrameObj; // IFrameElement on web, null on mobile
  JSObject? _webMap;
  JSObject? _webDriverMarker;
  JSObject? _webPickupMarker;
  JSObject? _webDropoffMarker;

  // ── Driver state ───────────────────────────────────────────────────────────
  LatLng? _driver;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _driverSub;

  // Smooth movement
  AnimationController? _moveAnim;
  Animation<double>? _moveT;
  LatLng? _moveFrom;
  LatLng? _moveTo;
  DateTime _lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Camera ─────────────────────────────────────────────────────────────────
  bool _autoFollow = true;
  bool _didInitialFit = false;

  // ── Custom marker bitmaps ──────────────────────────────────────────────────
  // (We skip BitmapDescriptor.fromAsset to avoid asset path coupling.
  //  Instead we use defaultMarkerWithHue with custom colour hues.)

  @override
  void initState() {
    super.initState();
    _driver = widget.initialDriverLatLng;
    _startDriverSub(widget.driverId);
    if (kIsWeb) _ensureWebMapView();
    _safeInitMap();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (kIsWeb) _ensureWebMapView();
        _safeInitMap();
        if (kIsWeb) _queueWebMapSync();
        _scheduleMapRecoveryRetry();
      }
    });
  }

  @override
  void didUpdateWidget(PFUberLiveMap old) {
    super.didUpdateWidget(old);
    if (old.driverId != widget.driverId) {
      _driverSub?.cancel();
      _moveAnim?.stop();
      _moveAnim?.dispose();
      _moveAnim = null;
      _startDriverSub(widget.driverId);
    }
    if (old.initialDriverLatLng != widget.initialDriverLatLng &&
        _driver == old.initialDriverLatLng) {
      setState(() => _driver = widget.initialDriverLatLng);
    }
    if (kIsWeb) _ensureWebMapView();
    final coordsChanged =
        old.pickupGeo != widget.pickupGeo ||
        old.dropoffGeo != widget.dropoffGeo ||
        old.initialDriverLatLng != widget.initialDriverLatLng;
    if (coordsChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (kIsWeb) _ensureWebMapView();
          _safeInitMap();
          if (kIsWeb) _queueWebMapSync();
        }
      });
    }
  }

  @override
  void dispose() {
    _driverSub?.cancel();
    _moveAnim?.dispose();
    _fallbackTimer?.cancel();
    _mapRecoveryTimer?.cancel();
    _controller?.dispose();
    _webMapController.dispose();
    super.dispose();
  }

  // ── Firestore subscription ─────────────────────────────────────────────────

  void _startDriverSub(String? driverId) {
    if (driverId == null || driverId.isEmpty) return;
    _driverSub = FirebaseFirestore.instance
        .collection('drivers')
        .doc(driverId)
        .snapshots()
        .listen(_onDriverDoc);
  }

  bool get _hasMapCoordinates =>
      _driver != null || _pickup != null || _dropoff != null;

  void _armMapTimeout() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted || _mapLoaded) return;
      debugPrint('[LIVE BOOKING] map fallback shown');
      setState(() {
        _mapLoading = false;
        _mapReady = false;
        _mapFailed = true;
        _showFallback = true;
        _mapInitStarted = false;
      });
      _scheduleMapRecoveryRetry();
    });
  }

  void _scheduleMapRecoveryRetry(
      [Duration delay = const Duration(milliseconds: 1200)]) {
    if (!kIsWeb) return;
    _mapRecoveryTimer?.cancel();
    _mapRecoveryTimer = Timer(delay, () {
      if (!mounted || _mapLoaded) return;
      debugPrint('[PF MAP] auto retry init');
      _safeInitMap();
    });
  }

  void _failMapInit(Object error, [StackTrace? stackTrace]) {
    print('[PF MAP] MAP INIT FAILED — likely browser key / referrer / billing issue');
    print('[PF MAP] init error: $error');
    if (stackTrace != null) {
      print(stackTrace.toString());
    }
    if (!mounted) return;
    _fallbackTimer?.cancel();
    setState(() {
      _mapReady = false;
      _mapLoading = false;
      _mapFailed = true;
      _showFallback = true;
      _mapInitStarted = false;
    });
    _scheduleMapRecoveryRetry();
  }

  Future<void> _safeInitMap() async {
    if (!mounted || _mapReady || (_mapInitStarted && !_mapFailed)) return;

    final pickup = _pickup;
    final dropoff = _dropoff;
    debugPrint('[LIVE BOOKING] map init start');
    debugPrint(
      '[PF MAP] coords pickup=${pickup?.latitude},${pickup?.longitude} '
      'dropoff=${dropoff?.latitude},${dropoff?.longitude}',
    );

    if (!_hasMapCoordinates) {
      debugPrint('[PF MAP] map init continuing without coordinates');
    }

    setState(() {
      _mapInitStarted = true;
      _mapLoading = true;
      _mapFailed = false;
      _showFallback = false;
      _mapLoaded = false;
    });
    _armMapTimeout();

    if (!kIsWeb) {
      _mapRecoveryTimer?.cancel();
      setState(() {
        _mapReady = true;
        _mapLoading = false;
        _mapInitStarted = false;
      });
      return;
    }

    _ensureWebMapView();
    if (!mounted) return;
    _mapRecoveryTimer?.cancel();
    _fallbackTimer?.cancel();
    setState(() {
      _mapLoaded = true;
      _mapReady = true;
      _mapLoading = false;
      _mapFailed = false;
      _showFallback = false;
      _mapInitStarted = false;
    });
    return;
  }

  void _onDriverDoc(DocumentSnapshot<Map<String, dynamic>> ds) {
    final data = ds.data() ?? {};
    final rawLoc = data['lastLocation'];

    double? lat = (data['lat'] as num?)?.toDouble();
    double? lng = (data['lng'] as num?)?.toDouble();
    if ((lat == null || lng == null) && rawLoc is Map) {
      lat = (rawLoc['lat'] as num?)?.toDouble() ??
          (rawLoc['latitude'] as num?)?.toDouble();
      lng = (rawLoc['lng'] as num?)?.toDouble() ??
          (rawLoc['longitude'] as num?)?.toDouble();
    } else if ((lat == null || lng == null) && rawLoc is GeoPoint) {
      lat = rawLoc.latitude;
      lng = rawLoc.longitude;
    }

    if (lat == null || lng == null) return;

    // Throttle: ≤1 update per second.
    final now = DateTime.now();
    if (now.difference(_lastUpdate).inMilliseconds < 1000) return;
    _lastUpdate = now;

    _animateDriver(LatLng(lat, lng));
    if (!_mapReady && !_mapFailed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _safeInitMap();
        }
      });
    } else if (kIsWeb) {
      _queueWebMapSync();
    }
  }

  void _animateDriver(LatLng target) {
    final from = _driver;
    if (from == null) {
      if (mounted) setState(() => _driver = target);
      if (kIsWeb) _queueWebMapSync();
      _tryFollow(target);
      return;
    }

    _moveAnim?.stop();
    _moveAnim?.dispose();

    _moveFrom = from;
    _moveTo = target;

    _moveAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _moveT = CurvedAnimation(parent: _moveAnim!, curve: Curves.easeInOut);

    _moveAnim!.addListener(() {
      if (!mounted) return;
      final t = _moveT!.value;
      final f = _moveFrom!;
      final to = _moveTo!;
      setState(() => _driver = LatLng(
            f.latitude + (to.latitude - f.latitude) * t,
            f.longitude + (to.longitude - f.longitude) * t,
          ));
    });

    _moveAnim!.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _driver = target);
        if (kIsWeb) _queueWebMapSync();
        _tryFollow(target);
      }
    });

    _moveAnim!.forward();
  }

  void _tryFollow(LatLng pos) {
    if (_autoFollow && _controller != null) {
      _controller!.animateCamera(CameraUpdate.newLatLng(pos));
    }
  }

  // ── Geometry helpers ───────────────────────────────────────────────────────

  LatLng? get _pickup => widget.pickupGeo == null
      ? null
      : LatLng(widget.pickupGeo!.latitude, widget.pickupGeo!.longitude);

  LatLng? get _dropoff => widget.dropoffGeo == null
      ? null
      : LatLng(widget.dropoffGeo!.latitude, widget.dropoffGeo!.longitude);

  Future<void> _fitBounds() async {
    final c = _controller;
    if (c == null) return;
    final pts = [
      if (_driver != null) _driver!,
      if (_pickup != null) _pickup!,
      if (_dropoff != null) _dropoff!,
    ];
    if (pts.isEmpty) return;

    if (pts.length == 1) {
      await c.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: pts.first, zoom: 14.5)));
      return;
    }

    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts.skip(1)) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    // Add generous padding
    final latPad = ((maxLat - minLat) * 0.25).clamp(0.003, 0.1);
    final lngPad = ((maxLng - minLng) * 0.25).clamp(0.003, 0.1);

    await c.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat - latPad, minLng - lngPad),
        northeast: LatLng(maxLat + latPad, maxLng + lngPad),
      ),
      56,
    ));
  }

  Future<void> _recenter() async {
    setState(() => _autoFollow = true);
    if (kIsWeb) {
      _fitOrCenterWebMap(forceFit: false);
      return;
    }
    if (_driver != null && _controller != null) {
      await _controller!
          .animateCamera(CameraUpdate.newLatLng(_driver!));
    } else {
      await _fitBounds();
    }
  }

  JSObject? _googleObject() {
    final google = _jsGoogle;
    return google is JSObject ? google : null;
  }

  JSObject? _mapsObject() {
    final google = _googleObject();
    final maps = google?['maps'];
    return maps is JSObject ? maps : null;
  }

  JSObject? _documentObject() {
    final doc = globalContext['document'];
    return doc is JSObject ? doc : null;
  }

  JSObject? _mapDomElement() {
    final doc = _documentObject();
    if (doc == null) return null;
    final el =
        doc.callMethod<JSAny?>('getElementById'.toJS, _webMapDomId.toJS);
    return el is JSObject ? el : null;
  }

  JSObject _jsLatLngLiteral(LatLng point) =>
      <String, Object>{'lat': point.latitude, 'lng': point.longitude}.jsify()
          as JSObject;

  String _webMapUrl() {
    final center = _driver ?? _pickup ?? _dropoff;
    if (center == null) return 'about:blank';
    final q = '${center.latitude},${center.longitude}';
    return 'https://maps.google.com/maps?output=embed&z=13&q=$q';
  }

  void _ensureWebMapView() {
    if (!kIsWeb) return;
    if (!_webViewRegistered) {
      _webFrameObj = pf_platform_view.registerPfUberMapViewFactory(
        _webViewType,
        _webMapDomId,
      );
      _webViewRegistered = true;
    }
    final frame = _webFrameObj;
    if (frame != null) {
      pf_platform_view.updatePfUberMapViewSrc(frame, _webMapUrl());
    }
  }

  void _registerWebMapView() {
    if (!kIsWeb || _webViewRegistered) return;
    _webFrameObj = pf_platform_view.registerPfUberMapViewFactory(_webViewType, _webMapDomId);
    _webViewRegistered = true;
  }

  void _queueWebMapSync() {
    if (!kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady || _mapFailed) return;
      _ensureWebMapView();
    });
  }

  void _clearWebMarker(JSObject? marker) {
    if (marker == null) return;
    marker.callMethodVarArgs('setMap'.toJS, [null]);
  }

  JSObject? _upsertWebMarker({
    required JSObject? current,
    required LatLng? position,
    required String title,
    required int zIndex,
  }) {
    if (position == null) {
      _clearWebMarker(current);
      return null;
    }

    final maps = _mapsObject();
    final map = _webMap;
    if (maps == null || map == null) return current;

    final options = <String, Object?>{
      'position': _jsLatLngLiteral(position),
      'map': map,
      'title': title,
      'zIndex': zIndex,
    }.jsify();

    if (current != null) {
      current.callMethod<JSAny?>('setOptions'.toJS, options);
      return current;
    }

    final markerCtor = maps['Marker'];
    if (markerCtor is! JSFunction) return null;
    return markerCtor.callAsConstructor<JSObject>(options);
  }

  void _fitOrCenterWebMap({bool forceFit = false}) {
    if (kIsWeb) {
      _ensureWebMapView();
      _didInitialFit = true;
      return;
    }

    final map = _webMap;
    final maps = _mapsObject();
    if (map == null || maps == null) return;

    final pts = [
      if (_driver != null) _driver!,
      if (_pickup != null) _pickup!,
      if (_dropoff != null) _dropoff!,
    ];
    if (pts.isEmpty) return;

    if (!forceFit && _autoFollow && _driver != null) {
      map.callMethod<JSAny?>('panTo'.toJS, _jsLatLngLiteral(_driver!));
      return;
    }

    if (pts.length == 1) {
      map.callMethod<JSAny?>('setCenter'.toJS, _jsLatLngLiteral(pts.first));
      map.callMethod<JSAny?>('setZoom'.toJS, 14.5.toJS);
      _didInitialFit = true;
      return;
    }

    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts.skip(1)) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final latPad = ((maxLat - minLat) * 0.25).clamp(0.003, 0.1);
    final lngPad = ((maxLng - minLng) * 0.25).clamp(0.003, 0.1);

    final boundsCtor = maps['LatLngBounds'];
    if (boundsCtor is! JSFunction) return;

    final bounds = boundsCtor.callAsConstructor<JSObject>(
      <String, Object>{
        'lat': minLat - latPad,
        'lng': minLng - lngPad,
      }.jsify(),
      <String, Object>{
        'lat': maxLat + latPad,
        'lng': maxLng + lngPad,
      }.jsify(),
    );

    map.callMethod<JSAny?>('fitBounds'.toJS, bounds);
    _didInitialFit = true;
  }

  void _syncWebMap() {
    if (!kIsWeb || !_mapReady || _mapFailed) return;

    try {
      _registerWebMapView();
      final maps = _mapsObject();
      final element = _mapDomElement();
      if (maps == null || element == null) {
        _scheduleMapRecoveryRetry(const Duration(milliseconds: 500));
        return;
      }

      if (_webMap == null) {
        final target =
            _driver ?? _pickup ?? _dropoff ?? const LatLng(29.9511, -90.0715);
        final mapCtor = maps['Map'];
        if (mapCtor is! JSFunction) {
          _failMapInit('google.maps.Map constructor unavailable');
          return;
        }

        _webMap = mapCtor.callAsConstructor<JSObject>(
          element,
          <String, Object>{
            'center': _jsLatLngLiteral(target),
            'zoom': 13.5,
            'disableDefaultUI': true,
            'zoomControl': false,
            'streetViewControl': false,
            'mapTypeControl': false,
            'fullscreenControl': false,
            'gestureHandling': 'greedy',
          }.jsify(),
        );
      }

      _webDriverMarker = _upsertWebMarker(
        current: _webDriverMarker,
        position: _driver,
        title:
            (widget.driverName?.isNotEmpty ?? false) ? widget.driverName! : 'Driver',
        zIndex: 10,
      );
      _webPickupMarker = _upsertWebMarker(
        current: _webPickupMarker,
        position: _pickup,
        title: 'Pickup',
        zIndex: 5,
      );
      _webDropoffMarker = _upsertWebMarker(
        current: _webDropoffMarker,
        position: _dropoff,
        title: 'Dropoff',
        zIndex: 5,
      );

      _fitOrCenterWebMap(forceFit: !_didInitialFit);
      _fallbackTimer?.cancel();

      if (!_mapLoaded && mounted) {
        setState(() {
          _mapLoaded = true;
          _mapReady = true;
          _mapLoading = false;
          _mapFailed = false;
          _showFallback = false;
          _mapInitStarted = false;
        });
      } else {
        _mapLoaded = true;
      }
    } catch (e, st) {
      _failMapInit(e, st);
    }
  }

  // ── Fallback card ──────────────────────────────────────────────────────────

  Widget _buildFallback() {
    final d = _driver;
    final pu = _pickup;
    final dr = _dropoff;
    return Container(
      height: widget.height,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PFColors.surface,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: PFColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: PFColors.dangerSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.map_outlined,
                  color: PFColors.danger, size: 18),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Map temporarily unavailable',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: PFColors.ink)),
            ),
          ]),
          const SizedBox(height: 4),
          const Text('Live map unavailable. Coordinates shown below.',
              style: TextStyle(color: PFColors.muted, fontSize: 12)),
          const SizedBox(height: 14),
          const Divider(color: PFColors.border),
          const SizedBox(height: 10),
          if (d == null && pu == null && dr == null)
            const Text('No location data available yet.',
                style: TextStyle(color: PFColors.muted, fontSize: 13)),
          if (d != null)
            _coordRow(Icons.local_taxi_rounded, 'Driver',
                '${d.latitude.toStringAsFixed(5)}, ${d.longitude.toStringAsFixed(5)}'),
          if (pu != null)
            _coordRow(Icons.trip_origin_rounded, 'Pickup',
                '${pu.latitude.toStringAsFixed(5)}, ${pu.longitude.toStringAsFixed(5)}'),
          if (dr != null)
            _coordRow(Icons.location_on_rounded, 'Dropoff',
                '${dr.latitude.toStringAsFixed(5)}, ${dr.longitude.toStringAsFixed(5)}'),
          const Spacer(),
          SizedBox(
            width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  debugPrint('[LIVE BOOKING] retry map');
                  setState(() {
                    _showFallback = false;
                    _mapFailed = false;
                    _mapReady = false;
                    _mapLoading = true;
                    _mapInitStarted = false;
                    _mapLoaded = false;
                    _mapRetryCount++;
                  });
                  _safeInitMap();
                  _scheduleMapRecoveryRetry();
                },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry map'),
              style: OutlinedButton.styleFrom(
                foregroundColor: PFColors.primary,
                side: const BorderSide(color: PFColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coordRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(children: [
          Icon(icon, color: PFColors.primary, size: 14),
          const SizedBox(width: 6),
          Text('$label: ',
              style:
                  const TextStyle(color: PFColors.muted, fontSize: 12)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: PFColors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace')),
          ),
        ]),
      );

  // ── Bottom info overlay ────────────────────────────────────────────────────

  bool get _hasOverlay =>
      (widget.driverName?.isNotEmpty ?? false) ||
      (widget.vehicleLabel?.isNotEmpty ?? false) ||
      (widget.licensePlate?.isNotEmpty ?? false) ||
      (widget.etaText?.isNotEmpty ?? false) ||
      (widget.bookingStatus?.isNotEmpty ?? false);

  Widget _bottomOverlay() {
    if (!_hasOverlay) return const SizedBox.shrink();
    final status = widget.bookingStatus ?? 'pending';
    return Positioned(
      left: 10,
      right: 54, // leave room for recenter FAB
      bottom: 10,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(children: [
          PFLiveDot(status: status, size: 9),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.driverName?.isNotEmpty ?? false)
                  Text(widget.driverName!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                if ((widget.vehicleLabel?.isNotEmpty ?? false) ||
                    (widget.licensePlate?.isNotEmpty ?? false))
                  Text(
                    [widget.vehicleLabel, widget.licensePlate]
                        .where((s) => s?.isNotEmpty ?? false)
                        .join(' · '),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11),
                  ),
                if (widget.bookingStatus?.isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: _StatusTimeline(status: status),
                  ),
              ],
            ),
          ),
          if (widget.etaText?.isNotEmpty ?? false) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: PFColors.primarySoft,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: PFColors.primaryGlow),
              ),
              child: Text(widget.etaText!,
                  style: const TextStyle(
                      color: PFColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12)),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Markers ────────────────────────────────────────────────────────────────

  Set<Marker> get _markers {
    return <Marker>{
      if (_driver != null)
        Marker(
          markerId: const MarkerId('pf_driver'),
          position: _driver!,
          infoWindow: InfoWindow(
            title: (widget.driverName?.isNotEmpty ?? false)
                ? widget.driverName!
                : 'Driver',
            snippet: widget.vehicleLabel,
          ),
          // Hue 340 ≈ deep rose/pink
          icon: BitmapDescriptor.defaultMarkerWithHue(340),
          zIndex: 10,
        ),
      if (_pickup != null)
        Marker(
          markerId: const MarkerId('pf_pickup'),
          position: _pickup!,
          infoWindow: const InfoWindow(title: 'Pickup'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen),
          zIndex: 5,
        ),
      if (_dropoff != null)
        Marker(
          markerId: const MarkerId('pf_dropoff'),
          position: _dropoff!,
          infoWindow: const InfoWindow(title: 'Dropoff'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueYellow),
          zIndex: 5,
        ),
    };
  }

  List<fm.Marker> get _webMarkers {
    return <fm.Marker>[
      if (_driver != null)
        fm.Marker(
          point: ll.LatLng(_driver!.latitude, _driver!.longitude),
          width: 40,
          height: 40,
          child: _webMarkerDot(
            icon: Icons.local_taxi_rounded,
            color: PFColors.primary,
          ),
        ),
      if (_pickup != null)
        fm.Marker(
          point: ll.LatLng(_pickup!.latitude, _pickup!.longitude),
          width: 34,
          height: 34,
          child: _webMarkerDot(
            icon: Icons.trip_origin_rounded,
            color: const Color(0xFF1E9E75),
          ),
        ),
      if (_dropoff != null)
        fm.Marker(
          point: ll.LatLng(_dropoff!.latitude, _dropoff!.longitude),
          width: 34,
          height: 34,
          child: _webMarkerDot(
            icon: Icons.location_on_rounded,
            color: PFColors.goldBase,
          ),
        ),
    ];
  }

  Widget _webMarkerDot({required IconData icon, required Color color}) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      _ensureWebMapView();
    }
    if (_showFallback || _mapFailed) return _buildFallback();

    if (_mapLoading || !_mapReady) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: PFColors.surface,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: PFColors.border),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(height: 10),
              Text(
                'Loading map…',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: PFColors.muted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          // ── Map ───────────────────────────────────────────────────────────
          Positioned.fill(
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(widget.borderRadius),
              child: kIsWeb
                  ? (_webViewRegistered
                      ? HtmlElementView(viewType: _webViewType)
                      : const Center(child: CircularProgressIndicator()))
                  : (defaultTargetPlatform == TargetPlatform.android ||
                          defaultTargetPlatform == TargetPlatform.iOS)
                      ? Builder(
                          builder: (context) {
                            final initialTarget =
                                _driver ?? _pickup ?? _dropoff ?? const LatLng(29.9511, -90.0715);
                            try {
                              return GoogleMap(
                            initialCameraPosition: CameraPosition(
                                target: initialTarget, zoom: 13.5),
                            markers: _markers,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            compassEnabled: false,
                            mapToolbarEnabled: false,
                            onMapCreated: (c) async {
                              try {
                                _controller = c;
                                debugPrint('[LIVE BOOKING] map init success');
                                if (mounted) {
                                  _mapRecoveryTimer?.cancel();
                                  setState(() {
                                    _mapLoaded = true;
                                    _mapReady = true;
                                    _mapLoading = false;
                                    _mapFailed = false;
                                    _showFallback = false;
                                    _mapInitStarted = false;
                                  });
                                } else {
                                  _mapLoaded = true;
                                }
                                _fallbackTimer?.cancel();
                                if (!_didInitialFit) {
                                  await _fitBounds();
                                  _didInitialFit = true;
                                }
                              } catch (e, st) {
                                _failMapInit(e, st);
                              }
                            },
                            onCameraMoveStarted: () {
                              if (_autoFollow) setState(() => _autoFollow = false);
                            },
                          );
                        } catch (e, st) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              _failMapInit(e, st);
                            }
                          });
                          return const SizedBox.shrink();
                        }
                      },
                        )
                      : _buildFallback(),
            ),
          ),

          // ── Recenter FAB ─────────────────────────────────────────────────
          if (!_autoFollow)
            Positioned(
              right: 10,
              bottom: 10,
              child: _RecenterButton(onTap: _recenter),
            ),

          // ── Bottom info overlay ─────────────────────────────────────────
          _bottomOverlay(),

          // ── "Waiting for location" overlay ──────────────────────────────
          if (_driver == null && _pickup == null && _dropoff == null)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius:
                        BorderRadius.circular(widget.borderRadius),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Waiting for location…',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: PFColors.muted,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Recenter button ───────────────────────────────────────────────────────────

class _RecenterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RecenterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          shape: BoxShape.circle,
          border: Border.all(color: PFColors.primary, width: 1.5),
          boxShadow: [
            BoxShadow(
                color: PFColors.primary.withValues(alpha: 0.3),
                blurRadius: 10),
          ],
        ),
        child: const Icon(Icons.my_location_rounded,
            color: PFColors.primary, size: 18),
      ),
    );
  }
}

// ── Compact status timeline ───────────────────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  final String status;
  const _StatusTimeline({required this.status});

  static const _steps = [
    ('accepted', 'Accepted'),
    ('en_route', 'En Route'),
    ('arrived', 'Arrived'),
    ('in_progress', 'In Progress'),
    ('completed', 'Done'),
  ];

  @override
  Widget build(BuildContext context) {
    final norm =
        status.toLowerCase().replaceAll(' ', '_').replaceAll('driver_assigned', 'accepted');
    final current = _steps.indexWhere((s) => s.$1 == norm);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _steps.asMap().entries.map((e) {
          final idx = e.key;
          final label = e.value.$2;
          final done = idx <= current;
          final active = idx == current;

          return Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: active
                    ? PFColors.primary
                    : done
                        ? PFColors.primarySoft
                        : Colors.white12,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight:
                      active ? FontWeight.w900 : FontWeight.w600,
                  color: active
                      ? Colors.white
                      : done
                          ? PFColors.primary
                          : Colors.white38,
                ),
              ),
            ),
            if (idx < _steps.length - 1)
              Container(
                width: 10,
                height: 1,
                color: idx < current ? PFColors.primary : Colors.white24,
                margin: const EdgeInsets.symmetric(horizontal: 2),
              ),
          ]);
        }).toList(),
      ),
    );
  }
}
