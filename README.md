# LyricsFloat (macOS)

一个接近 macOS 风格的 Apple Music 歌词悬浮窗原型。

## 功能

- 悬浮窗始终置顶，不随应用切换隐藏
- 可拖动窗口、可通过窗口边缘缩放
- 歌词填充动画（当前行从左到右高亮）
- 触控板/鼠标捏合缩放歌词字号
- 状态控制：锁定窗口、点击穿透、透明度轮换
- 主题切换：`Graphite`（深色）/`Frosted`（浅色毛玻璃）
- 菜单栏控制入口（开启点击穿透后也能恢复交互）

## 歌词来源优先级

1. Apple Music 内嵌时间轴（若歌词本身带 `[mm:ss.xx]`）
2. 本地 `.lrc` 文件
3. 网易云歌词 API（可选开关，默认关闭）
4. Apple Music 纯文本歌词的估算时间轴（回退）

## 运行

```bash
swift build
swift run LyricsFloat
```

首次运行时，macOS 可能要求授权控制 `Music` 应用，请允许。

## 导出 .app

```bash
./scripts/export_app.sh
```

导出产物位置：

- `./dist/LyricsFloat.app`

导出脚本会执行：

- Release 编译
- 组装 `LyricsFloat.app`
- 写入 `Info.plist`（包含 Apple Events 权限说明）
- 本地 ad-hoc 签名（便于直接启动）

## 本地 LRC 放置目录

程序会优先在以下目录查找：

- `./Lyrics/`（项目根目录）
- `~/Music/LyricsFloat/Lyrics/`
- `~/Library/Application Support/LyricsFloat/Lyrics/`

建议文件名：

- `<歌曲名> - <歌手名>.lrc`
- `<歌手名> - <歌曲名>.lrc`
- `<persistentID>.lrc`

## 关于网易云非官方 API

当前实现使用了公开可访问的非官方接口作为“可选兜底源”，不作为唯一依赖。  
这类接口可能随时变更、限流或失效，也可能存在服务条款风险。建议生产环境优先使用：

- 合法授权的官方歌词服务
- 或你自己的歌词服务层（带缓存和容灾）
- 感谢[Linux.do](https://linux.do)社区支持


