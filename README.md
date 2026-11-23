# sysbox-proc-transfer-nix

Nix packaging for patched Sysbox with protected procfs and opt-in sysfs transfer in nested user namespaces.

- [English](#english)
- [日本語](#日本語)

## English

### Build

The Flake provides `sysbox-proc-transfer` for `aarch64-linux` and `x86_64-linux`. Each build installs the patched `sysbox-fs` and its matching `proc-mount-helper` and `sysfs-mount-helper` in `bin/`. The source, build dependencies and Go modules are pinned. See [the pinned upstream project](https://github.com/michibiki-io/sysbox-proc-transfer/tree/92292991eaef1e4b766c66e8a6d2ae8765b94af0) for compatibility and third-party license notices.

Set `rev` to the full commit SHA of this packaging repository, then build on either supported architecture with Flakes enabled.

```sh
rev=REPLACE_WITH_FULL_PACKAGING_COMMIT_SHA
nix build --no-link "github:michibiki-io/sysbox-proc-transfer-nix/$rev#sysbox-proc-transfer"
```

Release jobs build and test both targets on their native runners. The release contains source and build records with pinned input checksums and the SHA-256 of each executable.

The Nix build links `sysbox-fs` against glibc and libseccomp from the Nix store. Both mount helpers are statically linked.

### Use with NixOS

Add the following to an existing configuration that imports the host's `services.sysboxProcTransfer` module. Replace the placeholder with the same full commit SHA used to build the package.

```nix
{ pkgs, ... }:
let
  transfer = builtins.getFlake
    "github:michibiki-io/sysbox-proc-transfer-nix/REPLACE_WITH_FULL_PACKAGING_COMMIT_SHA";
  package = transfer.packages.${pkgs.stdenv.hostPlatform.system}.sysbox-proc-transfer;
in
{
  services.sysboxProcTransfer = {
    enable = true;
    inherit package;
  };

  # Opt in only when the container meets the requirements below.
  # systemd.services.sysbox-fs.environment.SYSBOX_SYSFS_TRANSFER_HELPER =
  #   "${package}/bin/sysfs-mount-helper";
}
```

The consuming module sets the daemon and proc helper paths. For sysfs transfer, use the sysfs helper from the same package. Container registration requires visible `/sys` mount and protection metadata. Transfer requires a `sysfs` mount at `/sys` with mountinfo Root `/` and a real `/tmp` directory inside the outer rootfs. See [upstream compatibility](https://github.com/michibiki-io/sysbox-proc-transfer/blob/92292991eaef1e4b766c66e8a6d2ae8765b94af0/docs/compatibility.md).

### Verification

The native CI builds run the focused upstream checks. The logs confirm the FUSE mount target and propagation Go tests and the C helper regression on both architectures. Two other regression tests need a sysfs mount in the Linux build sandbox. CI adds `/sys` with `extra-sandbox-paths = /sys` and checks that both tests passed. On a default Nix sandbox without that mount, the build logs that it skips the sysfs mount fixture cases.

The runtime scope for this package is arm64 NixOS procfs using upstream `tests/runtime/verify.sh` as a non-root user. Confirm that the running daemon and configured proc helper use the selected package before running the verifier. amd64 and sysfs runtime verification are out of scope for this package's initial acceptance. The upstream sysfs consumer gate remains pending.

## 日本語

### ビルド

Flake は `aarch64-linux` と `x86_64-linux` 向けの `sysbox-proc-transfer` を提供します。パッチを適用した `sysbox-fs`、対応する `proc-mount-helper` と `sysfs-mount-helper` が `bin/` に入ります。ソース、ビルド依存、Go モジュールは固定しています。対応環境と第三者ライセンスは [固定した上流リポジトリ](https://github.com/michibiki-io/sysbox-proc-transfer/tree/92292991eaef1e4b766c66e8a6d2ae8765b94af0) を参照してください。

`rev` にこのパッケージ用リポジトリの完全なコミット SHA を設定し、Flakes を有効にした対応アーキテクチャの環境で実行します。

```sh
rev=REPLACE_WITH_FULL_PACKAGING_COMMIT_SHA
nix build --no-link "github:michibiki-io/sysbox-proc-transfer-nix/$rev#sysbox-proc-transfer"
```

リリースジョブは各アーキテクチャのネイティブランナーでビルドとテストを実行します。リリースではソースと、入力のチェックサムおよび実行ファイルごとの SHA-256 を記録したビルド記録を配布します。

Nix ビルドの `sysbox-fs` は、Nix ストア内の glibc と libseccomp に動的リンクします。2つのマウント用ヘルパーは静的リンクです。

### NixOS で利用する

ホスト側の `services.sysboxProcTransfer` モジュールを読み込んでいる構成に設定を追加します。Flake の参照にはビルドで指定した完全なコミット SHA を使います。具体的な記述は、英語節の [NixOS 設定例](#use-with-nixos) を参照してください。

デーモンと proc ヘルパーのパスは利用側モジュールが設定します。sysfs 転送も使う場合は、設定例の `SYSBOX_SYSFS_TRANSFER_HELPER` に同じパッケージのヘルパーを指定します。コンテナの登録には `/sys` のマウントと保護情報が必要です。転送には `/sys` が型 `sysfs` かつ mountinfo の Root が `/` であることと、外側 rootfs に実ディレクトリの `/tmp` があることが必要です。詳細は [上流の互換性文書](https://github.com/michibiki-io/sysbox-proc-transfer/blob/92292991eaef1e4b766c66e8a6d2ae8765b94af0/docs/compatibility.md) を参照してください。

### 検証

ネイティブランナーでの CI は、固定した上流の回帰テストを実行します。両アーキテクチャのログで、FUSE のマウント対象と伝播を検証する Go テスト、および C ヘルパーの回帰テストの成功を確認します。別の2件には、ビルド用の Linux サンドボックス内に sysfs マウントが必要です。CI は `extra-sandbox-paths = /sys` で `/sys` を渡し、2件の成功を確認します。標準の Nix サンドボックスにこのマウントがなければ、sysfs マウントを必要とするテストを省略したことがビルドログに出ます。

実行時の検証対象は arm64 NixOS 上の procfs です。稼働中のデーモンと設定された proc ヘルパーが選択したパッケージを参照することを確認してから、構成済みの Sysbox コンテナ内で上流の `tests/runtime/verify.sh` を一般ユーザーとして実行します。amd64 と sysfs の実行時検証は初回の受け入れ範囲外で、上流の sysfs 利用側の受け入れ検証は未完了です。
