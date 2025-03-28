import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:stattrak/models/map_page_functions.dart' as mf;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

class SharedRoutePage extends StatefulWidget {
  final String routeId;

  const SharedRoutePage({Key? key, required this.routeId}) : super(key: key);

  @override
  State<SharedRoutePage> createState() => _SharedRoutePageState();
}

class _SharedRoutePageState extends State<SharedRoutePage> {
  final MapController _mapController = MapController();

  LatLng? _startMarker;
  LatLng? _endMarker;
  bool _isLoading = true;
  String? _errorMsg;

  // Holds the fetched route alternatives from the routing API.
  List<mf.RouteInfo> _routeAlternatives = [];

  @override
  void initState() {
    super.initState();
    _fetchRouteData();
  }

  // Fetch the saved start/end coordinates from Supabase,
  // then re-fetch the route geometry using fetchAllRoutesForTwoPoints.
  Future<void> _fetchRouteData() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('shared_routes')
          .select('start_lat, start_lng, end_lat, end_lng')
          .eq('id', widget.routeId)
          .maybeSingle();

      if (response == null) {
        setState(() {
          _errorMsg = "No shared route found for ID: ${widget.routeId}";
          _isLoading = false;
        });
        return;
      }

      final startLat = response['start_lat'] as double?;
      final startLng = response['start_lng'] as double?;
      final endLat = response['end_lat'] as double?;
      final endLng = response['end_lng'] as double?;

      if (startLat == null || startLng == null || endLat == null || endLng == null) {
        setState(() {
          _errorMsg = "Invalid or missing coordinates in DB for route ID: ${widget.routeId}";
          _isLoading = false;
        });
        return;
      }

      _startMarker = LatLng(startLat, startLng);
      _endMarker = LatLng(endLat, endLng);

      // Re-fetch the route geometry from your routing API.
      final fetchedRoutes = await mf.fetchAllRoutesForTwoPoints(
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
        apiKey: dotenv.env['GEOAPIFY_API_KEY'] ?? '',
      );

      setState(() {
        _routeAlternatives = fetchedRoutes;
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      setState(() {
        _errorMsg = "Supabase error: ${error.message}";
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMsg = "Unexpected error: $error";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Colors for different route types.
    final routeColors = {
      'balanced': Colors.blue.withOpacity(0.8),
      'short': Colors.green.withOpacity(0.8),
      'less_maneuvers': Colors.purple.withOpacity(0.8),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text("Shared Route"),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMsg != null
          ? Center(child: Text(_errorMsg!))
          : (_startMarker == null || _endMarker == null)
          ? Center(child: Text("Coordinates not found."))
          : FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          // Ensure the map starts at the first/starting endpoint
          center: _startMarker!,
          zoom: 13.0,
          // Optional: disable rotation if you want
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            tileProvider: CancellableNetworkTileProvider(),
          ),
          // Display the route polylines.
          if (_routeAlternatives.isNotEmpty)
            PolylineLayer(
              polylines: _routeAlternatives.map((route) {
                final color = routeColors[route.type] ?? Colors.red;
                return Polyline(
                  points: route.points,
                  strokeWidth: 5.0,
                  color: color,
                  borderStrokeWidth: 1.0,
                  borderColor: Colors.white.withOpacity(0.6),
                );
              }).toList(),
            ),
          // Markers for start and end points.
          MarkerLayer(
            markers: [
              Marker(
                point: _startMarker!,
                width: 40,
                height: 40,
                child: Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40,
                ),
              ),
              Marker(
                point: _endMarker!,
                width: 40,
                height: 40,
                child: Icon(
                  Icons.location_pin,
                  color: Colors.blue,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
      // Add floating action buttons for Zoom In/Out
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zoom In
          FloatingActionButton(
            heroTag: "zoomIn",
            mini: false, // or true for a smaller button
            onPressed: () {
              final currentZoom = _mapController.zoom;
              // Increase zoom by 1, or clamp if needed
              _mapController.move(_mapController.center, currentZoom + 1);
            },
            child: Icon(Icons.add),
          ),
          SizedBox(height: 8),
          // Zoom Out
          FloatingActionButton(
            heroTag: "zoomOut",
            mini: false,
            onPressed: () {
              final currentZoom = _mapController.zoom;
              // Decrease zoom by 1, or clamp if needed
              _mapController.move(_mapController.center, currentZoom - 1);
            },
            child: Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}
