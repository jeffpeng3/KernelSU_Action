#!/usr/bin/env bash
# Patches author: weishu <twsxtd@gmail.com>
# Shell authon: xiaoleGun <1592501605@qq.com>
#               bdqllW <bdqllT@gmail.com>
# Tested kernel versions: 5.4, 4.19, 4.14, 4.9
# 20240321

patch_files=(
    fs/namespace.c
)

for i in "${patch_files[@]}"; do

    if grep -q "ksu" "$i"; then
        echo "Warning: $i contains KernelSU"
        continue
    fi

    case $i in

        fs/namespace.c)
        sed -i '/int ksys_umount(char __user \*name, int flags)/i \
#ifdef CONFIG_KSU\
static int can_umount(const struct path *path, int flags)\
{\
    struct mount *mnt = real_mount(path->mnt);\
\
    if (!may_mount())\
        return -EPERM;\
    if (path->dentry != path->mnt->mnt_root)\
        return -EINVAL;\
    if (!check_mnt(mnt))\
        return -EINVAL;\
    if (mnt->mnt.mnt_flags & MNT_LOCKED) /* Check optimistically */\
        return -EINVAL;\
    if (flags & MNT_FORCE && !capable(CAP_SYS_ADMIN))\
        return -EPERM;\
    return 0;\
}\
\
// caller is responsible for flags being sane\
int path_umount(struct path *path, int flags)\
{\
    struct mount *mnt = real_mount(path->mnt);\
    int ret;\
\
    ret = can_umount(path, flags);\
    if (!ret)\
        ret = do_umount(mnt, flags);\
\
    /* we must not call path_put() as that would clear mnt_expiry_mark */\
    dput(path->dentry);\
    mntput_no_expire(mnt);\
    return ret;\
}\
#endif\
' fs/namespace.c
        ;;

    esac

done