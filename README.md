# sysbox-compat-nix / Nix 向け Sysbox 互換パッケージ

## Table of Contents / 目次

- [English](#english)
  - [Build](#build)
  - [Use with NixOS](#use-with-nixos)
  - [Cilium compatibility](#cilium-compatibility)
  - [Optional Cilium warning Agent](#optional-cilium-warning-agent)
  - [Verification](#verification)
- [日本語](#日本語)
  - [ビルド](#ビルド)
  - [NixOS で利用する](#nixos-で利用する)
  - [Cilium 互換機能](#cilium-互換機能)
  - [警告対応版 Cilium Agent](#警告対応版-cilium-agent)
  - [検証](#検証)

## English

### Build

The `sysbox-compat` Flake output is available for `aarch64-linux` and
`x86_64-linux`. It provides `sysbox-fs`, `sysbox-runc`,
`proc-mount-helper`, and `sysfs-mount-helper` in `bin/`.
The `default`, `sysbox-proc-transfer`, and `sysbox-cilium-lab` outputs
point to the same package. Sources and Go dependencies are pinned. Use the
upstream repository for the source, compatibility notes, and license notices.
[Pinned sysbox-compat source](https://github.com/michibiki-io/sysbox-compat/tree/905e09e1e417364ae08ae3713ce7dfb9eab681a1)

Set `rev` to the full commit SHA of this packaging repository.

```sh
rev=REPLACE_WITH_FULL_PACKAGING_COMMIT_SHA
nix build --no-link "github:michibiki-io/sysbox-compat-nix/$rev#sysbox-compat"
```

The daemon and OCI runtime use their Nix store closure. Both mount helpers
are statically linked. The source lock is installed at
`share/sysbox-proc-transfer/sources.lock.json`.

### Use with NixOS

In a host configuration that already imports `services.sysboxProcTransfer`,
select the package from the same full revision used for the build.

```nix
{ pkgs, ... }:
let
  compat = builtins.getFlake
    "github:michibiki-io/sysbox-compat-nix/REPLACE_WITH_FULL_PACKAGING_COMMIT_SHA";
  package = compat.packages.${pkgs.stdenv.hostPlatform.system}.sysbox-compat;
in
{
  services.sysboxProcTransfer = {
    enable = true;
    inherit package;
  };

  # Enable sysfs transfer for containers that meet the requirements below.
  # systemd.services.sysbox-fs.environment.SYSBOX_SYSFS_TRANSFER_HELPER =
  #   "${package}/bin/sysfs-mount-helper";
}
```

The NixOS module selects the filesystem daemon and proc helper. Configure
the OCI runtime entry that runs the workload to execute
`${package}/bin/sysbox-runc`, preserving any host-specific runtime wrapper
settings. Use the daemon, runtime, and helpers from the same package revision.

Container registration requires visible `/sys` mount and protection metadata.
Sysfs transfer requires a `sysfs` mount at `/sys` with mountinfo Root `/`
and a real `/tmp` directory in the outer rootfs.
[Upstream filesystem compatibility](https://github.com/michibiki-io/sysbox-compat/blob/905e09e1e417364ae08ae3713ce7dfb9eab681a1/docs/compatibility.md)

### Cilium compatibility

The standard daemon and runtime support the narrow perf output and JIT probe
requests without setting `SYSBOX_EXPERIMENT_PERF_OUTPUT`. The host provisions
cgroup v2, delegated bpffs and a BPF token for the workload, and per-job cgroup
registration. Existing OCI seccomp denials take precedence. Requests outside
the authorization or supported shapes continue in the kernel.

For kind, prepare the delegated bpffs at `/sys/fs/bpf` for each node before
its Cilium init containers start, and make `/etc/sysctl.d` writable for the
configuration they install. The upstream guide specifies the required kernel
features, the host-owned registry and its cleanup, and the limits of the perf
event and JIT response.
[Upstream host requirements and runtime checks](https://github.com/michibiki-io/sysbox-compat/blob/905e09e1e417364ae08ae3713ce7dfb9eab681a1/docs/cilium-lab.md#standard-build-and-host-requirements)

### Optional Cilium warning Agent

Use `cilium-warning-agent` when reproducing the separate TCX recovery and
socket termination scenarios. It provides a standalone Cilium v1.20.4
executable for the disposable kind fixture. The catalog regression run with
the stock Agent is also documented upstream.
[Warning test procedure](https://github.com/michibiki-io/sysbox-compat/blob/905e09e1e417364ae08ae3713ce7dfb9eab681a1/docs/cilium-lab.md#separate-cilium-patch-for-the-warnings)

```sh
nix build --out-link result-agent "github:michibiki-io/sysbox-compat-nix/$rev#cilium-warning-agent"
```

### Verification

CI builds on both native architectures. It checks output aliases, the two
matching Sysbox binaries and both helpers, and the focused procfs, sysfs, FUSE,
perf, JIT, and runtime notification tests. CI supplies `/sys` to the Nix
sandbox and checks the two mount-dependent tests. A default sandbox without
`/sys` logs the mount fixture skips. The test workflow also checks the optional
Agent version and standalone ELF. Release records include source revisions,
both Go dependency hashes, and checksums of the four standard binaries.

For the arm64 NixOS procfs runtime check, confirm the configured daemon and
proc helper use the selected package, then run upstream `tests/runtime/verify.sh`
as a non-root user inside the configured container. The native package CI
covers builds and focused checks. Use the upstream disposable comparison for
perf and JIT runtime behavior, and the upstream filesystem guide for sysfs
runtime validation.
[Disposable runtime comparison](https://github.com/michibiki-io/sysbox-compat/blob/905e09e1e417364ae08ae3713ce7dfb9eab681a1/docs/cilium-lab.md#disposable-runtime-comparison)

## 日本語

### ビルド

Flake は `aarch64-linux` と `x86_64-linux` 向けに `sysbox-compat` を提供します。
`bin/` には `sysbox-fs`、`sysbox-runc`、`proc-mount-helper`、`sysfs-mount-helper` が入ります。
`default`、`sysbox-proc-transfer`、`sysbox-cilium-lab` は同じパッケージを指します。
ソースと Go の依存は固定しています。対応環境とライセンスは上流を参照してください。
[固定した sysbox-compat ソース](https://github.com/michibiki-io/sysbox-compat/tree/905e09e1e417364ae08ae3713ce7dfb9eab681a1)

`rev` には、このパッケージ用リポジトリの完全なコミット SHA を指定します。

```sh
rev=REPLACE_WITH_FULL_PACKAGING_COMMIT_SHA
nix build --no-link "github:michibiki-io/sysbox-compat-nix/$rev#sysbox-compat"
```

デーモンと OCI ランタイムの実行には、Nix ストア上の依存が必要です。
2 つのマウント用ヘルパーは静的リンクです。
ソースロックは `share/sysbox-proc-transfer/sources.lock.json` に入ります。

### NixOS で利用する

`services.sysboxProcTransfer` を導入済みのホストでは、ビルドで指定した
完全なコミット SHA でパッケージを設定します。
[NixOS 設定例](#use-with-nixos)

NixOS モジュールはデーモンと proc ヘルパーを選びます。
対象のコンテナを起動する OCI ランタイムには `${package}/bin/sysbox-runc` を指定します。
ホスト固有のランタイムラッパーを使用している場合は、その設定を保持します。
デーモン、ランタイム、ヘルパーは同じパッケージのリビジョンで揃えます。

コンテナの登録には、参照できる `/sys` マウントと保護情報が必要です。
sysfs 転送には、型が `sysfs`、mountinfo の Root が `/` である `/sys` と、
外側 rootfs 内の実ディレクトリ `/tmp` が必要です。
[上流のファイルシステム互換性](https://github.com/michibiki-io/sysbox-compat/blob/905e09e1e417364ae08ae3713ce7dfb9eab681a1/docs/compatibility.md)

### Cilium 互換機能

標準のデーモンとランタイムで、`SYSBOX_EXPERIMENT_PERF_OUTPUT` の設定なしに
対象の perf 出力と JIT プローブを利用できます。
ホストには cgroup v2、ワークロードに委譲する bpffs と BPF token、ジョブ単位の cgroup 登録が必要です。
既存の OCI seccomp による拒否が優先されます。認可や対応する要求の条件を満たさない呼び出しはカーネルに委ねます。

kind では Cilium の init container が動く前に、各ノードの `/sys/fs/bpf` に委譲済みの bpffs を用意します。
init container が Cilium の設定を書く `/etc/sysctl.d` も書き込み可能にします。
カーネルの前提、ホスト側の登録と後片付け、perf イベントと JIT 応答の範囲は上流を参照してください。
[上流のホスト要件と実行時の検証](https://github.com/michibiki-io/sysbox-compat/blob/905e09e1e417364ae08ae3713ce7dfb9eab681a1/docs/cilium-lab.md#standard-build-and-host-requirements)

### 警告対応版 Cilium Agent

TCX の復旧とソケット終了を再現するときは `cilium-warning-agent` を使います。
使い捨ての kind 環境で実行できる、Cilium v1.20.4 の単体バイナリです。
未改変 Agent で完走したカタログ試験の記録も上流にあります。
[警告に対応する試験手順](https://github.com/michibiki-io/sysbox-compat/blob/905e09e1e417364ae08ae3713ce7dfb9eab681a1/docs/cilium-lab.md#separate-cilium-patch-for-the-warnings)

```sh
nix build --out-link result-agent "github:michibiki-io/sysbox-compat-nix/$rev#cilium-warning-agent"
```

### 検証

CI は両アーキテクチャでネイティブにビルドします。
出力の別名、対応する Sysbox バイナリとヘルパー 4 点、および procfs、sysfs、FUSE、perf、JIT、ランタイム通知の回帰テストを確認します。
CI の Nix サンドボックスには `/sys` を渡し、マウントを必要とするテスト 2 件の成功を確認します。
`/sys` を渡さない標準のサンドボックスでは、それらを省略したことがログに出ます。
テストワークフローはオプションの Agent のバージョンと単体 ELF も検証します。
リリース用のビルド記録には、ソースリビジョン、両方の Go 依存ハッシュ、標準バイナリ 4 点のチェックサムが入ります。

arm64 NixOS で procfs を検証するときは、稼働中のデーモンと proc ヘルパーが選択したパッケージを参照することを確認し、
構成済みコンテナ内で上流の `tests/runtime/verify.sh` を一般ユーザーとして実行します。
Nix パッケージの CI はビルドと個別テストを対象とします。
perf と JIT の実行時の挙動は上流の使い捨て環境で比較し、sysfs の実行時の検証は上流のファイルシステム互換性に従います。
[使い捨て環境での比較](https://github.com/michibiki-io/sysbox-compat/blob/905e09e1e417364ae08ae3713ce7dfb9eab681a1/docs/cilium-lab.md#disposable-runtime-comparison)
