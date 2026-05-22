/// API 配置常量
class ApiConfig {
  // 食堂数据 API
  static const String canteenDataUrl =
      'https://canteen.zju.edu.cn/monitor/general_new.php';
  static const String localCanteenProxyUrl = String.fromEnvironment(
    'CANTEEN_PROXY_URL',
    defaultValue: 'http://127.0.0.1:51989/canteen/general_new.php',
  );

  // 班车数据 API
  static const String busScheduleUrl =
      'https://bccx.zju.edu.cn/schoolbus_wx/api';

  // 图书馆座位 API (需要认证)
  static const String libraryBookingUrl = 'https://booking.lib.zju.edu.cn';
  static const String localLibraryProxyUrl = String.fromEnvironment(
    'LIBRARY_PROXY_URL',
    defaultValue: 'http://127.0.0.1:51989',
  );

  // 浙大统一身份认证
  static const String zjuCasUrl = 'https://zjuam.zju.edu.cn/cas/login';

  // 超时设置
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}

/// 校区配置
class CampusConfig {
  static const List<Map<String, String>> campuses = [
    {'id': 'zijingang', 'name': '紫金港'},
    {'id': 'yuquan', 'name': '玉泉'},
    {'id': 'xixi', 'name': '西溪'},
    {'id': 'huajiachi', 'name': '华家池'},
    {'id': 'haining', 'name': '海宁'},
    {'id': 'zhoushan', 'name': '舟山'},
  ];

  static const String defaultCampus = 'zijingang';
}
