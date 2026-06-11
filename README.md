# 球程 CupCast ⚽

> 世界杯 2026 观赛 App — 实时查看 **赛程 · 实况 · 结果 · 积分/对阵 · 竞彩赔率**

经一层后端代理统一数据, App 本身不直连任何外部源。实况自动轮询, 弱网回退本地缓存。

```
┌──────────────┐   HTTP   ┌────────────────────┐         ┌────────────────┐
│  Flutter App │ ───────▶ │   代理 (FastAPI)     │ ──────▶ │  API-Football  │  赛事数据
│ (Android/iOS)│ ◀─────── │  缓存 · 限流 · 降级   │ ──────▶ │  500.com       │  竞彩赔率
└──────────────┘          └────────────────────┘         └────────────────┘
```

## 功能

| 页面 | 说明 |
|------|------|
| 📅 赛程 | 未开赛列表, 按日期/阶段筛选 |
| 🔴 实况 | 进行中比赛, 比分 + 事件时间轴, **每 30 秒自动刷新** |
| 📊 结果 | 已完赛历史比分(含点球) |
| 🏆 积分/对阵 | 小组积分表(出线区高亮)+ 淘汰赛对阵 |
| 💰 赔率 | 中国体彩竞彩赔率(胜平负, 仅展示不投注) |

## 技术栈

- **App:** Flutter (Dart 3.11) · `http` · `provider` · `shared_preferences`
- **代理:** Python 3.10 · FastAPI · httpx · selectolax
- **测试:** 代理 24 + App 30 全绿, `flutter analyze` 干净, 全程 TDD

## 快速开始

详见 **[RUNNING.md](RUNNING.md)**。最短路径:

```bash
# 1. 代理
cd proxy
py -3.10 -m venv .venv && .venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env        # 填 API-Football 密钥
uvicorn app.main:app --port 8000

# 2. App (另开终端)
cd app
flutter pub get
flutter run                   # 模拟器默认连 10.0.2.2:8000
```

## 目录

```
proxy/      FastAPI 代理 — app/(代码) tests/(24测试)
app/        Flutter App  — lib/(models·data·state·ui) test/(30测试)
prototype/  可点击 HTML 原型(5 页)
docs/superpowers/  设计 spec + 两份实现计划
RUNNING.md  端到端运行文档
```

## 路线图

- [ ] 赔率抓取对接真实 500.com 页面(当前 `parse_wdl` 选择器为占位)
- [ ] 横向淘汰赛对阵图 UI(数据层 `fetchBracket` 已就绪)
- [ ] 赔率让球 / 比分 / 总进球 / 半全场(代理当前仅胜平负)
- [ ] 从比赛点进赔率详情(当前用占位 matchId)
- [ ] 推送通知 / 收藏 / 多赛事

## 声明

本项目仅**展示**公开赛事信息与赔率, 不提供任何投注功能。理性看球, 远离非法赌博。
