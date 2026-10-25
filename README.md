# Whale Girl Touch Bar · 鲸鱼娘与三花猫

让鲸鱼娘和一只三花猫住进 MacBook 的 Touch Bar。支持原生触摸互动、随机玩耍，以及可选的 DeepSeek Harness（DSH）任务联动。

![Touch Bar 原生渲染预览](docs/images/touchbar-preview.png)

*预览为应用自身的离屏渲染。PC2005 动作素材来自 [PC2005-cloud/dsh-pet](https://github.com/PC2005-cloud/dsh-pet)，按其非商业素材条款使用。*

## 可以做什么

- **28 段完整原版动作**：吃零食、涮火锅、玩魔方、跳舞、打盹等；可以随机轮换，也能从菜单栏动作库点播。
- **真正侧身移动**：角色横移时使用稳定的侧跑循环，左右朝向随移动方向变化；完整原片仍保留在动作库。
- **稳定体型**：所有 PC2005 动作使用相同人物比例和脚底锚点，切换道具、气泡或遮挡关系时不再改变体型。
- **独立小猫**：小猫会散步、跑跳、离开一会儿，再回到鲸鱼娘身边；也有挡路、追赶和重聚的小剧情。
- **原生 Touch Bar 控件**：轻触、长按摸头、拖动与横向甩动；最右侧圆圈切换系统音量、亮度组件，并提供「返回桌宠」。
- **可选 DSH 联动**：同步思考、执行、等待、完成和出错状态；从菜单栏面板手动聊天、碎碎念或查询余额。

没有 DSH 也可以进行本地陪伴。Touch Bar 不显示文字气泡，长回复在菜单栏面板和对话窗口中阅读。

## 系统与硬件

| 项目 | 要求与验证状态 |
| --- | --- |
| Touch Bar | 需要带有物理 Touch Bar 的 MacBook；普通功能键、屏幕刘海和外接键盘不能替代 |
| macOS | 编译目标为 macOS 13 及以上；当前实际运行验证为 macOS 26.2、Apple Silicon |
| CPU | 构建脚本默认生成 arm64 + x86_64 通用二进制；Intel 实机运行仍需社区验证 |
| DSH（可选） | 桥接固定依赖 `dsh-pet@0.3.8`，当前联动验证基于 DSH `0.2.1-rc.2` |
| 开发工具 | Xcode Command Line Tools；桥接安装和开发测试另需 Node.js、Python 3 |

本项目使用经运行时检查的私有 Touch Bar 接口。系统更新可能改变其行为；声明编译目标不等于已经逐版本验证兼容性。

## 从源码运行

安装 Xcode Command Line Tools 后，在项目根目录执行：

```sh
bash build.sh
bash scripts/test.sh
bash scripts/install.sh --dry-run
bash scripts/install.sh
open "$HOME/Applications/DSH 鲸鱼娘.app"
```

默认构建输出为 `build/DSH 鲸鱼娘.app`，安装到当前用户的 `Applications` 目录。安装不会自动启动应用；同名且应用身份一致的旧版本会先备份；身份不同的应用不会被覆盖。只需要本机架构时，可执行 `ARCHS=arm64 bash build.sh` 或 `ARCHS=x86_64 bash build.sh`。

也可以在仓库的 Releases 页面下载应用压缩包。请检查发布说明中的架构、系统验证记录和签名状态；默认本地构建使用 ad-hoc 签名，不代表已获 Apple 公证。

## 如何操作

1. 打开应用后，菜单栏会出现小鱼图标；点击打开控制面板。
2. 点「打开动作库」选择完整动作；点皮肤开关切换 PC2005 动画或原版鲸鱼娘。
3. 在 Touch Bar 轻触角色打开互动选项，长按摸头，按住拖动，快速甩动会产生横向滑行。
4. 点最右侧圆圈显示系统音量、亮度组件，再点「返回桌宠」回到角色。
5. 暂停或退出应用会收起本应用的 Touch Bar；锁屏和睡眠时也会停止显示。

登录自启由使用者自行开启，不随安装默认启用：

```sh
bash scripts/autostart.sh enable --dry-run
bash scripts/autostart.sh enable
bash scripts/autostart.sh disable
```

应用保持在预期安装位置时，上述默认路径即可使用；自定义安装位置请给脚本传入 `--app`。

## 可选：连接 DSH

先安装和配置你自己的 DSH 与模型，再执行桥接安装。预览不会改动 DSH：

```sh
node scripts/setup-dsh.mjs --dry-run
node scripts/setup-dsh.mjs --apply
```

脚本尝试寻找官方 DSH CLI；也可以用 `--dsh-cli` 明确指定。默认 profile 为 `desktop`，其他部署可显式传入 `--profile` 和 `--dsh-home`。安装完成后，在当前任务结束时正常重开 DSH，使新插件生效。

首次配置采用原生 Touch Bar 渲染目标，关闭自动碎碎念、自动余额轮询和系统通知。若发现已有配置与此冲突，安装器会拒绝覆盖并说明下一步。详细流程见 [DSH 接入说明](docs/dsh.md)。

聊天和碎碎念会调用使用者在 DSH 中选择的模型，可能产生费用；只有主动点击时才请求。余额能力取决于服务商支持。PC2005 没有亲密度或小鱼干养成接口，本应用的投喂是本地互动。

## 卸载

```sh
bash scripts/uninstall.sh --dry-run
bash scripts/uninstall.sh
```

卸载脚本仅处理经过身份检查的本应用和它的自启项，保留用户数据及 DSH 资料。若另行安装了 DSH 桥接，可单独移除其插件声明：

```sh
node scripts/remove-dsh.mjs --dry-run
node scripts/remove-dsh.mjs --apply
```

## 开发、隐私与发布

```sh
python3 scripts/audit-release.py --tree .
bash build.sh
bash scripts/test.sh
bash scripts/package.sh --dry-run
bash scripts/package.sh
```

发布前应审查暂存区和实际归档内容；已有 Git 历史时也运行审计脚本的 `--history` 检查。凭据、个人 profile、日志、聊天记忆、备份及本机安装记录均不属于源码仓库或下载包；`.gitignore` 不能代替审查。参见 [贡献说明](CONTRIBUTING.md)、[隐私与安全](SECURITY.md)、[发布流程](docs/releasing.md)。

## 原作者与许可

本仓库新增代码采用 [MIT](LICENSE)。第三方代码和素材保留各自条款，**代码许可证不代表所有动画和角色形象都可以商用**。

- PC2005 原始动作：[PC2005-cloud/dsh-pet](https://github.com/PC2005-cloud/dsh-pet)，固定 `v0.3.8`；其动画、提示词和源视频采用上游非商业素材条款，并要求衍生作品署名。
- 原版精灵及部分行为逻辑：[vlln/whale-girl](https://github.com/vlln/whale-girl)，MIT，Copyright 2026 Sam Gao（vlln）；角色来源注明 ZipZipPipe。
- 三花猫为 AI 辅助生成的原创图集，在贡献者可授予的权利范围内按项目 MIT 提供；应用图标参考鲸鱼娘角色。此安排不扩张第三方角色、PC2005 素材或衍生图标的权利。

完整来源和范围见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。本项目是社区改作，与 DeepSeek、Apple 或素材原作者没有官方隶属或背书关系。
