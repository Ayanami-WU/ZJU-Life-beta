# 食堂数据 API 集成说明

## 数据来源

食堂人流数据来自 `http://canteen.zju.edu.cn/general_new.php?t=xxx`

## API 响应格式

```json
{
  "data": {
    "canteen_name": [
      "海宁食堂一楼",
      "舟山食堂一楼",
      "之江食堂大厅",
      "华家池五食堂一楼",
      "华家池一食堂",
      "西溪二食堂二楼",
      "西溪一食堂二楼",
      "西溪一食堂一楼",
      "玉泉四食堂二楼",
      "玉泉四食堂一楼",
      "玉泉二食堂二楼",
      "玉泉二食堂一楼",
      "玉泉一食堂一楼",
      "紫金港银泉餐厅一楼A区",
      "紫金港银泉餐厅二楼",
      "紫金港银泉餐厅一楼",
      "紫金港玉湖餐厅二楼",
      "紫金港澄月餐厅二楼",
      "紫金港澄月餐厅一楼",
      "紫金港麦香餐厅",
      "紫金港临湖餐厅二楼",
      "紫金港风味餐厅",
      "紫金港休闲餐厅",
      "紫金港西区食堂",
      "紫金港东区食堂"
    ],
    "canteen_no": [
      "800037", "800035", "800033", "800031", "800030",
      "800028", "800025", "800024", "800019", "800018",
      "800016", "800015", "800013", "800102", "800101",
      "800100", "800012", "800011", "800010", "800009",
      "800008", "800004", "800003", "800002", "800001"
    ],
    "canteen_num": [
      null, null, null, null, null,
      null, null, null, null, null,
      null, null, null, null, null,
      null, null, null, null, null,
      null, "17", null, null, null
    ],
    "canteen_allowance": [
      600, 360, 340, 460, 460,
      600, 424, 460, 500, 600,
      190, 160, 444, 804, 804,
      534, 1000, 460, 380, 320,
      200, 783, 688, 860, 1060
    ]
  }
}
```

## 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `canteen_name` | string[] | 食堂名称列表 |
| `canteen_no` | string[] | 食堂编号 |
| `canteen_num` | (string\|null)[] | 当前人数，null 表示暂无数据 |
| `canteen_allowance` | number[] | 食堂容量 |

## 校区推断

根据食堂名称包含的关键词推断所属校区：

```dart
final campusKeywords = {
  'zijingang': ['紫金港', '银泉', '玉湖', '澄月', '麦香', '临湖', '风味', '休闲'],
  'yuquan': ['玉泉'],
  'xixi': ['西溪'],
  'huajiachi': ['华家池'],
  'haining': ['海宁'],
  'zhoushan': ['舟山', '之江'],
};
```

## 拥挤程度计算

```dart
double crowdLevel = currentCount / capacity;

String crowdStatus;
if (crowdLevel < 0.3) status = '空闲';
else if (crowdLevel < 0.6) status = '适中';
else if (crowdLevel < 0.85) status = '较挤';
else status = '拥挤';
```

## 注意事项

1. 此 API 需要在**校园网内**才能访问
2. 添加时间戳参数 `t=xxx` 防止缓存
3. `canteen_num` 可能为 `null`，表示该食堂暂无实时数据
