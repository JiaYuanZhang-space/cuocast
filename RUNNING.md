# 世界杯 2026 App — 运行文档

两部分: **后端代理(FastAPI)** + **Flutter App**。App 不直连数据源, 一切经代理。先跑代理, 再跑 App。

```
Flutter App ──HTTP──> 代理(:8000) ──> API-Football(赛事数据)
                                  └──> 500.com(竞彩赔率, 抓取)
```

---

## 0. 前置环境

| 工具 | 版本 | 本机位置 |
|------|------|---------|
| Python | **3.10+**(不能用 3.8) | `py -3.10`(3.10.11 已装) |
| Flutter SDK | 3.x(Dart 3.11) | `D:\MySoft\Program\Tools\flutter\bin` |
| API-Football 密钥 | 免费注册 | https://www.api-sports.io/ |

> ⚠️ 默认 `python` 是 3.8.10, 跑不了代理(代码用 3.10+ 语法)。代理一律用 `py -3.10` 或 venv 里的 python。

---

## 1. 启动后端代理

### 1.1 首次安装

```powershell
cd D:\MySoft\Space\Project\ai_project\proxy
py -3.10 -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

### 1.2 配置密钥

```powershell
copy .env.example .env
```

编辑 `.env`, 填入 API-Football 密钥:
```
API_FOOTBALL_KEY=你的密钥
API_FOOTBALL_BASE=https://v3.football.api-sports.io
WC_LEAGUE_ID=1
WC_SEASON=2026
```

> 没填密钥也能启动, 但赛事端点会返回 502(上游 401)。

### 1.3 运行

```powershell
cd D:\MySoft\Space\Project\ai_project\proxy
.venv\Scripts\activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

> `--host 0.0.0.0` 让模拟器/真机能访问宿主机。

### 1.4 验证代理

另开一个终端:
```powershell
curl http://localhost:8000/health
```
应返回 `{"status":"ok"}`。

其他端点(返回 `{"data": ..., "stale": false}`):

| 路径 | 说明 |
|------|------|
| `/fixtures` | 赛程 |
| `/live` | 进行中比赛 |
| `/results` | 已完赛 |
| `/standings` | 小组积分 |
| `/bracket` | 淘汰赛对阵(按轮次) |
| `/events?fixtureId=<id>` | 某场事件(进球/牌/换人) |
| `/odds?matchId=<id>` | 竞彩赔率(抓取失败返回 `data:null`) |

`stale:true` = 上游不可用, 已回退到上次缓存。

---

## 2. 启动 Flutter App

### 2.1 配置代理地址

编辑 `app/lib/config.dart` 的 `proxyBaseUrl`, 按运行目标选:

| 运行目标 | 地址 |
|---------|------|
| **Android 模拟器** | `http://10.0.2.2:8000`(默认, 10.0.2.2 = 模拟器眼中的宿主机) |
| **iOS 模拟器 / 桌面 / Web** | `http://localhost:8000` |
| **真机(同一局域网)** | `http://<宿主机IP>:8000`, 如 `http://192.168.1.20:8000` |

宿主机 IP 查法: `ipconfig`(看 IPv4 地址)。

### 2.2 安装 + 运行

```powershell
cd D:\MySoft\Space\Project\ai_project\app
flutter pub get
flutter devices          # 看可用设备
flutter run              # 选设备运行; 或 flutter run -d chrome / -d windows
```

App 启动后底部 5 标签: 赛程 · 实况 · 结果 · 积分 · 赔率。
- 实况页每 30 秒自动刷新; 所有页下拉刷新。
- 网络失败时显示上次缓存数据。

---

## 3. 跑测试

代理:
```powershell
cd D:\MySoft\Space\Project\ai_project\proxy
.venv\Scripts\python.exe -m pytest tests\ -v
```
预期: **24 passed**。

App:
```powershell
cd D:\MySoft\Space\Project\ai_project\app
flutter test
flutter analyze
```
预期: **30 tests passed** + `No issues found!`。

---

## 4. 端到端最短路径

1. 终端 A: 启动代理(第 1 节), 确认 `/health` 返回 ok。
2. 改 `config.dart` 地址(第 2.1 节)。
3. 终端 B: `cd app && flutter run`, 选设备。
4. App 内切标签, 看真实赛事数据。

---

## 5. 常见问题

| 现象 | 原因 / 解决 |
|------|------------|
| 代理启动报语法错 | 用了 Python 3.8。改用 `py -3.10` / venv。 |
| 赛事端点 502 | 没填 / 填错 API-Football 密钥; 或当日免费额度(100次/天)用尽。 |
| App 一直转圈或"加载失败" | 代理没起 / 地址配错。模拟器必须用 `10.0.2.2` 而非 `localhost`。 |
| App 真机连不上 | 宿主机防火墙挡了 8000; 或 IP 填错; 确认手机与电脑同局域网。 |
| 赔率页"暂无赔率" | 赔率抓取选择器 `parse_wdl` 的 `table#wdl` 是**占位**, 需按真实 500.com 页面结构调整(见 `proxy/app/odds_scraper.py`)。 |
| `flutter run` 找不到设备 | `flutter devices` 看列表; Windows 桌面用 `-d windows`, 浏览器用 `-d chrome`。 |

---

## 6. 尚未完成(见 `docs/superpowers/specs/`)

- 赔率抓取选择器需对接真实 500.com 页面
- 横向淘汰赛对阵图 UI(数据层 `fetchBracket` 已就绪)
- 赔率让球/比分/总进球/半全场(代理当前只给胜平负)
- 从比赛点进赔率详情(当前赔率页用占位 matchId=101)
- 商店合规(含赔率内容审核)

---

## 7. 目录速查

```
proxy/    FastAPI 代理 — app/(代码) tests/(24测试) README.md
app/      Flutter App — lib/(models/data/state/ui) test/(30测试) README.md
prototype/index.html   可点击 HTML 原型(5页)
docs/superpowers/      spec + 实现计划
```
