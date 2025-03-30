import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'models/map_page_functions.dart' as mf; // Ensure this path is correct
import 'package:geolocator/geolocator.dart';
import 'package:stattrak/weather_service.dart';
import 'package:stattrak/widgets/appbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// If needed, set a default or handle missing
final String geoapifyApiKey = dotenv.env['GEOAPIFY_API_KEY'] ?? "YOUR_GEOAPIFY_API_KEY";

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  LatLng? marker1;
  LatLng? marker2;
  List<mf.RouteInfo> routeAlternatives = [];

  double zoomLevel = 13.0;
  final MapController mapController = MapController();
  TextEditingController searchController = TextEditingController();
  TextEditingController marker1Controller = TextEditingController();
  TextEditingController marker2Controller = TextEditingController();

  bool showMarkerDetails = false;
  String? _avatarUrl;
  final userId = Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadUserAvatar();
  }

  @override
  void dispose() {
    searchController.dispose();
    marker1Controller.dispose();
    marker2Controller.dispose();
    mapController.dispose();
    super.dispose();
  }

  // ---------------------------
  // Load user avatar from 'profiles'
  // ---------------------------
  Future<void> _loadUserAvatar() async {
    if (userId == null) {
      print("Cannot load avatar: User not logged in.");
      return;
    }
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('avatar_url')
          .eq('id', userId!)
          .maybeSingle();

      if (mounted && response != null) {
        setState(() {
          _avatarUrl = response['avatar_url'];
        });
      }
    } on PostgrestException catch (error) {
      print("Supabase error loading avatar: ${error.message}");
    } catch (error) {
      print("Unexpected error loading avatar: $error");
    }
  }

  // Show a dialog with weather details for marker1
  void showDetailedForecastDialog(OneCallForecast forecast) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Detailed Forecast"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Current Temp: ${forecast.currentTemp?.toStringAsFixed(1) ?? 'N/A'} °C"),
                Text("Description: ${forecast.currentDescription ?? 'N/A'}"),
                SizedBox(height: 16),
                Text("Daily Forecast:", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                if (forecast.dailyForecasts == null || forecast.dailyForecasts!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text("No daily forecast available."),
                  )
                else
                  ...forecast.dailyForecasts!.map((day) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Day: ${day.dayTemp?.toStringAsFixed(1) ?? 'N/A'}°C, Night: ${day.nightTemp?.toStringAsFixed(1) ?? 'N/A'}°C"),
                        Text("Desc: ${day.description ?? 'N/A'}"),
                        Divider(height: 10, thickness: 0.5),
                      ],
                    ),
                  )).toList(),
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

  // Search location logic
  Future<List<Map<String, dynamic>>> fetchLocations(String query) async {
    try {
      final String url = 'https://api.geoapify.com/v1/geocode/search?text=$query&apiKey=$geoapifyApiKey';

      final http.Response response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch locations: HTTP ${response.statusCode}');
      }

      final Map<String, dynamic> data = json.decode(response.body);

      if (data['features'] == null || !(data['features'] is List)) {
        return [];
      }

      return (data['features'] as List).map<Map<String, dynamic>>((feature) {
        final properties = feature['properties'] as Map<String, dynamic>;
        final geometry = feature['geometry'] as Map<String, dynamic>;

        // Extract coordinates from geometry
        final List<dynamic> coordinates = geometry['coordinates'] as List<dynamic>;
        final double longitude = coordinates[0] as double;
        final double latitude = coordinates[1] as double;

        // Create formatted address from components
        final String name = properties['formatted'] ?? 'Unknown location';

        // Return a properly structured Map without any nullable types
        return {
          'name': name,
          'latlng': LatLng(latitude, longitude),
          'address': name
        };
      }).toList();
    } catch (e) {
      print("Error fetching locations: $e");
      throw Exception('Failed to fetch locations: $e');
    }
  }

  // Move the map to a given location
  void moveToLocation(LatLng location, {double? targetZoom}) {
    mf.moveToLocation(mapController, location, targetZoom ?? zoomLevel);
  }

  // Add a marker on tap
  void addMarker(LatLng location) {
    if (!mounted) return;
    setState(() {
      final coordsText = "${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}";
      if (marker1 == null) {
        marker1 = location;
        marker1Controller.text = coordsText;

        // Optionally fetch weather for marker1
        WeatherService.fetchDetailedForecast(
          lat: location.latitude,
          lon: location.longitude,
        ).then((forecast) {
          if (mounted) {
            showDetailedForecastDialog(forecast);
          }
        }).catchError((error) {
          print("Error fetching detailed forecast: $error");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Could not fetch weather data."), backgroundColor: Colors.orange),
            );
          }
        });
      } else if (marker2 == null) {
        marker2 = location;
        marker2Controller.text = coordsText;
        // Once both markers exist, fetch routes automatically
        fetchAllRoutes();
      } else {
        // Both markers set, user must remove one
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Both markers are set. Remove one to add a new location.")),
        );
      }
    });
  }

  // Remove marker
  void removeMarker(int markerNumber) {
    if (!mounted) return;
    setState(() {
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
    });
  }

  // Fetch routes between marker1 and marker2
  Future<void> fetchAllRoutes() async {
    if (marker1 == null || marker2 == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please set two markers to find routes.")),
        );
      }
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Finding routes..."), duration: Duration(seconds: 2)),
      );
    }
    print("Fetching routes...");
    await mf.fetchAllRoutes(
      marker1: marker1,
      marker2: marker2,
      routeAlternatives: routeAlternatives,
      setStateCallback: () { if (mounted) setState(() {}); },
      fitMapToRoutesCallback: () => mf.fitMapToRoutes(
        routeAlternatives: routeAlternatives,
        mapController: mapController,
      ),
      apiKey: geoapifyApiKey,
    );
    print("Route fetching complete. Alternatives found: ${routeAlternatives.length}");
    if (mounted && routeAlternatives.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No routes found between markers."), backgroundColor: Colors.orange),
      );
    }
  }

  // Show user location
  Future<void> _onGetMyLocationPressed() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Getting your location...")),
    );
    final LatLng? userLocation = await mf.getCurrentLocation();
    if (!mounted) return;
    if (userLocation != null) {
      moveToLocation(userLocation);
      setState(() {
        final coordsText = "${userLocation.latitude.toStringAsFixed(6)}, ${userLocation.longitude.toStringAsFixed(6)}";
        if (marker1 == null) {
          marker1 = userLocation;
          marker1Controller.text = coordsText;
        } else if (marker2 == null) {
          marker2 = userLocation;
          marker2Controller.text = coordsText;
          fetchAllRoutes();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Both markers are set. Current location not added as marker.")),
          );
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location unavailable. Check permissions and GPS."), backgroundColor: Colors.red),
      );
    }
  }

  // ====== Step 1: Fetch friend list from user_friendships
