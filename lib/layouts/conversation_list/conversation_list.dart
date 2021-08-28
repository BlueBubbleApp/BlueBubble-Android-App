import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/setup_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/conversation_list/pinned_conversation_tile.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/search/search_view.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class ConversationList extends StatefulWidget {
  ConversationList({Key? key, required this.showArchivedChats}) : super(key: key);

  final bool showArchivedChats;

  @override
  _ConversationListState createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  Color? currentHeaderColor;
  bool hasPinnedChats = false;

  // ignore: close_sinks
  StreamController<Color?> headerColorStream = StreamController<Color?>.broadcast();

  late ScrollController scrollController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (this.mounted) {
      theme = Colors.transparent;
    }

    SystemChannels.textInput.invokeMethod('TextInput.hide').catchError((e) {
      debugPrint("Error caught while hiding keyboard: ${e.toString()}");
    });
  }

  @override
  void dispose() {
    super.dispose();

    // Remove the scroll listener from the state
    scrollController.removeListener(scrollListener);
  }

  @override
  void initState() {
    super.initState();
    ChatBloc().refreshChats();
    scrollController = ScrollController()..addListener(scrollListener);

    // Listen for any incoming events
    EventDispatcher.instance.stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'refresh' && this.mounted) {
        setState(() {});
      }
    });
  }

  Color? get theme => currentHeaderColor;

  set theme(Color? color) {
    if (currentHeaderColor == color) return;
    currentHeaderColor = color;
    if (!headerColorStream.isClosed) headerColorStream.sink.add(currentHeaderColor);
  }

  void scrollListener() {
    !_isAppBarExpanded ? theme = Colors.transparent : theme = context.theme.accentColor.withOpacity(0.5);
  }

  bool get _isAppBarExpanded {
    return scrollController.hasClients && scrollController.offset > (125 - kToolbarHeight);
  }

  List<Widget> getHeaderTextWidgets({double? size}) {
    TextStyle? style = context.textTheme.headline1;
    if (size != null) style = style!.copyWith(fontSize: size);

    return [Text(widget.showArchivedChats ? "Archive" : "Messages", style: style), Container(width: 10)];
  }

  Widget getSyncIndicatorWidget() {
    return Obx(() {
      if (!SettingsManager().settings.showSyncIndicator.value) return SizedBox.shrink();
      if (!SetupBloc().isSyncing.value) return Container();
      return buildProgressIndicator(context, size: 10);
    });
  }

  void openNewChatCreator() async {
    bool shouldShowSnackbar = (await SettingsManager().getMacOSVersion())! >= 11;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (BuildContext context) {
          return ConversationView(
            isCreator: true,
            showSnackbar: shouldShowSnackbar,
          );
        },
      ),
    );
  }

  void sortChats() {
    ChatBloc().chats.sort((a, b) {
      if (a.pinIndex.value != null && b.pinIndex.value != null)
        return a.pinIndex.value!.compareTo(b.pinIndex.value!);
      if (b.pinIndex.value != null) return 1;
      if (a.pinIndex.value != null) return -1;
      if (!a.isPinned! && b.isPinned!) return 1;
      if (a.isPinned! && !b.isPinned!) return -1;
      if (a.latestMessageDate == null && b.latestMessageDate == null) return 0;
      if (a.latestMessageDate == null) return 1;
      if (b.latestMessageDate == null) return -1;
      return -a.latestMessageDate!.compareTo(b.latestMessageDate!);
    });
  }

  Widget buildSettingsButton() => !widget.showArchivedChats
      ? PopupMenuButton(
          color: context.theme.accentColor,
          onSelected: (dynamic value) {
            if (value == 0) {
              ChatBloc().markAllAsRead();
            } else if (value == 1) {
              Navigator.of(context).push(
                ThemeSwitcher.buildPageRoute(
                  builder: (context) => ConversationList(
                    showArchivedChats: true,
                  ),
                ),
              );
            } else if (value == 2) {
              Navigator.of(context).push(
                ThemeSwitcher.buildPageRoute(
                  builder: (BuildContext context) {
                    return SettingsPanel();
                  },
                ),
              );
            }
          },
          itemBuilder: (context) {
            return <PopupMenuItem>[
              PopupMenuItem(
                value: 0,
                child: Text(
                  'Mark all as read',
                  style: context.textTheme.bodyText1,
                ),
              ),
              PopupMenuItem(
                value: 1,
                child: Text(
                  'Archived',
                  style: context.textTheme.bodyText1,
                ),
              ),
              PopupMenuItem(
                value: 2,
                child: Text(
                  'Settings',
                  style: context.textTheme.bodyText1,
                ),
              ),
            ];
          },
          child: ThemeSwitcher(
            iOSSkin: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                color: context.theme.accentColor,
              ),
              child: Icon(
                Icons.more_horiz,
                color: context.theme.primaryColor,
                size: 15,
              ),
            ),
            materialSkin: Icon(
              Icons.more_vert,
              color: context.textTheme.bodyText1!.color,
              size: 25,
            ),
            samsungSkin: Icon(
              Icons.more_vert,
              color: context.textTheme.bodyText1!.color,
              size: 25,
            ),
          ),
        )
      : Container();

  FloatingActionButton buildFloatingActionButton() {
    return FloatingActionButton(
        backgroundColor: context.theme.primaryColor,
        child: Icon(Icons.message, color: Colors.white, size: 25),
        onPressed: openNewChatCreator);
  }

  List<Widget> getConnectionIndicatorWidgets() {
    if (!SettingsManager().settings.showConnectionIndicator.value) return [];

    return [Obx(() => getIndicatorIcon(SocketManager().state.value, size: 12)), Container(width: 10.0)];
  }

  @override
  Widget build(BuildContext context) {
    return ThemeSwitcher(
      iOSSkin: _Cupertino(parent: this),
      materialSkin: _Material(parent: this),
      samsungSkin: _Samsung(parent: this),
    );
  }
}

class _Cupertino extends StatelessWidget {
  const _Cupertino({Key? key, required this.parent}) : super(key: key);

  final _ConversationListState parent;

