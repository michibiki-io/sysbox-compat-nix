{
  buildGoModule,
  coreutils,
  glibc,
  inputs,
  lib,
  libseccomp,
  pkg-config,
  protobuf,
  runCommand,
  stdenv,
}:

let
  inherit (inputs) transfer;
  lock = builtins.fromJSON (builtins.readFile "${transfer}/build/sources.lock.json");
  sourceChecks = lib.mapAttrsToList (
    name: revision:
    lib.assertMsg (inputs.${name}.rev == revision.revision) "Sysbox source ${name} disagrees with upstream"
  ) lock.components;
  checkInputHashes = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (path: hash: "${hash}  ${path}") lock.source_sha256
  );

  sourceTree = runCommand "sysbox-transfer-source" { } ''
    (
      cd ${transfer}
      sha256sum --strict --check <<'HASHES'
    ${checkInputHashes}
    HASHES
    )
    cp -R ${inputs.root} "$out"
    chmod -R u+w "$out"
    cp -R --remove-destination ${inputs.fs}/. "$out/sysbox-fs/"
    cp -R --remove-destination ${inputs.ipc}/. "$out/sysbox-ipc/"
    cp -R --remove-destination ${inputs.libs}/. "$out/sysbox-libs/"
    cp -R --remove-destination ${inputs.runc}/. "$out/sysbox-runc/"
    chmod -R u+w "$out/sysbox-fs"
    cp -R --remove-destination ${inputs.fuse}/. "$out/sysbox-fs/bazil/"
  '';

  protocGenGo = buildGoModule {
    pname = "protoc-gen-go-legacy";
    version = "1.3.5";
    src = inputs.legacyProtobuf;
    vendorHash = null;
    subPackages = [ "protoc-gen-go" ];
    doCheck = false;
  };
