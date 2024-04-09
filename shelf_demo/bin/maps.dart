import 'dart:math';
import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_toolkit/flutter_map_toolkit.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter_Map_Toolkit Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  DistanceInfo? distanceInfo;
  static const _mapboxPublicToken =
      'pk.eyJ1IjoiZm1vdGFsbGViIiwiYSI6ImNsNWppYXJiZjAwZGwzbG5uN2NqcHc2a3EifQ.sDOg7Y2k9Nxat1MlkPj2lg';
  final httpClient = Dio();
  final _mapEventTap = MapTapEventHandler();
  late final directionProvider = MapboxDirectionProvider(
    mapboxToken: _mapboxPublicToken,
    getRequestHandler: (String url) async {
      final response = await httpClient.get<Map<String, dynamic>>(
        url,
      );
      return response.data!;
    },
  );
  final directionController = DirectionsLayerController();
  final _points = <LatLng>[];
  final plugins = [
    PointSelectorPlugin(),
    DirectionsPlugin(),
    LiveMarkerPlugin(),
  ];
  final _mapBoxAddress = mapBoxUrlBuilder(
    style: 'fmotalleb/cl6m8kuee009v16pkv7m6mxgs',
    is2x: true,
    accessToken: _mapboxPublicToken,
  );

  final pointProvider = SampleStreamedPointProvider();
  void onPointSelect(PointSelectionEvent event) {
    if (event.state == PointSelectionState.select) {
      if (event.point != null) {
        // _points.add(event.point!);
        setState(() {
          distanceInfo = directionController.lastPath?.distanceToPoint(
            event.point!,
          );
        });
        pointProvider.controller.insert(event.point!);
      }
    } else if (event.point != null) {
      _points.remove(event.point);
      pointProvider.controller.remove(event.point!);
    }
    if (_points.length > 1) {
      directionController.requestDirections(_points);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: FlutterMap(
                options: MapOptions(
                  plugins: plugins,
                  minZoom: 5,
                  maxZoom: 18,
                  adaptiveBoundaries: false,
                  onTap: (tapPosition, point) {
                    _mapEventTap.update(point);
                  },
                  center: LatLng(32.553447, 53.064549),
                  zoom: 5,
                ),
                layers: [
                  /// base map tile backed by mapbox
                  TileLayerOptions(
                    maxNativeZoom: 15,
                    urlTemplate: _mapBoxAddress,
                  ),

                  if (distanceInfo != null) ...[
                    MarkerLayerOptions(
                      markers: [
                        Marker(
                          width: 80,
                          height: 80,
                          point: distanceInfo!.source,
                          builder: (ctx) => const Icon(
                            Icons.location_on,
                            color: Colors.red,
                          ),
                        ),
                        Marker(
                          width: 80,
                          height: 80,
                          point: distanceInfo!.destination,
                          builder: (ctx) => const Icon(
                            Icons.location_off,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    PolylineLayerOptions(
                      polylines: [
                        Polyline(
                          points: [
                            distanceInfo!.source,
                            distanceInfo!.destination,
                          ],
                          strokeWidth: 3,
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ],

                  /// direction layer for showing the route between selected points
                  // DirectionsLayerOptions(
                  //   provider: directionProvider,
                  //   useCachedRoute: true,
                  //   controller: directionController,
                  //   loadingBuilder: (context) {
                  //     return const Center(
                  //       child: CircularProgressIndicator(),
                  //     );
                  //   },
                  // ),

                  PointSelectorOptions(
                    onPointSelected: onPointSelect,
                    marker: MarkerInfo(
                      view: (context, __) => SizedBox(),
                    ),
                    removeOnTap: true,
                    mapEventLink: _mapEventTap,
                  ),

                  /// draw selected points on map
                  LiveMarkerOptionsWithStream(
                    pointsInfoProvider: pointProvider,
                    markers: {
                      'm0': MarkerInfo(
                          view: (_, __) => Icon(
                                Icons.gpp_good_sharp,
                                color: Colors.black.withOpacity(0.2),
                              )),
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension Randomize<T> on List<T> {
  T get random => this[Random().nextInt(length)];
  List<T> randomize() {
    final result = toList();
    result.shuffle();
    return result;
  }
}

class SamplePointsEventCubit extends Cubit<List<PointInfo>> {
  SamplePointsEventCubit(this.iconIds, [super.initialState = const []]);
  final List<String> iconIds;
  final _points = <LatLng>[];
  int get pointsCount => _points.length;
  Iterable<PointInfo> get _information {
    return _points.map(
      (e) => PointInfo(
        rotation: 0,
        position: e,
        iconId: iconIds.random,
        metaData: {},
      ),
    );
  }

  void refresh() {
    emit(
      _information.toList(),
    );
  }

  void removeAll() {
    _points.clear();
    emit([]);
  }

  void insert(LatLng point) {
    _points.add(point);
    emit(_information.toList());
  }

  void remove(LatLng point) {
    _points.remove(point);
    emit(_information.toList());
  }
}

class SampleStreamedPointProvider extends PointInfoStreamedProvider {
  final controller = SamplePointsEventCubit([
    'm0',
  ]);
  @override
  Stream<List<PointInfo>> getPointStream(
    Stream<MapInformationRequestParams?> params,
  ) =>
      controller.stream;

  @override
  void invoke() {
    controller.refresh();
  }
}