  @override
  Widget build(BuildContext context) {
    bool showArchived = parent.widget.showArchivedChats;
    Brightness brightness = ThemeData.estimateBrightnessForColor(context.theme.backgroundColor);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: context.theme.backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            context.theme.backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Obx(
        () => Scaffold(
          appBar: PreferredSize(
            preferredSize: Size(
              context.width,
              SettingsManager().settings.reducedForehead.value ? 10 : 40,
            ),
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: StreamBuilder<Color?>(
                  stream: parent.headerColorStream.stream,
                  builder: (context, snapshot) {
                    return AnimatedCrossFade(
                      crossFadeState:
                          parent.theme == Colors.transparent ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                      duration: Duration(milliseconds: 250),
                      secondChild: AppBar(
                        iconTheme: IconThemeData(color: context.theme.primaryColor),
                        elevation: 0,
                        backgroundColor: parent.theme,
                        centerTitle: true,
                        brightness: brightness,
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            Text(
                              showArchived ? "Archive" : "Messages",
                              style: context.textTheme.bodyText1,
                            ),
                          ],
                        ),
                      ),
                      firstChild: AppBar(
                        leading: new Container(),
                        elevation: 0,
                        brightness: brightness,
                        backgroundColor: context.theme.backgroundColor,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          backgroundColor: context.theme.backgroundColor,
          extendBodyBehindAppBar: true,
          body: CustomScrollView(
            controller: parent.scrollController,
            physics: ThemeManager().scrollPhysics,
            slivers: <Widget>[
              SliverAppBar(
                leading: ((SettingsManager().settings.skin.value == Skins.iOS && showArchived) ||
                        (SettingsManager().settings.skin.value == Skins.Material ||
                                SettingsManager().settings.skin.value == Skins.Samsung) &&
                            !showArchived)
                    ? IconButton(
                        icon: Icon(
                            (SettingsManager().settings.skin.value == Skins.iOS && showArchived)
                                ? Icons.arrow_back_ios
                                : Icons.arrow_back,
                            color: context.theme.primaryColor),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      )
                    : new Container(),
                stretch: true,
                expandedHeight: (!showArchived) ? 80 : 50,
                backgroundColor: Colors.transparent,
                pinned: false,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: <StretchMode>[StretchMode.zoomBackground],
                  background: Stack(
                    fit: StackFit.expand,
                  ),
                  centerTitle: true,
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(height: 20),
                      Container(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: <Widget>[
                            Container(width: (!showArchived) ? 20 : 50),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ...parent.getHeaderTextWidgets(),
                                ...parent.getConnectionIndicatorWidgets(),
                                parent.getSyncIndicatorWidget(),
                              ],
                            ),
                            Spacer(
                              flex: 25,
                            ),
                            if (!showArchived)
                              ClipOval(
                                child: Material(
                                  color: context.theme.accentColor, // button color
                                  child: InkWell(
                                    child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Icon(Icons.search, color: context.theme.primaryColor, size: 12)),
                                    onTap: () async {
                                      Navigator.of(context).push(
                                        CupertinoPageRoute(
                                          builder: (context) => SearchView(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            if (!showArchived) Container(width: 10.0),
                            if (SettingsManager().settings.moveChatCreatorToHeader.value && !showArchived)
                              ClipOval(
                                child: Material(
                                  color: context.theme.accentColor, // button color
                                  child: InkWell(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Icon(Icons.create, color: context.theme.primaryColor, size: 12),
                                    ),
                                    onTap: this.parent.openNewChatCreator,
                                  ),
                                ),
                              ),
                            if (SettingsManager().settings.moveChatCreatorToHeader.value) Container(width: 10.0),
                            parent.buildSettingsButton(),
                            Spacer(
                              flex: 3,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // SliverToBoxAdapter(
              //   child: Container(
              //     padding: EdgeInsets.symmetric(horizontal: 30, vertical: 5),
              //     child: GestureDetector(
              //       onTap: () {
              //         Navigator.of(context).push(
              //           MaterialPageRoute(
              //             builder: (context) => SearchView(),
              //           ),
              //         );
              //       },
              //       child: AbsorbPointer(
              //         child: SearchTextBox(),
              //       ),
              //     ),
              //   ),
              // ),
              Obx(() {
                if (ChatBloc().chats.archivedHelper(showArchived).bigPinHelper(true).isEmpty) {
                  return SliverToBoxAdapter(child: Container());
                }
                ChatBloc().chats.archivedHelper(showArchived).sort(Chat.sort);

                int rowCount = context.mediaQuery.orientation == Orientation.portrait
                    ? SettingsManager().settings.pinRowsPortrait.value
                    : SettingsManager().settings.pinRowsLandscape.value;
                int colCount = SettingsManager().settings.pinColumnsPortrait.value;
                if (context.mediaQuery.orientation != Orientation.portrait) {
                  colCount = (colCount / context.mediaQuerySize.height * context.mediaQuerySize.width).floor();
                }
                int pinCount = ChatBloc().chats.archivedHelper(showArchived).bigPinHelper(true).length;
                int usedRowCount = min((pinCount / colCount).ceil(), rowCount);
                int maxOnPage = rowCount * colCount;
                PageController _controller = PageController();
                int _pageCount = (pinCount / maxOnPage).ceil();
                int _filledPageCount = (pinCount / maxOnPage).floor();

                return SliverPadding(
                  padding: EdgeInsets.only(
                    top: 10,
                    bottom: 10,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: (context.mediaQuerySize.width + 30) / colCount * usedRowCount,
                      ),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: <Widget>[
                          PageView.builder(
                            physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                            scrollDirection: Axis.horizontal,
                            controller: _controller,
                            itemBuilder: (context, index) {
                              return Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                alignment: _pageCount > 1 ? WrapAlignment.start : WrapAlignment.center,
                                children: List.generate(
                                  index < _filledPageCount
                                      ? maxOnPage
                                      : ChatBloc().chats.archivedHelper(showArchived).bigPinHelper(true).length %
                                          maxOnPage,
                                  (_index) {
                                    return PinnedConversationTile(
                                      key: Key(ChatBloc()
                                          .chats
                                          .archivedHelper(showArchived)
                                          .bigPinHelper(true)[index * maxOnPage + _index]
                                          .guid
                                          .toString()),
                                      chat: ChatBloc()
                                          .chats
                                          .archivedHelper(showArchived)
                                          .bigPinHelper(true)[index * maxOnPage + _index],
                                    );
                                  },
                                ),
                              );
                            },
                            itemCount: _pageCount,
                          ),
                          if (_pageCount > 1)
                            SmoothPageIndicator(
                              controller: _controller,
                              count: _pageCount,
                              effect: ScaleEffect(
                                dotHeight: 5.0,
                                dotWidth: 5.0,
                                spacing: 5.0,
                                radius: 5.0,
                                scale: 1.5,
                                activeDotColor: context.theme.primaryColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              Obx(() {
                ChatBloc().chats.archivedHelper(showArchived).sort(Chat.sort);
                if (!ChatBloc().hasChats.value) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.only(top: 50.0),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Loading chats...",
                                style: Theme.of(context).textTheme.subtitle1,
                              ),
                            ),
                            buildProgressIndicator(context, size: 15),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                if (!ChatBloc().hasChats.value) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.only(top: 50.0),
                        child: Text(
                          showArchived ? "You have no archived chats :(" : "You have no chats :(",
                          style: Theme.of(context).textTheme.subtitle1,
                        ),
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return ConversationTile(
                        key: Key(
                            ChatBloc().chats.archivedHelper(showArchived).bigPinHelper(false)[index].guid.toString()),
                        chat: ChatBloc().chats.archivedHelper(showArchived).bigPinHelper(false)[index],
                      );
                    },
                    childCount: ChatBloc().chats.archivedHelper(showArchived).bigPinHelper(false).length,
                  ),
                );
              }),
            ],
          ),
          floatingActionButton:
              !SettingsManager().settings.moveChatCreatorToHeader.value ? parent.buildFloatingActionButton() : null,
        ),
      ),
    );
  }
}

class _Material extends StatefulWidget {
  _Material({Key? key, required this.parent}) : super(key: key);

  final _ConversationListState parent;

  @override
  __MaterialState createState() => __MaterialState();
}

class __MaterialState extends State<_Material> {
  List<Chat> selected = [];

  bool hasPinnedChat() {
    for (var i = 0; i < ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats).length; i++) {
      if (ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats)[i].isPinned!) {
        widget.parent.hasPinnedChats = true;
        return true;
      } else {
        return false;
      }
    }
    return false;
  }

  bool hasNormalChats() {
    int counter = 0;
    for (var i = 0; i < ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats).length; i++) {
      if (ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats)[i].isPinned!) {
        counter++;
      } else {}
    }
    if (counter == ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats).length) {
      return false;
    } else {
      return true;
    }
  }

  Widget slideLeftBackground(Chat chat) {
    return Container(
      color: SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.pin
          ? Colors.yellow[800]
          : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.alerts
              ? Colors.purple
              : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.delete
                  ? Colors.red
                  : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.mark_read
                      ? Colors.blue
                      : Colors.red,
      child: Align(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Icon(
              SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.pin
                  ? (chat.isPinned! ? Icons.star_outline : Icons.star)
                  : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.alerts
                      ? (chat.isMuted! ? Icons.notifications_active : Icons.notifications_off)
                      : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.delete
                          ? Icons.delete_forever
                          : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.mark_read
                              ? (chat.hasUnreadMessage! ? Icons.mark_chat_read : Icons.mark_chat_unread)
                              : (chat.isArchived! ? Icons.unarchive : Icons.archive),
              color: Colors.white,
            ),
            Text(
              SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.pin
                  ? (chat.isPinned! ? " Unpin" : " Pin")
                  : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.alerts
                      ? (chat.isMuted! ? ' Show Alerts' : ' Hide Alerts')
                      : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.delete
                          ? " Delete"
                          : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.mark_read
                              ? (chat.hasUnreadMessage! ? ' Mark Read' : ' Mark Unread')
                              : (chat.isArchived! ? ' UnArchive' : ' Archive'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.right,
            ),
            SizedBox(
              width: 20,
            ),
          ],
        ),
        alignment: Alignment.centerRight,
      ),
    );
  }

  Widget slideRightBackground(Chat chat) {
    return Container(
      color: SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.pin
          ? Colors.yellow[800]
          : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.alerts
              ? Colors.purple
              : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.delete
                  ? Colors.red
                  : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.mark_read
                      ? Colors.blue
                      : Colors.red,
      child: Align(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 20,
            ),
            Icon(
              SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.pin
                  ? (chat.isPinned! ? Icons.star_outline : Icons.star)
                  : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.alerts
                      ? (chat.isMuted! ? Icons.notifications_active : Icons.notifications_off)
                      : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.delete
                          ? Icons.delete_forever
                          : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.mark_read
                              ? (chat.hasUnreadMessage! ? Icons.mark_chat_read : Icons.mark_chat_unread)
                              : (chat.isArchived! ? Icons.unarchive : Icons.archive),
              color: Colors.white,
            ),
            Text(
              SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.pin
                  ? (chat.isPinned! ? " Unpin" : " Pin")
                  : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.alerts
                      ? (chat.isMuted! ? ' Show Alerts' : ' Hide Alerts')
                      : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.delete
                          ? " Delete"
                          : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.mark_read
                              ? (chat.hasUnreadMessage! ? ' Mark Read' : ' Mark Unread')
                              : (chat.isArchived! ? ' UnArchive' : ' Archive'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.left,
            ),
          ],
        ),
        alignment: Alignment.centerLeft,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    hasPinnedChat();
    bool showArchived = widget.parent.widget.showArchivedChats;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: context.theme.backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            context.theme.backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Obx(
        () => WillPopScope(
          onWillPop: () async {
            if (selected.isNotEmpty) {
              selected = [];
              setState(() {});
              return false;
            }
            return true;
          },
          child: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(60),
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 500),
                child: selected.isEmpty
                    ? AppBar(
                        iconTheme: IconThemeData(color: context.theme.primaryColor),
                        brightness: ThemeData.estimateBrightnessForColor(context.theme.backgroundColor),
                        bottom: PreferredSize(
                          child: Container(
                            color: context.theme.dividerColor,
                            height: 0,
                          ),
                          preferredSize: Size.fromHeight(0.5),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ...widget.parent.getHeaderTextWidgets(size: 20),
                            ...widget.parent.getConnectionIndicatorWidgets(),
                            widget.parent.getSyncIndicatorWidget(),
                          ],
                        ),
                        actions: [
                          (!showArchived)
                              ? GestureDetector(
                                  onTap: () async {
                                    Navigator.of(context).push(
                                      CupertinoPageRoute(
                                        builder: (context) => SearchView(),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.search,
                                      color: context.textTheme.bodyText1!.color,
                                    ),
                                  ),
                                )
                              : Container(),
                          (SettingsManager().settings.moveChatCreatorToHeader.value && !showArchived)
                              ? GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      ThemeSwitcher.buildPageRoute(
                                        builder: (BuildContext context) {
                                          return ConversationView(
                                            isCreator: true,
                                          );
                                        },
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.create,
                                      color: context.textTheme.bodyText1!.color,
                                    ),
                                  ),
                                )
                              : Container(),
                          Padding(
                            padding: EdgeInsets.only(right: 20),
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 15.5),
                              child: Container(
                                width: 40,
                                child: widget.parent.buildSettingsButton(),
                              ),
                            ),
                          ),
                        ],
                        backgroundColor: context.theme.backgroundColor,
                      )
                    : Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (([0, selected.length])
                                    .contains(selected.where((element) => element.hasUnreadMessage!).length))
                                  GestureDetector(
                                    onTap: () {
                                      selected.forEach((element) async {
                                        await element.toggleHasUnread(!element.hasUnreadMessage!);
                                      });
                                      selected = [];
                                      if (this.mounted) setState(() {});
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        selected[0].hasUnreadMessage! ? Icons.mark_chat_read : Icons.mark_chat_unread,
                                        color: context.textTheme.bodyText1!.color,
                                      ),
                                    ),
                                  ),
                                if (([0, selected.length])
                                    .contains(selected.where((element) => element.isMuted!).length))
                                  GestureDetector(
                                    onTap: () {
                                      selected.forEach((element) async {
                                        await element.toggleMute(!element.isMuted!);
                                      });
                                      selected = [];
                                      if (this.mounted) setState(() {});
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        selected[0].isMuted! ? Icons.notifications_active : Icons.notifications_off,
                                        color: context.textTheme.bodyText1!.color,
                                      ),
                                    ),
                                  ),
                                if (([0, selected.length])
                                    .contains(selected.where((element) => element.isPinned!).length))
                                  GestureDetector(
                                    onTap: () {
                                      selected.forEach((element) {
                                        element.togglePin(!element.isPinned!);
                                      });
                                      selected = [];
                                      if (this.mounted) setState(() {});
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        selected[0].isPinned! ? Icons.star_outline : Icons.star,
                                        color: context.textTheme.bodyText1!.color,
                                      ),
                                    ),
                                  ),
                                GestureDetector(
                                  onTap: () {
                                    selected.forEach((element) {
                                      if (element.isArchived!) {
                                        ChatBloc().unArchiveChat(element);
                                      } else {
                                        ChatBloc().archiveChat(element);
                                      }
                                    });
                                    selected = [];
                                    if (this.mounted) setState(() {});
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      showArchived ? Icons.unarchive : Icons.archive,
                                      color: context.textTheme.bodyText1!.color,
                                    ),
                                  ),
                                ),
                                if (selected[0].isArchived!)
                                  GestureDetector(
                                    onTap: () {
                                      selected.forEach((element) {
                                        ChatBloc().deleteChat(element);
                                        Chat.deleteChat(element);
                                      });
                                      selected = [];
                                      if (this.mounted) setState(() {});
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        Icons.delete_forever,
                                        color: context.textTheme.bodyText1!.color,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            backgroundColor: context.theme.backgroundColor,
            body: Obx(
              () {
                if (!ChatBloc().hasChats.value) {
                  return Center(
                    child: Container(
                      padding: EdgeInsets.only(top: 50.0),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "Loading chats...",
                              style: Theme.of(context).textTheme.subtitle1,
                            ),
                          ),
                          buildProgressIndicator(context, size: 15),
                        ],
                      ),
                    ),
                  );
                }
                if (ChatBloc().chats.archivedHelper(showArchived).isEmpty) {
                  return Center(
                    child: Container(
                      padding: EdgeInsets.only(top: 50.0),
                      child: Text(
                        "You have no archived chats :(",
                        style: context.textTheme.subtitle1,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  physics: ThemeSwitcher.getScrollPhysics(),
                  itemBuilder: (context, index) {
                    return Obx(() {
                      if (SettingsManager().settings.swipableConversationTiles.value) {
                        return Dismissible(
                            background:
                                Obx(() => slideRightBackground(ChatBloc().chats.archivedHelper(showArchived)[index])),
                            secondaryBackground:
                                Obx(() => slideLeftBackground(ChatBloc().chats.archivedHelper(showArchived)[index])),
                            // Each Dismissible must contain a Key. Keys allow Flutter to
                            // uniquely identify widgets.
                            key: UniqueKey(),
                            // Provide a function that tells the app
                            // what to do after an item has been swiped away.
                            onDismissed: (direction) async {
                              if (direction == DismissDirection.endToStart) {
                                if (SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.pin) {
                                  await ChatBloc()
                                      .chats
                                      .archivedHelper(showArchived)[index]
                                      .togglePin(!ChatBloc().chats.archivedHelper(showArchived)[index].isPinned!);
                                  EventDispatcher.instance.emit("refresh", null);
                                  if (this.mounted) setState(() {});
                                } else if (SettingsManager().settings.materialLeftAction.value ==
                                    MaterialSwipeAction.alerts) {
                                  await ChatBloc()
                                      .chats
                                      .archivedHelper(showArchived)[index]
                                      .toggleMute(!ChatBloc().chats.archivedHelper(showArchived)[index].isMuted!);
                                  if (this.mounted) setState(() {});
                                } else if (SettingsManager().settings.materialLeftAction.value ==
                                    MaterialSwipeAction.delete) {
                                  ChatBloc().deleteChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                  Chat.deleteChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                } else if (SettingsManager().settings.materialLeftAction.value ==
                                    MaterialSwipeAction.mark_read) {
                                  ChatBloc().toggleChatUnread(ChatBloc().chats.archivedHelper(showArchived)[index],
                                      !ChatBloc().chats.archivedHelper(showArchived)[index].hasUnreadMessage!);
                                } else {
                                  if (ChatBloc().chats.archivedHelper(showArchived)[index].isArchived!) {
                                    ChatBloc().unArchiveChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                  } else {
                                    ChatBloc().archiveChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                  }
                                }
                              } else {
                                if (SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.pin) {
                                  await ChatBloc()
                                      .chats
                                      .archivedHelper(showArchived)[index]
                                      .togglePin(!ChatBloc().chats.archivedHelper(showArchived)[index].isPinned!);
                                  EventDispatcher.instance.emit("refresh", null);
                                  if (this.mounted) setState(() {});
                                } else if (SettingsManager().settings.materialRightAction.value ==
                                    MaterialSwipeAction.alerts) {
                                  await ChatBloc()
                                      .chats
                                      .archivedHelper(showArchived)[index]
                                      .toggleMute(!ChatBloc().chats.archivedHelper(showArchived)[index].isMuted!);
                                  if (this.mounted) setState(() {});
                                } else if (SettingsManager().settings.materialRightAction.value ==
                                    MaterialSwipeAction.delete) {
                                  ChatBloc().deleteChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                  Chat.deleteChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                } else if (SettingsManager().settings.materialRightAction.value ==
                                    MaterialSwipeAction.mark_read) {
                                  ChatBloc().toggleChatUnread(ChatBloc().chats.archivedHelper(showArchived)[index],
                                      !ChatBloc().chats.archivedHelper(showArchived)[index].hasUnreadMessage!);
                                } else {
                                  if (ChatBloc().chats.archivedHelper(showArchived)[index].isArchived!) {
                                    ChatBloc().unArchiveChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                  } else {
                                    ChatBloc().archiveChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                  }
                                }
                              }
                            },
                            child: (!showArchived && ChatBloc().chats.archivedHelper(showArchived)[index].isArchived!)
                                ? Container()
                                : (showArchived && !ChatBloc().chats.archivedHelper(showArchived)[index].isArchived!)
                                    ? Container()
                                    : ConversationTile(
                                        key: UniqueKey(),
                                        chat: ChatBloc().chats.archivedHelper(showArchived)[index],
                                        inSelectMode: selected.isNotEmpty,
                                        selected: selected,
                                        onSelect: (bool selected) {
                                          if (selected) {
                                            this.selected.add(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                            setState(() {});
                                          } else {
                                            this.selected.removeWhere((element) =>
                                                element.guid ==
                                                ChatBloc().chats.archivedHelper(showArchived)[index].guid);
                                            setState(() {});
                                          }
                                        },
                                      ));
                      } else {
                        return ConversationTile(
                          key: UniqueKey(),
                          chat: ChatBloc().chats.archivedHelper(showArchived)[index],
                          inSelectMode: selected.isNotEmpty,
                          selected: selected,
                          onSelect: (bool selected) {
                            if (selected) {
                              this.selected.add(ChatBloc().chats.archivedHelper(showArchived)[index]);
                              setState(() {});
                            } else {
                              this.selected.removeWhere((element) =>
                                  element.guid == ChatBloc().chats.archivedHelper(showArchived)[index].guid);
                              setState(() {});
                            }
                          },
                        );
                      }
                    });
                  },
                  itemCount: ChatBloc().chats.archivedHelper(showArchived).length,
                );
              },
            ),
            floatingActionButton: selected.isEmpty && !SettingsManager().settings.moveChatCreatorToHeader.value
                ? widget.parent.buildFloatingActionButton()
                : null,
          ),
        ),
      ),
    );
  }
}

