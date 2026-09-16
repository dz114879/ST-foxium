# FFSS/Foxium V2 README

## 简介

FFSS (Foxium V2) 是一个面向 SillyTavern 的交互式 Bash 工具，提供一组常用修复、编辑和优化功能。

---

## 功能列表

### 1. 修复功能

- 修复 node 包问题无法启动酒馆
- 强制删除扩展
- 二合一爆内存修复
- [风险] 允许给 Gemini 3 系列模型发图（仅 ST `<= 1.13.*`）

### 2. 编辑器

- `config.yaml` 编辑器
- `settings.json` 编辑器
- [已弃用] Claude/Gemini 模型列表修改器（改用 [SillyTavern-CustomModels](https://github.com/LenAnderson/SillyTavern-CustomModels) 插件）

### 3. 优化功能

- 解除聊天文件大小限制
- 启用自动备份

---

## 使用方式

先 `cd` 到 ST 根目录（有 `start.bat` 的那个目录），或 ST 的上一级目录，然后一行执行：

```bash
curl -fL --retry 3 --connect-timeout 15 "https://raw.githubusercontent.com/dz114879/ST-foxium/refs/heads/main/build/ffss.sh" -o ffss.sh && bash ffss.sh
```

`-f` 让下载出错时直接失败，不会把「404: Not Found」这类错误页面存成 ffss.sh；`&&` 保证只有下载完整才会执行。以后再想启动，无需再次下载，直接 `bash ffss.sh` 即可。

想先看看脚本内容再运行：把命令末尾的 `&& bash ffss.sh` 去掉，用 `less ffss.sh` 查看，确认后再 `bash ffss.sh`。

### 只跑爆内存修复（--fix-oom）

只想执行「二合一爆内存修复」、不想进菜单时，加 `--fix-oom`：

```bash
bash ffss.sh --fix-oom
```

所有确认自动按 y 处理，中途不需要任何输入；无法自动决定的选择（同时存在多个 SillyTavern 目录，或 Windows 下有多个启动脚本）会直接报错退出，不会替你猜。修改前依旧会备份到本次的 `STbackupF/<时间戳_随机后缀>/`，有任何一步没成功时退出码非 0。

非交互模式不询问酒馆用户名（该修复用不到），也不会主动安装 `jq` / `yq`。完整参数见 `bash ffss.sh --help`。

---

## 运行说明

脚本启动后会依次执行这些检查：

1. 查找 SillyTavern 目录
2. 读取 ST 版本
3. 创建本次运行的备份会话目录
4. 设置酒馆用户名
5. 检测 `jq` / `yq`

全部通过后进入主菜单。

---

## 备份文件位置

- 功能执行前的备份：保存在你当前执行的 Foxium 脚本所在目录下的 `STbackupF/<时间戳_随机后缀>/` 中。比如你把 `foxium.sh` 放在 ST 根目录运行，通常就是 `./STbackupF/<时间戳_随机后缀>/`；脚本启动检查完成后也会直接显示“本次备份目录”。
- 启用“自动备份”后的启动前备份：保存在启动脚本所在目录下的 `foxiumV2/STbackupF/auto_backup_<时间戳>/` 中。以默认放在 ST 根目录的 `start.sh` / `Start.bat` / `start.bat` 为例，路径通常就是 `./foxiumV2/STbackupF/auto_backup_<时间戳>/`。

如果找不到备份，优先检查上面这两个目录。

---

## 开发：运行测试

测试使用 [bats-core](https://github.com/bats-core/bats-core)，只在本机运行，没有 CI：

```bash
bats tests/
```

其中一个用例会检查 `build/ffss.sh` 是否与 `lib/` 同步。改完 `lib/` 如果忘了重新生成发布文件，它会直接失败——这是唯一会静默把旧代码发给用户的失误。