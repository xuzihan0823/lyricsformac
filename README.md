# LyricsFloat (macOS)

一个接近 macOS 风格的 Apple Music 歌词悬浮窗原型。

## 已实现

- 悬浮窗始终置顶，不随应用切换隐藏
- 可拖动窗口、可通过窗口边缘缩放
- 歌词填充动画（当前行从左到右高亮）
- 触控板/鼠标捏合缩放歌词字号
- Apple Music 当前歌曲信息和歌词轮询读取（AppleScript）

## 运行

```bash
swift build
swift run LyricsFloat
```

## 权限

首次运行时，macOS 可能要求授权控制 `Music` 应用，请允许。

## 说明

Apple Music 通过脚本读取到的歌词通常是整段文本（非逐词时间轴）。  
当前实现会根据歌曲时长和每行字符数进行动态分配，得到“近似同步”的平滑填充效果。
