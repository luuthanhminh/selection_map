import 'dart:convert';
import 'package:fl_template/ui/pages/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stacked/stacked.dart';
import 'package:syncfusion_flutter_maps/maps.dart';

class HomeViewModel extends BaseViewModel {
  List<Model> sublayerData = <Model>[];

  MapShapeSource dataSource;
  List<MapShapeSource> sublayerSources = <MapShapeSource>[];

  MapShapeSource _sublayerSource;

  MapShapeSource get sublayerSource => _sublayerSource;

  set sublayerSource(MapShapeSource sublayerSource) {
    _sublayerSource = sublayerSource;
    notifyListeners();
  }

  List<MapSublayer> mapSublayer = <MapSublayer>[];
  List<PolygonModel> _polygons = <PolygonModel>[];

  List<PolygonModel> get polygons => _polygons;

  set polygons(List<PolygonModel> polygons) {
    _polygons = polygons;
    notifyListeners();
  }

  MapShapeSource shapeSource;
  MapZoomPanBehavior zoomPanBehavior;
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  set selectedIndex(int selectedIndex) {
    _selectedIndex = selectedIndex;
    notifyListeners();
  }
  int _selectedIndexCountry = 0;

  int get selectedIndexCountry => _selectedIndexCountry;

  set selectedIndexCountry(int selectedIndexCountry) {
    _selectedIndexCountry = selectedIndexCountry;
    notifyListeners();
  }
  String stateId = '0';
  double zoomLv = 0;
  MapShapeLayerController mapShapeLayerController;

  Future<String> getGeoJson() async {
    final dynamic geoJson = await rootBundle.loadString('assets/geojson/country.json');
    return geoJson;
  }

  Future<String> getGeoJsonUnited() async {
    final String geoJson = await rootBundle.loadString('assets/geojson/united.json');
    return geoJson;
  }

  Future<void> drawRegion({bool isLoadCountry}) async {
    final String geojson = await getGeoJsonUnited();
    final Map<String, dynamic> json = jsonDecode(geojson);
    final List<dynamic> featuresJson =
        (json['features'] as List<dynamic>).toList();
    sublayerData.clear();
    featuresJson.forEach((e) {
      final dynamic property = e['properties'];
      sublayerData.add(
          Model(property['name'], Colors.white, property['density'], e['id']));
    });
    sublayerSource = MapShapeSource.asset(
      'assets/geojson/united.json',
      shapeDataField: 'name',
      dataCount: sublayerData.length,
      primaryValueMapper: (int index) => sublayerData[index].key,
      shapeColorValueMapper: (int index) => sublayerData[index].color,
    );
  }

  Future<void> drawCountries() async {
    final String geojson = await getGeoJson();
    final Map<String, dynamic> json = jsonDecode(geojson);
    final List<dynamic> featuresJson =
        (json['features'] as List<dynamic>).toList();

    final geoJsonss =
        featuresJson.where((e) => e['properties']['STATE'] == stateId).toList();

    List<PolygonModel> polygonss = <PolygonModel>[];
    geoJsonss.forEach((e) {
      List<MapLatLng> polygon1 = <MapLatLng>[];
      List<dynamic> geometry;
      if (e['geometry']['type'] == 'MultiPolygon') {
        geometry = e['geometry']['coordinates'][0][0];
      } else {
        geometry = e['geometry']['coordinates'][0];
      }
      List.generate(geometry.length, (index) {
        final List<dynamic> latlg = geometry[index];
        final num lat = latlg[0];
        final num lng = latlg[1];
        MapLatLng mapLatLng = MapLatLng(lng.toDouble(), lat.toDouble());
        polygon1.add(mapLatLng);
      });
      polygonss.add(PolygonModel(polygon1, Colors.red));
    });

    polygons = polygonss;
  }
}
