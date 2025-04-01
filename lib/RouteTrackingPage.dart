import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'models/map_page_functions.dart' as mf;

class TrackingState {
  final LatLng? userLocation;
  final mf.RouteProgress progress;
  final bool isLoading;
  final bool isCompleted;
  final DateTime? lastUpdateTime; // Add timestamp for tracking updates

  TrackingState({
    this.userLocation,
    required this.progress,
    this.isLoading = false,
    this.isCompleted = false,
    this.lastUpdateTime,
  });

  TrackingState copyWith({
    LatLng? userLocation,
    mf.RouteProgress? progress,
    bool? isLoading,
    bool? isCompleted,
    DateTime? lastUpdateTime,
  }) {
    return TrackingState(
      userLocation: userLocation ?? this.userLocation,
      progress: progress ?? this.progress,
      isLoading: isLoading ?? this.isLoading,
      isCompleted: isCompleted ?? this.isCompleted,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
    );
  }
}

// Add this to your RouteTrackingPageState class
LatLng? _previousLoggedLocation;

class RouteTrackingPage extends StatefulWidget {
  final LatLng startPoint;
  final LatLng endPoint;
  final mf.RouteInfo selectedRoute;

  const RouteTrackingPage({
    Key? key,
    required this.startPoint,
    required this.endPoint,
    required this.selectedRoute,
  }) : super(key: key);

  @override
  _RouteTrackingPageState createState() => _RouteTrackingPageState();
}

class _RouteTrackingPageState extends State<RouteTrackingPage> {
  final MapController mapController = MapController();
  StreamSubscription<Position>? _locationSubscription;
  Timer? _periodicUpdateTimer;
  Timer? _backendSyncTimer;
  Timer? _logLocationTimer; // 🆕 Added for logging

  double zoomLevel = 16.0;
  bool autoFollow = true;

  TrackingState _trackingState = TrackingState(
    progress: mf.RouteProgress(coveredDistanceMeters: 0, percentage: 0),
    isLoading: true,
  );

  @override
  void initState() {
    super.initState();
    _initializeTracking();

    // More frequent location updates
    _periodicUpdateTimer = Timer.periodic(
        const Duration(seconds: 1), // Reduced from 3 seconds
            (_) => _refreshLocationState()
    );

    // Keep the backend sync timer but make it independent of tracking
    _backendSyncTimer = Timer.periodic(
        const Duration(seconds: 15),
            (_) => _syncWithBackend()
    );

    // More frequent location logging
    _logLocationTimer = Timer.periodic(
        const Duration(seconds: 5), // Reduced from 10 seconds
            (_) => _logUserLocation()
    );
  }

  // Added missing method for showing error snackbars
  void _showErrorSnackbar(String message) {
    if (!mounted) return;

    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text(message),
    //     backgroundColor: Colors.red,
    //     duration: const Duration(seconds: 3),
    //   ),
    // );
  }

  // Added missing method for showing success snackbars
  void _showSuccessSnackbar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Added missing method to toggle auto-follow mode
  void _toggleAutoFollow() {
    setState(() {
      autoFollow = !autoFollow;
      if (autoFollow && _trackingState.userLocation != null) {
        mf.moveToLocation(mapController, _trackingState.userLocation!, zoomLevel);
      }
    });
  }

  Future<void> _initializeTracking() async {
    setState(() {
      _trackingState = _trackingState.copyWith(isLoading: true);
    });

    // Request highest accuracy location permissions
    await _checkAndRequestPermissions();

    final initialLocation = await mf.getCurrentLocation(_showErrorSnackbar);
    if (!mounted) return;

    if (initialLocation != null) {
      final progress = mf.calculateRouteProgress(
        currentLocation: initialLocation,
        routePoints: widget.selectedRoute.points,
        totalRouteDistanceMeters: widget.selectedRoute.distanceMeters,
      );

      setState(() {
        _trackingState = _trackingState.copyWith(
          userLocation: initialLocation,
          progress: progress,
          isLoading: false,
        );
      });

      if (autoFollow) {
        mf.moveToLocation(mapController, initialLocation, zoomLevel);
      }
    } else {
      setState(() {
        _trackingState = _trackingState.copyWith(isLoading: false);
      });
      _showErrorSnackbar("Could not get initial location. Tracking started with last known position.");
    }

    // Start location updates with improved settings
    _locationSubscription = mf.startLocationUpdatesStream(
      onLocationUpdate: _handleLocationUpdate,
      onError: _showErrorSnackbar,
      accuracy: LocationAccuracy.best, // Changed from 'highest' to 'best'
      distanceFilter: 0, // Reduced from 1 to capture minor movements
      timeInterval: 1000, // Add a time-based update interval (1 second)
    );
  }

