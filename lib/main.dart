import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pref_dessert/pref_dessert.dart';

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

void main() {
  flutterLocalNotificationsPlugin = new FlutterLocalNotificationsPlugin();
  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Flutter Demo',
      theme: new ThemeData(
        primarySwatch: Colors.deepOrange,
      ),
      home: new MyHomePage(),
    );
  }
}

class Contest {
  String title;
  String site;
  DateTime startAt;
  DateTime endAt;
  bool isFavorite = false;

  Contest({@required this.title, @required this.startAt, @required this.endAt, @required this.site, this.isFavorite});

  String toString() {
    return "\nTitle: " + title + "\nSite: " + site + "\nStarts at: " + startAt.toIso8601String() + "\nEnds at: " + endAt.toIso8601String();
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Contest> favorites = [];

  Future<dom.Document> getCompetitions() async {
    var repo = new FuturePreferencesRepository<Contest>(new ContestDessert());
    favorites = await repo.findAll();
    var response = await get("https://clist.by/");
    return parse(response.body);
  }

  @override
  void initState() {
    super.initState();
    var initializationSettingsAndroid = new AndroidInitializationSettings('ic_launcher');
    var initializationSettingsIOS = new IOSInitializationSettings();
    var initializationSettings = new InitializationSettings(initializationSettingsAndroid, initializationSettingsIOS);
    flutterLocalNotificationsPlugin.initialize(initializationSettings, selectNotification: (str) {});
  }

  @override
  Widget build(BuildContext context) {
    List<Contest> contestList;

    return Scaffold(
      appBar: AppBar(
        title: Text("Contest Notifs"),
        actions: <Widget>[
          IconButton(
              icon: Icon(Icons.search),
              onPressed: () {
                showSearch(context: context, delegate: SearchContests(contests: contestList));
              })
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () {
          return getCompetitions();
        },
        child: FutureBuilder<dom.Document>(
            future: getCompetitions(),
            builder: (_, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
              var contestElement = snapshot.data.getElementById("contests");
              contestList = favorites;
              var contests = contestElement.getElementsByClassName("row contest coming");

              // Creating two different methods for adding because some contest elements have more attributes than others for some reason
              contests.forEach((e) {
                var currentContest = e.text.split('\n');
                var toBeAdded = e.text.split('\n')[30].trim() == "UTC"
                    ? Contest(
                        title: currentContest[31].trim(),
                        startAt: DateTime.parse(currentContest[28].trim()).add(DateTime.now().timeZoneOffset),
                        endAt: DateTime.parse(currentContest[29].trim()).add(DateTime.now().timeZoneOffset),
                        site: currentContest[33].trim(),
                      )
                    : Contest(
                        title: currentContest[33].trim(),
                        startAt: DateTime.parse(currentContest[30].trim()).add(DateTime.now().timeZoneOffset),
                        endAt: DateTime.parse(currentContest[31].trim()).add(DateTime.now().timeZoneOffset),
                        site: currentContest[35].trim(),
                      );
                if (!contestList.any((c) {
                  return toBeAdded.title == c.title;
                })) {
                  contestList.add(toBeAdded);
                  for(int i = favorites.length; i < contestList.length; i++) {
                    if(contestList[i].startAt.compareTo(toBeAdded.startAt) == 1) {
                      contestList.insert(i, toBeAdded);
                      break;
                    }
                  }
                }
              });

              // Returning widget for each contest in contestList
              return ContestDisplay(
                contestList: contestList,
              );
            }),
      ),
    );
  }
}

class SearchContests extends SearchDelegate {
  List<Contest> contests;

  SearchContests({@required this.contests});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.close),
        onPressed: () {
          query = "";
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return null;
  }

  @override
  Widget buildResults(BuildContext context) {
    Map<String, int> searchHere = new Map();
    List<Contest> contestsShown = [];
    contests.forEach((contest) {
      searchHere.putIfAbsent(contest.title.toLowerCase(), () => contests.indexOf(contest));
      searchHere.putIfAbsent(contest.site, () => contests.indexOf(contest));
    });
    bool repeating = false;
    searchHere.forEach((str, index) {
      if (repeating)
        repeating = false;
      else if (str.contains(query.toLowerCase())) {
        repeating = true;
        contestsShown.add(contests[index]);
      }
    });
    return ContestDisplay(contestList: contestsShown);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    Map<String, int> searchHere = new Map();
    List<Contest> contestsShown = [];
    contests.forEach((contest) {
      searchHere.putIfAbsent(contest.title.toLowerCase(), () => contests.indexOf(contest));
      searchHere.putIfAbsent(contest.site, () => contests.indexOf(contest));
    });
    bool repeating = false;
    searchHere.forEach((str, index) {
      if (repeating)
        repeating = false;
      else if (str.contains(query.toLowerCase())) {
        repeating = true;
        contestsShown.add(contests[index]);
      }
    });
    print(contestsShown);
    return ContestDisplay(contestList: contestsShown).createState().build(context);
  }
}

// Display all the contests supplied to the widget (as a list)
class ContestDisplay extends StatefulWidget {
  final List<Contest> contestList;

