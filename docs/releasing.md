# GitHub 发布流程

## 1. 核对范围

发布源码来自独立的干净目录，只包含必要代码、素材、脚本、测试与文档。不要把个人工作目录、系统 Touch Bar 备份、DSH profile 或本机诊断目录整体提交。

首次发布前检查：

- README 与第三方许可完整，预览图中没有用户信息。
- 本地路径、安装记录、聊天内容和凭据已排除。
- 实际暂存文件清单、差异和已有 Git 历史已经审查。
- 默认安装不会自动启用登录自启，不会自动调用模型。
- 已在临时用户环境测试安装、配置冲突、卸载和自启取消。
- 架构构建结果和真实硬件运行验证分开记录。

## 2. 构建与验证

```sh
python3 scripts/audit-release.py --tree .
gitleaks dir . --redact=100
bash build.sh
bash scripts/test.sh
bash scripts/package.sh --dry-run
bash scripts/package.sh
python3 scripts/source-package.py --dry-run
python3 scripts/source-package.py
```

默认产物在 `dist/`。源码构建默认包含 arm64 和 x86_64；二进制包含某架构不代表该架构已经通过物理 Touch Bar 实机验收。

Gitleaks 工作树扫描使用 `gitleaks dir . --redact=100`；暂存区扫描使用 `gitleaks git --pre-commit --staged . --redact=100`。这里的命令针对干净发布目录，不扫描个人 DSH 数据。参数已按 Gitleaks 8.30.1 核对，工具来源为 [gitleaks/gitleaks](https://github.com/gitleaks/gitleaks)。扫描输出全量脱敏；如另行指定报告文件，写到仓库外的私有临时目录，报告不得入库。

检查最终压缩包文件清单和 SHA-256。应用包只携带必要运行资源、帮助和署名，不携带本机 profile、日志、备份或私钥。

## 3. 签名与公证

默认打包使用 ad-hoc 签名，并明确标记为未公证。公开下载版可使用 Developer ID 签名；打包脚本仅在显式设置 `SIGN_IDENTITY` 时使用该身份。只有明确设置 `NOTARY_PROFILE` 才提交公证请求。

签名身份与公证凭据由维护者的钥匙串或受保护的 CI 配置管理。不要把证书、口令、密钥文件或账户信息提交到仓库，不要在工作流日志中打印它们。

Apple 官方说明：<https://developer.apple.com/developer-id/>。

## 4. 建立仓库与发布

创建仓库、选择可见性并审查首次提交。仓库名可采用 `whale-girl-touchbar`；实际所有者与网址由维护者决定，本模板不预设。

版本号以 `VERSION` 为准，推荐标签形式为 `v12.0.2`。发布前再次核对实际版本，不要复用已经发布过的标签指向不同代码。使用 GitHub Releases 附上应用压缩包、校验文件和发布说明；源码存档与可安装应用包应清楚区分。

打包和 CI 不会自动创建公开仓库或推送发布。维护者在审查后执行远程操作。

GitHub 官方说明：<https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases>。

## 发布说明模板

```markdown
# Whale Girl Touch Bar VERSION

本版变化：
- [具体用户可见变化]

下载：
- [应用压缩包及架构]
- [SHA-256 文件]

兼容性：
- 需要物理 Touch Bar
- macOS 编译目标下限：[版本]
- 实机验证：[系统 / CPU / 机型；没有测过的明确写未测]
- DSH 联动验证：[版本或未验证]

签名与公证：[ad-hoc 未公证 / Developer ID / 已公证；按实际填写]

模型调用：[仅手动 / 具体变动与费用说明]

原始动画作者：https://github.com/PC2005-cloud/dsh-pet
PC2005 动画素材按其非商业条款使用；其他来源见 THIRD_PARTY_NOTICES.md。
```


## 手动首次上传示例

先在 GitHub 创建属于自己的空仓库。以下账号是占位符，不能原样使用；命令应在已经检查过的干净发布目录运行。

```sh
git init -b main
python3 scripts/audit-release.py --tree .
git add Sources Resources Support Tests scripts docs .github \
  README.md LICENSE THIRD_PARTY_NOTICES.md CHANGELOG.md CONTRIBUTING.md \
  SECURITY.md .gitignore .gitattributes VERSION build.sh
python3 scripts/audit-release.py --tree . --staged
gitleaks git --pre-commit --staged . --redact=100
git diff --cached --stat
git diff --cached
```

审查实际暂存内容后再创建首个提交并推送：

```sh
git commit -m "Prepare initial Touch Bar companion release"
git remote add origin https://github.com/YOUR_ACCOUNT/whale-girl-touchbar.git
git push -u origin main
```

远程地址和账号由发布者填写。若目录已经有 Git 历史，先运行 `python3 scripts/audit-release.py --tree . --history` 和 `gitleaks git . --redact=100`，并确认当前仓库和远程地址；不要直接重复初始化或把其他项目的历史带进来。上面的示例不会代替文件、暂存区及历史审查。

可重复的本机 Gitleaks 检查：`python3 scripts/scan-publish.py`；已暂存文件另加 `--staged`，已有历史另加 `--history`。脚本只从官方固定版本下载扫描器，核对预置 SHA-256 后在本机执行，不上传候选文件；报告保存在被忽略的 build 目录中。
