# 构建指南

这份指南用于说明如何在本地使用 Xcode 构建本项目，并最终导出 `.app` 与 `.dmg`。

## 1. 准备工作

- 已安装 Xcode
- 已能正常打开项目 [MonitorControl.xcodeproj](/Users/likai/Documents/apple-project/MonitorControl/MonitorControl.xcodeproj)
- 已解析 Swift Package 依赖

如果依赖没有自动解析，可以在 Xcode 中执行：

`File > Packages > Resolve Package Versions`

## 2. 修改版本号

项目根目录已经提供了版本号脚本：

[set-version.sh](/Users/likai/Documents/apple-project/MonitorControl/set-version.sh)

使用方法：

```sh
./set-version.sh 1.1.0
```

或者直接运行后手动输入：

```sh
./set-version.sh
```

这个脚本会：

- 更新工程中的 `MARKETING_VERSION`
- 同步更新发布模板里的示例版本号

## 3. 在 Xcode 中构建 `.app`

1. 用 Xcode 打开 [MonitorControl.xcodeproj](/Users/likai/Documents/apple-project/MonitorControl/MonitorControl.xcodeproj)
2. 左上角 `Scheme` 选择 `MonitorControl`
3. 将配置切换到 `Release`
4. 检查 `Signing & Capabilities`
   确保 `MonitorControl` 和 `MonitorControlHelper` 都使用你的 Team
5. 点击菜单栏：
   `Product > Archive`

构建完成后会自动打开 `Organizer`。

## 4. 从 Organizer 导出 `.app`

在 `Organizer` 中：

1. 选中刚生成的 Archive
2. 点击右侧 `Distribute App`
3. 选择 `Custom`
4. 点击 `Next`
5. 选择 `Copy App`
6. 后面保持默认，继续 `Next`
7. 选择一个导出目录
8. 点击 `Export`

导出完成后，你会得到一个 `LumaGlass.app`。

## 5. 使用终端打包 `.dmg`

拿到 `.app` 后，在终端执行以下命令：

```sh
mkdir -p /tmp/LumaGlassDMG
rm -rf /tmp/LumaGlassDMG/LumaGlass.app
rm -f /tmp/LumaGlassDMG/Applications
cp -R "/你的导出目录/LumaGlass.app" /tmp/LumaGlassDMG/
ln -s /Applications /tmp/LumaGlassDMG/Applications

hdiutil create \
  -volname "LumaGlass" \
  -srcfolder /tmp/LumaGlassDMG \
  -ov \
  -format UDZO \
  "/你的输出目录/LumaGlass-1.1.0.dmg"
```

说明：

- `/你的导出目录/LumaGlass.app` 需要替换成你刚刚导出的 `.app` 实际路径
- `/你的输出目录/LumaGlass-1.1.0.dmg` 需要替换成你想保存 `.dmg` 的目标路径
- 文件名里的 `1.1.0` 可以改成你当前版本号

## 6. 可选：DMG 背景图

项目根目录已经有一张可用的 DMG 背景图：

[dmg-background-1200x720.png](/Users/likai/Documents/apple-project/MonitorControl/dmg-background-1200x720.png)

尺寸为：

- `1200 x 720`

如果你后面要进一步做美化版 DMG，可以在制作窗口布局时使用这张图。

## 7. 常见问题

### 依赖解析失败

先确认当前网络可以访问这些依赖仓库：

- `MediaKeyTap`
- `Sparkle`
- `SimplyCoreAudio`
- `KeyboardShortcuts`
- `Settings`

然后在 Xcode 里重新执行：

`File > Packages > Resolve Package Versions`

### Archive 成功了，但导不出 `.app`

通常优先检查：

- 是否正确选择了 `Custom`
- 是否选择了 `Copy App`
- 签名 Team 是否配置正确

### 构建后版本号不对

先运行：

```sh
./set-version.sh 目标版本号
```

然后重新 Archive。

### `CFBundleVersion` 自动变化

这是项目里的构建脚本行为，属于正常现象。它会自动递增 build number，不影响你手动设置的 `MARKETING_VERSION`。

## 8. 推荐流程

每次正式发版，建议按这个顺序操作：

1. 运行 `./set-version.sh x.y.z`
2. 在 Xcode 中执行 `Archive`
3. 从 `Organizer` 导出 `.app`
4. 用 `hdiutil` 打包 `.dmg`
5. 上传到 GitHub Releases
6. 参考 [RELEASE_TEMPLATE.md](/Users/likai/Documents/apple-project/MonitorControl/RELEASE_TEMPLATE.md) 编写发布说明
