import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart'; // Needed for callbacks like Function(String)
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';

// --- Data Models ---

/// Holds route data including geometry and metadata.
class RouteInfo {
  final String type; // e.g., 'balanced', 'short'
  final List<LatLng> points; // Route geometry
  final double distanceMeters;
  final double timeSeconds;

  RouteInfo({
    required this.type,
    required this.points,
    required this.distanceMeters,
    required this.timeSeconds,
  });
}

/// Holds calculated progress details.
class RouteProgress {
  final double coveredDistanceMeters;
  final double percentage; // 0.0 to 100.0

  RouteProgress({
    required this.coveredDistanceMeters,
    required this.percentage,
  });
}


// --- Internal Helper for API Calls ---

/// Fetches a specific route type from Geoapify. (Internal use)
Future<RouteInfo?> _fetchRouteByTypeInternal({
  required LatLng marker1,
  required LatLng marker2,
  required String type, // e.g., 'balanced', 'short'
  required String mode, // e.g., 'drive', 'walk'
  required String apiKey,
}) async {
  // Basic validation
  if (apiKey.isEmpty || apiKey == "YOUR_GEOAPIFY_API_KEY") {
    print("Geoapify API Key is missing or invalid.");
    return null;
  }

  final url = "https://api.geoapify.com/v1/routing?"
      "waypoints=${marker1.latitude},${marker1.longitude}|${marker2.latitude},${marker2.longitude}"
      "&mode=$mode"
      "&type=$type"
      "&format=geojson" // Ensure GeoJSON format
      "&apiKey=$apiKey";

  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['features'] == null || decoded['features'].isEmpty) {
        print("No features found in Geoapify response for type $type, mode $mode.");
        return null;
      }

      final feature = decoded['features'][0];
      final geometry = feature['geometry'];
      if (geometry == null || geometry['coordinates'] == null) {
        print("No coordinates found for type $type, mode $mode.");
        return null;
      }

      List<LatLng> points = [];
      // Geoapify returns coordinates as [longitude, latitude]
      if (geometry['type'] == 'MultiLineString') {
        final List<dynamic> multiLineCoordinates = geometry['coordinates'];
        points = multiLineCoordinates.expand((line) {
          return (line as List).map((coord) {
            if (coord is List && coord.length >= 2 && coord[0] is num && coord[1] is num) {
              return LatLng(coord[1].toDouble(), coord[0].toDouble()); // Lat, Lng order for latlong2
            }
            return null;
          });
        }).whereType<LatLng>().toList();
      } else if (geometry['type'] == 'LineString') {
        final List<dynamic> lineCoordinates = geometry['coordinates'];
        points = lineCoordinates.map((coord) {
          if (coord is List && coord.length >= 2 && coord[0] is num && coord[1] is num) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble()); // Lat, Lng order for latlong2
          }
          return null;
        }).whereType<LatLng>().toList();
      }


      if (points.isEmpty) {
        print("Parsed points list is empty for type $type, mode $mode.");
        return null;
      }

      final props = feature['properties'];
      double distanceMeters = (props['distance'] ?? 0.0).toDouble();
      double timeSeconds = (props['time'] ?? 0.0).toDouble();

      return RouteInfo(
        type: type,
        points: points,
        distanceMeters: distanceMeters,
        timeSeconds: timeSeconds,
      );
    } else {
      print("Error fetching route type $type, mode $mode: ${response.statusCode} ${response.body}");
      // Provide more specific error message based on status code if possible
      return null;
    }
  } catch (e) {
    print("Exception fetching route type $type, mode $mode: $e");
    return null;
  }
}

// --- Public Logic Functions ---

// == Location Search ==

