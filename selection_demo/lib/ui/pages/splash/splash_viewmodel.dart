import 'package:fl_template/app/app_router.dart';
import 'package:fl_template/app/setup_locator.dart';
import 'package:fl_template/generated/l10n.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class SplashViewModel extends BaseViewModel {
  final _navigationService = locator.get<NavigationService>();
  String get title => S.current.title;

  Future<void> startUp() async {
    await Future.delayed(Duration(seconds: 3));
    _navigationService.navigateTo(AppRoute.homeView, arguments: "Testing");
  }
}