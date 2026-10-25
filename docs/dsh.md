# 可选 DSH 接入

本地动画、猫咪和 Touch Bar 触摸不依赖 DSH。任务状态、聊天、碎碎念和余额查询需要安装独立宿主适配包。

## 安装前

- 安装官方 DSH，并在其中配置自己的模型。
- 当前验证的宿主为 DSH `0.2.1-rc.2`；桥接固定依赖 `dsh-pet@0.3.8`。
- 准备可用的 Node.js 以运行安装脚本。
- 先完成正在执行的任务；插件安装后需要正常重开 DSH 才加载。

## 预览与安装

```sh
node scripts/setup-dsh.mjs --dry-run
node scripts/setup-dsh.mjs --apply
```

没有 `--apply` 时只预览。脚本会尝试找到官方 DSH CLI；需要时可明确指定：

```sh
node scripts/setup-dsh.mjs --apply \
  --dsh-cli "/Applications/DeepSeek Harness.app/Contents/Resources/runtime/cli/bin/dsh" \
  --profile desktop
```

`--dsh-home` 用于自定义数据根；`--profile` 默认为 `desktop`。先运行 `--help` 查看当前可用选项。不要把个人模型凭据复制进项目目录或当成参数传入这些脚本。

## 初始配置

安全初始配置只创建原生 Touch Bar 使用的 `main` 宠物：显示目标为 `web`，但桥接不加载浏览器渲染器，也不启动桌面宠物 Helper。自动碎碎念、自动余额轮询和系统通知关闭，工作状态联动开启。

已有配置不会被静默重写。若安装器报告冲突，先按说明审查自己的设置；可用 `--write-example` 生成一份不含凭据的新示例，比较后再决定如何使用。不要为安装桌宠删除整个 DSH 数据目录。

## 使用与故障排查

重开 DSH 后，适配会发布非敏感运行端点文件，原生应用自动发现当前端口。没有检测到适配时，应用继续本地陪伴；可以在菜单栏查看连接状态。

- 确认 DSH 与桥接实际加载在同一个 profile。
- 确认 DSH 已重开，而非只有网页刷新。
- 如果以前单独安装了上游 `dsh-pet`，按安装器提示处理重复渲染配置。
- 模型调用失败时，先在 DSH 内确认模型能正常工作；不要把 API Key 填进 Touch Bar 的地址框。
- 尊重 DSH 的本机访问授权；不要复制浏览器 Cookie 或关闭访问闸门。

聊天和碎碎念仅在主动点击时请求模型，可能计费。余额支持范围取决于服务商。此桥接不提供亲密度或食物库存养成系统。

## 移除桥接

```sh
node scripts/remove-dsh.mjs --dry-run
node scripts/remove-dsh.mjs --apply
```

移除通过官方 CLI 撤销本插件声明，保留 DSH 的会话、账户与用户配置。应用自身的卸载是单独步骤，见主 README。

上游原作者：<https://github.com/PC2005-cloud/dsh-pet>。
