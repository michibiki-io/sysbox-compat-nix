{
  buildGoModule,
  inputs,
  libapparmor,
  libseccomp,
  standard,
}:

buildGoModule (finalAttrs: {
  pname = "sysbox-runc-cilium-lab";
  inherit (standard) version src nativeBuildInputs postPatch;
  modRoot = "sysbox-runc";
  subPackages = [ "." ];
  patches = standard.patches ++ [ "${inputs.transfer}/patches/cilium-bpf-lab.patch" ];

  proxyVendor = true;
  vendorHash = "sha256-vbnjDfZUHLgphsJo9F7DOoy1GKvBM55v6ta0chd7ZSE=";
  passthru.vendorHash = finalAttrs.vendorHash;
  buildInputs = [ libapparmor libseccomp ];
  env.CGO_ENABLED = 1;
  tags = [ "seccomp" "apparmor" "idmapped_mnt" "netgo" "osusergo" ];
  ldflags = [
    "-linkmode=external"
    "-X main.version=0.7.1-cilium-lab"
    "-X main.commitId=${inputs.runc.rev}"
  ];

  doCheck = false;
})
