


import 'package:fl_template/ui/pages/home/home_page.dart';
import 'package:fl_template/ui/pages/splash/splash_page.dart';
import 'package:flutter/material.dart';

class AppRoute {
  static const splashView = '/';
  static const homeView = '/home';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch(settings.name) {
      case homeView:
        return MaterialPageRoute(builder: (_) => MyHomePage());
      default:
        return MaterialPageRoute(builder: (_) => SplashPage());
    }
  }
}