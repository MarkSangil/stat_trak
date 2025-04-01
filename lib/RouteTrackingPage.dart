import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart'; // Keep for distance calculation if not moved
import 'package:latlong2/latlong.dart';
import 'models/map_page_functions.dart' as mf; // Import logic functions

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
  LatLng? currentUserLocation;
  StreamSubscription<Position>? _locationSubscription; // Changed from Timer

  // UI State
  double zoomLevel = 16.0; // Start more zoomed in
  bool autoFollow = true;
  bool _isLoadingLocation = true; // Initially loading location
  mf.RouteProgress currentProgress = mf.RouteProgress(coveredDistanceMeters: 0, percentage: 0);


  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel(); // Cancel location stream subscription
    mapController.dispose();
    super.dispose();
  }

  // --- Initialization ---
  Future<void> _initializeTracking() async {
    // Get initial location first to center map quickly
    final initialLocation = await mf.getCurrentLocation(_showErrorSnackbar);
    if (mounted && initialLocation != null) {
      setState(() {
        currentUserLocation = initialLocation;
        _isLoadingLocation = false;
        // Calculate initial progress
        currentProgress = mf.calculateRouteProgress(
          currentLocation: initialLocation,
          routePoints: widget.selectedRoute.points,
          totalRouteDistanceMeters: widget.selectedRoute.distanceMeters,
        );
        // Move map initially if auto-follow is on
        if (autoFollow) {
          mf.moveToLocation(mapController, initialLocation, zoomLevel);
        }
      });
    } else if (mounted) {
      // Handle case where initial location fails but still start stream
      setState(() => _isLoadingLocation = false);
      _showErrorSnackbar("Could not get initial location. Tracking started.");
    }

    // Start continuous location updates stream
    _locationSubscription = mf.startLocationUpdatesStream(
      onLocationUpdate: _handleLocationUpdate,
      onError: _showErrorSnackbar,
      // Optional: Adjust accuracy/distance filter if needed
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    );
  }

  // --- Location Update Handling ---
  void _handleLocationUpdate(LatLng newLocation) {
    if (!mounted) return;

    setState(() {
      currentUserLocation = newLocation;
      _isLoadingLocation = false; // No longer initially loading

      // Recalculate progress
      currentProgress = mf.calculateRouteProgress(
        currentLocation: newLocation,
        routePoints: widget.selectedRoute.points,
        totalRouteDistanceMeters: widget.selectedRoute.distanceMeters,
      );

      // Move map if auto-follow is enabled
      if (autoFollow) {
        mf.moveToLocation(mapController, newLocation, zoomLevel);
      }

      // Check for completion (optional)
      if (currentProgress.percentage >= 99.0) {
        _showSuccessSnackbar("Route completed!");
        _locationSubscription?.pause(); // Stop updates on completion?
        // Maybe navigate back or show a summary dialog
      }
    });
  }

  // --- UI Actions ---
  void _toggleAutoFollow() {
    setState(() {
      autoFollow = !autoFollow;
      if (autoFollow && currentUserLocation != null) {
        // If turning auto-follow ON, immediately center on current location
        mf.moveToLocation(mapController, currentUserLocation!, zoomLevel);
      }
    });
  }

  // --- UI Helpers ---
  void _showSnackbar(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : (isSuccess ? Colors.green : Theme.of(context).snackBarTheme.backgroundColor),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }
  void _showErrorSnackbar(String message) => _showSnackbar(message, isError: true);
  void _showSuccessSnackbar(String message) => _showSnackbar(message, isSuccess: true);


  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine route color (consider passing this or using theme)
    final routeColor = widget.selectedRoute.type == 'short' ? Colors.green :
    widget.selectedRoute.type == 'less_maneuvers' ? Colors.purple :
    colorScheme.primary; // Default to primary


    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking Route'),
        backgroundColor: theme.appBarTheme.backgroundColor ?? colorScheme.primary,
        foregroundColor: theme.appBarTheme.foregroundColor ?? colorScheme.onPrimary,
        actions: [
          // Toggle Auto-Follow Button
          IconButton(
            icon: Icon(autoFollow ? Icons.gps_fixed : Icons.gps_not_fixed),
            onPressed: _toggleAutoFollow,
            tooltip: autoFollow ? "Disable Auto-Follow" : "Enable Auto-Follow",
          )
        ],
      ),
      body: Stack(
        children: [
          // --- Map Display ---
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              // Center initially on start point, but location updates will move it
              initialCenter: currentUserLocation ?? widget.startPoint,
              initialZoom: zoomLevel,
              maxZoom: 19,
              minZoom: 5,
              // Handle map interaction affecting auto-follow and zoom
              onPositionChanged: (position, hasGesture) {
                if (!mounted) return;
                bool zoomChanged = false;
                if (position.zoom != null && position.zoom != zoomLevel) {
                  zoomLevel = position.zoom!;
                  zoomChanged = true;
                }
                // If user manually interacts (pan/zoom), disable auto-follow
                if (hasGesture && autoFollow) {
                  setState(() {
                    autoFollow = false;
                    // Only update zoom state if it actually changed
                    // This prevents unnecessary rebuilds just for panning
                    if(zoomChanged) {} // No need to call setState again if only zoom changed
                  });
                } else if (zoomChanged) {
                  // If only zoom changed (e.g., via buttons), update state without disabling auto-follow
                  setState(() {});
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: ['a', 'b', 'c'],
                userAgentPackageName: 'com.stattrak.app', // Use your actual package name
                tileProvider: CancellableNetworkTileProvider(),
              ),
              // --- Route Polyline ---
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.selectedRoute.points,
                    strokeWidth: 6.0, // Slightly thicker
                    color: routeColor.withOpacity(0.7),
                    borderStrokeWidth: 1.0,
                    borderColor: Colors.white.withOpacity(0.5),
                  ),
                ],
              ),
              // --- Markers ---
              MarkerLayer(
                markers: [
                  // Start Marker
                  Marker(
                    point: widget.startPoint, width: 80, height: 80, alignment: Alignment.topCenter,
                    child: Tooltip(message: "Start", child: Icon(Icons.trip_origin, color: Colors.redAccent, size: 35)),
                  ),
                  // End Marker
                  Marker(
                    point: widget.endPoint, width: 80, height: 80, alignment: Alignment.topCenter,
                    child: Tooltip(message: "Destination", child: Icon(Icons.flag, color: colorScheme.secondary, size: 35)),
                  ),
                  // Current Location Marker
                  if (currentUserLocation != null)
                    Marker(
                      point: currentUserLocation!, width: 80, height: 80, alignment: Alignment.center, // Center alignment for person icon
                      child: Tooltip(
                        message: "You are here",
                        // Use a clearer current location icon
                        child: Icon(Icons.person_pin_circle_rounded, color: Colors.blue, size: 40,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 5.0)]),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // --- Loading Indicator ---
          if (_isLoadingLocation)
            Center(
              child: CircularProgressIndicator(),
            ),

          // --- Progress Bar Overlay ---
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: currentProgress.percentage / 100.0, // Value between 0.0 and 1.0
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(routeColor),
                      minHeight: 6, // Make progress bar thicker
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Progress: ${currentProgress.percentage.toStringAsFixed(1)}%",
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    // Optional: Show remaining distance
                    // Text(
                    //   "Remaining: ${((widget.selectedRoute.distanceMeters - currentProgress.coveredDistanceMeters)/1000).toStringAsFixed(1)} km",
                    //   style: theme.textTheme.bodySmall,
                    // ),
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