/// Fetches location suggestions from Geoapify Geocoding API.
Future<List<Map<String, dynamic>>> fetchLocations(String query, String apiKey) async {
  // Basic validation
  if (apiKey.isEmpty || apiKey == "YOUR_GEOAPIFY_API_KEY") {
    print("Geoapify API Key is missing or invalid for location search.");
    return [];
  }
  if (query.length < 3) return []; // Avoid querying for very short strings

  final String url = 'https://api.geoapify.com/v1/geocode/search?text=${Uri.encodeComponent(query)}&apiKey=$apiKey&limit=5';

  try {
    final http.Response response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      print('Failed to fetch locations: HTTP ${response.statusCode}');
      return [];
    }

    final Map<String, dynamic> data = json.decode(response.body);

    if (data['features'] == null || data['features'] is! List) {
      return [];
    }

    return List<Map<String, dynamic>>.from((data['features'] as List).map((feature) {
      try {
        final properties = feature['properties'] as Map<String, dynamic>;
        final geometry = feature['geometry'] as Map<String, dynamic>;
        final List<dynamic> coordinates = geometry['coordinates'] as List<dynamic>;
        // GeoJSON format is [longitude, latitude]
        final double longitude = (coordinates[0] as num).toDouble();
        final double latitude = (coordinates[1] as num).toDouble();
        final String name = properties['formatted'] ?? 'Unknown location';

        return {
          'name': name,
          'latlng': LatLng(latitude, longitude), // LatLng(latitude, longitude)
          'address': name,
        };
      } catch (e) {
        print("Error processing location feature: $e");
        return null;
      }
    }).where((item) => item != null));
  } catch (e) {
    print("Error in fetchLocations: $e");
    return [];
  }
}


// == Route Fetching ==

/// Fetches route alternatives and updates the provided list via callbacks.
Future<void> fetchAndSetRoutes({
  required LatLng marker1,
  required LatLng marker2,
  required List<RouteInfo> routeListToUpdate, // Pass the state list to modify
  required Function updateStateCallback,    // Callback to trigger setState in UI
  required Function fitMapCallback,         // Callback to trigger map fitting in UI
  required String apiKey,
  required Function(String) showInfoMessage, // Callback for status messages
  required Function(String) showErrorMessage, // Callback for error messages
  String mode = 'drive', // Default to drive
}) async {
  if (apiKey.isEmpty || apiKey == "YOUR_GEOAPIFY_API_KEY") {
    showErrorMessage("Cannot fetch routes: Geoapify API Key is missing.");
    return;
  }

  showInfoMessage("Finding routes...");
  routeListToUpdate.clear();
  updateStateCallback(); // Show routes cleared immediately

  // Define types based on mode? For now, keep standard driving types.
  final routeTypes = ['balanced', 'short', 'less_maneuvers'];
  List<Future<RouteInfo?>> futures = [];

  for (final type in routeTypes) {
    futures.add(_fetchRouteByTypeInternal(
      marker1: marker1,
      marker2: marker2,
      type: type,
      mode: mode,
      apiKey: apiKey,
    ));
  }

  try {
    final results = await Future.wait(futures);
    routeListToUpdate.addAll(results.whereType<RouteInfo>()); // Add non-null results

    updateStateCallback(); // Update UI with fetched routes

    if (routeListToUpdate.isNotEmpty) {
      fitMapCallback();
    } else {
      showErrorMessage("No routes found between markers.");
    }
  } catch (e) {
    print("Error waiting for route futures: $e");
    showErrorMessage("An error occurred while fetching routes.");
    updateStateCallback(); // Ensure UI updates even on error
  }
}

// == User Profile ==

/// Fetches the user's avatar URL from Supabase.
Future<String?> fetchUserAvatar(String userId) async {
  try {
    final response = await Supabase.instance.client
        .from('profiles')
        .select('avatar_url')
        .eq('id', userId)
        .maybeSingle();
    return response?['avatar_url'] as String?;
  } catch (error) { // Catch generic errors too
    print("Error loading avatar: $error");
    return null;
  }
}

// == Map Page Marker/Interaction Logic ==

/// Handles logic for placing markers on the main map page.
void handleMapTap({
  required LatLng location,
  required LatLng? currentMarker1,
  required LatLng? currentMarker2,
  required Function(LatLng) setMarker1, // Callback to set marker1 state in UI
  required Function(LatLng) setMarker2, // Callback to set marker2 state in UI
  required Function(LatLng) triggerWeatherFetch, // Callback to start weather fetch
  required Function triggerRouteFetch,     // Callback to start route fetch
  required Function(String) showInfoMessage, // Callback for messages
}) {
  if (currentMarker1 == null) {
    setMarker1(location);
    triggerWeatherFetch(location);
  } else if (currentMarker2 == null) {
    setMarker2(location);
    triggerRouteFetch(); // Fetch routes when second marker is set
  } else {
    showInfoMessage("Both markers are set. Remove one to add a new location.");
  }
}

