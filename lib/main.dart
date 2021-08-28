import 'dart:async';
import 'dart:io';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_list.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/settings/about_panel.dart';
import 'package:bluebubbles/layouts/settings/attachment_panel.dart';
import 'package:bluebubbles/layouts/settings/chat_list_panel.dart';
import 'package:bluebubbles/layouts/settings/conversation_panel.dart';
import 'package:bluebubbles/layouts/settings/custom_avatar_color_panel.dart';
import 'package:bluebubbles/layouts/settings/custom_avatar_panel.dart';
import 'package:bluebubbles/layouts/settings/pinned_order_panel.dart';
import 'package:bluebubbles/layouts/settings/private_api_panel.dart';
import 'package:bluebubbles/layouts/settings/redacted_mode_panel.dart';
import 'package:bluebubbles/layouts/settings/server_management_panel.dart';
import 'package:bluebubbles/layouts/settings/theme_panel.dart';
import 'package:bluebubbles/layouts/setup/failure_to_start.dart';
import 'package:bluebubbles/layouts/setup/setup_view.dart';
import 'package:bluebubbles/layouts/testing_mode.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/background_isolate.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/theme_object.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' hide Priority;
import 'package:flutter/services.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:secure_application/secure_application.dart';

// final SentryClient _sentry = SentryClient(
//     dsn:
//         "https://3123d4f0d82d405190cb599d0e904adc@o373132.ingest.sentry.io/5372783");

bool get isInDebugMode {
  // Assume you're in production mode.
  bool inDebugMode = false;

  // Assert expressions are only evaluated during development. They are ignored
  // in production. Therefore, this code only sets `inDebugMode` to true
  // in a development environment.
  assert(inDebugMode = true);

  return inDebugMode;
}

Future<Null> _reportError(dynamic error, dynamic stackTrace) async {
  // Print the exception to the console.
  debugPrint('Caught error: $error');
  if (isInDebugMode) {
    // Print the full stacktrace in debug mode.
    debugPrint(stackTrace.toString());
  } else {
    debugPrint(stackTrace.toString());
    // Send the Exception and Stacktrace to Sentry in Production mode.
    // _sentry.captureException(
    //   exception: error,
    //   stackTrace: stackTrace,
    // );
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      // If there is a bad certificate callback, override it if the host is part of
      // your server URL
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        String serverUrl = getServerAddress() ?? "";
        return serverUrl.contains(host);
      }; // add your localhost detection logic here if you want
  }
}

main() async {
  HttpOverrides.global = new MyHttpOverrides();

  // This captures errors reported by the Flutter framework.
  FlutterError.onError = (FlutterErrorDetails details) {
    if (isInDebugMode) {
      // In development mode simply print to console.
      FlutterError.dumpErrorToConsole(details);
    } else {
      // In production mode report to the application zone to report to
      // Sentry.
      Zone.current.handleUncaughtError(details.exception, details.stack!);
    }
  };

  WidgetsFlutterBinding.ensureInitialized();
  dynamic exception;
  try {
    await DBProvider.db.initDB();
    await initializeDateFormatting('fr_FR', null);
    await SettingsManager().init();
    await SettingsManager().getSavedSettings();
    Get.put(AttachmentDownloadService());
    Get.put(Logger());
    Get.put(LifeCycleManager());
    Get.put(EventDispatcher());
  } catch (e) {
    exception = e;
  }

  if (exception == null) {
    runZonedGuarded<Future<Null>>(() async {
      ThemeObject light = await ThemeObject.getLightTheme();
      ThemeObject dark = await ThemeObject.getDarkTheme();

      runApp(Main(
        lightTheme: light.themeData,
        darkTheme: dark.themeData,
      ));
    }, (Object error, StackTrace stackTrace) async {
      // Whenever an error occurs, call the `_reportError` function. This sends
      // Dart errors to the dev console or Sentry depending on the environment.
      await _reportError(error, stackTrace);
    });
  } else {
    runApp(FailureToStart(e: exception));
    throw Exception(exception);
  }
}