class _Samsung extends StatefulWidget {
  _Samsung({Key? key, required this.parent}) : super(key: key);

  final _ConversationListState parent;

  @override
  _SamsungState createState() => _SamsungState();
}

class _SamsungState extends State<_Samsung> {
  List<Chat> selected = [];

  bool hasPinnedChat() {
    for (var i = 0; i < ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats).length; i++) {
      if (ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats)[i].isPinned!) {
        widget.parent.hasPinnedChats = true;
        return true;
      } else {
        return false;
      }
    }
    return false;
  }

  bool hasNormalChats() {
    int counter = 0;
    for (var i = 0; i < ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats).length; i++) {
      if (ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats)[i].isPinned!) {
        counter++;
      } else {}
    }
    if (counter == ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats).length) {
      return false;
    } else {
      return true;
    }
  }

  Widget slideLeftBackground(Chat chat) {
    return Container(
      color: SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.pin
          ? Colors.yellow[800]
          : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.alerts
              ? Colors.purple
              : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.delete
                  ? Colors.red
                  : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.mark_read
                      ? Colors.blue
                      : Colors.red,
      child: Align(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Icon(
              SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.pin
                  ? (chat.isPinned! ? Icons.star_outline : Icons.star)
                  : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.alerts
                      ? (chat.isMuted! ? Icons.notifications_active : Icons.notifications_off)
                      : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.delete
                          ? Icons.delete_forever
                          : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.mark_read
                              ? (chat.hasUnreadMessage! ? Icons.mark_chat_read : Icons.mark_chat_unread)
                              : (chat.isArchived! ? Icons.unarchive : Icons.archive),
              color: Colors.white,
            ),
            Text(
              SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.pin
                  ? (chat.isPinned! ? " Unpin" : " Pin")
                  : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.alerts
                      ? (chat.isMuted! ? ' Show Alerts' : ' Hide Alerts')
                      : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.delete
                          ? " Delete"
                          : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.mark_read
                              ? (chat.hasUnreadMessage! ? ' Mark Read' : ' Mark Unread')
                              : (chat.isArchived! ? ' UnArchive' : ' Archive'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.right,
            ),
            SizedBox(
              width: 20,
            ),
          ],
        ),
        alignment: Alignment.centerRight,
      ),
    );
  }

  Widget slideRightBackground(Chat chat) {
    return Container(
      color: SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.pin
          ? Colors.yellow[800]
          : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.alerts
              ? Colors.purple
              : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.delete
                  ? Colors.red
                  : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.mark_read
                      ? Colors.blue
                      : Colors.red,
      child: Align(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 20,
            ),
            Icon(
              SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.pin
                  ? (chat.isPinned! ? Icons.star_outline : Icons.star)
                  : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.alerts
                      ? (chat.isMuted! ? Icons.notifications_active : Icons.notifications_off)
                      : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.delete
                          ? Icons.delete_forever
                          : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.mark_read
                              ? (chat.hasUnreadMessage! ? Icons.mark_chat_read : Icons.mark_chat_unread)
                              : (chat.isArchived! ? Icons.unarchive : Icons.archive),
              color: Colors.white,
            ),
            Text(
              SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.pin
                  ? (chat.isPinned! ? " Unpin" : " Pin")
                  : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.alerts
                      ? (chat.isMuted! ? ' Show Alerts' : ' Hide Alerts')
                      : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.delete
                          ? " Delete"
                          : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.mark_read
                              ? (chat.hasUnreadMessage! ? ' Mark Read' : ' Mark Unread')
                              : (chat.isArchived! ? ' UnArchive' : ' Archive'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.left,
            ),
          ],
        ),
        alignment: Alignment.centerLeft,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool showArchived = widget.parent.widget.showArchivedChats;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: context.theme.backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            context.theme.backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Obx(
        () => WillPopScope(
          onWillPop: () async {
            if (selected.isNotEmpty) {
              selected = [];
              setState(() {});
              return false;
            }
            return true;
          },
          child: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(60),
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 500),
                child: selected.isEmpty
                    ? AppBar(
                        shadowColor: Colors.transparent,
                        iconTheme: IconThemeData(color: context.theme.primaryColor),
                        brightness: ThemeData.estimateBrightnessForColor(context.theme.backgroundColor),
                        bottom: PreferredSize(
                          child: Container(
                            color: context.theme.dividerColor,
                            height: 0,
                          ),
                          preferredSize: Size.fromHeight(0.5),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            ...widget.parent.getHeaderTextWidgets(size: 20),
                            ...widget.parent.getConnectionIndicatorWidgets(),
                            widget.parent.getSyncIndicatorWidget(),
                          ],
                        ),
                        actions: [
                          (!showArchived)
                              ? GestureDetector(
                                  onTap: () async {
                                    Navigator.of(context).push(
                                      CupertinoPageRoute(
                                        builder: (context) => SearchView(),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.search,
                                      color: context.textTheme.bodyText1!.color,
                                    ),
                                  ),
                                )
                              : Container(),
                          (SettingsManager().settings.moveChatCreatorToHeader.value && !showArchived
                              ? GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      ThemeSwitcher.buildPageRoute(
                                        builder: (BuildContext context) {
                                          return ConversationView(
                                            isCreator: true,
                                          );
                                        },
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.create,
                                      color: context.textTheme.bodyText1!.color,
                                    ),
                                  ),
                                )
                              : Container()),
                          Padding(
                            padding: EdgeInsets.only(right: 20),
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 15.5),
                              child: Container(
                                width: 40,
                                child: widget.parent.buildSettingsButton(),
                              ),
                            ),
                          ),
                        ],
                        backgroundColor: context.theme.backgroundColor,
                      )
                    : Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (selected.length <= 1)
                                  GestureDetector(
                                    onTap: () {
                                      selected.forEach((element) async {
                                        await element.toggleMute(!element.isMuted!);
                                      });

                                      selected = [];
                                      if (this.mounted) setState(() {});
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        Icons.notifications_off,
                                        color: context.textTheme.bodyText1!.color,
                                      ),
                                    ),
                                  ),
                                GestureDetector(
                                  onTap: () {
                                    selected.forEach((element) {
                                      if (element.isArchived!) {
                                        ChatBloc().unArchiveChat(element);
                                      } else {
                                        ChatBloc().archiveChat(element);
                                      }
                                    });
                                    selected = [];
                                    if (this.mounted) setState(() {});
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      showArchived ? Icons.unarchive : Icons.archive,
                                      color: context.textTheme.bodyText1!.color,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    selected.forEach((element) async {
                                      await element.togglePin(!element.isPinned!);
                                    });

                                    selected = [];
                                    if (this.mounted) setState(() {});
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.star,
                                      color: context.textTheme.bodyText1!.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            backgroundColor: context.theme.backgroundColor,
            body: Obx(() {
              if (!ChatBloc().hasChats.value) {
                return Center(
                  child: Container(
                    padding: EdgeInsets.only(top: 50.0),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "Loading chats...",
                            style: Theme.of(context).textTheme.subtitle1,
                          ),
                        ),
                        buildProgressIndicator(context, size: 15),
                      ],
                    ),
                  ),
                );
              }
              if (ChatBloc().chats.archivedHelper(showArchived).isEmpty) {
                return Center(
                  child: Container(
                    padding: EdgeInsets.only(top: 50.0),
                    child: Text(
                      "You have no archived chats :(",
                      style: context.textTheme.subtitle1,
                    ),
                  ),
                );
              }

              bool hasPinned = hasPinnedChat();
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (hasPinned)
                      Container(
                        height: 20.0,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.transparent,
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                      ),
                    if (hasPinned)
                      Container(
                        padding: EdgeInsets.all(6.0),
                        decoration: new BoxDecoration(
                          color: context.theme.accentColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            return Obx(() {
                              if (SettingsManager().settings.swipableConversationTiles.value) {
                                return Dismissible(
                                  background: Obx(
                                      () => slideRightBackground(ChatBloc().chats.archivedHelper(showArchived)[index])),
                                  secondaryBackground: Obx(
                                      () => slideLeftBackground(ChatBloc().chats.archivedHelper(showArchived)[index])),
                                  // Each Dismissible must contain a Key. Keys allow Flutter to
                                  // uniquely identify widgets.
                                  key: UniqueKey(),
                                  // Provide a function that tells the app
                                  // what to do after an item has been swiped away.
                                  onDismissed: (direction) async {
                                    if (direction == DismissDirection.endToStart) {
                                      if (SettingsManager().settings.materialLeftAction.value ==
                                          MaterialSwipeAction.pin) {
                                        await ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived)[index]
                                            .togglePin(!ChatBloc().chats.archivedHelper(showArchived)[index].isPinned!);
                                        EventDispatcher.instance.emit("refresh", null);
                                        if (this.mounted) setState(() {});
                                      } else if (SettingsManager().settings.materialLeftAction.value ==
                                          MaterialSwipeAction.alerts) {
                                        await ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived)[index]
                                            .toggleMute(!ChatBloc().chats.archivedHelper(showArchived)[index].isMuted!);
                                        if (this.mounted) setState(() {});
                                      } else if (SettingsManager().settings.materialLeftAction.value ==
                                          MaterialSwipeAction.delete) {
                                        ChatBloc().deleteChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                        Chat.deleteChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                      } else if (SettingsManager().settings.materialLeftAction.value ==
                                          MaterialSwipeAction.mark_read) {
                                        ChatBloc().toggleChatUnread(
                                            ChatBloc().chats.archivedHelper(showArchived)[index],
                                            !ChatBloc().chats.archivedHelper(showArchived)[index].hasUnreadMessage!);
                                      } else {
                                        if (ChatBloc().chats.archivedHelper(showArchived)[index].isArchived!) {
                                          ChatBloc()
                                              .unArchiveChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                        } else {
                                          ChatBloc().archiveChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                        }
                                      }
                                    } else {
                                      if (SettingsManager().settings.materialRightAction.value ==
                                          MaterialSwipeAction.pin) {
                                        await ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived)[index]
                                            .togglePin(!ChatBloc().chats.archivedHelper(showArchived)[index].isPinned!);
                                        EventDispatcher.instance.emit("refresh", null);
                                        if (this.mounted) setState(() {});
                                      } else if (SettingsManager().settings.materialRightAction.value ==
                                          MaterialSwipeAction.alerts) {
                                        await ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived)[index]
                                            .toggleMute(!ChatBloc().chats.archivedHelper(showArchived)[index].isMuted!);
                                        if (this.mounted) setState(() {});
                                      } else if (SettingsManager().settings.materialRightAction.value ==
                                          MaterialSwipeAction.delete) {
                                        ChatBloc().deleteChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                        Chat.deleteChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                      } else if (SettingsManager().settings.materialRightAction.value ==
                                          MaterialSwipeAction.mark_read) {
                                        ChatBloc().toggleChatUnread(
                                            ChatBloc().chats.archivedHelper(showArchived)[index],
                                            !ChatBloc().chats.archivedHelper(showArchived)[index].hasUnreadMessage!);
                                      } else {
                                        if (ChatBloc().chats.archivedHelper(showArchived)[index].isArchived!) {
                                          ChatBloc()
                                              .unArchiveChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                        } else {
                                          ChatBloc().archiveChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                        }
                                      }
                                    }
                                  },
                                  child: (!showArchived &&
                                          ChatBloc().chats.archivedHelper(showArchived)[index].isArchived!)
                                      ? Container()
                                      : (showArchived &&
                                              !ChatBloc().chats.archivedHelper(showArchived)[index].isArchived!)
                                          ? Container()
                                          : ChatBloc().chats.archivedHelper(showArchived)[index].isPinned!
                                              ? ConversationTile(
                                                  key: UniqueKey(),
                                                  chat: ChatBloc().chats.archivedHelper(showArchived)[index],
                                                  inSelectMode: selected.isNotEmpty,
                                                  selected: selected,
                                                  onSelect: (bool selected) {
                                                    if (selected) {
                                                      this
                                                          .selected
                                                          .add(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                                    } else {
                                                      this.selected.removeWhere((element) =>
                                                          element.guid ==
                                                          ChatBloc().chats.archivedHelper(showArchived)[index].guid);
                                                    }

                                                    if (this.mounted) setState(() {});
                                                  },
                                                )
                                              : Container(),
                                );
                              } else {
                                if (!showArchived && ChatBloc().chats.archivedHelper(showArchived)[index].isArchived!)
                                  return Container();
                                if (showArchived && !ChatBloc().chats.archivedHelper(showArchived)[index].isArchived!)
                                  return Container();
                                if (ChatBloc().chats.archivedHelper(showArchived)[index].isPinned!) {
                                  return ConversationTile(
                                    key: UniqueKey(),
                                    chat: ChatBloc().chats.archivedHelper(showArchived)[index],
                                    inSelectMode: selected.isNotEmpty,
                                    selected: selected,
                                    onSelect: (bool selected) {
                                      if (selected) {
                                        this.selected.add(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                        if (this.mounted) setState(() {});
                                      } else {
                                        this.selected.removeWhere((element) =>
                                            element.guid == ChatBloc().chats.archivedHelper(showArchived)[index].guid);
                                        if (this.mounted) setState(() {});
                                      }
                                    },
                                  );
                                }
                                return Container();
                              }
                            });
                          },
                          itemCount: ChatBloc().chats.archivedHelper(showArchived).length,
                        ),
                      ),
                    if (hasNormalChats())
                      Container(
                        height: 20.0,
                        decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.transparent,
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(20))),
                      ),
                    if (hasNormalChats())
                      Container(
                        padding: const EdgeInsets.all(6.0),
                        decoration: new BoxDecoration(
                            color: context.theme.accentColor,
                            borderRadius: new BorderRadius.only(
                              topLeft: const Radius.circular(20.0),
                              topRight: const Radius.circular(20.0),
                              bottomLeft: const Radius.circular(20.0),
                              bottomRight: const Radius.circular(20.0),
                            )),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            return Obx(() {
                              if (SettingsManager().settings.swipableConversationTiles.value) {
                                return Dismissible(
                                  background: Obx(
                                      () => slideRightBackground(ChatBloc().chats.archivedHelper(showArchived)[index])),
                                  secondaryBackground: Obx(
                                      () => slideLeftBackground(ChatBloc().chats.archivedHelper(showArchived)[index])),
                                  // Each Dismissible must contain a Key. Keys allow Flutter to
                                  // uniquely identify widgets.
                                  key: UniqueKey(),
                                  // Provide a function that tells the app
                                  // what to do after an item has been swiped away.
                                  onDismissed: (direction) async {
                                    if (direction == DismissDirection.endToStart) {
                                      if (SettingsManager().settings.materialLeftAction.value ==
                                          MaterialSwipeAction.pin) {
                                        await ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived)[index]
                                            .togglePin(!ChatBloc().chats.archivedHelper(showArchived)[index].isPinned!);
                                        EventDispatcher.instance.emit("refresh", null);
                                        if (this.mounted) setState(() {});
                                      } else if (SettingsManager().settings.materialLeftAction.value ==
                                          MaterialSwipeAction.alerts) {
                                        await ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived)[index]
                                            .toggleMute(!ChatBloc().chats.archivedHelper(showArchived)[index].isMuted!);
                                        if (this.mounted) setState(() {});
                                      } else if (SettingsManager().settings.materialLeftAction.value ==
                                          MaterialSwipeAction.delete) {
                                        ChatBloc().deleteChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                        Chat.deleteChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                      } else if (SettingsManager().settings.materialLeftAction.value ==
                                          MaterialSwipeAction.mark_read) {
                                        ChatBloc().toggleChatUnread(
                                            ChatBloc().chats.archivedHelper(showArchived)[index],
                                            !ChatBloc().chats.archivedHelper(showArchived)[index].hasUnreadMessage!);
                                      } else {
                                        if (ChatBloc().chats.archivedHelper(showArchived)[index].isArchived!) {
                                          ChatBloc()
                                              .unArchiveChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                        } else {
                                          ChatBloc().archiveChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                        }
                                      }
                                    } else {
                                      if (SettingsManager().settings.materialRightAction.value ==
                                          MaterialSwipeAction.pin) {
                                        await ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived)[index]
                                            .togglePin(!ChatBloc().chats.archivedHelper(showArchived)[index].isPinned!);
                                        EventDispatcher.instance.emit("refresh", null);
                                        if (this.mounted) setState(() {});
                                      } else if (SettingsManager().settings.materialRightAction.value ==
                                          MaterialSwipeAction.alerts) {
                                        await ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived)[index]
                                            .toggleMute(!ChatBloc().chats.archivedHelper(showArchived)[index].isMuted!);
                                        if (this.mounted) setState(() {});
                                      } else if (SettingsManager().settings.materialRightAction.value ==
                                          MaterialSwipeAction.delete) {
                                        ChatBloc().deleteChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                        Chat.deleteChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                      } else if (SettingsManager().settings.materialRightAction.value ==
                                          MaterialSwipeAction.mark_read) {
                                        ChatBloc().toggleChatUnread(
                                            ChatBloc().chats.archivedHelper(showArchived)[index],
                                            !ChatBloc().chats.archivedHelper(showArchived)[index].hasUnreadMessage!);
                                      } else {
                                        if (ChatBloc().chats.archivedHelper(showArchived)[index].isArchived!) {
                                          ChatBloc()
                                              .unArchiveChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                        } else {
                                          ChatBloc().archiveChat(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                        }
                                      }
                                    }
                                  },
                                  child: (!showArchived &&
                                          ChatBloc().chats.archivedHelper(showArchived)[index].isArchived!)
                                      ? Container()
                                      : (showArchived &&
                                              !ChatBloc().chats.archivedHelper(showArchived)[index].isArchived!)
                                          ? Container()
                                          : (!ChatBloc().chats.archivedHelper(showArchived)[index].isPinned!)
                                              ? ConversationTile(
                                                  key: UniqueKey(),
                                                  chat: ChatBloc().chats.archivedHelper(showArchived)[index],
                                                  inSelectMode: selected.isNotEmpty,
                                                  selected: selected,
                                                  onSelect: (bool selected) {
                                                    if (selected) {
                                                      this
                                                          .selected
                                                          .add(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                                    } else {
                                                      this.selected.removeWhere((element) =>
                                                          element.guid ==
                                                          ChatBloc().chats.archivedHelper(showArchived)[index].guid);
                                                    }

                                                    if (this.mounted) setState(() {});
                                                  },
                                                )
                                              : Container(),
                                );
                              } else {
                                if (!showArchived && ChatBloc().chats.archivedHelper(showArchived)[index].isArchived!)
                                  return Container();
                                if (showArchived && !ChatBloc().chats.archivedHelper(showArchived)[index].isArchived!)
                                  return Container();
                                if (!ChatBloc().chats.archivedHelper(showArchived)[index].isPinned!) {
                                  return ConversationTile(
                                    key: UniqueKey(),
                                    chat: ChatBloc().chats.archivedHelper(showArchived)[index],
                                    inSelectMode: selected.isNotEmpty,
                                    selected: selected,
                                    onSelect: (bool selected) {
                                      if (selected) {
                                        this.selected.add(ChatBloc().chats.archivedHelper(showArchived)[index]);
                                      } else {
                                        this.selected.removeWhere((element) =>
                                            element.guid == ChatBloc().chats.archivedHelper(showArchived)[index].guid);
                                      }

                                      if (this.mounted) setState(() {});
                                    },
                                  );
                                }
                                return Container();
                              }
                            });
                          },
                          itemCount: ChatBloc().chats.archivedHelper(showArchived).length,
                        ),
                      )
                  ],
                ),
              );
            }),
            floatingActionButton: selected.isEmpty && !SettingsManager().settings.moveChatCreatorToHeader.value
                ? widget.parent.buildFloatingActionButton()
                : null,
          ),
        ),
      ),
    );
  }
}