/// Handles logic for removing a marker on the main map page.
void handleRemoveMarker({
  required int markerNumber,
  required Function clearMarker1State, // Callback to clear marker1 UI state
  required Function clearMarker2State, // Callback to clear marker2 UI state
  required List<RouteInfo> routesToClear, // Pass the state list to be cleared
}) {
  if (markerNumber == 1) {
    clearMarker1State();
  } else if (markerNumber == 2) {
    clearMarker2State();
  }
  if (routesToClear.isNotEmpty) {
    routesToClear.clear();
    // The calling UI MUST call setState after this function to reflect cleared routes
  }
}

// == Map Utilities ==

/// Moves the map view using the provided MapController.
void moveToLocation(MapController mapController, LatLng location, double zoom) {
  try {
    mapController.move(location, zoom);
  } catch (e) {
    print("Error moving map: $e");
  }
}

/// Adjusts map camera to fit all points from the provided routes.
void fitMapToRoutes({
  required List<RouteInfo> routeAlternatives,
  required MapController mapController,
}) {
  if (routeAlternatives.isEmpty) return;
  final allPoints = routeAlternatives.expand((r) => r.points).toList();
  if (allPoints.isEmpty) return;

  try {
    final bounds = LatLngBounds.fromPoints(allPoints);
    mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: EdgeInsets.all(50.0), // Padding around routes
      ),
    );
  } catch (e) {
    print("Error fitting map to bounds: $e");
  }
}


// == Device Location ==

/// Gets the current device location once. Handles permissions.
Future<LatLng?> getCurrentLocation(Function(String)? showErrorMessage) async {
  bool serviceEnabled;
  LocationPermission permission;

  try {
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      showErrorMessage?.call("Location services are disabled.");
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        showErrorMessage?.call("Location permissions are denied.");
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      showErrorMessage?.call("Location permissions permanently denied. Enable in settings.");
      // Consider Geolocator.openAppSettings(); or Geolocator.openLocationSettings();
      return null;
    }

    // Permissions granted, get position
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation, // High accuracy for tracking
      // Consider adding timeLimit if needed
    );
    return LatLng(position.latitude, position.longitude);
  } catch (e) {
    print("Error getting current location: $e");
    showErrorMessage?.call("Could not get current location.");
    return null;
  }
}


/// Handles the "Get My Location" action on the main map page.
Future<void> handleGetMyLocation({
  required LatLng? currentMarker1,
  required LatLng? currentMarker2,
  required Function(LatLng, {double? targetZoom}) moveMapCallback, // To move map
  required Function(LatLng) setMarker1, // Callback to set marker1 state
  required Function(LatLng) setMarker2, // Callback to set marker2 state
  required Function triggerRouteFetch,   // Callback to start route fetch
  required Function(String) showInfoMessage, // Callback for info messages
  required Function(String) showErrorMessage, // Callback for error messages
}) async {
  showInfoMessage("Getting your location...");
  final LatLng? userLocation = await getCurrentLocation(showErrorMessage);

  if (userLocation != null) {
    moveMapCallback(userLocation, targetZoom: 15.0); // Move map first

    // Now update markers based on current state
    if (currentMarker1 == null) {
      setMarker1(userLocation);
    } else if (currentMarker2 == null) {
      setMarker2(userLocation);
      triggerRouteFetch(); // Fetch routes automatically
    } else {
      showInfoMessage("Both markers already set. Location centered.");
    }
  }
  // Error messages handled within getCurrentLocation via showErrorMessage callback
}

// == Route Tracking Logic ==

/// Calculates route progress based on current location and route points.
RouteProgress calculateRouteProgress({
  required LatLng currentLocation,
  required List<LatLng> routePoints,
  required double totalRouteDistanceMeters,
}) {
  if (routePoints.isEmpty || totalRouteDistanceMeters <= 0) {
    return RouteProgress(coveredDistanceMeters: 0, percentage: 0);
  }

  double minDistanceToRoute = double.infinity;
  int closestSegmentStartIndex = 0;

  // Find the closest point/segment on the route to the current location
  for (int i = 0; i < routePoints.length - 1; i++) {
    // Simple distance to start point of segment - more complex projection needed for accuracy
    final dist = Geolocator.distanceBetween(
        currentLocation.latitude, currentLocation.longitude,
        routePoints[i].latitude, routePoints[i].longitude
    );
    if (dist < minDistanceToRoute) {
      minDistanceToRoute = dist;
      closestSegmentStartIndex = i;
    }
  }
  // Also check the last point
  final distToLast = Geolocator.distanceBetween(
      currentLocation.latitude, currentLocation.longitude,
      routePoints.last.latitude, routePoints.last.longitude
  );
  if (distToLast < minDistanceToRoute) {
    minDistanceToRoute = distToLast;
    closestSegmentStartIndex = routePoints.length - 1; // Treat as closest to the end
  }


  // Calculate distance covered along the route up to the start of the closest segment
  double coveredDistance = 0;
  for (int i = 0; i < closestSegmentStartIndex && i < routePoints.length - 1; i++) {
    final p1 = routePoints[i];
    final p2 = routePoints[i + 1];
    coveredDistance += Geolocator.distanceBetween(p1.latitude, p1.longitude, p2.latitude, p2.longitude);
  }

  // Basic progress calculation - can be improved with projection onto the segment
  double percentage = (coveredDistance / totalRouteDistanceMeters * 100).clamp(0.0, 100.0);

  return RouteProgress(
    coveredDistanceMeters: coveredDistance,
    percentage: percentage,
  );
}

