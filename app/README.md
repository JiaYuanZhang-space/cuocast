# 球程 CupCast (Flutter)

经后端代理查看赛程/实况/结果/积分/赔率。

## 运行
1. 先启动代理(见 `../proxy/README.md`), 监听 8000。
2. 配置代理地址 `lib/config.dart`:
   - Android 模拟器: `http://10.0.2.2:8000`(默认)
   - 桌面/Web/真机: 改为宿主机实际 IP, 如 `http://192.168.x.x:8000`
3. 运行:
   ```
   cd app
   flutter pub get
   flutter run
   ```

## 测试
```
cd app
flutter test
```

## 结构
- `models/` 数据模型 · `data/` 网络+缓存+仓库 · `state/` 控制器 · `ui/` 页面与组件
- 实况页每 30 秒轮询; 各页下拉刷新; 网络失败回退本地缓存。

## 后续增强(见 spec)
- 对阵图横向 bracket(`Repository.fetchBracket` 已就绪)
- 赔率让球/比分/总进球/半全场(代理当前只给胜平负)
- 从比赛点进赔率详情(当前赔率页用占位 matchId)
