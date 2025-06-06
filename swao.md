问题找到了！你的文件系统是BTRFS，这是导致swap文件无法启用的原因。BTRFS对swap文件有特殊要求，因为它是一个写时复制(CoW)文件系统。

对于BTRFS文件系统，你需要禁用swap文件的CoW属性才能使用它：

```bash
# 首先确保swap文件关闭
sudo swapoff /swapfile

# 删除现有的swap文件
sudo rm /swapfile

# 创建新文件并禁用CoW属性
sudo touch /swapfile
sudo chattr +C /swapfile8

# 设置大小
sudo dd if=/dev/zero of=/swapfile bs=1M count=4096

# 设置权限
sudo chmod 600 /swapfile

# 设置为swap
sudo mkswap /swapfile

# 激活swap
sudo swapon /swapfile
```

注意：`chattr +C`命令是关键，它禁用BTRFS的写时复制功能，这对swap文件至关重要。

如果你位于BTRFS子卷内，可能还需要额外考虑：

1. 在BTRFS的根子卷创建swap文件可能会更可靠
2. 确保swap文件不会被快照包含

另外，如果不想处理BTRFS的swap文件问题，可以考虑替代方案：
1. 创建一个专用的swap分区
2. 使用zram/zswap内存压缩
3. 使用swapfile循环设备

要检查文件是否已禁用CoW属性：
```bash
lsattr /swapfile
```
输出中应该包含"C"标志。输出中应该包含"C"标志。


# 使用 yay (如果你没有安装 yay，先安装它)
sudo pacman -S yay

# 安装 GitHub Desktop

pamac install android-studio
yay -S github-desktop-bin


libseccomp_2.5.5-3_aarch64

这个依赖没写，但是用到了