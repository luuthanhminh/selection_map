import 'package:fl_template/ui/pages/home/home_viewmodel.dart';
import 'package:fl_template/ui/view/mapbox.dart';
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
            body: MapBoxWidget()
          );
        },
        viewModelBuilder: () => HomeViewModel(),
        onModelReady: (model) {
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