/// Starts listening for location updates (e.g., for tracking).
/// Returns a StreamSubscription that should be cancelled when done.
StreamSubscription<Position>? startLocationUpdatesStream({
  required Function(LatLng) onLocationUpdate,
  required Function(String) onError,
  LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
  int distanceFilter = 10, // Update every 10 meters
}) {
  // Ensure permissions are handled before starting the stream (caller responsibility ideally)
  try {
    final LocationSettings locationSettings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
        onLocationUpdate(LatLng(position.latitude, position.longitude));
      },
      onError: (error) {
        print("Error in location stream: $error");
        onError("Location updates failed: $error");
        // Consider stopping the stream or retrying based on error type
      },
      cancelOnError: false, // Keep listening even after an error if desired
    );
  } catch (e) {
    print("Could not start location stream: $e");
    onError("Failed to start location tracking.");
    return null;
  }
}

Future<List<Map<String, dynamic>>> fetchFriendList(
    String userId,
    Function(String) showErrorMessage, // Callback for showing errors in UI
    ) async {
  print("Fetching friend list for user: $userId");
  try {
    // 1. Fetch friendship entries where the user is involved and status is 'accepted'
    final friendshipResponse = await Supabase.instance.client
        .from('user_friendships')
        .select('user_id, friend_id') // Select both IDs to determine the friend
        .or('user_id.eq.$userId,friend_id.eq.$userId') // User is one or the other
        .eq('status', 'accepted'); // Status must be accepted

    // Error handling for the response itself (though Supabase client usually throws)
    if (friendshipResponse == null) {
      throw Exception("Received null response fetching friendships.");
    }

    // Cast safely, assuming Supabase returns List<dynamic> which contains maps
    final friendships = (friendshipResponse as List<dynamic>).cast<Map<String, dynamic>>();

    if (friendships.isEmpty) {
      print("No accepted friendships found for user $userId.");
      return []; // Return empty list if no friendships
    }

    // 2. Extract the IDs of the friends (the ID that is *not* the current user's ID)
    final friendIds = friendships
        .map<String?>((friendship) {
      // If user_id is the current user, friend_id is the friend, otherwise user_id is the friend
      return (friendship['user_id'] == userId)
          ? friendship['friend_id'] as String?
          : friendship['user_id'] as String?;
    })
        .where((id) => id != null && id != userId) // Filter out nulls and the user themselves
        .toSet() // Ensure unique IDs
        .toList();

    if (friendIds.isEmpty) {
      print("Friend IDs list is empty after filtering.");
      return [];
    }

    print("Found friend IDs: $friendIds");

    // 3. Fetch the profiles for these friend IDs
    final profileResponse = await Supabase.instance.client
        .from('profiles')
        .select('id, username, full_name, avatar_url') // Select fields needed for display
        .inFilter('id', friendIds); // Use 'in_' filter for Supabase v2+

    if (profileResponse == null) {
      throw Exception("Received null response fetching profiles.");
    }

    final profiles = (profileResponse as List<dynamic>).cast<Map<String, dynamic>>();
    print("Fetched ${profiles.length} friend profiles.");
    return profiles;

  } on PostgrestException catch (error) {
    // Handle known Supabase errors (RLS, constraints, etc.)
    print("Supabase Postgrest error fetching friends: ${error.message}");
    showErrorMessage("Error fetching friends list. (${error.code ?? 'Supabase Error'})");
    return []; // Return empty list on error
  } catch (error) {
    // Handle other unexpected errors (network, parsing, etc.)
    print("Unexpected error fetching friends: $error");
    showErrorMessage("An unexpected error occurred while fetching friends.");
    return []; // Return empty list on error
  }
}


