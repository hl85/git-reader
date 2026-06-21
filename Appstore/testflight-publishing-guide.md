# Gits Reader - TestFlight 发布指南

TestFlight 是 Apple 官方提供的 Beta 测试工具，允许您在正式发布到 App Store 之前，邀请内部团队或外部用户测试您的 App。以下是完整的发布流程：

---

## 第一阶段：准备工作

### 1. 注册 Apple 开发者账号
* 必须拥有一个活跃的 Apple Developer 账号（个人账号每年 $99 美元）。

### 2. 在 App Store Connect 中创建 App
1. 登录 [App Store Connect](https://appstoreconnect.apple.com/)。
2. 点击 **我的 App** -> 点击左上角的 **“+”** 号 -> 选择 **新建 App**。
3. 填写基本信息：
   * **平台**：iOS
   * **名称**：`Gits Reader` (如果重名，可以尝试加后缀，如 `Gits Reader - Obsidian Sync`)
   * **主要语言**：简体中文 (Simplified Chinese)
   * **套装 ID (Bundle ID)**：选择您在 Xcode 中配置的 Bundle ID（例如 `com.yourname.GitsReader`）。
   * **SKU**：一个独特的标识符，可以用 `com.yourname.GitsReader`。
   * **用户访问权限**：完全访问权限。
4. 点击 **创建**。

---

## 第二阶段：Xcode 配置与打包上传

### 1. 配置 Signing & Capabilities
1. 在 Xcode 中打开 `GitsReader.xcodeproj`。
2. 选择项目根节点 -> 选择 **GitsReader** Target -> 进入 **Signing & Capabilities** 标签页。
3. 勾选 **Automatically manage signing** (自动管理签名)。
4. 在 **Team** 中选择您的 Apple 开发者账号团队。
5. 确保 **Bundle Identifier** 与您在 App Store Connect 中创建的 Bundle ID 完全一致。

### 2. 检查版本号与构建号
在 **General** 标签页中：
* **Version** (版本号)：例如 `1.0.0` (对应 App Store 的公开版本号)。
* **Build** (构建号)：例如 `1` (每次上传新包时，Build 号必须递增，如 `2`, `3`...)。

### 3. 打包 (Archive)
1. 在 Xcode 顶部运行设备选择器中，选择 **Any iOS Device (arm64)**（不能选择模拟器，否则 Archive 按钮是灰色的）。
2. 点击 Xcode 菜单栏的 **Product** -> **Archive**。
3. 等待编译完成，Xcode 会自动弹出 **Organizer** 窗口。

### 4. 上传到 App Store Connect
1. 在 Organizer 窗口中，选中刚刚打包好的版本，点击右侧的 **Distribute App**。
2. 选择 **TestFlight & App Store** -> 点击 **Distribute**。
3. 按照提示一路点击 **Next**，Xcode 会自动进行签名验证并上传。
4. 上传成功后，会显示 "App successfully uploaded"。

---

## 第三阶段：在 App Store Connect 中配置 TestFlight

上传成功后，通常需要等待 5-15 分钟，Apple 的服务器会对安装包进行处理（Processing）。处理完成后，您会收到一封电子邮件。

### 1. 完善测试信息 (Test Information)
1. 登录 App Store Connect，进入您的 App 页面。
2. 点击顶部导航栏的 **TestFlight** 标签页。
3. 在左侧菜单中点击 **测试信息 (Test Information)**。
4. 填写必填项：
   * **测试内容 (What to Test)**：简要说明这个版本测试什么（例如：`初始版本测试，支持 Git 同步与 Obsidian 语法渲染。`）。
   * **反馈 Email**：您的联系邮箱。

### 2. 内部测试 (Internal Testing) —— 无需审核，立即开始
内部测试适用于您的团队成员（最多 100 人，需在 App Store Connect 中添加为用户）。
1. 在 TestFlight 页面左侧，点击 **App Store Connect 用户**。
2. 点击旁边的 **“+”** 号，选择要邀请的团队成员。
3. 选中您刚刚上传的构建版本（Build）。
4. 成员会立即收到 TestFlight 邀请邮件，接受后即可在手机上的 TestFlight App 中下载安装。

### 3. 外部测试 (External Testing) —— 需要 Apple 简要审核
外部测试适用于公开测试或邀请非团队成员（最多 10,000 人，通过邮箱或公开链接邀请）。
1. 在 TestFlight 页面左侧，点击 **外部群组 (External Groups)** 旁的 **“+”** 号，创建一个新群组（如 `Beta Testers`）。
2. 进入该群组，点击 **构建版本 (Builds)** 标签页 -> 点击 **“+”** 号，添加您上传的构建版本。
3. 首次添加外部测试版本时，需要填写一些合规性信息（如是否使用了加密算法，由于我们使用了 `libgit2` 的 SSH/HTTPS 传输，如果询问是否使用了加密，通常选择“是”，并声明仅使用了标准系统加密/HTTPS 传输，即可快速通过）。
4. 提交审核（Beta App Review）。Apple 通常会在 **数小时到 24 小时内** 完成审核。
5. 审核通过后：
   * **邮箱邀请**：您可以在 **测试员 (Testers)** 标签页中点击 **“+”** 手动添加测试员的邮箱。
   * **公开链接**：您可以启用 **公开链接 (Public Link)**，生成一个 URL（如 `https://testflight.apple.com/join/xxxxxx`），分享到社交媒体或社群，任何人点击即可加入测试。
