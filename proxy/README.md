# 世界杯代理服务

App 与上游数据源之间的代理：持密钥、缓存、限流降级，把 API-Football 与第三方竞彩赔率统一成 App 友好的精简 JSON。

## 运行

Windows（默认 `python` 是 3.8，跑不了；用 3.10）：

```powershell
cd proxy
py -3.10 -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env   # 填入 API-Football 密钥
uvicorn app.main:app --reload --port 8000
```

## 端点

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/health` | 健康检查 |
| GET | `/fixtures` | 赛程 |
| GET | `/live` | 进行中比赛 |
| GET | `/results` | 已完赛（FT） |
| GET | `/standings` | 小组积分 |
| GET | `/bracket` | 淘汰赛对阵（按轮次分组） |
| GET | `/odds?matchId=<id>` | 竞彩赔率（抓取失败返回 `data:null`） |

返回形如 `{"data": ..., "stale": false}`。`stale:true` 表示上游不可用、回退到上次缓存。

## 缓存 TTL（秒）

实况 30、赛程 3600、结果 21600、积分 3600、对阵 3600、赔率 300。

## 测试

```powershell
cd proxy
.venv\Scripts\python.exe -m pytest tests/ -v
```

## 注意

- API 密钥只放 `.env`（环境变量），绝不下发到 App。
- 赔率抓取第三方站点（500.com），有改版/反爬风险；解析用 `parse_wdl`，失败时该场返回 `null`，不影响其他功能。
