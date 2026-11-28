# natter-build

Natter 的公开构建与发布仓库。源码在私库 `ltsj/natter`，本仓库只做编排、签名与发布，不保存构建逻辑。

## 发布

`release.yml` 由私库 `main` 的 push 经 webhook → Worker 触发，按固定 commit 构建：

- Linux x86_64 / ARM64 服务端包（含 Web 与 deploy 脚本）
- Windows x64 GPUI 便携 ZIP
- Android arm64 APK

Web 构建走源码的 `pnpm -C web build`，`prebuild` 会自动产出 `natter_voice_core` 与 `natter_client_core` 两个 WASM，再由 `ci/package.sh` 打包。

## 构建脚本

`ci/fetch.sh` 负责从私库拉取固定 commit 到 `$RUNNER_TEMP/natter-src`；`ci/package.sh`、`audit.py`、`strip-wasm.py` 等构建脚本随源码走，不在本仓库复制。