// ====== Step 1: Fetch friend list (Corrected Query) ======
  Future<List<Map<String, dynamic>>> _fetchFriendList() async {
    if (userId == null) {
      print("Cannot fetch friends: User not logged in.");
      return []; // Return empty list if user is not logged in
    }

    try {
      // Fetch friendship entries where the current user is either user_id or friend_id, and status is accepted
      final response = await Supabase.instance.client
          .from('user_friendships')
          .select('user_id, friend_id') // Select both IDs to determine who the friend is
          .or('user_id.eq.$userId,friend_id.eq.$userId') // User is one or the other
          .eq('status', 'accepted'); // Status must be accepted

      if (response is List) {
        final friendships = response.map((e) => e as Map<String, dynamic>).toList();
        if (friendships.isEmpty) {
          print("No accepted friendships found for user $userId.");
          return []; // Return empty if no friendships found
        }

        // Extract the IDs of the friends (the ID that is *not* the current user's ID)
        final friendIds = friendships.map<String>((friendship) {
          // If user_id is the current user, friend_id is the friend, otherwise user_id is the friend
          return (friendship['user_id'] == userId)
              ? friendship['friend_id']
              : friendship['user_id'];
        }).where((id) => id != null).toSet().toList(); // Use Set to ensure unique IDs, handle potential nulls

        if (friendIds.isEmpty) {
          print("Friend IDs list is empty after filtering.");
          return [];
        }

        print("Found friend IDs: $friendIds");

        // Now fetch the profiles for these friend IDs
        final profileResponse = await Supabase.instance.client
            .from('profiles')
        // Select columns needed for display (id is needed to pass to _shareRouteWithFriend)
            .select('id, username, full_name, avatar_url')
            .inFilter('id', friendIds);
        if (profileResponse is List) {
          // Return the list of friend profiles
          final profiles = profileResponse.map((e) => e as Map<String, dynamic>).toList();
          print("Fetched ${profiles.length} friend profiles.");
          return profiles;
        } else {
          print("Profile response was not a list.");
          return [];
        }

      } else {
        print("Friendships response was not a list.");
        return []; // Return empty if the response format is unexpected
      }
    } on PostgrestException catch (error) {
      print("Supabase error fetching friends: ${error.message}");
      return [];
    } catch (error) {
      print("Unexpected error fetching friends: $error");
      return [];
    }
  }

  // ====== Step 2: Show friend list in a bottom sheet
  void _shareRouteWithFriendFlow() async {
    // Must have 2 markers and at least 1 route
    if (marker1 == null || marker2 == null || routeAlternatives.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No complete route to share. Place two markers and find a route first.")),
      );
      return;
    }
    final friends = await _fetchFriendList();
    if (!mounted) return;
    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You have no friends to share with!")),
      );
      return;
    }
    // Show a bottom sheet to pick a friend
