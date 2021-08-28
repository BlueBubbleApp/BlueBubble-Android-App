import 'dart:async';
import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/socket_singletons.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_details/conversation_details.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator/contact_selector_option.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoNavBar.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_group_widget.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/cupertino.dart' as Cupertino;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:slugify/slugify.dart';

mixin ConversationViewMixin<ConversationViewState extends StatefulWidget> on State<ConversationView> {
  /// Commonly shared variables
  Chat? chat;
  bool? isCreator;
  MessageBloc? messageBloc;

  /// Regular conversation view variables
  OverlayEntry? entry;
  LayerLink layerLink = LayerLink();
  List<String?> newMessages = [];
  bool processingParticipants = false;

  /// Chat selector variables
  List<Chat> conversations = [];
  List<UniqueContact> contacts = [];
  List<UniqueContact> selected = [];
  List<UniqueContact> prevSelected = [];
  String searchQuery = "";
  bool currentlyProcessingDeleteKey = false;
  CurrentChat? currentChat;
  bool markingAsRead = false;
  bool markedAsRead = false;
  String previousSearch = '';
  int previousContactCount = 0;

  final RxBool fetchingCurrentChat = false.obs;

  final _contactStreamController = StreamController<List<UniqueContact>>.broadcast();

  Stream<List<UniqueContact>> get contactStream => _contactStreamController.stream;

  TextEditingController chatSelectorController = new TextEditingController(text: " ");

  /// Conversation view methods
  ///
  ///
  /// ===========================================================
  void initConversationViewState() {
    if (isCreator!) return;
    NotificationManager().switchChat(chat);

    fetchParticipants();
    ContactManager().stream.listen((List<String?> addresses) async {
      fetchParticipants();
    });

    newMessages = ChatBloc()
        .chats
        .where((element) => element != chat && (element.hasUnreadMessage ?? false))
        .map((e) => e.guid)
        .toList();

    EventDispatcher.instance.stream.listen((Map<String, dynamic> event) {
      if (!["add-unread-chat", "remove-unread-chat", "refresh-messagebloc"].contains(event["type"])) return;
      if (!event["data"].containsKey("chatGuid")) return;

      // Ignore any events having to do with this chat
      String? chatGuid = event["data"]["chatGuid"];
      if (chat!.guid == chatGuid) return;

      int preLength = newMessages.length;
      if (event["type"] == "add-unread-chat" && !newMessages.contains(chatGuid)) {
        newMessages.add(chatGuid);
      } else if (event["type"] == "remove-unread-chat" && newMessages.contains(chatGuid)) {
        newMessages.remove(chatGuid);
      }

      // Only re-render if the newMessages count changes
      if (preLength != newMessages.length && this.mounted) setState(() {});
    });

    // Listen for changes in the group
    NewMessageManager().stream.listen((NewMessageEvent event) async {
      // Make sure we have the required data to qualify for this tile
      if (event.chatGuid != widget.chat!.guid) return;
      if (!event.event.containsKey("message")) return;
      if (widget.chat?.guid == null) return;
      // Make sure the message is a group event
      Message message = event.event["message"];
      if (!message.isGroupEvent()) return;

      // If it's a group event, let's fetch the new information and save it
      try {
        await fetchChatSingleton(widget.chat!.guid!);
      } catch (ex) {
        debugPrint(ex.toString());
      }

      setNewChatData(forceUpdate: true);
    });
  }

  void setNewChatData({forceUpdate: false}) async {
    // Save the current participant list and get the latest
    List<Handle> ogParticipants = widget.chat!.participants;
    await widget.chat!.getParticipants();

    // Save the current title and generate the new one
    String? ogTitle = widget.chat!.title;
    await widget.chat!.getTitle();

    // If the original data is different, update the state
    if (ogTitle != widget.chat!.title || ogParticipants.length != widget.chat!.participants.length || forceUpdate) {
      if (this.mounted) setState(() {});
    }
  }

  void didChangeDependenciesConversationView() {
    if (isCreator!) return;
    SocketManager().removeChatNotification(chat!);
  }

  void initCurrentChat(Chat chat) {
    currentChat = CurrentChat.getCurrentChat(chat);
    currentChat!.updateChatAttachments().then((value) {
      if (this.mounted) setState(() {});
    });
  }

  MessageBloc initMessageBloc() {
    messageBloc = new MessageBloc(chat);
    return messageBloc!;
  }

  void dispose() {
    messageBloc?.dispose();
    _contactStreamController.close();
    // NotificationManager().leaveChat();
    super.dispose();
  }

  Future<void> fetchParticipants() async {
    if (chat?.guid == null) return;
    if (isCreator!) return;
    // Prevent multiple calls to fetch participants
    if (processingParticipants) return;
    processingParticipants = true;

    // If we don't have participants, get them
    if (chat!.participants.isEmpty) {
      await chat!.getParticipants();

      // If we have participants, refresh the state
      if (chat!.participants.isNotEmpty) {
        if (this.mounted) setState(() {});
        return;
      }

      debugPrint("(Convo View) No participants found for chat, fetching...");

      try {
        // If we don't have participants, we should fetch them from the server
        Chat? data = await fetchChatSingleton(chat!.guid!);
        // If we got data back, fetch the participants and update the state
        if (data != null) {
          await chat!.getParticipants();
          if (chat!.participants.isNotEmpty) {
            debugPrint("(Convo View) Got new chat participants. Updating state.");
            if (this.mounted) setState(() {});
          } else {
            debugPrint("(Convo View) Participants list is still empty, please contact support!");
          }
        }
      } catch (ex) {
        debugPrint("There was an error fetching the chat");
        debugPrint(ex.toString());
      }
    }

    processingParticipants = false;
  }

  Future<void> openDetails() async {
    Chat _chat = await chat!.getParticipants();
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (context) => ConversationDetails(
          chat: _chat,
          messageBloc: messageBloc ?? initMessageBloc(),
        ),
      ),
    );
  }

  void markChatAsRead() {
    Function setProgress = (bool val) {
      if (this.mounted) {
        setState(() {
          markingAsRead = val;

          if (!val) {
            markedAsRead = true;
          }
        });
      }

      // Unset the marked icon
      Future.delayed(Duration(seconds: 3), () {
        if (this.mounted) {
          setState(() {
            markedAsRead = false;
          });
        }
      });
    };

    // Set that we are
    setProgress(true);

    SocketManager().sendMessage("mark-chat-read", {"chatGuid": chat!.guid}, (data) {
      setProgress(false);
    }).catchError((_) {
      setProgress(false);
    });
  }

  Widget buildCupertinoTrailing() {
    Color? fontColor = Theme.of(context).textTheme.headline1!.color;
    bool manualMark =
        SettingsManager().settings.enablePrivateAPI.value && SettingsManager().settings.privateManualMarkAsRead.value;
    bool showManual = !SettingsManager().settings.privateMarkChatAsRead.value && !(widget.chat?.isGroup() ?? false);
    List<Widget> items = [
      if (showManual && manualMark && markingAsRead)
        Padding(
            padding: EdgeInsets.only(right: SettingsManager().settings.colorblindMode.value ? 15.0 : 10.0),
            child: SettingsManager().settings.skin.value == Skins.iOS
                ? Theme(
                    data: ThemeData(
                      cupertinoOverrideTheme: Cupertino.CupertinoThemeData(
                        brightness: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor),
                      ),
                    ),
                    child: Cupertino.CupertinoActivityIndicator(
                      radius: 12,
                    ),
                  )
                : Container(
                    height: 24,
                    width: 24,
                    child: Center(
                        child: CircularProgressIndicator(
                      strokeWidth: 2,
                    )))),
      if (showManual && manualMark && !markingAsRead)
        Padding(
          padding: EdgeInsets.only(right: SettingsManager().settings.colorblindMode.value ? 10.0 : 5.0),
          child: GestureDetector(
            child: Icon(
              (markedAsRead) ? Icons.check_circle : Icons.check_circle_outline,
              color: (markedAsRead) ? HexColor('32CD32').withAlpha(200) : fontColor,
            ),
            onTap: markChatAsRead,
          ),
        ),
    ];

    if (SettingsManager().settings.showConnectionIndicator.value) {
      items.add(Obx(() => getIndicatorIcon(SocketManager().state.value, size: 12)));
    }

    if (items.length <= 1) {
      items.add(Container(width: 40));
    }

    return Stack(
      alignment: (!SettingsManager().settings.showConnectionIndicator.value || !manualMark)
          ? AlignmentDirectional.center
          : AlignmentDirectional.topEnd,
      children: items,
    );
  }

  Widget buildConversationViewHeader() {
    Color backgroundColor = Theme.of(context).backgroundColor;
    Color? fontColor = Theme.of(context).textTheme.headline1!.color;
    String? title = chat!.title;

    final hideTitle = SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideContactInfo.value;
    final generateTitle =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.generateFakeContactNames.value;

    if (generateTitle)
      title = chat!.fakeParticipants.length > 1 ? "Group Chat" : chat!.fakeParticipants[0];
    else if (hideTitle) fontColor = Colors.transparent;

    if (SettingsManager().settings.skin.value == Skins.Material ||
        SettingsManager().settings.skin.value == Skins.Samsung) {
      return AppBar(
        brightness: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor),
        title: Text(
          title!,
          style: Theme.of(context).textTheme.headline1!.apply(color: fontColor),
        ),
        bottom: PreferredSize(
          child: Container(
            color: Theme.of(context).dividerColor,
            height: 0.5,
          ),
          preferredSize: Size.fromHeight(0.5),
        ),
        backgroundColor: backgroundColor,
        actionsIconTheme: IconThemeData(color: Theme.of(context).primaryColor),
        iconTheme: IconThemeData(color: Theme.of(context).primaryColor),
        actions: [
          Obx(() {
            if (SettingsManager().settings.showConnectionIndicator.value)
              return Obx(() => getIndicatorIcon(SocketManager().state.value, size: 12));
            else
              return SizedBox.shrink();
          }),
          Obx(() {
            if (SettingsManager().settings.privateManualMarkAsRead.value && markingAsRead)
              return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Center(
                      child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)),
                  )));
            else
              return SizedBox.shrink();
          }),
          Obx(() {
            if (SettingsManager().settings.enablePrivateAPI.value &&
                SettingsManager().settings.privateManualMarkAsRead.value &&
                !markingAsRead)
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  child: Icon(
                    (markedAsRead) ? Icons.check_circle : Icons.check_circle_outline,
                    color: (markedAsRead) ? HexColor('32CD32').withAlpha(200) : fontColor,
                  ),
                  onTap: markChatAsRead,
                ),
              );
            else
              return SizedBox.shrink();
          }),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              child: Icon(
                Icons.more_vert,
                color: fontColor,
              ),
              onTap: openDetails,
            ),
          ),
        ],
      );
    }

    // Build the stack
    List<Widget> avatars = [];
    chat!.participants.forEach((Handle participant) {
      avatars.add(
        Container(
          height: 42.0, // 2 px larger than the diameter
          width: 42.0, // 2 px larger than the diameter
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(context).accentColor,
            child: ContactAvatarWidget(
                key: Key("${participant.address}-conversation-view"),
                handle: participant,
                borderThickness: 0.1,
                editable: false,
                onTap: openDetails),
          ),
        ),
      );
    });

    TextStyle? titleStyle = Theme.of(context).textTheme.bodyText1;
    if (!generateTitle && hideTitle) titleStyle = titleStyle!.copyWith(color: Colors.transparent);

    // Calculate separation factor
    // Anything below -60 won't work due to the alignment
    double distance = avatars.length * -4.0;
    if (distance <= -30.0 && distance > -60) distance = -30.0;
    if (distance <= -60.0) distance = -35.0;

    // NOTE: THIS IS ZACH TRYING TO FIX THE NAV BAR (REPLACE IT)
    // IT KINDA WORKED BUT ULTIMATELY FAILED

    // return PreferredSize(
    //     preferredSize: Size(context.width, 80),
    //     child: ClipRect(
    //         child: BackdropFilter(
    //             filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
    //             child: Container(
    //                 decoration: BoxDecoration(
    //                   backgroundBlendMode: BlendMode.color,
    //                   border: Border(
    //                     bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 0.2),
    //                   ),
    //                   color: Theme.of(context).accentColor.withAlpha(125),
    //                 ),
    //                 child: Row(
    //                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //                     crossAxisAlignment: CrossAxisAlignment.center,
    //                     children: [
    //                       GestureDetector(
    //                         onTap: () {
    //                           Navigator.of(context).pop();
    //                         },
    //                         child: Row(
    //                           mainAxisSize: MainAxisSize.min,
    //                           mainAxisAlignment: MainAxisAlignment.start,
    //                           crossAxisAlignment: Cupertino.CrossAxisAlignment.center,
    //                           children: [
    //                             buildBackButton(context),
    //                             if (newMessages.length > 0)
    //                               Container(
    //                                 width: 25.0,
    //                                 height: 20.0,
    //                                 decoration: BoxDecoration(
    //                                     color: Theme.of(context).primaryColor,
    //                                     shape: BoxShape.rectangle,
    //                                     borderRadius: BorderRadius.circular(10)),
    //                                 child: Center(
    //                                     child: Text(newMessages.length.toString(),
    //                                         textAlign: TextAlign.center,
    //                                         style: TextStyle(color: Colors.white, fontSize: 12.0))),
    //                               ),
    //                           ],
    //                         ),
    //                       ),
    //                       GestureDetector(
    //                         onTap: openDetails,
    //                         child: Column(
    //                           crossAxisAlignment: CrossAxisAlignment.center,
    //                           mainAxisAlignment: Cupertino.MainAxisAlignment.center,
    //                           children: [
    //                             RowSuper(
    //                               children: avatars,
    //                               innerDistance: distance,
    //                               alignment: Alignment.center,
    //                             ),
    //                             Container(height: 5.0),
    //                             RichText(
    //                               maxLines: 1,
    //                               overflow: Cupertino.TextOverflow.ellipsis,
    //                               textAlign: TextAlign.center,
    //                               text: TextSpan(
    //                                 style: Theme.of(context).textTheme.headline2,
    //                                 children: [
    //                                   TextSpan(
    //                                     text: title,
    //                                     style: titleStyle,
    //                                   ),
    //                                   TextSpan(
    //                                     text: " >",
    //                                     style: Theme.of(context).textTheme.subtitle1,
    //                                   ),
    //                                 ],
    //                               ),
    //                             ),
    //                           ],
    //                         ),
    //                       ),
    //                       this.buildCupertinoTrailing()
    //                     ])))));

    return CupertinoNavigationBar(
        backgroundColor: Theme.of(context).accentColor.withAlpha(125),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 0.2),
        ),
        leading: GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
          },
          behavior: HitTestBehavior.translucent,
          child: Container(
            width: 40 + (ChatBloc().unreads.value > 0 ? 25 : 0),
            child: Row(
              mainAxisSize: Cupertino.MainAxisSize.min,
              mainAxisAlignment: Cupertino.MainAxisAlignment.start,
              children: [
                buildBackButton(context, callback: () async {
                  await SystemChannels.textInput.invokeMethod('TextInput.hide');
                }),
                if (ChatBloc().unreads.value > 0)
                  Container(
                    width: 25.0,
                    height: 20.0,
                    decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
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
          physics: Cupertino.NeverScrollableScrollPhysics(),
          padding: EdgeInsets.only(right: newMessages.length > 0 ? 10 : 0),
          children: <Widget>[
            Container(height: 10.0),
            GestureDetector(
              onTap: openDetails,
              child: Container(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // RowSuper(
                    //   children: avatars,
                    //   innerDistance: distance,
                    //   alignment: Alignment.center,
                    // ),
                    ContactAvatarGroupWidget(
                      chat: chat!,
                      size: avatars.length == 1 ? 40 : 45,
                      onTap: openDetails,
                    ),
                    if (avatars.length == 1) SizedBox(height: 5.0),
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
                            overflow: Cupertino.TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: Theme.of(context).textTheme.headline2,
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
                            style: Theme.of(context).textTheme.headline2,
                            children: [
                              TextSpan(
                                text: " >",
                                style: Theme.of(context).textTheme.subtitle1,
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
        trailing:
            Obx(() => Container(width: 40 + (ChatBloc().unreads.value > 0 ? 25 : 0), child: buildCupertinoTrailing())));
  }

  /// Chat selector methods
  ///
  ///
  /// ===========================================================
  void initChatSelector() {
    if (!isCreator!) return;

    loadEntries();

    // Add listener to filter the contacts on text change
    chatSelectorController.addListener(() {
      if (chatSelectorController.text.length == 0) {
        if (selected.length > 0 && !currentlyProcessingDeleteKey) {
          currentlyProcessingDeleteKey = true;
          selected.removeLast();
          resetCursor();
          fetchCurrentChat();
          setState(() {});
          // Prevent deletes from occuring multiple times
          Future.delayed(Duration(milliseconds: 100), () {
            currentlyProcessingDeleteKey = false;
          });
        } else {
          resetCursor();
        }
      } else if (chatSelectorController.text[0] != " ") {
        chatSelectorController.text =
            " " + chatSelectorController.text.substring(0, chatSelectorController.text.length - 1);
        chatSelectorController.selection = TextSelection.fromPosition(
          TextPosition(offset: chatSelectorController.text.length),
        );
        setState(() {});
      }
      searchQuery = chatSelectorController.text.substring(1);
      filterContacts();
    });
  }

  void resetCursor() {
    if (!isCreator!) return;
    chatSelectorController.text = " ";
    chatSelectorController.selection = TextSelection.fromPosition(
      TextPosition(offset: 1),
    );
  }

  Future<void> fetchCurrentChat() async {
    if (!isCreator!) return;
    if (selected.length == 1 && selected.first.isChat) {
      chat = selected.first.chat;
    }

    Function clearCurrent = () {
      chat = null;
      messageBloc = null;
      if (this.mounted) setState(() {});
    };

    // If we don't have anything selected, reset the chat and message bloc
    if (selected.length == 0) {
      return clearCurrent();
    }

    // Check and see if there are any matching chats to the select participants
    List<Chat?> matchingChats = [];

    // If it's just one recipient, try manual lookup
    if (selected.length == 1) {
      try {
        Chat? existingChat = await Chat.findOne({"chatIdentifier": slugify(selected[0].address!, delimiter: '')});
        if (existingChat != null) {
          matchingChats.add(existingChat);
        }
      } catch (ex) {}
    }

    if (matchingChats.length == 0) {
      // If we haven't completed the chats request, wait for it to finish
      if (!ChatBloc().chatRequest!.isCompleted) {
        await ChatBloc().chatRequest!.future;
      }

      for (var i in ChatBloc().chats) {
        // If the lengths don't match continue
        if (i.participants.length != selected.length) continue;

        // Iterate over each selected contact
        int matches = 0;
        for (UniqueContact contact in selected) {
          bool match = false;
          bool isEmailAddr = contact.address!.isEmail;
          String lastDigits = contact.address!.substring(contact.address!.length - 4, contact.address!.length);

          for (var participant in i.participants) {
            // If one is an email and the other isn't, skip
            if (isEmailAddr && !participant.address.isEmail) continue;

            // If the last 4 digits don't match, skip
            if (!participant.address.endsWith(lastDigits)) continue;

            // Get a list of comparable options
            List<String?> opts = await getCompareOpts(participant);
            match = sameAddress(opts, contact.address);
            if (match) break;
          }

          if (match) matches += 1;
        }

        if (matches == selected.length) matchingChats.add(i);
      }
    }

    // If there are no matching chats, clear the chat and message bloc
    if (matchingChats.length == 0) {
      return clearCurrent();
    }

    // Sort the chats and take the first one
    matchingChats.sort((a, b) => a!.participants.length.compareTo(b!.participants.length));
    chat = matchingChats.first;

    // Re-initialize the current chat and message bloc for the found chats
    currentChat = CurrentChat.getCurrentChat(chat);
    messageBloc = initMessageBloc();

    // Tell the notification manager that we are looking at a specific chat
    await NotificationManager().switchChat(chat);
    if (this.mounted) setState(() {});
  }

  Future<void> loadEntries() async {
    if (!isCreator!) return;

    // If we don't have chats, fetch them
    if (ChatBloc().chats.isEmpty) {
      await ChatBloc().refreshChats();
    }

    Function setChats = (List<Chat> newChats) async {
      conversations = newChats;
      for (int i = 0; i < conversations.length; i++) {
        if (isNullOrEmpty(conversations[i].participants)!) {
          await conversations[i].getParticipants();
        }
      }

      filterContacts();
    };

    ever(ChatBloc().chats, (List<Chat> chats) async {
      if (chats.length == 0) return;

      // Make sure the contact count changed, otherwise, don't set the chats
      if (chats.length == previousContactCount) return;
      previousContactCount = chats.length;

      // Update and filter the chats
      await setChats(chats);
    });

    // When the chat request is finished, set the chats
    if (ChatBloc().chatRequest != null) {
      await ChatBloc().chatRequest!.future;
      await setChats(ChatBloc().chats);
    }
  }

  void setContacts(List<UniqueContact> contacts, {bool addToStream = true, refreshState = false}) {
    this.contacts = contacts;
    if (addToStream && !_contactStreamController.isClosed) {
      _contactStreamController.sink.add(contacts);
    }

    if (refreshState && this.mounted) {
      setState(() {});
    }
  }

  void filterContacts() {
    if (!isCreator!) return;
    if (selected.length == 1 && selected.first.isChat) {
      this.setContacts([], addToStream: false);
    }

    String Function(String) slugText = (String text) {
      return slugify(text, delimiter: '').toString().replaceAll('-', '');
    };

    // slugify the search query for matching
    searchQuery = slugText(searchQuery);

    List<UniqueContact> _contacts = [];
    List<String> cache = [];
    Function addContactEntries = (Contact contact, {conditionally = false}) {
      for (Item phone in (contact.phones ?? [])) {
        if (phone.value == null) continue;
        String cleansed = slugText(phone.value!);
        if (conditionally && !cleansed.contains(searchQuery)) continue;

        if (!cache.contains(cleansed)) {
          cache.add(cleansed);
          _contacts.add(
            new UniqueContact(
              address: phone.value,
              displayName: contact.displayName,
              label: phone.label,
            ),
          );
        }
      }

      for (Item email in (contact.emails ?? [])) {
        if (email.value == null) continue;
        String emailVal = slugText.call(email.value!);
        if (conditionally && !emailVal.contains(searchQuery)) continue;

        if (!cache.contains(emailVal)) {
          cache.add(emailVal);
          _contacts.add(
            new UniqueContact(
              address: email.value,
              displayName: contact.displayName,
              label: email.label,
            ),
          );
        }
      }
    };

    if (widget.type != ChatSelectorTypes.ONLY_EXISTING) {
      for (Contact contact in ContactManager().contacts) {
        if (contact.displayName == null) continue;
        String name = slugText(contact.displayName!);
        if (name.contains(searchQuery)) {
          addContactEntries(contact);
        } else {
          addContactEntries(contact, conditionally: true);
        }
      }
    }

    List<UniqueContact> _conversations = [];
    if (selected.length == 0 && widget.type != ChatSelectorTypes.ONLY_CONTACTS) {
      for (Chat chat in conversations) {
        if (chat.title == null && chat.displayName == null) continue;
        String title = slugText(chat.title ?? chat.displayName!);
        if (title.contains(searchQuery)) {
          if (!cache.contains(chat.guid)) {
            cache.add(chat.guid!);
            _conversations.add(
              new UniqueContact(
                chat: chat,
                displayName: chat.title,
              ),
            );
          }
        }
      }
    }

    _conversations.addAll(_contacts);
    if (searchQuery.length > 0)
      _conversations.sort((a, b) {
        if (a.isChat && a.chat!.participants.length == 1) return -1;
        if (b.isChat && b.chat!.participants.length == 1) return 1;
        if (a.isChat && !b.isChat) return 1;
        if (b.isChat && !a.isChat) return -1;
        if (!b.isChat && !a.isChat) return 0;
        return a.chat!.participants.length.compareTo(b.chat!.participants.length);
      });

    bool shouldRefreshState = searchQuery != previousSearch || contacts.length == 0 || conversations.length == 0;
    this.setContacts(_conversations, refreshState: shouldRefreshState);
    previousSearch = searchQuery;
  }

  Future<Chat?> createChat() async {
    if (chat != null) return chat;
    Completer<Chat?> completer = Completer();
    if (searchQuery.length > 0) {
      selected.add(new UniqueContact(address: searchQuery, displayName: searchQuery));
    }

    List<String> participants = selected.map((e) => cleansePhoneNumber(e.address!)).toList();
    Map<String, dynamic> params = {};
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Theme.of(context).accentColor,
            title: Text(
              "Creating a new chat...",
              style: Theme.of(context).textTheme.bodyText1,
            ),
            content:
                Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Container(
                // height: 70,
                // color: Colors.black,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                ),
              ),
            ]),
          );
        });

    params["participants"] = participants;
    debugPrint("Starting chat with participants: ${participants.join(", ")}");

    Function returnChat = (Chat newChat) async {
      await newChat.save();
      await ChatBloc().updateChatPosition(newChat);
      completer.complete(newChat);
      Navigator.of(context).pop();
    };

    // If there is only 1 participant, try to find the chat
    Chat? existingChat;
    if (participants.length == 1) {
      existingChat = await Chat.findOne({"chatIdentifier": slugify(participants[0], delimiter: '')});
    }

    if (existingChat == null) {
      SocketManager().sendMessage(
        "start-chat",
        params,
        (data) async {
          if (data['status'] != 200) {
            Navigator.of(context).pop();
            showDialog(
                barrierDismissible: false,
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(
                      "Could not create",
                    ),
                    content: Text(
                      "Reason: (${data["error"]["type"]}) -> ${data["error"]["message"]}",
                    ),
                    actions: [
                      TextButton(
                        child: Text(
                          "Ok",
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      )
                    ],
                  );
                });
            completer.complete(null);
            return;
          }

          // If everything went well, let's add the chat to the bloc
          Chat newChat = Chat.fromMap(data["data"]);
          await returnChat(newChat);
        },
      );
    }

    if (existingChat != null) {
      await returnChat(existingChat);
    }

    return completer.future;
  }

  void onSelected(UniqueContact item) async {
    fetchingCurrentChat.value = true;
    if (item.isChat) {
      if (widget.type == ChatSelectorTypes.ONLY_EXISTING) {
        selected.add(item);
        chat = item.chat;
        this.setContacts([], addToStream: false, refreshState: true);
      } else {
        for (Handle e in item.chat?.participants ?? []) {
          UniqueContact contact = new UniqueContact(
              address: e.address,
              displayName: ContactManager().getCachedContactSync(e.address)?.displayName ?? await formatPhoneNumber(e));
          selected.add(contact);
        }

        await fetchCurrentChat();
      }

      resetCursor();
      if (this.mounted) setState(() {});
      fetchingCurrentChat.value = false;
      return;
    }
    // Add the selected item
    selected.add(item);
    fetchCurrentChat();

    // Reset the controller text
    resetCursor();
    if (this.mounted) setState(() {});
    fetchingCurrentChat.value = false;
  }

  Widget buildChatSelectorBody() => StreamBuilder(
      initialData: contacts,
      stream: contactStream,
      builder: (BuildContext context, AsyncSnapshot<List<UniqueContact>> snapshot) {
        List? data = snapshot.hasData ? snapshot.data : [];
        return ListView.builder(
          physics: ThemeSwitcher.getScrollPhysics(),
          itemBuilder: (BuildContext context, int index) => ContactSelectorOption(
            key: new Key("selector-${data![index].displayName}"),
            item: data[index],
            onSelected: onSelected,
            index: index,
          ),
          itemCount: data?.length ?? 0,
        );
      });

  Widget buildChatSelectorHeader() => PreferredSize(
        preferredSize: Size.fromHeight(40),
        child: Cupertino.CupertinoNavigationBar(
          backgroundColor: Theme.of(context).accentColor.withOpacity(0.5),
          middle: Container(
            child: Text(
              widget.customHeading ?? "New Message",
              style: Theme.of(context).textTheme.headline2,
            ),
          ),
          leading: buildBackButton(context, iconSize: 20),
        ),
      );
}

class UniqueContact {
  final String? displayName;
  final String? label;
  final String? address;
  final Chat? chat;

  bool get isChat => chat != null;

  UniqueContact({this.displayName, this.label, this.address, this.chat});
}