  Future<void> _checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorSnackbar("Location services are disabled. Please enable in settings.");
      // Optionally open location settings
      // await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorSnackbar("Location permissions denied. Tracking may not work properly.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorSnackbar("Location permissions permanently denied. Please enable in app settings.");
    }
  }

  void _handleLocationUpdate(LatLng newLocation) {
    if (!mounted) return;

    // Log raw update for debugging
    print("📱 Raw Location Update - Lat: ${newLocation.latitude}, Lng: ${newLocation.longitude}");

    // Check if location has actually changed (with small tolerance)
    final bool hasLocationChanged = _trackingState.userLocation == null ||
        _calculateDistance(_trackingState.userLocation!, newLocation) > 0.1;

    if (hasLocationChanged) {
      final newProgress = mf.calculateRouteProgress(
        currentLocation: newLocation,
        routePoints: widget.selectedRoute.points,
        totalRouteDistanceMeters: widget.selectedRoute.distanceMeters,
      );

      bool isCompleted = newProgress.percentage >= 99.0;

      setState(() {
        _trackingState = _trackingState.copyWith(
          userLocation: newLocation,
          progress: newProgress,
          isCompleted: isCompleted,
          lastUpdateTime: DateTime.now(), // Add timestamp for debugging
        );
      });

      if (autoFollow) {
        mf.moveToLocation(mapController, newLocation, zoomLevel);
      }

      if (isCompleted && !_trackingState.isCompleted) {
        _showSuccessSnackbar("Route completed!");
        _locationSubscription?.pause();
        _periodicUpdateTimer?.cancel();
        _backendSyncTimer?.cancel();
        _logLocationTimer?.cancel();
      }
    }
  }