in
assert lock.schema_version == 1;
assert lib.all lib.id sourceChecks;
assert lock.generator == "github.com/golang/protobuf/protoc-gen-go@v1.3.5";
buildGoModule (finalAttrs: {
  pname = "sysbox-proc-transfer";
  version = "${lock.upstream_tag}-${builtins.substring 0 7 transfer.rev}";
  src = sourceTree;
  modRoot = "sysbox-fs";
  subPackages = [ "cmd/sysbox-fs" ];
  proxyVendor = true;
  passthru.vendorHash = finalAttrs.vendorHash;
  vendorHash = "sha256-8PitbwNlnJjFcNI4P2fOCzW10qq98WueH5z8xkXutJI=";

  patches = [
    "${transfer}/patches/proc-transfer.patch"
    "${transfer}/patches/sysfs-transfer.patch"
    "${transfer}/patches/fuse-overlay-mount.patch"
  ];
  nativeBuildInputs = [ pkg-config protobuf protocGenGo ];
  buildInputs = [ libseccomp ];
  env.CGO_ENABLED = 1;

  postPatch = ''
    for dir in sysbox-ipc/{sysboxFsGrpc/sysboxFsProtobuf,sysboxMgrGrpc/sysboxMgrProtobuf}; do
      substituteInPlace "$dir/Makefile" \
        --replace-fail /usr/local/include/ ${lib.getDev protobuf}/include/
    done
    make -C sysbox-ipc sysbox-ipc
    test -s sysbox-ipc/sysboxFsGrpc/sysboxFsProtobuf/sysboxFsProtobuf.pb.go
    test -s sysbox-ipc/sysboxMgrGrpc/sysboxMgrProtobuf/sysboxMgrProtobuf.pb.go
  '';

  # The FUSE regression belongs to a separate Go module.
  modPostBuild = ''
    (cd bazil && go mod download)
  '';

  tags = [ "netgo" "osusergo" ];
  ldflags = [
    "-linkmode=external"
    "-X main.edition=Community"
    "-X main.version=0.7.1-proc-sysfs-transfer"
    "-X main.commitId=${lock.components.fs.revision}+proc-sysfs-transfer"
  ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    export GOFLAGS="$GOFLAGS -ldflags=-linkmode=external"
    tests=${transfer}/tests
    install -m644 "$tests/upstream/proc_policy_test.go" seccomp/
    install -m644 "$tests/upstream/fuse_mount_target_test.go" "$tests/upstream/mount_propagation_test.go" seccomp/
    install -Dm644 "$tests/unit/lifecycle.c" seccomp/testdata/proc_lifecycle.c
    install -m644 "$tests/upstream/sysfs_policy_test.go" sysfstransfer/policy_test.go
    install -m644 "$tests/upstream/sysfs_snapshot_test.go" mount/
    install -m644 "$tests/upstream/sysfs_metadata_test.go" handler/implementations/
    install -m644 "$tests/upstream/sysfs_dentry_test.go" "$tests/upstream/fuse_container_test.go" fuse/
    install -m644 "$tests/upstream/fuse_identity_test.go" bazil/fs/lookup_identity_test.go
    substituteInPlace handler/implementations/sysfs_metadata_test.go sysfstransfer/policy_test.go \
      --replace-fail /bin/sh ${stdenv.shell}
    substituteInPlace sysfstransfer/policy_test.go \
      --replace-fail /bin/sleep ${lib.getExe' coreutils "sleep"}

    # The upstream build uses only focused tests alongside these packages' production files.
    testProductionFiles() {
      local directory=$1 test=$2 pattern=$3
      local -a files
      mapfile -d "" -t files < <(find "$directory" -maxdepth 1 -name '*.go' ! -name '*_test.go' -print0)
      go test "''${files[@]}" "$directory/$test" -run "$pattern" -count=1
    }
    testProductionFiles handler/implementations sysfs_metadata_test.go '^TestNetwork(SourceMetadata|MetadataGrandchild)$'
    testProductionFiles fuse sysfs_dentry_test.go '^TestProtectedNetworkLookupFailure$'
    testProductionFiles fuse fuse_container_test.go '^TestNetworkOwningContainer$'
    (cd bazil && testProductionFiles fs lookup_identity_test.go '^Test(LookupIdentityFreshAttributes|GetattrDispatchInode|NetworkReadDirDispatch)$')
    go test ./mount -run '^TestSysfsRegistration(Snapshot|RootMetadata)$' -count=1
    # A default Nix Linux sandbox does not bind sysfs. CI supplies the read-only
    # fixture and verifies that both mount-dependent cases actually ran.
    if awk '$5 == "/sys" && $(NF-2) == "sysfs" { found = 1 } END { exit !found }' /proc/self/mountinfo; then
      go test -v ./sysfstransfer
    else
      echo "Skipping sysfs mount fixture cases because /sys is absent in the build sandbox"
      go test -v ./sysfstransfer -skip '^(TestMissingAcquisition|TestRootMountIDMismatch)$'
    fi
    go test -v -tags 'netgo osusergo' ./seccomp \
      -run '^Test(Proc(PolicyBeforeNestedTransfer|RequesterThreadPidfd|TransferInvalidNotificationDoesNotLaunch|TransferRealNotification)|RetryMountPropagationInKernel|FuseRequester(Descriptor|FilesystemIDs)|Fuse(TargetKeepsSelectedDescriptor|OverlayMountAncestry|BindAtimeOperation|WorkerReplyDeadline|WorkerSlots|WorkerProcess|LegacyMountFlags))$' \
      -count=1
    "$CC" -O2 -Wall -Wextra -Werror -Wno-unused-function -UNDEBUG \
      "$tests/unit/fuse-mount-lookup.c" -o fuse-mount-lookup-test
    ./fuse-mount-lookup-test
    echo 'PASS: fuse-mount-lookup C regression'
    runHook postCheck
  '';

  postInstall = ''
    for helper in proc-mount-helper sysfs-mount-helper; do
      "$CC" -O2 -Wall -Wextra -Werror -static -L${glibc.static}/lib \
        "${transfer}/helper/$helper.c" -o "$out/bin/$helper"
    done
    install -Dm644 "${transfer}/build/sources.lock.json" "$out/share/sysbox-proc-transfer/sources.lock.json"
  '';

  meta = {
    description = "Sysbox filesystem daemon and matching procfs and sysfs transfer helpers";
    homepage = "https://github.com/michibiki-io/sysbox-proc-transfer";
    license = with lib.licenses; [ asl20 bsd3 mit lgpl21Only ];
    mainProgram = "sysbox-fs";
    platforms = [ "aarch64-linux" "x86_64-linux" ];
  };
})
