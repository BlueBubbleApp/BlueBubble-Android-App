import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:battery_optimization/battery_optimization.dart';
import 'package:get/get.dart';

// Dummy controller so we can use [GetBuilder]
class BatteryOptimizationController extends GetxController {}

class BatteryOptimizationPage extends StatelessWidget {
  const BatteryOptimizationPage({Key? key, required this.controller}) : super(key: key);
  final PageController controller;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<BatteryOptimizationController>(
        initState: (_) {
          // If battery optimizations are already disabled, go to the next page
          BatteryOptimization.isIgnoringBatteryOptimizations().then((isDisabled) {
            if (isDisabled!) {
              controller.nextPage(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          });
        },
        init: BatteryOptimizationController(),
        global: false,
        builder: (_) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            systemNavigationBarColor: Theme.of(context).backgroundColor, // navigation bar color
            systemNavigationBarIconBrightness: Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
            statusBarColor: Colors.transparent, // status bar color
          ),
          child: Scaffold(
            backgroundColor: Theme.of(context).accentColor,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      "By default, your phone manufacturer may utilize strict memory management techiques on background processes. As a result, we recommend disabling Battery Optimizations so that the app functions properly and delivers all notifications.",
                      style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(height: 10.0),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      "Click the button below to go to your phone's battery optimization settings where you can disable the it for BlueBubbles.",
                      style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(height: 25.0),
                  CupertinoButton(
                    child: Text("Disable Battery Optimizations"),
                    color: Theme.of(context).primaryColor,
                    onPressed: () async {
                      BatteryOptimization.openBatteryOptimizationSettings();
                    },
                  ),
                  Container(height: 20.0),
                  ClipOval(
                    child: Material(
                      color: Theme.of(context).primaryColor, // button color
                      child: InkWell(
                        child: SizedBox(width: 60, height: 60, child: Icon(Icons.check, color: Colors.white)),
                        onTap: () async {
                          controller.nextPage(
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}