// Inside _shareRouteWithFriendFlow function, replace the existing showModalBottomSheet call with this:

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows sheet height to adjust more freely
      shape: RoundedRectangleBorder( // Optional: Add rounded corners to the top
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (ctx) {
        // Add padding and a title inside the sheet
        return Padding(
          padding: EdgeInsets.only(
              top: 16.0,
              left: 16.0,
              right: 16.0,
              // Add bottom padding to account for system navigation, etc.
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Make column height fit content
            children: [
              // Title for the sheet
              Text(
                "Share Route With...",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: 16), // Spacing after title

              // Check if friends list is actually empty (as a safeguard)
              if (friends.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Text("No friends available."),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true, // Important within Column/Flexible
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      // Each 'friendProfile' is a map like: {id, username, full_name, avatar_url}
                      final friendProfile = friends[index];

                      // Get data using the correct keys from the profile map
                      final friendId = friendProfile['id']; // Use 'id' for the friend's ID
                      final friendName = friendProfile['username'] ?? friendProfile['full_name'] ?? 'Unknown Friend';
                      final avatarUrl = friendProfile['avatar_url'];

                      // Prevent errors if ID is somehow null
                      if (friendId == null) {
                        print("Warning: Found friend profile with null ID at index $index");
                        return SizedBox.shrink(); // Skip rendering if ID is null
                      }

                      // Build the list tile for the friend
                      return ListTile(
                        leading: avatarUrl != null && avatarUrl.isNotEmpty
                            ? CircleAvatar(
                          backgroundImage: NetworkImage(avatarUrl),
                          // Optional: Add error builder for network image
                          onBackgroundImageError: (exception, stackTrace) {
                            print("Error loading avatar: $exception");
                            // You could potentially return a placeholder here, but CircleAvatar handles it okay
                          },
                        )
                            : CircleAvatar(child: Icon(Icons.person_outline)), // Fallback icon
                        title: Text(friendName),
                        // Optional: Add subtitle for clarity or debugging
                        // subtitle: Text("ID: ${friendId.substring(0, 8)}..."), // Show partial ID?

                        // Action when a friend is tapped
                        onTap: () {
                          Navigator.pop(context); // Close the bottom sheet
                          // Pass the CORRECT friendId (which is not null here)
                          _shareRouteWithFriend(friendId);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

// ====== Step 3: Insert route data for the chosen friend (Corrected Error Handling) ======
  // !! Assumes 'shared_routes' table exists with correct columns and RLS policies !!
  Future<void> _shareRouteWithFriend(String friendId) async {
    // Null check for markers (essential for getting coordinates)
    if (marker1 == null || marker2 == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Start or end marker missing.")),
      );
      return;
    }
    // Null check for current user ID
    final currentUserId = userId; // Use the state variable
    if (currentUserId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: Not logged in.")),
      );
      return;
    }

    // Get coordinates safely AFTER checking markers are not null
    final startLat = marker1!.latitude;
    final startLng = marker1!.longitude;
    final endLat = marker2!.latitude;
    final endLng = marker2!.longitude;

    print("Attempting to share route with friend $friendId..."); // Log start

    try {
      // Perform the insert operation. Await will throw PostgrestException on DB/RLS errors.
      await Supabase.instance.client
          .from('shared_routes') // *** ENSURE THIS TABLE EXISTS ***
          .insert({
        'owner_user_id': currentUserId,
        'friend_user_id': friendId,
        'start_lat': startLat,
        'start_lng': startLng,
        'end_lat': endLat,
        'end_lng': endLng,
        // 'created_at' uses DB default
      });

      // If await completes without throwing, the insert was successful (at least from client's view)
      print("Route shared successfully with friend $friendId");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Route details shared!"), backgroundColor: Colors.green),
      );

    } on PostgrestException catch (error) {
      // Catch specific Supabase errors (e.g., RLS violation, constraint violation)
      print("Supabase error sharing route: ${error.message}");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to share route: ${error.message}"), backgroundColor: Colors.red),
      );
    } catch (e) {
      // Catch any other generic errors (e.g., network issues, unexpected errors)
      print("Generic exception sharing route: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred while sharing route."), backgroundColor: Colors.red),
      );
    }
  }
  // Step 4: Replace old “Share My Location” logic with the friend-sharing flow
  Future<void> _shareAndSaveCurrentLocation() async {
    // Instead of saving just the user’s single location, we now show the friend list
    _shareRouteWithFriendFlow();
  }

  @override
  Widget build(BuildContext context) {
    final routeColors = {
      'balanced': Colors.blue.withOpacity(0.8),
      'short': Colors.green.withOpacity(0.8),
      'less_maneuvers': Colors.purple.withOpacity(0.8),
    };

    return Scaffold(
      appBar: MyCustomAppBar(
        onNotificationPressed: () => debugPrint('Notification icon pressed!'),
        onGroupPressed: () => debugPrint('Group icon pressed!'),
        avatarUrl: _avatarUrl,
      ),
      // Show route info if routes exist
      bottomSheet: routeAlternatives.isNotEmpty
          ? Container(
        color: Theme.of(context).cardColor,
        padding: EdgeInsets.all(12.0),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Route Options:",
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: routeAlternatives.length,
                itemBuilder: (context, index) {
                  final route = routeAlternatives[index];
                  final distanceKm = (route.distanceMeters / 1000).toStringAsFixed(1);
                  final timeMin = (route.timeSeconds / 60).toStringAsFixed(0);
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 8,
                      backgroundColor: routeColors[route.type] ?? Colors.grey,
                    ),
                    title: Text(
                      "${route.type.toUpperCase()} (${distanceKm}km, ~${timeMin}min)",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 8),
            // The existing "Share My Location" button triggers the friend-sharing
            Center(
              child: ElevatedButton.icon(
                icon: Icon(Icons.share_location),
                onPressed: _shareAndSaveCurrentLocation, // triggers friend flow
                label: Text("Share My Location"),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
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
              initialCenter: LatLng(14.5547, 121.0244),
              initialZoom: zoomLevel,
              onTap: (tapPosition, latLng) => addMarker(latLng),
              onPositionChanged: (position, hasGesture) {
                if (hasGesture &&
                    mounted &&
                    position.zoom != null &&
                    position.zoom != zoomLevel) {
                  setState(() {
                    zoomLevel = position.zoom!;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.stattrak.app',
                tileProvider: CancellableNetworkTileProvider(),
              ),
              if (routeAlternatives.isNotEmpty)
                PolylineLayer(
                  polylines: routeAlternatives.map((route) {
                    final color = routeColors[route.type] ?? Colors.black;
                    return Polyline(
                      points: route.points,
                      strokeWidth: 5.0,
                      color: color.withOpacity(0.8),
                      isDotted: false,
                      borderStrokeWidth: 1.0,
                      borderColor: Colors.white.withOpacity(0.6),
                    );
                  }).toList(),
                ),
              MarkerLayer(
                markers: [
                  if (marker1 != null)
                    Marker(
                      point: marker1!,
                      width: 80,
                      height: 80,
                      child: Tooltip(
                        message: "Start / Point 1\nTap pin to remove",
                        child: GestureDetector(
                          onTap: () => removeMarker(1),
                          child: Icon(Icons.location_on, color: Colors.red, size: 45),
                        ),
                      ),
                      alignment: Alignment.topCenter,
                    ),
                  if (marker2 != null)
                    Marker(
                      point: marker2!,
                      width: 80,
                      height: 80,
                      child: Tooltip(
                        message: "End / Point 2\nTap pin to remove",
                        child: GestureDetector(
                          onTap: () => removeMarker(2),
                          child: Icon(Icons.location_on, color: Colors.blue, size: 45),
                        ),
                      ),
                      alignment: Alignment.topCenter,
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 70,
            left: 10,
            right: 10,
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 250),
                padding: EdgeInsets.all(12.0),
                constraints: BoxConstraints(minHeight: 50),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Markers & Routes",
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: Icon(showMarkerDetails ? Icons.expand_less : Icons.expand_more),
                          tooltip: showMarkerDetails ? "Collapse Details" : "Expand Details",
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          onPressed: () {
                            if (mounted) {
                              setState(() {
                                showMarkerDetails = !showMarkerDetails;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    AnimatedCrossFade(
                      firstChild: Container(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: marker1Controller,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: "Start / Marker 1",
                                hintText: "Tap map to set",
                                isDense: true,
                                suffixIcon: marker1 == null
                                    ? null
                                    : IconButton(
                                  icon: Icon(Icons.clear, color: Colors.grey[600], size: 20),
                                  tooltip: "Remove Marker 1",
                                  onPressed: () => removeMarker(1),
                                ),
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            SizedBox(height: 10),
                            TextField(
                              controller: marker2Controller,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: "End / Marker 2",
                                hintText: "Tap map to set",
                                isDense: true,
                                suffixIcon: marker2 == null
                                    ? null
                                    : IconButton(
                                  icon: Icon(Icons.clear, color: Colors.grey[600], size: 20),
                                  tooltip: "Remove Marker 2",
                                  onPressed: () => removeMarker(2),
                                ),
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (marker1 != null && marker2 != null) ...[
                              SizedBox(height: 15),
                              ElevatedButton.icon(
                                icon: Icon(Icons.directions),
                                label: Text(routeAlternatives.isEmpty ? "Find Routes" : "Refresh Routes"),
                                onPressed: fetchAllRoutes,
                                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 36)),
                              ),
                            ]
                          ],
                        ),
                      ),
                      crossFadeState: showMarkerDetails ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: Duration(milliseconds: 250),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 10,
            right: 10,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              child: TypeAheadField<Map<String, dynamic>>(
                debounceDuration: Duration(milliseconds: 400),
                textFieldConfiguration: TextFieldConfiguration(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: "Search location or address...",
                    prefixIcon: Icon(Icons.search, color: Theme.of(context).hintColor, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 14.0),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                      icon: Icon(Icons.clear, size: 20),
                      tooltip: "Clear search",
                      onPressed: () {
                        searchController.clear();
                        if (mounted) setState(() {});
                        FocusScope.of(context).unfocus();
                      },
                    )
                        : null,
                  ),
                  onChanged: (value) {
                    if (mounted) setState(() {});
                  },
                ),
                suggestionsCallback: (pattern) async {
                  if (pattern.length < 3) {
                    return [];
                  }
                  return await fetchLocations(pattern);
                },
                itemBuilder: (context, suggestion) {
                  return ListTile(
                    leading: Icon(Icons.location_pin, size: 18, color: Colors.grey),
                    title: Text(suggestion['name'] ?? 'Unknown',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    dense: true,
                  );
                },
                onSuggestionSelected: (suggestion) {
                  if (suggestion['latlng'] is LatLng) {
                    LatLng location = suggestion['latlng'];
                    searchController.text = suggestion['name'] ?? '';
                    moveToLocation(location, targetZoom: 14.0);
                    addMarker(location);
                    FocusScope.of(context).unfocus();
                  } else {
                    print("Invalid suggestion selected: $suggestion");
                  }
                },
                loadingBuilder: (context) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                noItemsFoundBuilder: (context) => Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text('No locations found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)),
                ),
                errorBuilder: (context, error) => Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text('Error: ${error.toString().split(':').last}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red)),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: routeAlternatives.isNotEmpty ? (200 + 20) : 20,
          right: 10,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: "currentLocation",
              onPressed: _onGetMyLocationPressed,
              tooltip: "Go to my current location",
              child: Icon(Icons.my_location),
            ),
            SizedBox(height: 12),
            FloatingActionButton(
              heroTag: "zoomIn",
              mini: true,
              onPressed: () {
                if (mounted) {
                  double currentZoom = mapController.camera.zoom;
                  double nextZoom = (currentZoom + 1.0).clamp(1.0, 19.0);
                  moveToLocation(mapController.camera.center, targetZoom: nextZoom);
                }
              },
              tooltip: "Zoom In",
              child: Icon(Icons.add),
            ),
            SizedBox(height: 8),
            FloatingActionButton(
              heroTag: "zoomOut",
              mini: true,
              onPressed: () {
                if (mounted) {
                  double currentZoom = mapController.camera.zoom;
                  double nextZoom = (currentZoom - 1.0).clamp(1.0, 19.0);
                  moveToLocation(mapController.camera.center, targetZoom: nextZoom);
                }
              },
              tooltip: "Zoom Out",
              child: Icon(Icons.remove),
            ),
          ],
        ),
      ),
    );
  }
}
