import 'dart:math';
import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:assorted_layout_widgets/assorted_layout_widgets.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/layouts/conversation_view/messages_view.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:faker/faker.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoNavBar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class ThemeSelectorController extends GetxController {
  late Widget messagesView;
  final RxInt selectedTheme = 3.obs;
  final RxInt selectedSkin = 1.obs;

  @override
  void onInit() {
    setMessagesView();
    ever(selectedTheme, (_) {
      AdaptiveTheme.of(Get.context!).setThemeMode(AdaptiveThemeMode.values[selectedTheme.value - 1]);
    });
    ever(selectedSkin, (_) {
      SettingsManager().settings.skin.value = Skins.values[selectedSkin.value - 1];
      setMessagesView();
      update();
    });
    super.onInit();
  }

  void setMessagesView() {
    /*messagesView = MessagesView(
      messageBloc: MessageBloc(
        Chat(
            id: 69,
            guid: 'theme-selector',
            displayName: "Sample Chat",
            participants: [
              Handle(
                  id: -1,
                  address: "John Doe"
              ),
              Handle(
                  id: -2,
                  address: "Jane Doe"
              ),
              Handle(
                  id: -3,
                  address: "You"
              ),
            ]
        ),
      ),
      chat: Chat(
          id: 69,
          guid: 'theme-selector',
          displayName: "Sample Chat",
          participants: [
            Handle(
                id: -1,
                address: "John Doe"
            ),
            Handle(
                id: -2,
                address: "Jane Doe"
            ),
            Handle(
                id: -3,
                address: "You"
            ),
          ]
      ),
      showHandle: true,
      messages: [
        Message(
          guid: "theme-selector-4",
          dateCreated: DateTime(1, 1, 2021, 9, 40),
          dateDelivered: DateTime(1, 1, 2021, 9, 41),
          isFromMe: false,
          hasReactions: false,
          hasAttachments: false,
          text: faker.lorem.words(5).join(" "),
          handle: Handle(
            id: -2,
            address: "Jane Doe",
          ),
        ),
        Message(
          guid: "theme-selector-3",
          dateCreated: DateTime(1, 1, 2021, 9, 40),
          dateDelivered: DateTime(1, 1, 2021, 9, 41),
          isFromMe: true,
          hasReactions: true,
          hasAttachments: false,
          text: faker.lorem.words(15).join(" "),
          handle: Handle(
            id: -3,
            address: "You",
          ),
          associatedMessages: [
            Message(
              guid: "theme-selector-3",
              text: "Jane Doe laughed at a message you sent",
              associatedMessageType: "laugh",
              isFromMe: false,
            ),
          ],
        ),
        Message(
          guid: "theme-selector-2",
          dateCreated: DateTime(1, 1, 2021, 9, 45),
          dateDelivered: DateTime(1, 1, 2021, 9, 46),
          isFromMe: false,
          hasReactions: true,
          hasAttachments: true,
          text: faker.lorem.words(20).join(" "),
          handle: Handle(
            id: -1,
            address: "John Doe",
          ),
          associatedMessages: [
            Message(
              guid: "theme-selector-2",
              text: "Jane Doe liked a message you sent",
              associatedMessageType: "like",
              isFromMe: true,
            ),
          ],
          attachments: [
            Attachment(
              guid: "theme-selector-attachment",
              originalROWID: Random.secure().nextInt(10000),
              transferName: "assets/icon/icon.png",
              mimeType: "image/png",
              width: 200,
              height: 200,
            )
          ],
        ),
        Message(
          guid: "theme-selector-1",
          dateCreated: DateTime(1, 1, 2021, 9, 40),
          dateDelivered: DateTime(1, 1, 2021, 9, 41),
          isFromMe: true,
          hasReactions: false,
          hasAttachments: false,
          text: faker.lorem.words(10).join(" "),
          handle: Handle(
            id: -3,
            address: "You",
          ),
        ),
      ],
    );*/
  }
}

