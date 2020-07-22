import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
void main() {
  SdkContext.init(IsolateOrigin.main);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HEREMAP integration',
      home: HomeScreen(
        channel:
            IOWebSocketChannel.connect('ws://52.57.38.214:1880/ws/bike_data'),
      ),
      theme: ThemeData(primaryColor: Colors.blueAccent),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final WebSocketChannel channel;

  HomeScreen({Key key, @required this.channel}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Position _currentPosition;
  MapImage _carMarkerImage;
  MapImage _personMarkerImage;
  Timer timer;
  List<MapMarker> _mapMarkerList = new List<MapMarker>();
  List<Location> _locations = new List<Location>();

  var geoLocator = Geolocator();
  var locationOptions =
      LocationOptions(accuracy: LocationAccuracy.high, distanceFilter: 10);
  StreamSubscription<Position> positionStream;

  @override
  void initState() {
    _generateMarker();
    _generateUserMarker();
    positionStream =
        geoLocator.getPositionStream(locationOptions).listen((position) {
      setState(() {
        _currentPosition = position;
      });
    });

    super.initState();
  }

  void dispose() {
    positionStream.cancel();
    widget.channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(
        title: Text('Here Map Test'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Container(
        child: HereMap(
          onMapCreated: _onMapCreated,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.send),
        onPressed: () {
          _sendLocation();
        },
      ),
    );
  }

  Future<http.Response> _sendLocation() {
    return http.post(
      'https://example-url-here.com',
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(_locations),
    );
  }

  Future<void> _generateMarker() async {
    if (_personMarkerImage == null) {
      Uint8List imagePixelData = await _loadFileAsUint8List('car-icon.png');
      _carMarkerImage =
          MapImage.withPixelDataAndImageFormat(imagePixelData, ImageFormat.png);
    }
  }
  Future<void> _generateUserMarker() async {
    if (_carMarkerImage == null) {
      Uint8List imagePixelData = await _loadFileAsUint8List('person.png');
      _personMarkerImage =
          MapImage.withPixelDataAndImageFormat(imagePixelData, ImageFormat.png);
    }
  }

  _onMapCreated(HereMapController hereMapController) {
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay,
        (MapError error) {
      if (error == null) {
        hereMapController.camera.lookAtPointWithDistance(
            GeoCoordinates(
                _currentPosition.latitude, _currentPosition.longitude), 240);
        _addPersonMarker(
            GeoCoordinates(
                _currentPosition.latitude, _currentPosition.longitude),
            hereMapController);
            widget.channel.stream.listen((data) {
              var jsonPosition = json.decode(data);
              setState(() {
                _locations.add(Location.fromJson(jsonPosition["position"]));
              });
              _removeMarker(hereMapController);
              _addNewMarker(GeoCoordinates(double.parse(jsonPosition["position"]["lat"]), double.parse(jsonPosition["position"]["lon"])), hereMapController);
            });
      } else {
        print("Ma loading error : " + error.toString());
      }
    });
  }

  Future<Uint8List> _loadFileAsUint8List(String fileName) async {
    ByteData fileData = await rootBundle.load('images/' + fileName);
    return Uint8List.view(fileData.buffer);
  }

  _removeMarker(HereMapController _hereMapController) {
    if (_mapMarkerList.isNotEmpty) {
      _hereMapController.mapScene.removeMapMarker(_mapMarkerList.last);
    }
  }

  _addNewMarker(
      GeoCoordinates geoCoordinates, HereMapController _hereMapController) {
    MapMarker marker = MapMarker(geoCoordinates, _carMarkerImage);
    _hereMapController.mapScene.addMapMarker(marker);
    setState(() {
      _mapMarkerList.add(marker);
    });
  }
  _addPersonMarker(
      GeoCoordinates geoCoordinates, HereMapController _hereMapController) {
    MapMarker marker = MapMarker(geoCoordinates, _personMarkerImage);
    _hereMapController.mapScene.addMapMarker(marker);
  }
}

class Location {
  final double lat;
  final double lon;
  final double alt;

  Location(this.lat, this.lon, this.alt);

  Location.fromJson(Map json)
      : lat = json['lat'],
        lon = json['lon'],
        alt = json['alt'];

  Map toJson() => {
    'lat': lat,
    'lon': lon,
    'alt': alt,
  };
}
