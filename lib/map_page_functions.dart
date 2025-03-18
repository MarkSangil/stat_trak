import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';


/// A model to hold route data. You can also keep this in map_page.dart if preferred.
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

/// Fetch a route for a given 'type' (fast, short, balanced) from Geoapify.
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
    return null;
  }
}

/// Fetch multiple routes (fast, short, balanced) and store them in [routeAlternatives].
Future<void> fetchAllRoutes({
  required LatLng? marker1,
  required LatLng? marker2,
  required List<RouteInfo> routeAlternatives,
  required Function setStateCallback,
  required Function fitMapToRoutesCallback,
  required String apiKey,
}) async {
  if (marker1 == null || marker2 == null) return;

  final routeTypes = ['fast', 'short', 'balanced'];
  routeAlternatives.clear();

  for (final type in routeTypes) {
    final route = await fetchRouteByType(
      marker1: marker1,
      marker2: marker2,
      type: type,
      apiKey: apiKey,
    );
    if (route != null) {
      routeAlternatives.add(route);
    }
  }

  // Trigger a rebuild in your widget
  setStateCallback();
  // Auto-fit map after new polylines
  fitMapToRoutesCallback();
}

/// Geocoding to find locations by [query].
Future<List<Map<String, dynamic>>> fetchLocations(
    String query, String apiKey) async {
  final url =
      "https://api.geoapify.com/v1/geocode/search?text=$query&apiKey=$apiKey";
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final decoded = json.decode(response.body);
    List<Map<String, dynamic>> locations =
    decoded['features'].map<Map<String, dynamic>>((feature) {
      return {
        'name': feature['properties']['formatted'],
        'latlng': LatLng(
          feature['geometry']['coordinates'][1],
          feature['geometry']['coordinates'][0],
        )
      };
    }).toList();

    return locations;
  } else {
    throw Exception("Failed to fetch locations");
  }
}

/// Move map to a given [location].
void moveToLocation(MapController mapController, LatLng location, double zoom) {
  mapController.move(location, zoom);
}

/// Add a marker ([whichMarker] = 1 or 2). Returns updated [marker1] or [marker2].
LatLng? addMarker({
  required LatLng? marker,
  required LatLng location,
  required Function(String) updateTextField,
}) {
  if (marker == null) {
    updateTextField("${location.latitude}, ${location.longitude}");
    return location;
  }
  // If marker was not null, we just return it unchanged
  return marker;
}

/// Remove a marker. Clears the text field.
void removeMarker({
  required int markerNumber,
  required Function clearMarker1,
  required Function clearMarker2,
  required List<RouteInfo> routeAlternatives,
}) {
  if (markerNumber == 1) {
    clearMarker1();
  } else {
    clearMarker2();
  }
  routeAlternatives.clear();
}

/// Fit the map to show all polylines in [routeAlternatives].
void fitMapToRoutes({
  required List<RouteInfo> routeAlternatives,
  required MapController mapController,
}) {
  if (routeAlternatives.isEmpty) return;
  final allPoints = routeAlternatives.expand((r) => r.points).toList();
  if (allPoints.isEmpty) return;

  double minLat = double.infinity, maxLat = -double.infinity;
  double minLng = double.infinity, maxLng = -double.infinity;

  for (var p in allPoints) {
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
    if (p.longitude < minLng) minLng = p.longitude;
    if (p.longitude > maxLng) maxLng = p.longitude;
  }

  final centerLat = (minLat + maxLat) / 2;
  final centerLng = (minLng + maxLng) / 2;

  double latDelta = (maxLat - minLat).abs();
  double lngDelta = (maxLng - minLng).abs();
  double largestDelta = (latDelta > lngDelta) ? latDelta : lngDelta;
  double newZoom = 11;

  if (largestDelta < 0.1) {
    newZoom = 13;
  } else if (largestDelta < 0.5) {
    newZoom = 11.5;
  } else if (largestDelta < 1.0) {
    newZoom = 10.5;
  } else {
    newZoom = 9;
  }

  mapController.move(LatLng(centerLat, centerLng), newZoom);
}

Future<LatLng?> getCurrentLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return null;
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return null;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return null;
  }

  Position position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
  return LatLng(position.latitude, position.longitude);
}