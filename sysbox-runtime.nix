{
  buildGoModule,
  common,
  inputs,
  libapparmor,
  libseccomp,
  variant,
}:

buildGoModule (finalAttrs: common // {
  pname = "sysbox-runc-compat";
  modRoot = "sysbox-runc";
  subPackages = [ "." ];

  proxyVendor = true;
  vendorHash = "sha256-vbnjDfZUHLgphsJo9F7DOoy1GKvBM55v6ta0chd7ZSE=";
  passthru.vendorHash = finalAttrs.vendorHash;
  buildInputs = [ libapparmor libseccomp ];
  env.CGO_ENABLED = 1;
  tags = [ "seccomp" "apparmor" "idmapped_mnt" "netgo" "osusergo" ];
  ldflags = [
    "-linkmode=external"
    "-X main.version=0.7.1-${variant}"
    "-X main.commitId=${inputs.runc.rev}+${variant}"
  ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    go test -v -tags 'seccomp apparmor idmapped_mnt netgo osusergo' \
      ./libsysbox/syscont -run '^TestCiliumNotificationsByDefault$' -count=1
    runHook postCheck
  '';
})
