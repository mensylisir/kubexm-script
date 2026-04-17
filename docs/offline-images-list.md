# 离线镜像清单 (images.list)

KubeXM 在 `download` 阶段会生成镜像清单文件，用于离线环境镜像推送与完整性校验。

默认路径:
- `packages/images/images.list`

兼容路径:
- `packages/images.list` (旧格式，仍支持)

行为说明:
- `kubexm download` 会在下载镜像成功或命中已有镜像时记录到清单。
- `kubexm push images --packages` 只使用清单中的镜像推送到 Registry。
- `kubexm create cluster` (offline + registry.enable=true) 会自动推送 `packages/images/images.list` 中的镜像。

注意:
- 如果你手动添加镜像，请同时下载对应镜像目录并更新 `images.list`。
- 清单为空会触发离线校验回退到“核心镜像列表”检查。
