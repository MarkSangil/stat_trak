import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'map_page_functions.dart' as mf;

const String geoapifyApiKey = "YOUR_GEOAPIFY_API_KEY";

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  LatLng? marker1;
  LatLng? marker2;
  List<mf.RouteInfo> routeAlternatives = [];

  double zoomLevel = 13.0;
  MapController mapController = MapController();

  // Controllers for search and marker details text fields.
  TextEditingController searchController = TextEditingController();
  TextEditingController marker1Controller = TextEditingController();
  TextEditingController marker2Controller = TextEditingController();

  // Toggle for active/inactive state of marker details panel.
  bool showMarkerDetails = false;

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
    setState(() {
      if (marker1 == null) {
        marker1 = mf.addMarker(
          marker: marker1,
          location: location,
          updateTextField: (val) => marker1Controller.text = val,
        );
      } else if (marker2 == null) {
        marker2 = mf.addMarker(
          marker: marker2,
          location: location,
          updateTextField: (val) => marker2Controller.text = val,
        );
        fetchAllRoutes();
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final routeColors = {
      'fast': Colors.blue,
      'short': Colors.green,
      'balanced': Colors.red,
    };

    return Scaffold(
      appBar: AppBar(title: Text("Map with Multiple Routes")),
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
                  final distanceKm =
                  (route.distanceMeters / 1000).toStringAsFixed(2);
                  final timeMin =
                  (route.timeSeconds / 60).toStringAsFixed(1);
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
          /// 1) Flutter Map
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
                      child: Icon(Icons.location_pin, color: Colors.red, size: 40),
                    ),
                  if (marker2 != null)
                    Marker(
                      point: marker2!,
                      child: Icon(Icons.location_pin, color: Colors.blue, size: 40),
                    ),
                ],
              ),
            ],
          ),

          /// 2) Collapsible Marker Details Panel
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
                        // Title row with expand/collapse icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Marker Details",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: Icon(
                                showMarkerDetails
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                              onPressed: () {
                                setState(() {
                                  showMarkerDetails = !showMarkerDetails;
                                });
                              },
                            ),
                          ],
                        ),
                        // Show marker details only if expanded
                        if (showMarkerDetails) ...[
                          SizedBox(height: 10),
                          TextField(
                            controller: marker1Controller,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: "Marker 1 (Lat, Lng)",
                            ),
                          ),
                          SizedBox(height: 10),
                          TextField(
                            controller: marker2Controller,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: "Marker 2 (Lat, Lng)",
                            ),
                          ),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (marker1 != null)
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => removeMarker(1),
                                ),
                              if (marker2 != null)
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => removeMarker(2),
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

          /// 3) Search Bar (on top so suggestions appear above other widgets)
          Positioned(
            top: 10,
            left: 15,
            right: 15,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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
                  },
                ),
              ),
            ),
          ),

          /// 4) Zoom Controls
          Positioned(
            bottom: 100,
            right: 20,
            child: Column(
              children: [
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
              ],
            ),
          ),
        ],
      ),

      /// Directions FAB appears if both markers exist.
      floatingActionButton: (marker1 != null && marker2 != null)
          ? FloatingActionButton(
        child: Icon(Icons.directions),
        onPressed: fetchAllRoutes,
      )
          : null,
    );
  }
}

/// Legend widget remains the same
class _LegendEntry extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendEntry({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 14, height: 14, color: color),
        SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}
