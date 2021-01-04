import 'package:fl_template/ui/pages/home/home_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:stacked/stacked.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import 'package:provider/provider.dart';

/// This widget is the home page of the application.
class MyHomePage extends StatefulWidget {
  /// Initialize the instance of the [MyHomePage] class.
  const MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  _MyHomePageState();

  bool isDraw = false;
  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<HomeViewModel>.reactive(
        builder: (BuildContext context, HomeViewModel model, _) {
          return Scaffold(
            body: model.sublayerSource == null
                ? Container()
                : SfMaps(
                    layers: <MapLayer>[
                      MapShapeLayer(
                        source: model.shapeSource,
                        zoomPanBehavior: model.zoomPanBehavior,
                        onWillZoom: (zoomLevel) {
                          if (zoomLevel.newZoomLevel > 8 && isDraw == false) {
                            isDraw = true;
                            model.drawCountries();
                          } else if (zoomLevel.newZoomLevel < 8 &&
                              isDraw == true) {
                            isDraw = false;
                            model.polygons = <PolygonModel>[];
                          }
                          model.zoomLv = zoomLevel.newZoomLevel;
                          return true;
                        },
                        sublayers: <MapSublayer>[
                          model.sublayerSource == null
                              ? Container()
                              : MapShapeSublayer(
                                  source: model.sublayerSource,
                                  selectedIndex: model.selectedIndex,

                                  onSelectionChanged: (int index) {
                                    model.selectedIndex = index;
                                    model.stateId =
                                        '${model.sublayerData[index].stateId}';
                                    if (model.zoomLv > 8) {
                                      model.drawCountries();
                                    }
                                  },
                                  selectionSettings: const MapSelectionSettings(
                                    color: Colors.lime,
                                    strokeWidth: 3,
                                    strokeColor: Colors.black,
                                  ),
                                ),
                          MapPolygonLayer(
                            polygons: List<MapPolygon>.generate(
                              model.polygons.length,
                              (int index) {
                                return MapPolygon(
                                    points: model.polygons[index].points,
                                    color: model.selectedIndexCountry == index
                                        ? Colors.pink
                                        : Colors.blue,
                                    onTap: () {
                                      model.selectedIndexCountry = index;
                                    });
                              },
                            ).toSet(),
                          ),
                        ],
                      ),
                    ],
                  ),
          );
        },
        viewModelBuilder: () => HomeViewModel(),
        onModelReady: (model) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            model.drawRegion(isLoadCountry: false);
            // model.drawCountries();
            model.shapeSource = MapShapeSource.asset(
              'assets/geojson/united.json',
              shapeDataField: 'name',
            );
            model.zoomPanBehavior = MapZoomPanBehavior(
              minZoomLevel: 1,
              maxZoomLevel: 20,
              zoomLevel: 2,
              focalLatLng: MapLatLng(31.51073, -96.4247),
            );
          });
        });
  }
}

class Model {
  Model(this.key, this.color, this.size, this.stateId);

  final String key;
  final Color color;
  final int size;
  final String stateId;
}

class PolygonModel {
  PolygonModel(this.points, this.color);
  final List<MapLatLng> points;
  final Color color;
}