  ContestDisplay({@required this.contestList});

  @override
  _ContestDisplayState createState() => _ContestDisplayState(contestList: contestList);
}

class _ContestDisplayState extends State<ContestDisplay> {
  List<Contest> contestList;

  _ContestDisplayState({@required this.contestList});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: contestList.map((contest) {
        return InkWell(
          onTap: () => launch(contest.site),
          child: ListTile(
            title: Text(contest.title.split('@')[0]),
            subtitle: Text(
              contest.title.split('@')[1].trim() +
                  ": " +
                  DateFormat.j().format(contest.startAt) +
                  ", " +
                  DateFormat.MMMEd().format(contest.startAt),
            ),
            trailing: IconButton(
                icon: Icon(Icons.calendar_today),
                onPressed: () async {
                  var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
                      'id', 'Nexus', 'Channel for showing scheduled notifs',
                      importance: Importance.Max, priority: Priority.High);
                  var iOSPlatformChannelSpecifics = new IOSNotificationDetails();
                  var platformChannelSpecifics = new NotificationDetails(androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
                  await flutterLocalNotificationsPlugin
                      .schedule(
                          0, 'Contest in an hour!', contest.title, contest.startAt.subtract(Duration(hours: 1)), platformChannelSpecifics,
                          payload: ' ')
                      .then((x) async {
                    Scaffold.of(context).showSnackBar(SnackBar(
                        content: Text("Scheduled reminder, you will be reminded of "
                            "this contest an hour before it starts.")));
                  });
                }),
            leading: IconButton(
                icon: Icon(
                  contest.isFavorite != null && contest.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: contest.isFavorite != null && contest.isFavorite ? Colors.redAccent : Colors.grey,
                ),
                onPressed: () async {
                  contest.isFavorite = contest.isFavorite != null ? !contest.isFavorite : true;
                  var repo = new FuturePreferencesRepository<Contest>(new ContestDessert());
                  if (contest.isFavorite)
                    repo.save(contest);
                  else
                    repo.removeWhere((c) {
                      return c.title == contest.title;
                    });
                  setState(() {});
                }),
          ),
        );
      }).toList(),
    );
  }
}


// Serialization helper class to store Contest information in the shared preferences
class ContestDessert extends DesSer<Contest> {
  @override
  Contest deserialize(String s) {
    var map = json.decode(s);
    return new Contest(
        title: map['title'] as String,
        startAt: DateTime.parse(map['startAt']),
        endAt: DateTime.parse(map['endAt']),
        site: map['site'] as String,
        isFavorite: map['isFavorite'] as bool);
  }

  @override
  String serialize(Contest t) {
    var map = {
      "title": t.title,
      "startAt": t.startAt.toIso8601String(),
      "endAt": t.endAt.toIso8601String(),
      "site": t.site,
      "isFavorite": t.isFavorite
    };
    return json.encode(map);
  }

  @override
  String get key => null;
}
