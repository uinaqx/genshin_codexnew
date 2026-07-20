# Codex Klee Skin

给Codex Desktop做的一套可莉主题。浅奶油色界面、可莉红与暖金色点缀，首页、侧栏、建议卡片、输入框和聊天背景会一起换肤，原生按钮仍可正常点击。

## Windows一键安装

直接下载并双击：

[下载KleeCodexSkin-Setup-v1.1.2.exe](https://github.com/uinaqx/genshin_codexnew/releases/latest/download/KleeCodexSkin-Setup-v1.1.2.exe)

> 紧急兼容说明：Microsoft Store Codex 26.700及以上版本会拒绝CDP调试启动。v1.1.2安装后默认执行安全恢复，不会自动启用皮肤；它会还原完整安装前配置、备份并重建渲染缓存，然后从官方入口启动Codex。

安装包自带Node运行环境。安装完成后会自动打开可莉Codex皮肤管理器，可以：

- 一键启用或修复可莉皮肤
- 切换全屏版式和横幅版式
- 恢复Codex官方界面
- 从管理器或Windows设置中彻底卸载
- 启动失败时自动回滚并从官方入口重启Codex
- 导出不包含登录凭据内容的诊断报告

首次启用前，需要先安装Microsoft Store版Codex并正常打开、登录一次。安装包目前没有商业代码签名，Windows首次下载时可能显示SmartScreen提示，确认文件来自本仓库后选择仍要运行即可。

主视觉为本项目专门生成的原创同人风格插画，没有直接转载官方图或来源不明的二创图。

## 界面预览

| 首页全屏版 | 聊天页 |
| --- | --- |
| ![可莉主题首页全屏版预览](docs/previews/home-fullscreen.webp) | ![可莉主题聊天页预览](docs/previews/chat.webp) |

预览图按Codex当前界面结构本地渲染，用于展示配色、裁切和布局。真实界面中的按钮、侧栏、建议卡和输入框仍是Codex原生控件。

## 支持平台

- Windows 10/11，Microsoft Store版Codex Desktop
- macOS，官方Codex Desktop
- Windows一键安装包无需另装Node.js；手动安装方式需要Node.js 20或更高版本

## Windows手动安装

先打开并登录一次Codex，然后在PowerShell中运行：

```powershell
git clone https://github.com/uinaqx/genshin_codexnew.git
cd genshin_codexnew
.\quickstart.ps1
```

安装后默认启用可莉全屏主题。切换布局：

```powershell
node scripts\set-theme.mjs klee-spark-knight fullscreen
node scripts\set-theme.mjs klee-spark-knight banner
```

恢复官方界面：

```powershell
scripts\restore-dream-skin.ps1
```

完整卸载并恢复安装前的基础配色：

```powershell
scripts\restore-dream-skin.ps1 -Uninstall -RestoreBaseTheme
```

## macOS安装

下载并解压仓库后，双击：

```text
Install AutoSkin on macOS.command
```

也可以在终端运行：

```bash
scripts/autoskin-macos.sh install
scripts/autoskin-macos.sh theme klee-spark-knight fullscreen
```

卸载：

```bash
scripts/autoskin-macos.sh uninstall
```

## 它怎么工作

项目启动Codex时只在本机回环地址开启调试端口，再通过CDP注入CSS和少量界面装饰脚本。它不会替换或修改Codex官方文件，不会清空聊天、项目、登录信息或插件。

主题文件位于：

```text
themes/klee-spark-knight/
├── art.webp
├── extra.css
└── theme.json
```

更换主视觉或继续调整主题时，请按[THEME-SPEC.md](THEME-SPEC.md)的规则操作。

## 验证

列出并校验主题：

```bash
node scripts/injector.mjs --themes
node tests/test-klee-theme.mjs
```

macOS完整测试：

```bash
tests/test-macos.sh
```

## 许可证与声明

代码基于[Finderchangchang/codex-autoskin](https://github.com/Finderchangchang/codex-autoskin)，使用MIT许可证。修改说明见[NOTICE.md](NOTICE.md)，素材来源见[ASSET_PROVENANCE.md](ASSET_PROVENANCE.md)。

这是非官方同人项目，与OpenAI、HoYoverse无隶属或合作关系。角色形象、游戏名称和相关标识不属于MIT授权内容。