/// Inserts the shared route details into the Supabase 'shared_routes' table.
/// Returns true on success, false on failure.
Future<bool> shareRouteWithFriendDb({
  required String currentUserId,
  required String friendId,
  required LatLng marker1, // Start point
  required LatLng marker2, // End point
  required Function(String) showSuccessMessage, // Callback for success UI feedback
  required Function(String) showErrorMessage,   // Callback for error UI feedback
}) async {
  print("Attempting DB insert to share route from $currentUserId to $friendId...");

  try {
    // Perform the insert operation.
    // Ensure your 'shared_routes' table has RLS policies allowing authenticated users
    // to insert rows where 'owner_user_id' matches their own ID.
    await Supabase.instance.client
        .from('shared_routes') // *** ENSURE THIS TABLE EXISTS with correct RLS ***
        .insert({
      'owner_user_id': currentUserId,
      'friend_user_id': friendId,
      'start_lat': marker1.latitude,
      'start_lng': marker1.longitude,
      'end_lat': marker2.latitude,
      'end_lng': marker2.longitude,
      // 'route_name': 'Shared Route', // Optional: Add a name?
      // 'created_at' should ideally use the DB default value (e.g., now())
    });

    // If the insert doesn't throw an error, assume success
    print("Route shared successfully in DB with friend $friendId");
    showSuccessMessage("Route shared successfully!");
    return true; // Indicate success

  } on PostgrestException catch (error) {
    // Catch specific Supabase errors (e.g., RLS violation, constraint violation)
    print("Supabase Postgrest error sharing route: ${error.message}");
    // Provide a slightly more user-friendly message if possible
    String uiError = "Failed to share route. (${error.code ?? 'DB Error'})";
    if (error.message.contains("violates row-level security policy")) {
      uiError = "Failed to share route. (Permission denied)";
    } else if (error.message.contains("violates foreign key constraint")) {
      uiError = "Failed to share route. (Invalid friend ID)";
    }
    showErrorMessage(uiError);
    return false; // Indicate failure
  } catch (e) {
    // Catch any other generic errors (e.g., network issues)
    print("Generic exception sharing route: $e");
    showErrorMessage("An error occurred while sharing route.");
    return false; // Indicate failure
  }
}

Future<List<RouteInfo>> fetchAllRoutesForTwoPoints({
  required double startLat,
  required double startLng,
  required double endLat,
  required double endLng,
  required String apiKey,
  String mode = 'drive', // Allow specifying mode (drive, walk, bicycle)
  Function(String)? showErrorMessage, // Optional callback for errors
}) async {
  // Basic validation
  if (apiKey.isEmpty || apiKey == "YOUR_GEOAPIFY_API_KEY") {
    print("Geoapify API Key is missing or invalid.");
    showErrorMessage?.call("API Key is missing, cannot fetch route geometry.");
    return []; // Return empty list if no key
  }

  print("Fetching route geometry for shared route...");

  // Create LatLng objects needed by the internal fetcher
  LatLng marker1 = LatLng(startLat, startLng);
  LatLng marker2 = LatLng(endLat, endLng);

  // Use relevant route types based on mode if necessary, keeping driving for now
  final routeTypes = ['balanced', 'short', 'less_maneuvers'];
  List<RouteInfo> routes = [];
  List<Future<RouteInfo?>> futures = [];

  // Fetch route info for each type concurrently
  for (String type in routeTypes) {
    futures.add(_fetchRouteByTypeInternal( // Use the internal helper
      marker1: marker1,
      marker2: marker2,
      type: type,
      mode: mode,
      apiKey: apiKey,
    ));
  }

  try {
    final results = await Future.wait(futures);
    // Filter out null results and add valid routes to the list
    routes.addAll(results.whereType<RouteInfo>());

    print("Fetched ${routes.length} route geometries.");
    if (routes.isEmpty) {
      showErrorMessage?.call("Could not fetch route geometry between the points.");
    }
    return routes; // Return the list of fetched routes

  } catch (e) {
    print("Error fetching routes for two points: $e");
    showErrorMessage?.call("An error occurred while fetching route geometry.");
    return []; // Return empty list on error
  }
}

