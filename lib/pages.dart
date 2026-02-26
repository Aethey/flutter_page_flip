import 'package:flutter/material.dart';

@immutable
class DemoPageData {
  const DemoPageData({
    required this.title,
    required this.body,
    required this.pageNumber,
  });

  final String title;
  final String body;
  final int pageNumber;
}

@immutable
class PageTypography {
  const PageTypography({
    required this.horizontalPadding,
    required this.topPadding,
    required this.bottomPadding,
    required this.titleSize,
    required this.bodySize,
    required this.lineHeight,
    required this.paragraphSpacing,
    required this.pageNumberSize,
  });

  final double horizontalPadding;
  final double topPadding;
  final double bottomPadding;
  final double titleSize;
  final double bodySize;
  final double lineHeight;
  final double paragraphSpacing;
  final double pageNumberSize;
}

const PageTypography kPaperTypography = PageTypography(
  horizontalPadding: 28,
  topPadding: 34,
  bottomPadding: 28,
  titleSize: 26,
  bodySize: 16,
  lineHeight: 1.72,
  paragraphSpacing: 16,
  pageNumberSize: 13,
);

const List<DemoPageData> kDemoPages = [
  DemoPageData(
    pageNumber: 1,
    title: '风从纸页间穿过',
    body:
        '午后四点，窗外的梧桐叶被一阵短风掀起，光线像细小的水纹落在桌角。'
        '我把手指按在书页边缘，听见纸纤维极轻的摩擦声，那声音像有人在远处慢慢折一封旧信。\n\n'
        '阅读最迷人的时刻，不是看见答案，而是看见问题在句子之间缓慢成形。'
        '每一页都像一扇半开的门，门后并不急着给出结论，只让你先站在门槛上，'
        '闻见木头、灰尘和雨后的空气。',
  ),
  DemoPageData(
    pageNumber: 2,
    title: '城市的背面',
    body:
        '清晨第一班地铁进站时，广告灯箱还没完全点亮，站台像一块尚未显影的底片。'
        '人群在同一条扶梯上升，却各自想着不同方向的路。\n\n'
        '有人把今天排成清单，有人把昨天折成口袋里的小纸条。'
        '城市从不缺少速度，缺少的是那一秒钟的停顿：'
        '你抬头，看见高架桥下的一束斜光，突然知道自己仍然在生活，而不只是赶路。',
  ),
  DemoPageData(
    pageNumber: 3,
    title: '手写体温度',
    body:
        '键盘让句子整齐，手写让句子有呼吸。'
        '当笔尖在纸上停顿，你能看见犹豫的形状；当一笔忽然加重，'
        '你也能看见决心落下去的重量。\n\n'
        '我们总以为记忆依靠容量，其实它更依靠触感。'
        '一张泛黄便签、一本压扁的笔记本、一次写错后划掉的名字，'
        '都在悄悄提醒：时间并不是流逝，它只是换了一种纹理继续存在。',
  ),
  DemoPageData(
    pageNumber: 4,
    title: '雨夜与路灯',
    body:
        '夜里十点半，雨开始变密。'
        '路灯把每一滴雨都照成短暂的金线，落地后立刻消失。'
        '我在便利店门口等雨小一点，听见冰柜压缩机低频运转，像远处海潮。\n\n'
        '那一刻忽然明白，所谓平静并不是环境安静，'
        '而是你能在嘈杂里辨认出自己的节奏。'
        '就像翻页时那道弧线，看起来柔软，却始终知道该落向哪里。',
  ),
  DemoPageData(
    pageNumber: 5,
    title: '最后一页之前',
    body:
        '真正难的不是结束，而是承认结束后仍然要继续。'
        '书快读到尾声时，我们会下意识放慢速度，'
        '仿佛只要翻页更慢一点，故事就能多停留几分钟。\n\n'
        '但纸页终究会落下，灯也终究会熄灭。'
        '好在你已经带走了一部分光：'
        '它会在下一次抬手翻页时，重新照亮你的指尖。',
  ),
];
