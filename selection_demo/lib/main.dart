import 'package:fl_template/app/app_router.dart';
import 'package:fl_template/app/setup_locator.dart';
import 'package:fl_template/generated/l10n.dart';
import 'package:fl_template/app/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:stacked_themes/stacked_themes.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeManager.initialise();
  // sets up the internal locator
  await setupLocator();
  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ThemeBuilder(
      defaultThemeMode: ThemeMode.light,
      darkTheme: darkTheme,
      lightTheme: lightTheme,
      statusBarColorBuilder: (theme) => theme.accentColor,
      builder: (context, regularTheme, darkTheme, themeMode) => MaterialApp(
        title: 'Flutter Demo',
        darkTheme: darkTheme,
        themeMode: themeMode,
        theme: regularTheme,
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        onGenerateRoute: AppRoute.generateRoute,
        initialRoute: AppRoute.splashView,
        navigatorKey: locator<NavigationService>().navigatorKey,
      ),
    );
  }
}
