import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_unity_widget_example/core/constant.dart';
import 'package:flutter_unity_widget_example/game/my_game.dart';
import 'package:location/location.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'page.dart';

const randomMarkerNum = 100;

class CustomMarkerPage extends ExamplePage {
  CustomMarkerPage() : super(const Icon(Icons.place), 'Custom marker');

  @override
  Widget build(BuildContext context) {
    return CustomMarker();
  }
}

class CustomMarker extends StatefulWidget {
  const CustomMarker();

  @override
  State createState() => CustomMarkerState();
}

class CustomMarkerState extends State<CustomMarker> {
  final Random _rnd = new Random(10);

  MapboxMapController _mapController;
  List<Marker> _markers = [];
  List<_MarkerState> _markerStates = [];
  LocationData locationData;
  void _addMarkerStates(_MarkerState markerState) {
    _markerStates.add(markerState);
  }

  void _onMapCreated(MapboxMapController controller) {
    _mapController = controller;
    controller.addListener(() {
      if (controller.isCameraMoving) {
        _updateMarkerPosition();
      }
    });
    _mapController.onSymbolTapped.add((argument) {
      print("duyddddddddddddddddd");
    });
  }

  void _onStyleLoadedCallback() {
    print('onStyleLoadedCallback');
  }

  void _onMapLongClickCallback(Point<double> point, LatLng coordinates) {
    _addMarker(point, coordinates, "assets/symbols/custom-icon.png");
  }

  void _onCameraIdleCallback() {
    _updateMarkerPosition();
  }

  void _updateMarkerPosition() {
    final coordinates = <LatLng>[];

    for (final markerState in _markerStates) {
      coordinates.add(markerState.getCoordinate());
    }

    _mapController.toScreenLocationBatch(coordinates).then((points){
      _markerStates.asMap().forEach((i, value){
        _markerStates[i].updatePosition(points[i]);
      });
    });
  }

  void _addMarker(Point<double> point, LatLng coordinates, String img) {
    setState(() {
      _markers.add(Marker(_rnd.nextInt(100000).toString(), coordinates, point, _addMarkerStates, img));
    });
  }

  Future<LocationData> getLocation() async {
    locationData = await Location().getLocation();
    print("Location data ${locationData.latitude}");
    return locationData;
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return new Scaffold(
      body: FutureBuilder<LocationData>(
        future: getLocation(),
        builder: (BuildContext context, AsyncSnapshot<LocationData> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return Container(
                height: size.height,
                width: size.width,
                child: Center(
                  child: Container(
                    height: 50,width: 50,
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            default:
              if (snapshot.hasError)
                return Stack(
                    children: [
                      MapboxMap(
                        accessToken: ACCESS_TOKEN,
                        trackCameraPosition: true,
                        onMapCreated: _onMapCreated,
                        onMapLongClick: _onMapLongClickCallback,
                        onCameraIdle: _onCameraIdleCallback,
                        onStyleLoadedCallback: _onStyleLoadedCallback,
                        initialCameraPosition: const CameraPosition(target: LatLng(35.0, 135.0), bearing: 270.0,
                          tilt: 30.0,
                          zoom: 14.0,),
                      ),
                      IgnorePointer(
                          ignoring: false,
                          child:
                          Stack(
                            children: _markers,
                          )
                      )
                    ]
                );
              else
                return Stack(
                    children: [
                      MapboxMap(
                        accessToken: ACCESS_TOKEN,
                        trackCameraPosition: true,
                        onMapCreated: _onMapCreated,
                        onMapLongClick: _onMapLongClickCallback,
                        onCameraIdle: _onCameraIdleCallback,
                        onStyleLoadedCallback: _onStyleLoadedCallback,
                        initialCameraPosition:  CameraPosition(target: LatLng(locationData.latitude, locationData.longitude), bearing: 270.0,
                          tilt: 30.0,
                          zoom: 14.0,),
                      ),
                      Container(
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
          for (var i = 0; i < randomMarkerNum; i++) {
            final lat = _rnd.nextDouble() * 0.1 + locationData.latitude;
            final lng = _rnd.nextDouble() * 0.1 + locationData.longitude;
            param.add(LatLng(lat, lng));
          }
          _mapController.toScreenLocationBatch(param).then((value) {
            for (var i = 0; i < randomMarkerNum; i++) {
              var point = Point<double>(value[i].x, value[i].y);
              _addMarker(point, param[i], "assets/gift.gif");
            }
          });
          //add player  current position
          var playerPosition = <LatLng>[];
          playerPosition.add(LatLng(locationData.latitude, locationData.longitude));
          _mapController.toScreenLocationBatch(playerPosition).then((value) {
            var point = Point<double>(value[0].x, value[0].y);
            _addMarker(point, playerPosition[0], "assets/face_icon.jpg");
          });

        },
        child: Icon(Icons.add),
      ),
    );
  }

  // ignore: unused_element
  void _measurePerformance() {
    final trial = 10;
    final batches = [500, 1000, 1500, 2000, 2500, 3000];
    var results = Map<int, List<double>>();
    for (final batch in batches) {
      results[batch] = [0.0, 0.0];
    }

    _mapController.toScreenLocation(LatLng(0, 0));
    Stopwatch sw = Stopwatch();

    for (final batch in batches) {
      //
      // primitive
      //
      for (var i = 0; i < trial; i++) {
        sw.start();
        var list = <Future<Point<num>>>[];
        for (var j = 0; j < batch; j++) {
          var p = _mapController.toScreenLocation(LatLng(j.toDouble() % 80, j.toDouble() % 300));
          list.add(p);
        }
        Future.wait(list);
        sw.stop();
        results[batch][0] += sw.elapsedMilliseconds;
        sw.reset();
      }

      //
      // batch
      //
      for (var i = 0; i < trial; i++) {
        sw.start();
        var param = <LatLng>[];
        for (var j = 0; j < batch; j++) {
          param.add(LatLng(j.toDouble() % 80, j.toDouble() % 300));
        }
        Future.wait([_mapController.toScreenLocationBatch(param)]);
        sw.stop();
        results[batch][1] += sw.elapsedMilliseconds;
        sw.reset();
      }

      print('batch=$batch,primitive=${results[batch][0] / trial}ms, batch=${results[batch][1] / trial}ms');
    }

  }
}

class Marker extends StatefulWidget {
  final Point _initialPosition;
  final LatLng _coordinate;
  final String img;
  final void Function(_MarkerState) _addMarkerState;

  Marker(String key, this._coordinate, this._initialPosition, this._addMarkerState, this.img) : super(key: Key(key));

  @override
  State<StatefulWidget> createState() {
    final state = _MarkerState(_initialPosition, imgAsset: img);
    _addMarkerState(state);
    return state;
  }
}

class _MarkerState extends State with TickerProviderStateMixin {
  final _iconSize = 20.0;
  String imgAsset;
  Point _position;

  AnimationController _controller;
  Animation<double> _animation;

  _MarkerState(this._position, {this.imgAsset});

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
    if(imgAsset == null){
      imgAsset = "assets/gift.gif";
    }
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
         Container(
           height: 60,
           width: 60,
           child: GestureDetector(
             child:  Image.asset('${imgAsset}', height: _iconSize),
             onTap: (){
               print('asdasdasdasdsad');
               Navigator.of(context).push(MaterialPageRoute(builder: (context) => MyGame()));
             },
           ),
         )
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

