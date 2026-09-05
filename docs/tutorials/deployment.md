# 部署与分享试玩

## 本机浏览器

先完成 `python3 tools/workspace.py build RingRush`，再运行：

```sh
python3 -m http.server 8771 --bind 127.0.0.1 --directory builds/RingRush/web
```

打开 `http://127.0.0.1:8771/`。`127.0.0.1` 只供这台电脑使用，朋友无法通过这个地址远程访问。需要同一局域网试玩时，将 bind 改为本机局域网地址，并分享该地址；正式远程试玩使用下面的 HTTPS 静态部署。

## 静态托管

1. 解压 `builds/RingRush/RingRush-Web-Playtest.zip`，将里面的完整目录上传至自己的静态托管空间（可使用支持大文件的 Nginx、对象存储或 itch.io HTML5 项目）。
2. `index.html` 作为入口；`.wasm`、`.pck`、`.js`、图标和纹理变体都必须保留。确认所选托管服务单文件大小限制能容纳 PCK。
3. 使用 HTTPS，服务器对 `.wasm` 返回 `application/wasm`，不要把二进制请求重写为 SPA 首页。HTML 短缓存；发布新版本时清除同名 PCK/JS/WASM 缓存，避免版本混用。
4. 上传到版本目录，检查后再切换入口，方便回滚。先验收加载、声音、战斗、页面返回和刷新后存档，再把链接发给朋友。

此预设为单线程 Godot Web Compatibility 导出。需要支持 WebGL 2/WebAssembly 的浏览器；必须通过 HTTP(S)，不能双击 HTML 使用 `file://`。浏览器音频需要玩家交互；本地进度依赖同源浏览器存储，清理站点数据、换浏览器或换 origin 可能让存档不可见。[Godot Web 导出说明](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_web.html)。

## Mac

直接分享 `builds/RingRush/mac/RingRush.zip`，内含 app、中文试玩说明和许可证。当前为未 notarize 的试玩；使用自己信任来源的包，按 macOS 的打开提示操作。公开发行请按[构建教程](builds.md)完成签名与 notarization。

## 新版本交付

保存版本号、Git commit、SHA256SUMS、验证记录与已知限制。生成文件留在忽略提交的 builds 或外部 release 存储中，不提交到源码仓库。部署到公网涉及你的托管账户和地址；本次只生成可部署产物和步骤，没有创建外部站点。
