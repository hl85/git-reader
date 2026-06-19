# GitHub Pages 隐私政策部署指南

App Store 审核**必须**提供一个可公开访问的隐私政策 URL。由于 Gits Reader 是一个无服务器的本地应用，使用 GitHub Pages 免费托管隐私政策是最简单、最专业且完全免费的方案。

以下是两种最常用的部署方式，您可以选择其中一种：

---

## 方案 A：直接部署在当前项目的 GitHub 仓库中（推荐，最简单）

如果您的 `git-reader` 代码已经托管在 GitHub 上，可以直接利用该仓库开启 GitHub Pages。

### 步骤 1：整理文件结构
1. 在项目根目录下创建一个名为 `docs` 的文件夹（如果还没有）。
2. 将 `Appstore/privacy.html` 复制到 `docs` 文件夹中，并重命名为 `index.html`。
   * *这样访问 `https://您的用户名.github.io/仓库名/` 时就会直接显示隐私政策。*

### 步骤 2：提交并推送到 GitHub
在终端运行以下命令（或使用您的 Git GUI 工具）：
```bash
git add docs/index.html
git commit -m "docs: add privacy policy for GitHub Pages"
git push origin main
```

### 步骤 3：在 GitHub 仓库设置中开启 Pages
1. 打开您的 GitHub 仓库页面（例如 `https://github.com/您的用户名/git-reader`）。
2. 点击顶部导航栏的 **Settings** (设置)。
3. 在左侧菜单栏中，找到 **Code and automation** 分组，点击 **Pages**。
4. 在 **Build and deployment** -> **Source** 下，选择 **Deploy from a branch**。
5. 在 **Branch** 下：
   * 选择您的主分支（如 `main` 或 `master`）。
   * 将旁边的目录从 `/ (root)` 改为 `/docs`。
   * 点击 **Save** (保存)。
6. 等待 1-2 分钟，刷新页面，顶部会显示一行绿色的提示：
   > "Your site is live at `https://您的用户名.github.io/git-reader/`"
7. **这个 URL 就是您要填入 App Store Connect 的隐私政策 URL！**

---

## 方案 B：创建一个独立的个人主页仓库（适合未来发布更多 App）

如果您不想把隐私政策放在代码仓库里，或者代码仓库是私有的（注：私有仓库开启 GitHub Pages 需要 GitHub Pro，而公有仓库是免费的），您可以创建一个专门的个人主页仓库。

### 步骤 1：新建仓库
1. 在 GitHub 上创建一个新仓库，命名为：`您的用户名.github.io`（必须完全匹配这个格式，全部小写）。
2. 勾选 **Add a README file**，并将仓库设为 **Public** (公开)。

### 步骤 2：上传隐私政策
1. 在该仓库中，直接上传 `Appstore/privacy.html`，并重命名为 `index.html`（或者保留为 `privacy.html`）。
2. 提交更改。

### 步骤 3：获取 URL
1. 这种特殊命名的仓库会自动开启 GitHub Pages。
2. 您的隐私政策 URL 将是：
   * 如果重命名为了 `index.html`：`https://您的用户名.github.io/`
   * 如果保留为 `privacy.html`：`https://您的用户名.github.io/privacy.html`
