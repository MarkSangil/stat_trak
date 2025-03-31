import 'dart:convert';
import 'package:flutter/material.dart'; // Added for potential future use (though avoided here)
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart'; // <-- Import share_plus
import 'package:supabase_flutter/supabase_flutter.dart'; // <-- Import supabase

/// A model to hold route data.
class RouteInfo {
  final String type;
  final List<LatLng> points;
  final double distanceMeters;
  final double timeSeconds;

  RouteInfo({
    required this.type,
    required this.points,
    required this.distanceMeters,
    required this.timeSeconds,
  });
}

Future<RouteInfo?> fetchRouteByType({
  required LatLng? marker1,
  required LatLng? marker2,
  required String type,
  required String apiKey,
}) async {
  if (marker1 == null || marker2 == null) return null;

  final url = "https://api.geoapify.com/v1/routing?"
      "waypoints=${marker1.latitude},${marker1.longitude}|${marker2.latitude},${marker2.longitude}"
      "&mode=drive"
      "&type=$type"
      "&apiKey=$apiKey";

  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    final decoded = json.decode(response.body);
    if (decoded['features'] == null || decoded['features'].isEmpty) {
      return null;
    }

    final List<dynamic> multiLineCoordinates =
    decoded['features'][0]['geometry']['coordinates'];

    List<LatLng> points = multiLineCoordinates.expand((line) {
      return line.map((coord) {
        if (coord is List && coord.length == 2) {
          return LatLng(coord[1].toDouble(), coord[0].toDouble());
        }
        return null;
      });
    }).whereType<LatLng>().toList();

    final props = decoded['features'][0]['properties'];
    double distanceMeters = (props['distance'] ?? 0).toDouble();
    double timeSeconds = (props['time'] ?? 0).toDouble();

    if (points.isEmpty) return null;

    return RouteInfo(
      type: type,
      points: points,
      distanceMeters: distanceMeters,
      timeSeconds: timeSeconds,
    );
  } else {
    print("Error fetching route type $type: ${response.statusCode} ${response.body}");
    return null;
  }
}

Future<void> fetchAllRoutes({
  required LatLng? marker1,
  required LatLng? marker2,
  required List<RouteInfo> routeAlternatives,
  required Function setStateCallback,
  required Function fitMapToRoutesCallback,
  required String apiKey,
}) async {
  if (marker1 == null || marker2 == null) return;

  final routeTypes = ['balanced', 'short', 'less_maneuvers'];
  routeAlternatives.clear();
  setStateCallback();

  List<Future<RouteInfo?>> futures = [];
  for (final type in routeTypes) {
    futures.add(fetchRouteByType(
      marker1: marker1,
      marker2: marker2,
      type: type,
      apiKey: apiKey,
    ));
  }

  final results = await Future.wait(futures);

  for (final route in results) {
    if (route != null) {
      routeAlternatives.add(route);
    }
  }

  setStateCallback();
  if (routeAlternatives.isNotEmpty) {
    fitMapToRoutesCallback();
  }
}

/// NEW FUNCTION: Fetch routes given start/end coordinates and return a list of RouteInfo.
/// This function is tailored for use in the SharedRoutePage to re-fetch the route geometry.
Future<List<RouteInfo>> fetchAllRoutesForTwoPoints({
  required double startLat,
  required double startLng,
  required double endLat,
  required double endLng,
  required String apiKey,
}) async {
  // Create marker instances from the provided coordinates.
  LatLng marker1 = LatLng(startLat, startLng);
  LatLng marker2 = LatLng(endLat, endLng);

  final routeTypes = ['balanced', 'short', 'less_maneuvers'];
  List<RouteInfo> routes = [];
  List<Future<RouteInfo?>> futures = [];

  // Fetch route info for each type.
  for (String type in routeTypes) {
    futures.add(fetchRouteByType(
      marker1: marker1,
      marker2: marker2,
      type: type,
      apiKey: apiKey,
    ));
  }

  final results = await Future.wait(futures);
  for (final route in results) {
    if (route != null) {
      routes.add(route);
    }
  }
  return routes;
}

