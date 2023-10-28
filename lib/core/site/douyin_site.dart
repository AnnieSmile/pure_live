import 'dart:convert';
import 'dart:math';

import 'package:get/get.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/core/common/convert_helper.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/danmaku/douyin_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/model/live_category.dart';
import 'package:pure_live/model/live_category_result.dart';
import 'package:pure_live/model/live_play_quality.dart';

import 'package:pure_live/model/live_search_result.dart';

class DouyinSite implements LiveSite {
  @override
  String id = "douyin";

  @override
  String name = "抖音直播";

  @override
  LiveDanmaku getDanmaku() => DouyinDanmaku();
  final SettingsService settings = Get.find<SettingsService>();
  Map<String, dynamic> headers = {
    "Authority": "live.douyin.com",
    "Referer": "https://live.douyin.com",
    "User-Agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.51",
  };

  Future<Map<String, dynamic>> getRequestHeaders() async {
    try {
      if (headers.containsKey("cookie")) {
        return headers;
      }
      var head = await HttpClient.instance
          .head("https://live.douyin.com", header: headers);
      head.headers["set-cookie"]?.forEach((element) {
        var cookie = element.split(";")[0];
        if (cookie.contains("ttwid")) {
          headers["cookie"] = cookie;
        }
      });
      return headers;
    } catch (e) {
      CoreLog.error(e);
      return headers;
    }
  }

