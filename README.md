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
- Claude/Gemini 模型列表修改器

### 3. 优化功能

- 解除聊天文件大小限制
- 启用自动备份

---

## 使用方式

先`cd`到ST根目录(有`start.bat`的那个目录)，或ST的上一级目录。依次执行: 

```bash
curl -L "https://raw.githubusercontent.com/dz114879/ST-foxium/refs/heads/main/build/ffss.sh" -o ffss.sh
chmod +x ffss.sh
./ffss.sh
```

以后再想启动，无需再次下载，直接使用`./ffss.sh`即可。

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