import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class _MapZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Color(0xFFF4A32D), size: 22),
      ),
    );
  }
}

class TrackOrderScreen extends StatefulWidget {
  final String orderId;
  final String estimatedDelivery;
  final int? orderCreatedAtMillis;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? deliveryAddressText;
  final String deliveryOptionTitle;
  final double deliveryFee;
  final double? checkoutDistanceKm;
  final String marketName;
  final double marketLatitude;
  final double marketLongitude;
  final String driverName;

  const TrackOrderScreen({
    super.key,
    required this.orderId,
    this.estimatedDelivery = '10 - 30 min',
    this.orderCreatedAtMillis,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.deliveryAddressText,
    this.deliveryOptionTitle = 'Express Delivery',
    this.deliveryFee = 0.0,
    this.checkoutDistanceKm,
    this.marketName = 'Culinary Market',
    this.marketLatitude = 30.0444,
    this.marketLongitude = 31.2357,
    this.driverName = 'Michael Johnson',
  });

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  final MapController _mapController = MapController();

  static const Color _orange = Color(0xFFF4A32D);
  static const Color _brown = Color(0xFF2C1810);
  static const Color _muted = Color(0xFF8B7355);
  static const Color _green = Color(0xFF4CAF50);
  static const Color _background = Color(0xFFFFFAF4);

  late LatLng _storeLocation;
  LatLng _deliveryLocation = const LatLng(30.0561, 31.2394);
  LatLng _driverLocation = const LatLng(30.0485, 31.2375);

  List<LatLng> _routePoints = [];
  Timer? _driverTimer;
  Timer? _statusTimer;

  bool _loadingLocation = true;
  bool _loadingRoute = true;
  String? _mapError;

  double _distanceKm = 0;
  int _etaMinutes = 0;
  late final DateTime _orderCreatedAt;
  late final int _chosenDeliveryMinutes;
  late final DateTime _targetArrivalTime;

  @override
  void initState() {
    super.initState();
    _storeLocation = LatLng(widget.marketLatitude, widget.marketLongitude);
    _orderCreatedAt = widget.orderCreatedAtMillis == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(widget.orderCreatedAtMillis!);
    _chosenDeliveryMinutes = _maxMinutesFromDeliveryTime(widget.estimatedDelivery);
    _targetArrivalTime = _orderCreatedAt.add(Duration(minutes: _chosenDeliveryMinutes));
    _startStatusClock();
    _setupMap();
  }

  @override
  void dispose() {
    _driverTimer?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }


  void _startStatusClock() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      setState(() {
        _etaMinutes = _remainingMinutesToTarget;
      });
    });
  }

  bool _isTimeReached(DateTime time) {
    final now = DateTime.now();
    return now.isAtSameMomentAs(time) || now.isAfter(time);
  }

  DateTime get _preparingTime => _orderCreatedAt.add(const Duration(minutes: 5));
  DateTime get _outForDeliveryTime => _orderCreatedAt.add(const Duration(minutes: 10));

  int _maxMinutesFromDeliveryTime(String value) {
    final numbers = RegExp(r'\d+').allMatches(value).map((m) => int.tryParse(m.group(0) ?? '') ?? 0).where((n) => n > 0).toList();
    if (numbers.isEmpty) return 30;
    return numbers.reduce(math.max);
  }

  String _formatClockTime(DateTime time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  int get _remainingMinutesToTarget {
    final remaining = _targetArrivalTime.difference(DateTime.now()).inMinutes;
    return remaining < 0 ? 0 : remaining;
  }

  bool get _hasArrived => DateTime.now().isAtSameMomentAs(_targetArrivalTime) ||
      DateTime.now().isAfter(_targetArrivalTime);

  double get _deliveryProgress {
    final totalSeconds = math.max(1, _targetArrivalTime.difference(_orderCreatedAt).inSeconds);
    final elapsedSeconds = DateTime.now().difference(_orderCreatedAt).inSeconds;
    return (elapsedSeconds / totalSeconds).clamp(0.0, 1.0).toDouble();
  }

  Future<void> _setupMap() async {
    await _getUserLocation();
    await _fetchRoute();
    _startDriverSimulation();

    if (mounted) {
      setState(() {
        _loadingLocation = false;
      });
    }
  }

  Future<void> _getUserLocation() async {
    try {
      // If the checkout screen sent a saved delivery address, use it directly.
      // This keeps Track Order connected to the address selected from the map.
      if (widget.deliveryLatitude != null && widget.deliveryLongitude != null) {
        _deliveryLocation = LatLng(
          widget.deliveryLatitude!,
          widget.deliveryLongitude!,
        );

        // Use the exact same marketplace location sent from Checkout.

        // Driver starts between marketplace and customer.
        _driverLocation = LatLng(
          (_storeLocation.latitude + _deliveryLocation.latitude) / 2,
          (_storeLocation.longitude + _deliveryLocation.longitude) / 2,
        );
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        setState(() {
          _mapError = 'Location service is disabled. Using sample location.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _mapError = 'Location permission denied. Using sample location.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _deliveryLocation = LatLng(position.latitude, position.longitude);

      // Keep the marketplace fixed, matching Checkout.

      // Driver starts between marketplace and customer.
      _driverLocation = LatLng(
        (_storeLocation.latitude + _deliveryLocation.latitude) / 2,
        (_storeLocation.longitude + _deliveryLocation.longitude) / 2,
      );
    } catch (e) {
      setState(() {
        _mapError = 'Could not get location. Using sample location.';
      });
    }
  }

  Future<void> _fetchRoute() async {
    setState(() => _loadingRoute = true);

    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${_storeLocation.longitude},${_storeLocation.latitude};'
          '${_deliveryLocation.longitude},${_deliveryLocation.latitude}'
          '?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        _useFallbackRoute();
        return;
      }

      final data = jsonDecode(response.body);

      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        _useFallbackRoute();
        return;
      }

      final route = routes.first;
      final coordinates = route['geometry']['coordinates'] as List;

      final points = coordinates.map<LatLng>((coord) {
        return LatLng(
          (coord[1] as num).toDouble(),
          (coord[0] as num).toDouble(),
        );
      }).toList();

      final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0;
      final durationSeconds = (route['duration'] as num?)?.toDouble() ?? 0;

      setState(() {
        _routePoints = points;
        _distanceKm = widget.checkoutDistanceKm ?? (distanceMeters / 1000);
        _etaMinutes = _remainingMinutesToTarget;
        _loadingRoute = false;
      });

      _updateDriverPositionFromOrderTime();
      _fitMapToRoute();
    } catch (e) {
      _useFallbackRoute();
    }
  }

  void _useFallbackRoute() {
    final distance = const Distance();

    setState(() {
      _routePoints = [
        _storeLocation,
        _driverLocation,
        _deliveryLocation,
      ];
      _distanceKm = widget.checkoutDistanceKm ?? distance.as(
        LengthUnit.Kilometer,
        _storeLocation,
        _deliveryLocation,
      );
      _etaMinutes = _remainingMinutesToTarget;
      _loadingRoute = false;
    });

    _updateDriverPositionFromOrderTime();
    _fitMapToRoute();
  }

  void _fitMapToRoute() {
    if (_routePoints.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bounds = LatLngBounds.fromPoints(_routePoints);

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    });
  }

  void _startDriverSimulation() {
    if (_routePoints.length < 2) return;

    _driverTimer?.cancel();
    _updateDriverPositionFromOrderTime(moveMapWhenArrived: true);

    _driverTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      _updateDriverPositionFromOrderTime(moveMapWhenArrived: false);

      if (_hasArrived) {
        timer.cancel();
        _mapController.move(_deliveryLocation, _mapController.camera.zoom);
      }
    });
  }

  void _updateDriverPositionFromOrderTime({bool moveMapWhenArrived = false}) {
    if (_routePoints.length < 2) return;

    final progress = _deliveryProgress;
    final nextLocation = progress >= 1.0
        ? _deliveryLocation
        : _pointOnRouteByProgress(progress);

    setState(() {
      _driverLocation = nextLocation;
      _etaMinutes = _remainingMinutesToTarget;
    });

    if (progress >= 1.0 && moveMapWhenArrived) {
      _mapController.move(_deliveryLocation, _mapController.camera.zoom);
    }
  }

  LatLng _pointOnRouteByProgress(double progress) {
    if (_routePoints.length < 2) return _deliveryLocation;

    final distance = const Distance();
    final segmentLengths = <double>[];
    double totalMeters = 0;

    for (int i = 0; i < _routePoints.length - 1; i++) {
      final segment = distance.as(
        LengthUnit.Meter,
        _routePoints[i],
        _routePoints[i + 1],
      );
      segmentLengths.add(segment);
      totalMeters += segment;
    }

    if (totalMeters <= 0) return _deliveryLocation;

    final targetMeters = totalMeters * progress.clamp(0.0, 1.0);
    double travelledMeters = 0;

    for (int i = 0; i < segmentLengths.length; i++) {
      final segment = segmentLengths[i];
      if (travelledMeters + segment >= targetMeters) {
        final segmentProgress = segment == 0
            ? 0.0
            : ((targetMeters - travelledMeters) / segment).clamp(0.0, 1.0);
        final start = _routePoints[i];
        final end = _routePoints[i + 1];

        return LatLng(
          start.latitude + ((end.latitude - start.latitude) * segmentProgress),
          start.longitude + ((end.longitude - start.longitude) * segmentProgress),
        );
      }
      travelledMeters += segment;
    }

    return _deliveryLocation;
  }

  void _zoomMap(double delta) {
    final currentZoom = _mapController.camera.zoom;
    final nextZoom = (currentZoom + delta).clamp(3.0, 18.0).toDouble();
    _mapController.move(_mapController.camera.center, nextZoom);
  }

  List<Marker> get _markers {
    return [
      _buildMarker(
        point: _storeLocation,
        color: _orange,
        icon: Icons.storefront,
        size: 42,
      ),
      _buildMarker(
        point: _driverLocation,
        color: Colors.blue,
        icon: Icons.delivery_dining,
        size: 48,
      ),
      _buildMarker(
        point: _deliveryLocation,
        color: _green,
        icon: Icons.home,
        size: 42,
      ),
    ];
  }

  Marker _buildMarker({
    required LatLng point,
    required Color color,
    required IconData icon,
    required double size,
  }) {
    return Marker(
      point: point,
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.52),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: _brown, size: 20),
        ),
        title: Text(
          _hasArrived ? 'Order Arrived' : 'Track Order',
          style: const TextStyle(
            color: _brown,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildMapCard(),
            if (_mapError != null) _buildWarningCard(),
            if (_hasArrived) _buildArrivedCard(),
            _buildDriverCard(),
            const SizedBox(height: 16),
            _buildOrderDetailsCard(),
            const SizedBox(height: 24),
            _buildStatusTitle(),
            const SizedBox(height: 16),
            _buildTimelineCard(),
            if (!_hasArrived) ...[
              const SizedBox(height: 24),
              _buildContactButtons(),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMapCard() {
    return Container(
      height: 320,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _driverLocation,
                initialZoom: 14,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.culinary_coach.app',
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: _orange,
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                MarkerLayer(markers: _markers),
              ],
            ),
            if (_loadingLocation || _loadingRoute)
              Container(
                color: Colors.white.withOpacity(0.65),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_orange),
                  ),
                ),
              ),
            Positioned(
              right: 12,
              top: 12,
              child: Column(
                children: [
                  _MapZoomButton(
                    icon: Icons.add,
                    onTap: () => _zoomMap(1),
                  ),
                  const SizedBox(height: 8),
                  _MapZoomButton(
                    icon: Icons.remove,
                    onTap: () => _zoomMap(-1),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: null,
                backgroundColor: Colors.white,
                elevation: 2,
                onPressed: () {
                  _mapController.move(_driverLocation, 15);
                },
                child: const Icon(Icons.my_location, color: _orange),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _orange.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _mapError!,
              style: const TextStyle(
                color: _brown,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard() {
    final arrived = _hasArrived;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: (arrived ? _green : _orange).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              arrived ? Icons.verified_outlined : Icons.delivery_dining,
              color: arrived ? _green : _orange,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  arrived ? 'Delivered By' : 'Your Driver',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.driverName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _brown,
                  ),
                ),
                const SizedBox(height: 4),
                const Row(
                  children: [
                    Icon(Icons.star, size: 14, color: _orange),
                    SizedBox(width: 4),
                    Text(
                      '4.9',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _brown,
                      ),
                    ),
                    Text(
                      ' (128 ratings)',
                      style: TextStyle(fontSize: 11, color: Color(0xFFA08F7E)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (arrived ? _green : _orange).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: arrived ? _green : _orange),
                const SizedBox(width: 6),
                Text(
                  arrived ? 'Arrived' : 'Active',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: arrived ? _green : _orange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrivedCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _green.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _green.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: _green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your order has arrived',
                  style: TextStyle(
                    color: _brown,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Delivered at ${_formatClockTime(_targetArrivalTime)} by ${widget.driverName}.',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildDetailRow('Order ID', widget.orderId),
          const SizedBox(height: 12),
          _buildDetailRow('Marketplace', widget.marketName),
          const SizedBox(height: 12),
          _buildDetailRow('Delivery Option', widget.deliveryOptionTitle),
          const SizedBox(height: 12),
          _buildDetailRow('Delivery Fee', '${widget.deliveryFee.toStringAsFixed(2)} EGP', valueColor: _orange),
          const SizedBox(height: 12),
          _buildDetailRow('Estimated Delivery', widget.estimatedDelivery,
              valueColor: _green),
          const SizedBox(height: 12),
          _buildDetailRow('Arrives At', _formatClockTime(_targetArrivalTime), valueColor: _green),
          if (widget.deliveryAddressText != null && widget.deliveryAddressText!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              'Address',
              widget.deliveryAddressText!,
            ),
          ],
          const SizedBox(height: 12),
          _buildDetailRow(
            'Distance',
            '${_distanceKm.toStringAsFixed(1)} km',
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            _hasArrived ? 'Delivery Status' : 'Driver ETA',
            _hasArrived ? 'Arrived' : (_etaMinutes == 0 ? 'Arriving now' : '$_etaMinutes mins'),
            valueColor: _hasArrived ? _green : _orange,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color valueColor = _brown}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: _muted)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: label == 'Address' ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTitle() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Order Status',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _brown,
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineCard() {
    final orderConfirmedDone = _isTimeReached(_orderCreatedAt);
    final preparingDone = _isTimeReached(_preparingTime);
    final outForDeliveryDone = _isTimeReached(_outForDeliveryTime);
    final deliveredDone = _isTimeReached(_targetArrivalTime);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildTimelineItem(
            isCompleted: orderConfirmedDone,
            isConnectorCompleted: preparingDone,
            title: 'Order Confirmed',
            time: _formatClockTime(_orderCreatedAt),
            isFirst: true,
          ),
          _buildTimelineItem(
            isCompleted: preparingDone,
            isConnectorCompleted: outForDeliveryDone,
            title: 'Preparing Your Order',
            time: _formatClockTime(_preparingTime),
          ),
          _buildTimelineItem(
            isCompleted: outForDeliveryDone,
            isConnectorCompleted: deliveredDone,
            title: 'Out for Delivery',
            time: _formatClockTime(_outForDeliveryTime),
          ),
          _buildTimelineItem(
            isCompleted: deliveredDone,
            title: 'Delivered',
            time: deliveredDone
                ? _formatClockTime(_targetArrivalTime)
                : 'Expected at ${_formatClockTime(_targetArrivalTime)}',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required bool isCompleted,
    bool isConnectorCompleted = false,
    required String title,
    required String time,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? _green : const Color(0xFFE0E0E0),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted ? Icons.check : Icons.circle,
                color: Colors.white,
                size: isCompleted ? 15 : 8,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 42,
                color: isConnectorCompleted ? _green : const Color(0xFFE0E0E0),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: isFirst ? 1 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? _brown : _muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFA08F7E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showCallDriverDialog(context),
              icon: const Icon(Icons.phone, size: 18),
              label: const Text('Call Driver'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _orange,
                side: const BorderSide(color: _orange),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showMessageDriverDialog(context),
              icon: const Icon(Icons.message, size: 18, color: Colors.white),
              label: const Text('Message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCallDriverDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Call Driver'),
        content: Text('Do you want to call ${widget.driverName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: _orange),
            child: const Text('Call', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMessageDriverDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Message Driver'),
        content: const Text('Messaging feature will be available soon.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: _orange),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}