  @override
  Future<List<LiveCategory>> getCategores() async {
    List<LiveCategory> categories = [];
    var result = await HttpClient.instance.getText(
      "https://live.douyin.com/hot_live",
      queryParameters: {},
      header: {
        "Authority": "live.douyin.com",
        "Referer": "https://live.douyin.com",
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.51",
      },
    );

    var renderData =
        RegExp(r'\{\\"pathname\\":\\"\/hot_live\\",\\"categoryData.*?\]\\n')
                .firstMatch(result)
                ?.group(0) ??
            "";
    var renderDataJson = json.decode(renderData
        .trim()
        .replaceAll('\\"', '"')
        .replaceAll(r"\\", r"\")
        .replaceAll(']\\n', ""));
    for (var item in renderDataJson["categoryData"]) {
      List<LiveArea> subs = [];
      var id = '${item["partition"]["id_str"]},${item["partition"]["type"]}';
      for (var subItem in item["sub_partition"]) {
        var subCategory = LiveArea(
          areaId:
              '${subItem["partition"]["id_str"]},${subItem["partition"]["type"]}',
          typeName: item["partition"]["title"] ?? '',
          areaType: id,
          areaName: subItem["partition"]["title"] ?? '',
          areaPic: "",
          platform: 'douyin',
        );
        subs.add(subCategory);
      }

      var category = LiveCategory(
        children: subs,
        id: id,
        name: asT<String?>(item["partition"]["title"]) ?? "",
      );
      subs.insert(
          0,
          LiveArea(
            areaId: category.id,
            typeName: category.name,
            areaType: category.id,
            areaPic: "",
            areaName: category.name,
            platform: 'douyin',
          ));
      categories.add(category);
    }
    return categories;
  }

  @override
  Future<LiveCategoryResult> getCategoryRooms(LiveArea category,
      {int page = 1}) async {
    var ids = category.areaType?.split(',');
    var partitionId = ids?[0];
    var partitionType = ids?[1];
    var result = await HttpClient.instance.getJson(
      "https://live.douyin.com/webcast/web/partition/detail/room/",
      queryParameters: {
        "aid": 6383,
        "app_name": "douyin_web",
        "live_id": 1,
        "device_platform": "web",
        "count": 15,
        "offset": (page - 1) * 15,
        "partition": partitionId,
        "partition_type": partitionType,
        "req_from": 2
      },
      header: await getRequestHeaders(),
    );
    var hasMore = (result["data"]["data"] as List).length >= 15;
    var items = <LiveRoom>[];
    for (var item in result["data"]["data"]) {
      var roomItem = LiveRoom(
        roomId: item["web_rid"],
        title: item["room"]["title"].toString(),
        cover: item["room"]["cover"]["url_list"][0].toString(),
        nick: item["room"]["owner"]["nickname"].toString(),
        liveStatus: LiveStatus.live,
        avatar: item["room"]["owner"]["avatar_thumb"]["url_list"][0].toString(),
        status: true,
        platform: 'douyin',
        area: item['tag_name'].toString(),
        watching:
            item["room"]?["room_view_stats"]?["display_value"].toString() ?? '',
      );
      items.add(roomItem);
    }
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveCategoryResult> getRecommendRooms({int page = 1}) async {
    var result = await HttpClient.instance.getJson(
      "https://live.douyin.com/webcast/web/partition/detail/room/",
      queryParameters: {
        "aid": 6383,
        "app_name": "douyin_web",
        "live_id": 1,
        "device_platform": "web",
        "count": 15,
        "offset": (page - 1) * 15,
        "partition": 720,
        "partition_type": 1,
      },
      header: await getRequestHeaders(),
    );

    var hasMore = (result["data"]["data"] as List).length >= 15;
    var items = <LiveRoom>[];

    for (var item in result["data"]["data"]) {
      var roomItem = LiveRoom(
        roomId: item["web_rid"],
        title: item["room"]["title"].toString(),
        cover: item["room"]["cover"]["url_list"][0].toString(),
        nick: item["room"]["owner"]["nickname"].toString(),
        platform: 'douyin',
        area: item["tag_name"] ?? '热门推荐',
        avatar: item["room"]["owner"]["avatar_thumb"]["url_list"][0].toString(),
        watching:
            item["room"]?["room_view_stats"]?["display_value"].toString() ?? '',
        liveStatus: LiveStatus.live,
      );
      items.add(roomItem);
    }
    return LiveCategoryResult(hasMore: hasMore, items: items);
  }

  @override
  Future<LiveRoom> getRoomDetail({required String roomId}) async {
    try {
      var detail = await getRoomWebDetail(roomId);
      var requestHeader = await getRequestHeaders();
      var webRid = roomId;
      var realRoomId =
          detail["roomStore"]["roomInfo"]["room"]["id_str"].toString();
      var userUniqueId =
          detail["userStore"]["odin"]["user_unique_id"].toString();
      var result = await HttpClient.instance.getJson(
        "https://live.douyin.com/webcast/room/web/enter/",
        queryParameters: {
          "aid": 6383,
          "app_name": "douyin_web",
          "live_id": 1,
          "device_platform": "web",
          "enter_from": "web_live",
          "web_rid": webRid,
          "room_id_str": realRoomId,
          "enter_source": "",
          "Room-Enter-User-Login-Ab": 0,
          "is_need_double_stream": false,
          "cookie_enabled": true,
          "screen_width": 1980,
          "screen_height": 1080,
          "browser_language": "zh-CN",
          "browser_platform": "Win32",
          "browser_name": "Edge",
          "browser_version": "114.0.1823.51"
        },
        header: requestHeader,
      );
      var roomInfo = result["data"]["data"][0];
      var userInfo = result["data"]["user"];
      var partition = result["data"]['partition_road_map'];
      var roomStatus = (asT<int?>(roomInfo["status"]) ?? 0) == 2;
      return LiveRoom(
        roomId: roomId,
        title: roomInfo["title"].toString(),
        cover: roomStatus ? roomInfo["cover"]["url_list"][0].toString() : "",
        nick: userInfo["nickname"].toString(),
        avatar: userInfo["avatar_thumb"]["url_list"][0].toString(),
        watching:
            roomInfo?["room_view_stats"]?["display_value"].toString() ?? '',
        liveStatus: roomStatus ? LiveStatus.live : LiveStatus.offline,
        link: "https://live.douyin.com/$webRid",
        area: partition?['partition']?['title'].toString() ?? '',
        status: roomStatus,
        platform: 'douyin',
        introduction: roomInfo["title"].toString(),
        notice: "",
        danmakuData: DouyinDanmakuArgs(
          webRid: webRid,
          roomId: realRoomId,
          userId: userUniqueId,
          cookie: headers["cookie"],
        ),
        data: roomInfo["stream_url"],
      );
    } catch (e) {
      LiveRoom liveRoom = settings.getLiveRoomByRoomId(roomId);
      liveRoom.liveStatus = LiveStatus.offline;
      liveRoom.status = false;
      return liveRoom;
    }
  }

  Future<Map> getRoomWebDetail(String webRid) async {
    var result = await HttpClient.instance.getText(
      "https://live.douyin.com/$webRid",
      queryParameters: {},
      header: {
        "Accept":
            "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
        "Authority": "live.douyin.com",
        "Referer": "https://live.douyin.com",
        "Cookie": "__ac_nonce=${generateRandomString(21)}",
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.51",
      },
    );

    var renderData = RegExp(r'\{\\"state\\":\{\\"isLiveModal.*?\]\\n')
            .firstMatch(result)
            ?.group(0) ??
        "";
    var str = renderData
        .trim()
        .replaceAll('\\"', '"')
        .replaceAll(r"\\", r"\")
        .replaceAll(']\\n', "");
    var renderDataJson = json.decode(str);

    return renderDataJson["state"];
    // return renderDataJson["app"]["initialState"]["roomStore"]["roomInfo"]
    //         ["room"]["id_str"]
    //     .toString();
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites(
      {required LiveRoom detail}) async {
    List<LivePlayQuality> qualities = [];
    var qualityData = json.decode(
        detail.data["live_core_sdk_data"]["pull_data"]["stream_data"])["data"];
    var qulityList =
        detail.data["live_core_sdk_data"]["pull_data"]["options"]["qualities"];
    for (var quality in qulityList) {
      var qualityItem = LivePlayQuality(
        quality: quality["name"],
        sort: quality["level"],
        data: <String>[
          qualityData[quality["sdk_key"]]["main"]["flv"].toString(),
          qualityData[quality["sdk_key"]]["main"]["hls"].toString(),
        ],
      );
      qualities.add(qualityItem);
    }
    qualities.sort((a, b) => b.sort.compareTo(a.sort));
    return qualities;
  }

  @override
  Future<List<String>> getPlayUrls(
      {required LiveRoom detail, required LivePlayQuality quality}) async {
    return quality.data;
  }

  @override
  Future<LiveSearchRoomResult> searchRooms(String keyword,
      {int page = 1}) async {
    String serverUrl = "https://www.douyin.com/aweme/v1/web/live/search/";
    var uri = Uri.parse(serverUrl)
        .replace(scheme: "https", port: 443, queryParameters: {
      "device_platform": "webapp",
      "aid": "6383",
      "channel": "channel_pc_web",
      "search_channel": "aweme_live",
      "keyword": keyword,
      "search_source": "switch_tab",
      "query_correct_type": "1",
      "is_filter_search": "0",
      "from_group_id": "",
      "offset": ((page - 1) * 10).toString(),
      "count": "10",
      "pc_client_type": "1",
      "version_code": "170400",
      "version_name": "17.4.0",
      "cookie_enabled": "true",
      "screen_width": "1980",
      "screen_height": "1080",
      "browser_language": "zh-CN",
      "browser_platform": "Win32",
      "browser_name": "Edge",
      "browser_version": "114.0.1823.58",
      "browser_online": "true",
      "engine_name": "Blink",
      "engine_version": "114.0.0.0",
      "os_name": "Windows",
      "os_version": "10",
      "cpu_core_num": "12",
      "device_memory": "8",
      "platform": "PC",
      "downlink": "4.7",
      "effective_type": "4g",
      "round_trip_time": "100",
      "webid": "7247041636524377637",
    });
    var requlestUrl = await signUrl(uri.toString());
    var result = await HttpClient.instance.getJson(
      requlestUrl,
      queryParameters: {},
      header: {
        "Accept":
            "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
        "Authority": "live.douyin.com",
        "Referer": "https://www.douyin.com/",
        "Cookie": "__ac_nonce=${generateRandomString(21)}",
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.51",
      },
    );
    var items = <LiveRoom>[];
    for (var item in result["data"] ?? []) {
      var itemData = json.decode(item["lives"]["rawdata"].toString());
      var roomStatus = (asT<int?>(itemData["status"]) ?? 0) == 2;
      var roomItem = LiveRoom(
        roomId: itemData["owner"]["web_rid"].toString(),
        title: itemData["title"].toString(),
        cover: itemData["cover"]["url_list"][0].toString(),
        nick: itemData["owner"]["nickname"].toString(),
        platform: 'douyin',
        avatar: itemData["owner"]["avatar_thumb"]["url_list"][0].toString(),
        liveStatus: roomStatus ? LiveStatus.live : LiveStatus.offline,
        area: '',
        status: roomStatus,
        watching: itemData["stats"]["total_user_str"].toString(),
      );
      items.add(roomItem);
    }
    return LiveSearchRoomResult(hasMore: items.length >= 10, items: items);
  }

  @override
  Future<LiveSearchAnchorResult> searchAnchors(String keyword,
      {int page = 1}) async {
    throw Exception("抖音暂不支持搜索主播，请直接搜索直播间");
  }

  @override
  Future<bool> getLiveStatus({required String roomId}) async {
    var result = await getRoomDetail(roomId: roomId);
    return result.status!;
  }

  @override
  Future<List<LiveSuperChatMessage>> getSuperChatMessage(
      {required String roomId}) {
    return Future.value(<LiveSuperChatMessage>[]);
  }

  //生成指定长度的16进制随机字符串
  String generateRandomString(int length) {
    var random = Random.secure();
    var values = List<int>.generate(length, (i) => random.nextInt(16));
    StringBuffer stringBuffer = StringBuffer();
    for (var item in values) {
      stringBuffer.write(item.toRadixString(16));
    }
    return stringBuffer.toString();
  }

  Future<String> signUrl(String url) async {
    try {
      // 发起一个签名请求
      // 服务端代码：https://github.com/5ime/Tiktok_Signature
      var signResult = await HttpClient.instance.postJson(
        "https://tk.nsapps.cn/",
        queryParameters: {},
        header: {"Content-Type": "application/json"},
        data: {
          "url": url,
          "userAgent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.51"
        },
      );
      var requlestUrl = signResult["data"]["url"].toString();
      return requlestUrl;
    } catch (e) {
      CoreLog.error(e);
      return url;
    }
  }
}