import 'package:fl_template/ui/pages/splash/splash_viewmodel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

class SplashPage extends ViewModelBuilderWidget<SplashViewModel> {

  @override
  Widget builder(BuildContext context, SplashViewModel model, Widget child) {
    return Scaffold(
      body: Center(
        child: Text(model.title),
      ),
    );
  }

  @override
  SplashViewModel viewModelBuilder(BuildContext context) => SplashViewModel();

  @override
  Future<void> onViewModelReady(SplashViewModel model) async {
    await model.startUp();
    super.onViewModelReady(model);
  }
}