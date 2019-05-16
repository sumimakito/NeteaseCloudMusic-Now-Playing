NeteaseCloudMusic-Now-Playing
======
通过进程注入的方式来获得 macOS 网易云音乐的正在播放信息

## 应用范例

同步我的近期正在播放信息

[https://mak1t0.cc/now-playing](https://mak1t0.cc/now-playing)

## 详细思路

[https://keep.moe/2019/05/16/netease-now-playing-lldb/](https://keep.moe/2019/05/16/netease-now-playing-lldb/)

[https://keep.moe/2019/05/16/netease-now-playing-interceptor/](https://keep.moe/2019/05/16/netease-now-playing-interceptor/)

## 构建

运行 `make` 构建成功后将生成 build 文件夹，其中 libncmnp.dylib 需要与可执行文件处于同一目录下。

## 使用

将 src/cli/script.py 复制至可执行文件所在目录，并保证 libncmnp.dylib 在同一目录下。

可以对 script.py 中的 on_updated 函数体进行修改，但不推荐修改函数签名。

另外由于脚本部分将使用 execv 调用 python，引入更多外部依赖可能会导致运行时出现未知问题，因此推荐在 script.py 中仅进行本地文件 I/O 操作（如更新记录当前播放歌曲信息的文件）。

这种情况下可以配合外部单独运行的 File watcher 来进行更复杂的操作。

```
sudo ./ncmnp $(pgrep NeteaseMusic)
```

> 缺少 sudo 会无法 Attach 及对内存进行注入

## 其他

代码仍在整理中，目前 leaks 工具暂未发现运行时内存泄漏。欢迎提供发现的 Bug。
