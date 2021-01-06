import 'dart:convert';
import 'package:fl_template/app/app_logger.dart';
import 'package:fl_template/ui/pages/home/home_viewmodel.dart';
import 'package:flutter/cupertino.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:stacked/stacked.dart';

class MapBoxWidget extends StatefulWidget {
  @override
  _MapBoxWidgetState createState() => _MapBoxWidgetState();
}

class _MapBoxWidgetState extends State<MapBoxWidget> {
  MapboxMapController mapController;

  void _onMapCreated(MapboxMapController controller) {
    mapController = controller;
  }
  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<HomeViewModel>.nonReactive(builder: (BuildContext context, HomeViewModel viewModel, _) {
      return MapboxMap(
        minMaxZoomPreference: MinMaxZoomPreference.unbounded,
        styleString: 'mapbox://styles/duong236/ckjingw6rd3s219p1epfmubfu',
        accessToken: 'pk.eyJ1IjoiZHVvbmcyMzYiLCJhIjoiY2tpbDV0aGZ1MDI2MzJxcDM5Ymh2NWJqayJ9.we7o5gtM_vH5BaodWPymAQ',
        onMapCreated: _onMapCreated,
        rotateGesturesEnabled: false,
        onMapClick: (e,a) {
          logger.d('eeeeeeeeeeeeeee $e');
          logger.d('aaaaaaaaaaaaaaa $a');
        },

        initialCameraPosition:
        const CameraPosition(
            target: LatLng(38.897435, -77.039679),
            zoom: 3.5),
        onStyleLoadedCallback: () {

        },
      );
    }, viewModelBuilder: () => HomeViewModel(), onModelReady: (model) async {
     final String geoJson = await model.getGeoJsonUnited();
     final Map decode = jsonDecode(geoJson);
      mapController.drawPolygonFeature(geoJson: <String, dynamic>{'geoJson': decode});

    });
  }
}
// mapbox://styles/hiennguyen92/ckizibco90v1u19o3gxs86dhz
//mapbox://styles/hiennguyen92/ckja53v0z5j1019p5o9z8bo37