/// The [Main] app.
///
/// This is the entry for the whole app (when the app is visible or not fully closed in the background)
/// This main widget controls
///     - Theming
///     - [NavgatorManager]
///     - [Home] widget
class Main extends StatelessWidget with WidgetsBindingObserver {
  final ThemeData darkTheme;
  final ThemeData lightTheme;
  const Main({Key? key, required this.lightTheme, required this.darkTheme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      /// These are the default white and dark themes.
      /// These will be changed by [SettingsManager] when you set a custom theme
      light: this.lightTheme,
      dark: this.darkTheme,

      /// The default is that the dark and light themes will follow the system theme
      /// This will be changed by [SettingsManager]
      initial: AdaptiveThemeMode.system,
      builder: (theme, darkTheme) => GetMaterialApp(
        /// Hide the debug banner in debug mode
        debugShowCheckedModeBanner: false,

        title: 'BlueBubbles',

        /// Set the light theme from the [AdaptiveTheme]
        theme: theme.copyWith(appBarTheme: theme.appBarTheme.copyWith(elevation: 0.0)),

        /// Set the dark theme from the [AdaptiveTheme]
        darkTheme: darkTheme.copyWith(appBarTheme: darkTheme.appBarTheme.copyWith(elevation: 0.0)),

        /// [Home] is the starting widget for the app
        home: Home(),

        builder: (context, child) => SecureApplication(
          child: Builder(builder: (context) {
            if (SettingsManager().canAuthenticate && !LifeCycleManager.instance.isAlive) {
              if (SettingsManager().settings.shouldSecure.value) {
                SecureApplicationProvider.of(context, listen: false)!.lock();
                if (SettingsManager().settings.securityLevel.value == SecurityLevel.locked_and_secured) {
                  SecureApplicationProvider.of(context, listen: false)!.secure();
                }
              }
            }
            return SecureGate(
              blurr: 0,
              opacity: 1.0,
              lockedBuilder: (context, controller) => Container(
                color: Theme.of(context).backgroundColor,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.0),
                        child: Text(
                          "BlueBubbles is currently locked. Please unlock to access your messages.",
                          style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Container(height: 20.0),
                      ClipOval(
                        child: Material(
                          color: Theme.of(context).primaryColor, // button color
                          child: InkWell(
                            child: SizedBox(width: 60, height: 60, child: Icon(Icons.lock_open, color: Colors.white)),
                            onTap: () async {
                              var localAuth = LocalAuthentication();
                              bool didAuthenticate = await localAuth.authenticate(
                                  localizedReason: 'Please authenticate to unlock BlueBubbles', stickyAuth: true);
                              if (didAuthenticate) {
                                controller!.authSuccess(unlock: true);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              child: child ?? Container(),
            );
          }),
        ),

        defaultTransition: Transition.cupertino,

        getPages: [
          GetPage(page: () => AboutPanel(), name: "/settings/about-panel"),
          GetPage(page: () => AttachmentPanel(), name: "/settings/attachment-panel"),
          GetPage(page: () => ChatListPanel(), name: "/settings/chat-list-panel"),
          GetPage(page: () => ConversationPanel(), name: "/settings/conversation-panel"),
          GetPage(
              page: () => CustomAvatarColorPanel(),
              name: "/settings/custom-avatar-color-panel",
              binding: CustomAvatarColorPanelBinding()),
          GetPage(
              page: () => CustomAvatarPanel(),
              name: "/settings/custom-avatar-panel",
              binding: CustomAvatarPanelBinding()),
          GetPage(page: () => PinnedOrderPanel(), name: "/settings/pinned-order-panel"),
          GetPage(
              page: () => PrivateAPIPanel(), name: "/settings/private-api-panel", binding: PrivateAPIPanelBinding()),
          GetPage(page: () => RedactedModePanel(), name: "/settings/redacted-mode-panel"),
          GetPage(
              page: () => ServerManagementPanel(),
              name: "/settings/server-management-panel",
              binding: ServerManagementPanelBinding()),
          GetPage(
              page: () => TestingMode(),
              name: "/testing-mode",
              binding: TestingModeBinding()),
          GetPage(page: () => ThemePanel(), name: "/settings/theme-panel", binding: ThemePanelBinding()),
        ],
      ),
    );
  }
}

/// [Home] widget is responsible for holding the main UI view.
///
/// It renders the main view and also initializes a few managers
///
/// The [LifeCycleManager] also is binded to the [WidgetsBindingObserver]
/// so that it can know when the app is closed, paused, or resumed
class Home extends StatefulWidget {
  Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    // Initalize a bunch of managers
    SettingsManager().init();
    MethodChannelInterface().init();

    // We initialize the [LifeCycleManager] so that it is open, because [initState] occurs when the app is opened
    LifeCycleManager.instance.opened();

    // This initialization sets the function address in the native code to be used later
    BackgroundIsolateInterface.initialize();

    // Create the notification in case it hasn't been already. Doing this multiple times won't do anything, so we just do it on every app start
    NotificationManager().createNotificationChannel(
      NotificationManager.NEW_MESSAGE_CHANNEL,
      "New Messages",
      "For new messages retreived",
    );
    NotificationManager().createNotificationChannel(
      NotificationManager.SOCKET_ERROR_CHANNEL,
      "Socket Connection Error",
      "Notifications that will appear when the connection to the server has failed",
    );

    // Get the saved settings from the settings manager after the first frame
    SchedulerBinding.instance!.addPostFrameCallback((_) async {
      await SettingsManager().getSavedSettings(context: context);
      // Get sharing media from files shared to the app from cold start
      // This one only handles files, not text
      ReceiveSharingIntent.getInitialMedia().then((List<SharedMediaFile> value) async {
        if (!SettingsManager().settings.finishedSetup.value) return;
        if (value.isEmpty) return;

        // If we don't have storage permission, we can't do anything
        if (!await Permission.storage.request().isGranted) return;

        // Add the attached files to a list
        List<File> attachments = <File>[];
        value.forEach((element) {
          attachments.add(File(element.path));
        });

        if (attachments.length == 0) return;

        // Go to the new chat creator, with all of our attachments
        Navigator.of(context).pushAndRemoveUntil(
          ThemeSwitcher.buildPageRoute(
            builder: (context) => ConversationView(
              existingAttachments: attachments,
              isCreator: true,
            ),
          ),
          (route) => route.isFirst,
        );
      });

      // Same thing as [getInitialMedia] except for text
      ReceiveSharingIntent.getInitialText().then((String? text) {
        if (!SettingsManager().settings.finishedSetup.value) return;
        if (text == null) return;

        // Go to the new chat creator, with all of our text
        Navigator.of(context).pushAndRemoveUntil(
          ThemeSwitcher.buildPageRoute(
            builder: (context) => ConversationView(
              existingText: text,
              isCreator: true,
            ),
          ),
          (route) => route.isFirst,
        );
      });

      // Request native code to retreive what the starting intent was
      //
      // The starting intent will be set when you click on a notification
      // This is only really necessary when opening a notification and the app is fully closed
      MethodChannelInterface().invokeMethod("get-starting-intent").then((value) {
        if (!SettingsManager().settings.finishedSetup.value) return;
        if (value != null) {
          // Open that chat
          MethodChannelInterface().openChat(value.toString());
        }
      });
    });

    // Bind the lifecycle events
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void didChangeDependencies() async {
    Locale myLocale = Localizations.localeOf(context);
    SettingsManager().countryCode = myLocale.countryCode;
    SettingsManager().settings.use24HrFormat.value = MediaQuery.of(Get.context!).alwaysUse24HourFormat;
    await FlutterLibphonenumber().init();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    // Clean up observer when app is fully closed
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  /// Called when the app is either closed or opened or paused
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Call the [LifeCycleManager] events based on the [state]
    if (state == AppLifecycleState.paused) {
      LifeCycleManager.instance.close();
    } else if (state == AppLifecycleState.resumed) {
      LifeCycleManager.instance.opened();
    }
  }

  /// Render
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: Theme.of(context).backgroundColor, // navigation bar color
      systemNavigationBarIconBrightness:
          Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
      statusBarColor: Colors.transparent, // status bar color
    ));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        // The stream builder connects to the [SocketManager] to check if the app has finished the setup or not
        body: StreamBuilder(
          stream: SocketManager().finishedSetup.stream,
          builder: (BuildContext context, AsyncSnapshot<bool?> snapshot) {
            if (snapshot.hasData) {
              // If the app has already gone through setup, show the convo list
              // Otherwise show the setup
              if (snapshot.data!) {
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.landscapeRight,
                  DeviceOrientation.landscapeLeft,
                  DeviceOrientation.portraitUp,
                  DeviceOrientation.portraitDown,
                ]);
                return ConversationList(
                  showArchivedChats: false,
                );
              } else {
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                ]);
                return WillPopScope(
                  onWillPop: () async => false,
                  child: SetupView(),
                );
              }
            } else {
              return Container();
            }
          },
        ),
      ),
    );
  }
}
