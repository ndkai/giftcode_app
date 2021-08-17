import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_unity_widget_example/core/constant.dart';
import 'package:flutter_unity_widget_example/map_controller/component/marker.dart';
import 'package:location/location.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

class MyMapBox extends StatefulWidget {
  const MyMapBox({Key key}) : super(key: key);

  @override
  _MyMapBoxState createState() => _MyMapBoxState();
}

class _MyMapBoxState extends State<MyMapBox> {
  final Random _rnd = new Random();
  MapboxMapController mapController;
  LocationData locationData;
  List<Marker> _markers = [];
  List<MarkerState> markerStates = [];

  @override
  void initState() {
    super.initState();
  }

  void _onMapCreated(MapboxMapController controller) {
    mapController = controller;
    controller.addListener(() {
      if (controller.isCameraMoving) {
        _updateMarkerPosition();
      }
    }); 
  }

  void _onMapLongClickCallback(Point<double> point, LatLng coordinates) {
    _addMarker(point, coordinates);
  }

  void _onStyleLoadedCallback() {
    print('onStyleLoadedCallback');
  }

  void _updateMarkerPosition() {
    final coordinates = <LatLng>[];

    for (final markerState in markerStates) {
      coordinates.add(markerState.getCoordinate());
    }

    mapController.toScreenLocationBatch(coordinates).then((points){
      markerStates.asMap().forEach((i, value){
        markerStates[i].updatePosition(points[i]);
      });
    });
  }

  void _addMarker(Point<double> point, LatLng coordinates) {
    setState(() {
      _markers.add(Marker(_rnd.nextInt(100000).toString(), coordinates, point, _addMarkerStates));
    });
  }

  void _addMarkerStates(MarkerState markerState) {
    markerStates.add(markerState);
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      body: FutureBuilder<LocationData>(
        future: getLocation(),
        builder: (BuildContext context, AsyncSnapshot<LocationData> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return Container(
                height: size.height,
                width: size.width,
                child: Container(
                  height: 50,width: 50,
                  child: CircularProgressIndicator(
                    value: 30,
                  ),
                ),
              );
            default:
              if (snapshot.hasError)
                return SizedBox(
                  width: size.width,
                  height: size.height,
                  child: MapboxMap(
                    accessToken: ACCESS_TOKEN,
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: const CameraPosition(
                      bearing: 270.0,
                      target: LatLng(51.5160895, -0.1294527),
                      tilt: 30.0,
                      zoom: 14.0,
                    ),
                  ),
                );
              else
                return  Stack(
                    children: [
                      SizedBox(
                        width: size.width,
                        height: size.height,
                        child: MapboxMap(
                          accessToken: ACCESS_TOKEN,
                          trackCameraPosition: true,
                          onMapLongClick: _onMapLongClickCallback,
                          onMapCreated: _onMapCreated,
                          onStyleLoadedCallback: _onStyleLoadedCallback,
                          initialCameraPosition: CameraPosition(
                            bearing: 270.0,
                            target: LatLng(snapshot.data.latitude,snapshot.data.longitude),
                            tilt: 30.0,
                            zoom: 17.0,
                          ),
                        ),
                      ),
                      IgnorePointer(
                          ignoring: true,
                          child:
                          Stack(
                            children: _markers,
                          )
                      )
                    ]
                );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (){
          //_measurePerformance();

          // Generate random markers
          var param = <LatLng>[];
          for (var i = 0; i < 20; i++) {
            final lat = _rnd.nextDouble() * 20 + 30;
            final lng = _rnd.nextDouble() * 20 + 125;
            param.add(LatLng(lat, lng));
          }

          mapController.toScreenLocationBatch(param).then((value) {
            for (var i = 0; i < 20; i++) {
              var point = Point<double>(value[i].x, value[i].y);
              _addMarker(point, param[i]);
            }
          });
        },
        child: Icon(Icons.add),
      ),
    );
  }

  Future<LocationData> getLocation() async {
    locationData = await Location().getLocation();
    print("Location data ${locationData.latitude}");
    return locationData;
  }
}

class Marker extends StatefulWidget {
  final Point _initialPosition;
  final LatLng _coordinate;
  final void Function(MarkerState) _addMarkerState;

  Marker(String key, this._coordinate, this._initialPosition, this._addMarkerState) : super(key: Key(key));

  @override
  State<StatefulWidget> createState() {
    final state = MarkerState(_initialPosition);
    _addMarkerState(state);
    return state;
  }
}

class MarkerState extends State with TickerProviderStateMixin {
  final _iconSize = 20.0;

  Point _position;

  AnimationController _controller;
  Animation<double> _animation;

  MarkerState(this._position);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var ratio = 1.0;

    //web does not support Platform._operatingSystem
    if (!kIsWeb) {
      // iOS returns logical pixel while Android returns screen pixel
      ratio = Platform.isIOS ? 1.0 : MediaQuery.of(context).devicePixelRatio;
    }

    return
      Positioned(
          left: _position.x / ratio - _iconSize / 2,
          top: _position.y / ratio - _iconSize / 2,
          child:
          RotationTransition(
              turns: _animation,
              child:
              Image.asset('assets/symbols/2.0x/custom-icon.png', height: _iconSize))
      );
  }

  void updatePosition(Point<num> point) {
    setState(() {
      _position = point;
    });
  }

  LatLng getCoordinate() {
    return (widget as Marker)._coordinate;
  }
}