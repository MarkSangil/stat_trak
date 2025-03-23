import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'models/map_page_functions.dart' as mf;
import 'package:geolocator/geolocator.dart';
import 'package:stattrak/weather_service.dart';
import 'package:stattrak/widgets/appbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final String geoapifyApiKey = dotenv.env['GEOAPIFY_API_KEY'] ?? "default_value_if_missing";

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  LatLng? marker1;
  LatLng? marker2;
  List<mf.RouteInfo> routeAlternatives = [];

  WeatherData? _weatherData;
  double zoomLevel = 13.0;
  MapController mapController = MapController();

  TextEditingController searchController = TextEditingController();
  TextEditingController marker1Controller = TextEditingController();
  TextEditingController marker2Controller = TextEditingController();

  bool showMarkerDetails = false;
  String? _avatarUrl;
  final userId = Supabase.instance.client.auth.currentUser?.id;

  Future<void> _loadUserAvatar() async {
    if (userId == null) return;

    final response = await Supabase.instance.client
        .from('profiles')
        .select('avatar_url')
        .eq('id', userId!)
        .maybeSingle();

    if (response != null && mounted) {
      setState(() {
        _avatarUrl = response['avatar_url'];
      });
    }
  }

  Future<void> fetchAllRoutes() async {
    await mf.fetchAllRoutes(
      marker1: marker1,
      marker2: marker2,
      routeAlternatives: routeAlternatives,
      setStateCallback: () => setState(() {}),
      fitMapToRoutesCallback: () => mf.fitMapToRoutes(
        routeAlternatives: routeAlternatives,
        mapController: mapController,
      ),
      apiKey: geoapifyApiKey,
    );
  }

  Future<List<Map<String, dynamic>>> fetchLocations(String query) {
    return mf.fetchLocations(query, geoapifyApiKey);
  }

  void moveToLocation(LatLng location) {
    mf.moveToLocation(mapController, location, zoomLevel);
  }

  void addMarker(LatLng location) {
    print("Tapped map at: $location");
    setState(() {
      if (marker1 == null) {
        marker1 = location;
        marker1Controller.text = "${location.latitude}, ${location.longitude}";

        WeatherService.fetchDetailedForecast(
          lat: location.latitude,
          lon: location.longitude,
        ).then((forecast) {
          showDetailedForecastDialog(forecast);
        }).catchError((error) {
          print("Error fetching detailed forecast: $error");
        });
      } else if (marker2 == null) {
        marker2 = location;
        marker2Controller.text = "${location.latitude}, ${location.longitude}";
        fetchAllRoutes();
      } else {
        print("Both markers are already set.");
      }
    });
  }

  void showDetailedForecastDialog(OneCallForecast forecast) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Detailed Forecast"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Current Temp: ${forecast.currentTemp} °C"),
                Text("Current Desc: ${forecast.currentDescription}"),
                SizedBox(height: 16),
                Text("Daily Forecast:", style: TextStyle(fontWeight: FontWeight.bold)),
                for (var day in forecast.dailyForecasts) ...[
                  SizedBox(height: 8),
                  Text("Day Temp: ${day.dayTemp}°C"),
                  Text("Night Temp: ${day.nightTemp}°C"),
                  Text("Description: ${day.description}"),
                  Divider(),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Close"),
            ),
          ],
        );
      },
    );
  }

  void removeMarker(int markerNumber) {
    mf.removeMarker(
      markerNumber: markerNumber,
      clearMarker1: () {
        marker1 = null;
        marker1Controller.clear();
      },
      clearMarker2: () {
        marker2 = null;
        marker2Controller.clear();
      },
      routeAlternatives: routeAlternatives,
    );
    setState(() {});
  }

  Future<void> _onGetMyLocationPressed() async {
    final userLocation = await mf.getCurrentLocation();
    if (userLocation != null) {
      mapController.move(userLocation, zoomLevel);

      setState(() {
        if (marker1 == null) {
          marker1 = userLocation;
          marker1Controller.text = "${userLocation.latitude}, ${userLocation.longitude}";
        } else if (marker2 == null) {
          marker2 = userLocation;
          marker2Controller.text = "${userLocation.latitude}, ${userLocation.longitude}";
        } else {
          print("Both markers are already set.");
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location not available or permission denied.")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserAvatar();
  }

  @override
  Widget build(BuildContext context) {
    final routeColors = {
      'fast': Colors.blue,
      'short': Colors.green,
      'balanced': Colors.red,
    };

    return Scaffold(
      appBar: MyCustomAppBar(
        onNotificationPressed: () {
          debugPrint('Notification icon pressed!');
        },
        onGroupPressed: () {
          debugPrint('Group icon pressed!');
        },
        avatarUrl: _avatarUrl,
      ),
      bottomSheet: routeAlternatives.isNotEmpty
          ? Container(
        color: Colors.white,
        padding: EdgeInsets.all(8.0),
        height: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Routes Found:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: routeAlternatives.length,
                itemBuilder: (context, index) {
                  final route = routeAlternatives[index];
                  final distanceKm = (route.distanceMeters / 1000).toStringAsFixed(2);
                  final timeMin = (route.timeSeconds / 60).toStringAsFixed(1);
                  return ListTile(
                    leading: Container(
                      width: 12,
                      height: 12,
                      color: routeColors[route.type] ?? Colors.grey,
                    ),
                    title: Text(
                      "${route.type.toUpperCase()} route: $distanceKm km, $timeMin mins",
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      )
          : null,
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: LatLng(48.8566, 2.3522),
              initialZoom: zoomLevel,
              onTap: (tapPosition, latLng) => addMarker(latLng),
            ),
            children: [
              TileLayer(
                tileProvider: CancellableNetworkTileProvider(),
                urlTemplate: "https://tile.openstreetmap.de/{z}/{x}/{y}.png",
              ),
              if (routeAlternatives.isNotEmpty)
                PolylineLayer(
                  polylines: routeAlternatives.map((route) {
                    final color = routeColors[route.type] ?? Colors.black;
                    return Polyline(
                      points: route.points,
                      strokeWidth: 4.0,
                      color: color,
                    );
                  }).toList(),
                ),
              MarkerLayer(
                markers: [
                  if (marker1 != null)
                    Marker(
                      point: marker1!,
                      width: 40,
                      height: 40,
                      child: Icon(Icons.location_pin, color: Colors.red, size: 40),
                    ),
                  if (marker2 != null)
                    Marker(
                      point: marker2!,
                      width: 40,
                      height: 40,
                      child: Icon(Icons.location_pin, color: Colors.blue, size: 40),
                    ),
                ],
              ),
            ],
          ),

          // Marker Info Panel
          Positioned(
            top: 70,
            left: 15,
            right: 15,
            child: Card(
              elevation: 4,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                constraints: BoxConstraints(
                  minHeight: 60,
                  maxHeight: showMarkerDetails ? 220 : 60,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Marker Details", style: TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: Icon(showMarkerDetails ? Icons.expand_less : Icons.expand_more),
                              onPressed: () {
                                setState(() {
                                  showMarkerDetails = !showMarkerDetails;
                                });
                              },
                            ),
                          ],
                        ),
                        if (showMarkerDetails) ...[
                          SizedBox(height: 10),
                          TextField(
                            controller: marker1Controller,
                            readOnly: true,
                            decoration: InputDecoration(labelText: "Marker 1 (Lat, Lng)"),
                          ),
                          SizedBox(height: 10),
                          TextField(
                            controller: marker2Controller,
                            readOnly: true,
                            decoration: InputDecoration(labelText: "Marker 2 (Lat, Lng)"),
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (marker1 != null)
                                TextButton.icon(
                                  onPressed: () => removeMarker(1),
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  label: Text("Delete Marker 1", style: TextStyle(color: Colors.red)),
                                ),
                              if (marker2 != null)
                                TextButton.icon(
                                  onPressed: () => removeMarker(2),
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  label: Text("Delete Marker 2", style: TextStyle(color: Colors.red)),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Location Search Bar
          Positioned(
            top: 8,
            left: 15,
            right: 15,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: TypeAheadField<Map<String, dynamic>>(
                  textFieldConfiguration: TextFieldConfiguration(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: "Search for a location...",
                      border: InputBorder.none,
                    ),
                  ),
                  suggestionsCallback: fetchLocations,
                  itemBuilder: (context, suggestion) {
                    return ListTile(title: Text(suggestion['name']));
                  },
                  onSuggestionSelected: (suggestion) {
                    LatLng location = suggestion['latlng'];
                    moveToLocation(location);
                    searchController.text = suggestion['name'];
                    addMarker(location);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: routeAlternatives.isNotEmpty ? 160 : 20,
          right: 10,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: "currentLocation",
              onPressed: _onGetMyLocationPressed,
              child: Icon(Icons.my_location),
            ),
            SizedBox(height: 10),
            FloatingActionButton(
              heroTag: "zoomIn",
              mini: true,
              child: Icon(Icons.zoom_in),
              onPressed: () {
                setState(() {
                  zoomLevel += 1;
                  mapController.move(mapController.center, zoomLevel);
                });
              },
            ),
            SizedBox(height: 10),
            FloatingActionButton(
              heroTag: "zoomOut",
              mini: true,
              child: Icon(Icons.zoom_out),
              onPressed: () {
                setState(() {
                  zoomLevel -= 1;
                  mapController.move(mapController.center, zoomLevel);
                });
              },
            ),
            if (marker1 != null && marker2 != null) ...[
              SizedBox(height: 10),
              FloatingActionButton(
                heroTag: "routeBtn",
                onPressed: fetchAllRoutes,
                child: Icon(Icons.directions),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