// Helper method to calculate distance between two points in meters
  double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
        point1.latitude, point1.longitude,
        point2.latitude, point2.longitude
    );
  }

  Future<void> _refreshLocationState() async {
    if (_trackingState.isCompleted) return;

    try {
      // Force a new location acquisition with high accuracy
      final location = await mf.getHighAccuracyLocation(_showErrorSnackbar);
      if (!mounted || location == null) return;

      // Always update the UI with the new location regardless of how small the change
      final progress = mf.calculateRouteProgress(
        currentLocation: location,
        routePoints: widget.selectedRoute.points,
        totalRouteDistanceMeters: widget.selectedRoute.distanceMeters,
      );

      setState(() {
        _trackingState = _trackingState.copyWith(
          userLocation: location,
          progress: progress,
          lastUpdateTime: DateTime.now(),
        );
      });

      if (autoFollow) {
        mf.moveToLocation(mapController, location, zoomLevel);
      }

      if (progress.percentage >= 99.0 && !_trackingState.isCompleted) {
        setState(() {
          _trackingState = _trackingState.copyWith(isCompleted: true);
        });
        _showSuccessSnackbar("Route completed!");
        _periodicUpdateTimer?.cancel();
        _backendSyncTimer?.cancel();
        _logLocationTimer?.cancel();
      }
    } catch (e) {
      print("Location refresh error: $e");
    }
  }

  Future<void> _syncWithBackend() async {
    if (_trackingState.userLocation == null) return;

    try {
      await mf.syncProgressWithSupabase(
        routeId: widget.selectedRoute.id,
        currentLocation: _trackingState.userLocation!,
        progress: _trackingState.progress.percentage,
      );
      print("Successfully synced with backend: ${_trackingState.progress.percentage.toStringAsFixed(1)}%");
    } catch (e) {
      print("Backend sync error: $e");
      // Don't let backend errors affect tracking
    }
  }

  void _logUserLocation() {
    if (_trackingState.userLocation != null) {
      final lat = _trackingState.userLocation!.latitude;
      final lng = _trackingState.userLocation!.longitude;
      final now = DateTime.now();
      final timestamp = "${now.hour}:${now.minute}:${now.second}";
      print("📍 User Location at $timestamp - Lat: $lat, Lng: $lng");

      // If we have a previous location, calculate and show the distance moved
      if (_previousLoggedLocation != null) {
        final distance = _calculateDistance(_previousLoggedLocation!, _trackingState.userLocation!);
        print("📏 Distance moved: ${distance.toStringAsFixed(2)} meters since last log");
      }

      _previousLoggedLocation = _trackingState.userLocation;
    } else {
      print("📍 User location not available yet.");
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _periodicUpdateTimer?.cancel();
    _backendSyncTimer?.cancel();
    _logLocationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final routeColor = widget.selectedRoute.type == 'short'
        ? Colors.green
        : widget.selectedRoute.type == 'less_maneuvers'
        ? Colors.purple
        : colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking Route'),
        backgroundColor: theme.appBarTheme.backgroundColor ?? colorScheme.primary,
        foregroundColor: theme.appBarTheme.foregroundColor ?? colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: Icon(autoFollow ? Icons.gps_fixed : Icons.gps_not_fixed),
            onPressed: _toggleAutoFollow,
            tooltip: autoFollow ? "Disable Auto-Follow" : "Enable Auto-Follow",
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: _trackingState.userLocation ?? widget.startPoint,
              initialZoom: zoomLevel,
              maxZoom: 19,
              minZoom: 5,
              onPositionChanged: (position, hasGesture) {
                if (!mounted) return;
                bool zoomChanged = false;
                if (position.zoom != null && position.zoom != zoomLevel) {
                  zoomLevel = position.zoom!;
                  zoomChanged = true;
                }
                if (hasGesture && autoFollow) {
                  setState(() {
                    autoFollow = false;
                  });
                } else if (zoomChanged) {
                  setState(() {});
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.stattrak.app',
                tileProvider: CancellableNetworkTileProvider(),
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.selectedRoute.points,
                    strokeWidth: 6.0,
                    color: routeColor.withOpacity(0.7),
                    borderStrokeWidth: 1.0,
                    borderColor: Colors.white.withOpacity(0.5),
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.startPoint,
                    width: 80,
                    height: 80,
                    alignment: Alignment.topCenter,
                    child: Tooltip(
                      message: "Start",
                      child: Icon(Icons.trip_origin,
                          color: Colors.redAccent, size: 35),
                    ),
                  ),
                  Marker(
                    point: widget.endPoint,
                    width: 80,
                    height: 80,
                    alignment: Alignment.topCenter,
                    child: Tooltip(
                      message: "Destination",
                      child: Icon(Icons.flag,
                          color: colorScheme.secondary, size: 35),
                    ),
                  ),
                  if (_trackingState.userLocation != null)
                    Marker(
                      point: _trackingState.userLocation!,
                      width: 80,
                      height: 80,
                      alignment: Alignment.center,
                      child: Tooltip(
                        message: "You are here",
                        child: Icon(Icons.person_pin_circle_rounded,
                            color: Colors.blue, size: 40, shadows: [
                              Shadow(color: Colors.black54, blurRadius: 5.0)
                            ]),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (_trackingState.isLoading)
            Center(child: CircularProgressIndicator()),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 4,
              child: Padding(
                padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: _trackingState.progress.percentage / 100.0,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(routeColor),
                      minHeight: 6,
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Progress: ${_trackingState.progress.percentage.toStringAsFixed(1)}%",
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (_trackingState.userLocation != null)
                          Text(
                            "Last updated: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}