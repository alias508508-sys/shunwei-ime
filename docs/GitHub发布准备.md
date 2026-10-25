# GitHub 源码与发行包准备

更新：2026-10-20。用户选择“先准备好，暂不上传”，本轮不创建远程仓库、不推送源码、不发布Release、不触发GitHub Actions。

建议项目名：`shunwei-ime`。GitHub用于版本管理、Issue反馈、自动构建和Release下载；GitHub Pages只能展示网页体验，无法代替系统输入法。

## 当前可交付

- Mac DMG：用户级图形安装器，内含真正InputMethodKit输入法，默认拼音。
- Windows EXE：NSIS安装器，内含x64/x86 TSF DLL，注册系统输入法，不是网页套壳。
- 源码ZIP：网页、Mac、Windows、词典数据、构建脚本、文档与Actions配置；不含下载的编译工具链、node_modules、构建缓存和凭证。

`releases`目录存放发行文件，不进入Git源码历史。发布时应把DMG和EXE放到GitHub Release附件；源码历史保留文本与构建配置。

## 后续上传流程

1. 确定仓库归属、名称、公开/私有。
2. 审阅暂存源码、第三方数据来源及原创代码许可选择。
3. 创建GitHub仓库、提交初始版本并推送。本轮未执行。
4. 手动触发 `.github/workflows/build.yml`。其Windows作业会用Windows SDK重新编译并执行解码检查；本轮尚未在GitHub运行，不能声称CI已通过。
5. 在真实Windows和Mac用户会话中启用输入法，逐项记录记事本/TextEdit、浏览器、办公软件、密码框、失焦、候选窗、安装与卸载结果。
6. 正式发布前补齐Apple Developer ID签名、公证，以及Windows代码签名。开发包目前未具备这些正式签名条件。

## 许可与数据

原始词库及派生数据出处、许可证保留在 `docs/THIRD_PARTY_NOTICES.md`、`docs/sources.json` 与 `data/upstream`。原创代码的对外开源许可证尚未选定；第三方词库的既有许可仍适用。

Windows引擎直接读取从同一原始数据导出的TSV；二进制发行包同时附带词库说明。不要把词库、引擎、应用三个层面的许可混为一谈。

## Git忽略项

`.gitignore`排除 `.tools`、`node_modules`、各平台build目录、releases、浏览器输出、`.env`、`.npmrc`、签名证书和移动配置文件。上传前仍应检查自己后续新增文件。

## 构建命令

```bash
npm ci
npm test
npm run build:mac
npm run package:mac
```

Mac本地交叉构建Windows需LLVM-MinGW 20261006（macOS universal工具链），设置 `SHUNWEI_MINGW_ROOT` 或放在脚本默认 `.tools`目录。再运行：

```bash
npm run build:windows:cross
npm run package:windows
```

Windows也可使用Visual Studio/Windows SDK直接构建 `windows/CMakeLists.txt`，分别选择x64和Win32平台；参见Actions配置。两条路径都不等于已经完成真实宿主测试。