class ThemeSelector extends StatelessWidget {
  final ThemeSelectorController controller = Get.put(ThemeSelectorController());

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeSelectorController>(
      builder: (_) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
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
                      "Select your app theme and skin",
                      style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(height: 50.0),
                  Obx(() => Container(
                    width: 350,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                controller.selectedTheme.value = 1;
                              },
                              child: Container(
                                padding: EdgeInsets.all(3),
                                height: 200,
                                width: 100,
                                decoration: controller.selectedTheme.value == 1 ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ) : null,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(17),
                                  child: AbsorbPointer(
                                    absorbing: true,
                                    child: SizedBox.expand(
                                        child: FittedBox(
                                            fit: BoxFit.fitHeight,
                                            alignment: Alignment.centerLeft,
                                            child: SizedBox(
                                              width: MediaQuery.of(context).size.width,
                                              height: MediaQuery.of(context).size.height,
                                              child: Theme(
                                                data: whiteLightTheme,
                                                child: Container(
                                                  color: whiteLightTheme.backgroundColor,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(bottom: 28.0),
                                                    child: Skin(
                                                      skin: Skins.values[controller.selectedSkin.value - 1],
                                                      child: Builder(
                                                          builder: (context) {
                                                            return Scaffold(
                                                                appBar: buildConversationViewHeader(context, Chat(
                                                                    id: 69,
                                                                    guid: 'theme-selector',
                                                                    displayName: "Sample Chat",
                                                                    participants: [
                                                                      Handle(
                                                                          id: -1,
                                                                          address: "John Doe"
                                                                      ),
                                                                      Handle(
                                                                          id: -2,
                                                                          address: "Jane Doe"
                                                                      ),
                                                                      Handle(
                                                                          id: -3,
                                                                          address: "You"
                                                                      ),
                                                                    ]
                                                                ), whiteLightTheme) as PreferredSizeWidget?,
                                                                body: controller.messagesView
                                                            );
                                                          }
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                        )
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text("Light"),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                controller.selectedTheme.value = 2;
                              },
                              child: Container(
                                padding: EdgeInsets.all(3),
                                height: 200,
                                width: 100,
                                decoration: controller.selectedTheme.value == 2 ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ) : null,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(17),
                                  child: AbsorbPointer(
                                    absorbing: true,
                                    child: SizedBox.expand(
                                        child: FittedBox(
                                            fit: BoxFit.fitHeight,
                                            alignment: Alignment.centerLeft,
                                            child: SizedBox(
                                              width: MediaQuery.of(context).size.width,
                                              height: MediaQuery.of(context).size.height,
                                              child: Theme(
                                                data: oledDarkTheme,
                                                child: Container(
                                                  color: oledDarkTheme.backgroundColor,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(bottom: 28.0),
                                                    child: Skin(
                                                      skin: Skins.values[controller.selectedSkin.value - 1],
                                                      child: Builder(
                                                          builder: (context) {
                                                            return Scaffold(
                                                                backgroundColor: oledDarkTheme.backgroundColor,
                                                                appBar: buildConversationViewHeader(context, Chat(
                                                                    id: 69,
                                                                    guid: 'theme-selector',
                                                                    displayName: "Sample Chat",
                                                                    participants: [
                                                                      Handle(
                                                                          id: -1,
                                                                          address: "John Doe"
                                                                      ),
                                                                      Handle(
                                                                          id: -2,
                                                                          address: "Jane Doe"
                                                                      ),
                                                                      Handle(
                                                                          id: -3,
                                                                          address: "You"
                                                                      ),
                                                                    ]
                                                                ), oledDarkTheme) as PreferredSizeWidget?,
                                                                body: controller.messagesView
                                                            );
                                                          }
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                        )
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text("Dark"),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                controller.selectedTheme.value = 3;
                              },
                              child: Container(
                                padding: EdgeInsets.all(3),
                                height: 200,
                                width: 100,
                                decoration: controller.selectedTheme.value == 3 ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ) : null,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(17),
                                  child: Skin(
                                    skin: Skins.values[controller.selectedSkin.value - 1],
                                    child: Stack(
                                        children: [
                                          Material(
                                            shape: TriangleBorder(section: Section.TOP),
                                            clipBehavior: Clip.antiAlias,
                                            color: whiteLightTheme.backgroundColor,
                                            child: AbsorbPointer(
                                              absorbing: true,
                                              child: SizedBox.expand(
                                                  child: FittedBox(
                                                      fit: BoxFit.fitHeight,
                                                      alignment: Alignment.centerLeft,
                                                      child: SizedBox(
                                                        width: MediaQuery.of(context).size.width,
                                                        height: MediaQuery.of(context).size.height,
                                                        child: Theme(
                                                          data: whiteLightTheme,
                                                          child: Container(
                                                            color: whiteLightTheme.backgroundColor,
                                                            child: Padding(
                                                              padding: const EdgeInsets.only(bottom: 28.0),
                                                              child: Builder(
                                                                  builder: (context) {
                                                                    return Scaffold(
                                                                        backgroundColor: whiteLightTheme.backgroundColor,
                                                                        appBar: buildConversationViewHeader(context, Chat(
                                                                            id: 69,
                                                                            guid: 'theme-selector',
                                                                            displayName: "Sample Chat",
                                                                            participants: [
                                                                              Handle(
                                                                                  id: -1,
                                                                                  address: "John Doe"
                                                                              ),
                                                                              Handle(
                                                                                  id: -2,
                                                                                  address: "Jane Doe"
                                                                              ),
                                                                              Handle(
                                                                                  id: -3,
                                                                                  address: "You"
                                                                              ),
                                                                            ]
                                                                        ), whiteLightTheme) as PreferredSizeWidget?,
                                                                        body: controller.messagesView
                                                                    );
                                                                  }
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                  )
                                              ),
                                            ),
                                          ),
                                          Material(
                                            shape: TriangleBorder(section: Section.BOTTOM),
                                            clipBehavior: Clip.antiAlias,
                                            color: oledDarkTheme.backgroundColor,
                                            child: AbsorbPointer(
                                              absorbing: true,
                                              child: SizedBox.expand(
                                                  child: FittedBox(
                                                      fit: BoxFit.fitHeight,
                                                      alignment: Alignment.centerLeft,
                                                      child: SizedBox(
                                                        width: MediaQuery.of(context).size.width,
                                                        height: MediaQuery.of(context).size.height,
                                                        child: Theme(
                                                          data: oledDarkTheme,
                                                          child: Container(
                                                            color: oledDarkTheme.backgroundColor,
                                                            child: Padding(
                                                              padding: const EdgeInsets.only(bottom: 28.0),
                                                              child: Builder(
                                                                  builder: (context) {
                                                                    return Scaffold(
                                                                        backgroundColor: oledDarkTheme.backgroundColor,
                                                                        appBar: buildConversationViewHeader(context, Chat(
                                                                            id: 69,
                                                                            guid: 'theme-selector',
                                                                            displayName: "Sample Chat",
                                                                            participants: [
                                                                              Handle(
                                                                                  id: -1,
                                                                                  address: "John Doe"
                                                                              ),
                                                                              Handle(
                                                                                  id: -2,
                                                                                  address: "Jane Doe"
                                                                              ),
                                                                              Handle(
                                                                                  id: -3,
                                                                                  address: "You"
                                                                              ),
                                                                            ]
                                                                        ), oledDarkTheme) as PreferredSizeWidget?,
                                                                        body: controller.messagesView
                                                                    );
                                                                  }
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                  )
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 5, left: 5,
                                            child: Icon(Icons.light_mode, color: Theme.of(context).primaryColor),
                                          ),
                                          Positioned(
                                            bottom: 5, right: 5,
                                            child: Icon(Icons.dark_mode, color: Theme.of(context).primaryColor),
                                          ),
                                        ]
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text("System"),
                            ),
                          ],
                        )
                      ],
                    ),
                  )),
                  Container(height: 50.0, child: Divider(height: 2, color: Colors.grey,), padding: EdgeInsets.symmetric(horizontal: 15)),
                  Obx(() =>  Container(
                    width: 250,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                controller.selectedSkin.value = 1;
                              },
                              child: Container(
                                padding: EdgeInsets.all(3),
                                height: 200,
                                width: 100,
                                decoration: controller.selectedSkin.value == 1 ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ) : null,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(17),
                                  child: AbsorbPointer(
                                    absorbing: true,
                                    child: SizedBox.expand(
                                        child: FittedBox(
                                            fit: BoxFit.fitHeight,
                                            alignment: Alignment.centerLeft,
                                            child: SizedBox(
                                              width: MediaQuery.of(context).size.width,
                                              height: MediaQuery.of(context).size.height,
                                              child: Theme(
                                                  data: Theme.of(context),
                                                  child: Skin(
                                                    skin: Skins.iOS,
                                                    child: Container(
                                                      color: Theme.of(context).backgroundColor,
                                                      child: Padding(
                                                        padding: const EdgeInsets.only(bottom: 28.0),
                                                        child: Builder(
                                                            builder: (context) {
                                                              return Scaffold(
                                                                  backgroundColor: Theme.of(context).backgroundColor,
                                                                  appBar: buildConversationViewHeader(context, Chat(
                                                                      id: 69,
                                                                      guid: 'theme-selector',
                                                                      displayName: "Sample Chat",
                                                                      participants: [
                                                                        Handle(
                                                                            id: -1,
                                                                            address: "John Doe"
                                                                        ),
                                                                        Handle(
                                                                            id: -2,
                                                                            address: "Jane Doe"
                                                                        ),
                                                                        Handle(
                                                                            id: -3,
                                                                            address: "You"
                                                                        ),
                                                                      ]
                                                                  ), Theme.of(context)) as PreferredSizeWidget?,
                                                                  body: controller.messagesView
                                                              );
                                                            }
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                              ),
                                            )
                                        )
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text("iOS"),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                controller.selectedSkin.value = 2;
                              },
                              child: Container(
                                padding: EdgeInsets.all(3),
                                height: 200,
                                width: 100,
                                decoration: controller.selectedSkin.value == 2 ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ) : null,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(17),
                                  child: AbsorbPointer(
                                    absorbing: true,
                                    child: SizedBox.expand(
                                        child: FittedBox(
                                            fit: BoxFit.fitHeight,
                                            alignment: Alignment.centerLeft,
                                            child: SizedBox(
                                              width: MediaQuery.of(context).size.width,
                                              height: MediaQuery.of(context).size.height,
                                              child: Theme(
                                                  data: Theme.of(context),
                                                  child: Skin(
                                                    skin: Skins.Material,
                                                    child: Container(
                                                      color: Theme.of(context).backgroundColor,
                                                      child: Padding(
                                                        padding: const EdgeInsets.only(bottom: 28.0),
                                                        child: Builder(
                                                            builder: (context) {
                                                              return Scaffold(
                                                                  backgroundColor: Theme.of(context).backgroundColor,
                                                                  appBar: buildConversationViewHeader(context, Chat(
                                                                      id: 69,
                                                                      guid: 'theme-selector',
                                                                      displayName: "Sample Chat",
                                                                      participants: [
                                                                        Handle(
                                                                            id: -1,
                                                                            address: "John Doe"
                                                                        ),
                                                                        Handle(
                                                                            id: -2,
                                                                            address: "Jane Doe"
                                                                        ),
                                                                        Handle(
                                                                            id: -3,
                                                                            address: "You"
                                                                        ),
                                                                      ]
                                                                  ), Theme.of(context)) as PreferredSizeWidget?,
                                                                  body: controller.messagesView
                                                              );
                                                            }
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                              ),
                                            )
                                        )
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text("Material"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )),
                  Container(height: 20.0),
                  ClipOval(
                    child: Material(
                      color: Theme.of(context).primaryColor, // button color
                      child: InkWell(
                        child: SizedBox(width: 60, height: 60, child: Icon(Icons.check, color: Colors.white)),
                        onTap: () async {
                          goToNextPage();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void goToNextPage() {
    SocketManager().toggleSetupFinished(true, applyToDb: true);
  }
}

class Skin extends InheritedWidget {
  final Skins skin;

  const Skin({
    Key? key,
    required Widget child,
    required this.skin,
  }) : super(key: key, child: child);

  static Skin? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<Skin>();
  }

  @override
  bool updateShouldNotify(Skin oldWidget) => false;
}

enum Section {TOP, BOTTOM}

class TriangleBorder extends ShapeBorder {
  final Section section;

  TriangleBorder({required this.section});

  @override
  EdgeInsetsGeometry get dimensions {
    return EdgeInsets.all(0);
  }

  @override
  ShapeBorder scale(double t) => this;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path();
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    var size = rect.size;
    var path = Path();
    if (section == Section.TOP){
      path.lineTo(size.width - 3, 0);
      path.lineTo(0, size.height - 3);
    } else {
      path.moveTo(size.width, size.height);
      path.lineTo(3, size.height);
      path.lineTo(size.width, 3);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}
}

Widget buildConversationViewHeader(BuildContext context, Chat chat, ThemeData theme) {
  Color backgroundColor = theme.backgroundColor;
  Color? fontColor = theme.textTheme.headline1!.color;
  String? title = chat.title ?? chat.displayName;
  Skins skin = Skin.of(context)!.skin;
  if (skin == Skins.Material ||
      skin == Skins.Samsung) {
    return AppBar(
      brightness: ThemeData.estimateBrightnessForColor(theme.backgroundColor),
      elevation: 0.0,
      title: Text(
        title!,
        style: theme.textTheme.headline1!.apply(color: fontColor),
      ),
      bottom: PreferredSize(
        child: Container(
          color: theme.dividerColor,
          height: 0.5,
        ),
        preferredSize: Size.fromHeight(0.5),
      ),
      leading: buildBackButton(context, skin: skin),
      backgroundColor: backgroundColor,
      actionsIconTheme: IconThemeData(color: theme.primaryColor),
      iconTheme: IconThemeData(color: theme.primaryColor),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: GestureDetector(
            child: Icon(
              Icons.more_vert,
              color: fontColor,
            ),
            onTap: () {},
          ),
        ),
      ],
    );
  }

  // Build the stack
  List<Widget> avatars = [];
  chat.participants.forEach((Handle participant) {
    avatars.add(
      Container(
        height: 42.0, // 2 px larger than the diameter
        width: 42.0, // 2 px larger than the diameter
        child: CircleAvatar(
          radius: 20,
          backgroundColor: theme.accentColor,
          child: ContactAvatarWidget(handle: participant, borderThickness: 0.1, editable: false, onTap: () {}),
        ),
      ),
    );
  });

  TextStyle? titleStyle = theme.textTheme.bodyText1;

  // Calculate separation factor
  // Anything below -60 won't work due to the alignment
  double distance = avatars.length * -4.0;
  if (distance <= -30.0 && distance > -60) distance = -30.0;
  if (distance <= -60.0) distance = -35.0;

  return CupertinoNavigationBar(
      backgroundColor: theme.accentColor.withAlpha(125),
      border: Border(
        bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 0.2),
      ),
      leading: GestureDetector(
        onTap: () {
          Navigator.of(context).pop();
        },
        child: Container(
          width: 40 + (ChatBloc().unreads.value > 0 ? 25 : 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              buildBackButton(context, skin: skin),
              if (ChatBloc().unreads.value > 0)
                Container(
                  width: 25.0,
                  height: 20.0,
                  decoration: BoxDecoration(
                      color: theme.primaryColor,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(
                      child: Text(ChatBloc().unreads.value.toString(),
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 12.0))),
                ),
            ],
          ),
        ),
      ),
      middle: ListView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(right: ChatBloc().unreads.value > 0 ? 10 : 0),
        children: <Widget>[
          Container(height: 10.0),
          GestureDetector(
            onTap: () {},
            child: Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  RowSuper(
                    children: avatars,
                    innerDistance: distance,
                    alignment: Alignment.center,
                  ),
                  Container(height: 5.0),
                  Center(
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: context.width / 2,
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: context.width / 2 - 55,
                            ),
                            child: RichText(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: theme.textTheme.headline2,
                                children: [
                                  TextSpan(
                                    text: title,
                                    style: titleStyle,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              style: theme.textTheme.headline2,
                              children: [
                                TextSpan(
                                  text: " >",
                                  style: theme.textTheme.subtitle1,
                                ),
                              ],
                            ),
                          ),
                        ]),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
      trailing: Obx(() => Container(width: 40 + (ChatBloc().unreads.value > 0 ? 25 : 0))));
}