Future<List<Map<String, dynamic>>> fetchLocations(String query, String apiKey) async {
  try {
    final String url = 'https://api.geoapify.com/v1/geocode/search?text=$query&apiKey=$apiKey';

    final http.Response response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch locations: HTTP ${response.statusCode}');
    }

    final Map<String, dynamic> data = json.decode(response.body);

    if (data['features'] == null || !(data['features'] is List)) {
      return [];
    }

    // Make sure we return a List<Map<String, dynamic>> with no nullable maps
    return List<Map<String, dynamic>>.from((data['features'] as List).map((feature) {
      final properties = feature['properties'] as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;

      // Extract coordinates and ensure they're not null
      final List<dynamic> coordinates = geometry['coordinates'] as List<dynamic>;
      final double longitude = coordinates[0] is double ? coordinates[0] : double.parse(coordinates[0].toString());
      final double latitude = coordinates[1] is double ? coordinates[1] : double.parse(coordinates[1].toString());

      // Create formatted name for display
      final String name = properties['formatted'] ?? 'Unknown location';

      return {
        'name': name,
        'latlng': LatLng(latitude, longitude),
        'address': name,
      };
    }));
  } catch (e) {
    print("Error in map_page_functions fetchLocations: $e");
    throw Exception('Failed to fetch locations: $e');
  }
}

void moveToLocation(MapController mapController, LatLng location, double zoom) {
  try {
    mapController.move(location, zoom);
  } catch (e) {
    // Handle potential errors if mapController isn't ready or disposed
    print("Error moving map: $e");
  }
}

void removeMarker({
  required int markerNumber,
  required Function clearMarker1,
  required Function clearMarker2, // Callback to clear marker2 state in widget
  required List<RouteInfo> routeAlternatives, // To clear routes when markers change
}) {
  if (markerNumber == 1) {
    clearMarker1();
  } else if (markerNumber == 2) { // Use else if for clarity
    clearMarker2();
  }
  // Always clear routes if any marker is removed
  routeAlternatives.clear();
}

void fitMapToRoutes({
  required List<RouteInfo> routeAlternatives,
  required MapController mapController,
}) {
  if (routeAlternatives.isEmpty) return;

  // Flatten all points from all routes
  final allPoints = routeAlternatives.expand((r) => r.points).toList();
  if (allPoints.isEmpty) return;

  // Calculate bounds using LatLngBounds for simplicity and correctness
  final bounds = LatLngBounds.fromPoints(allPoints);

  // Use mapController's fitBounds method - it handles zoom calculation
  try {
    mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: EdgeInsets.all(50.0), // Add padding around the bounds
      ),
    );
  } catch (e) {
    print("Error fitting map to bounds: $e");
    // Fallback or alternative handling if needed
  }
}

Future<LatLng?> getCurrentLocation() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users enable the services.
    print("Location services disabled.");
    // Consider showing a message to the user via the calling widget
    return null;
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (iOS only) or show an explanation.
      print("Location permissions denied.");
      return null;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    print("Location permissions permanently denied.");
    // Consider guiding the user to app settings via the calling widget
    return null;
  }

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  try {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      // Optional: Add time limit
      // timeLimit: Duration(seconds: 10),
    );
    return LatLng(position.latitude, position.longitude);
  } catch (e) {
    print("Error getting current position: $e");
    return null; // Handle timeout or other errors
  }
}

/// Creates a string representation of the location for sharing.
String createLocationShareString(LatLng location) {
  // Format coordinates to a reasonable number of decimal places
  return "latlng:${location.latitude.toStringAsFixed(6)},${location.longitude.toStringAsFixed(6)}";
}

/// Opens the OS share sheet to share the provided string.
void shareLocationString(String locationString) {
  // You can customize the shared text
  Share.share("Check out this location: $locationString");
}

/// Saves the user's shared location to the Supabase database.
/// Returns true on success, false on failure.
Future<bool> saveSharedLocationToDb(LatLng location) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    print("Error saving shared location: User not logged in.");
    return false; // Indicate failure: User not authenticated
  }

  try {
    await Supabase.instance.client.from('shared_locations').insert({
      'sharer_user_id': user.id, // Use the authenticated user's ID
      'latitude': location.latitude,
      'longitude': location.longitude,
      // 'shared_at' will use the default value (now()) if defined in the DB table
    });
    print("Location saved to DB for user ${user.id}: ${location.latitude}, ${location.longitude}");
    return true; // Indicate success
  } on PostgrestException catch (error) {
    // Catch specific Supabase errors for better debugging
    print("Supabase error saving shared location: ${error.message}");
    print("Details: ${error.details}");
    print("Hint: ${error.hint}");
    return false; // Indicate failure
  } catch (error) {
    print("Generic error saving shared location: $error");
    return false; // Indicate failure
  }
}
