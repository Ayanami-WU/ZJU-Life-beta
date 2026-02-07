# ZJU Life Flutter App

浙大生活助手 - Flutter 移动端应用

## 功能特性

- 🍽️ **食堂人流** - 实时查看各食堂拥挤程度
- 🚌 **班车查询** - 校区班车/小白车时刻表，支持日期时间选择和站点筛选
- 📚 **自习座位** - 图书馆座位实时数据（需登录）
- ⭐ **个人收藏** - 收藏常用食堂、班车路线
- 🌓 **深色模式** - 支持亮色/深色主题切换

## 环境要求

- Flutter 3.0+
- Dart 3.0+
- Android Studio / Xcode
- 真机或模拟器

## 快速开始

### 1. 安装 Flutter

参考官方文档: https://docs.flutter.dev/get-started/install

Windows 用户:
```powershell
# 下载 Flutter SDK 并解压到合适位置
# 添加 flutter/bin 到 PATH 环境变量
flutter doctor  # 检查环境
```

### 2. 安装依赖

```bash
cd zjulife_flutter
flutter pub get
```

### 3. 运行应用

```bash
# 检查可用设备
flutter devices

# 运行 (Debug 模式)
flutter run

# 指定设备运行
flutter run -d <device_id>
```

### 4. 构建发布版本

```bash
# Android APK
flutter build apk --release

# Android App Bundle (推荐用于上传应用商店)
flutter build appbundle

# iOS (需要 Mac)
flutter build ios --release
```

## 项目结构

```
lib/
├── main.dart              # 入口文件
├── app.dart               # App 配置
├── config/
│   ├── theme.dart         # 主题配置 (Editorial 风格)
│   ├── routes.dart        # 路由配置
│   └── constants.dart     # API 常量
├── models/
│   ├── canteen.dart       # 食堂数据模型
│   ├── bus.dart           # 班车数据模型
│   └── library.dart       # 图书馆座位模型
├── providers/
│   ├── auth_provider.dart      # 认证状态
│   ├── theme_provider.dart     # 主题状态
│   └── favorites_provider.dart # 收藏管理
├── services/
│   ├── http_service.dart       # HTTP 客户端
│   ├── canteen_service.dart    # 食堂数据服务
│   ├── bus_service.dart        # 班车服务
│   └── library_service.dart    # 图书馆服务
├── screens/
│   ├── main_shell.dart         # 主布局 + 底部导航
│   ├── home/                   # 首页
│   ├── canteen/                # 食堂页
│   ├── bus/                    # 班车页
│   ├── study/                  # 自习页
│   ├── profile/                # 我的页
│   └── auth/                   # 登录页 + CAS WebView
└── widgets/
    ├── header.dart             # 通用头部
    ├── cards.dart              # 卡片组件
    └── indicators.dart         # 指示器组件
```

## 设计风格

保留了原 Web 版的 **Editorial 设计风格**:

- 衬线字体标题 (Noto Serif SC)
- 方形边框卡片
- 黑白主色调 + 琥珀色强调
- 大写字母标签 (letter-spacing)
- 悬停反转效果

## 数据来源

| 功能 | 数据源 | 备注 |
|------|--------|------|
| 食堂人流 | `general_new.php?t=xxx` | 需内网访问 |
| 班车时刻 | `bccx.zju.edu.cn` | 需内网访问 |
| 图书馆座位 | `booking.lib.zju.edu.cn` | 需 CAS 认证 |

## 关于内网访问

移动端 App 相比 Web 的优势:

1. **无 CORS 限制** - 可以直接请求内网 API
2. **WebView 认证** - 可以通过 WebView 完成 CAS 登录并获取 Cookie
3. **在校园网内** - 连接校园 WiFi 或 VPN 后可访问所有内网资源

## 开发说明

### 添加新功能

1. 在 `models/` 创建数据模型
2. 在 `services/` 创建服务类
3. 在 `screens/` 创建页面
4. 在 `config/routes.dart` 添加路由

### 自定义主题

编辑 `lib/config/theme.dart` 修改颜色、字体等样式。

## 注意事项

- 字体文件需要手动添加到 `assets/fonts/` 目录
- 首次运行需要创建 `assets/images/` 和 `assets/icons/` 目录
- iOS 编译需要 macOS 系统

## License

MIT
