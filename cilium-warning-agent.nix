{
  buildGo126Module,
  inputs,
  lib,
}:

let
  version = "1.20.4";
  sourceVersion = "${version} ${inputs.cilium.rev} 2026-10-23";
in
buildGo126Module {
  pname = "cilium-warning-agent";
  inherit version;
  src = inputs.cilium;
  patches = [ "${inputs.transfer}/patches/cilium-v1.20.4-warning-lab.patch" ];
  vendorHash = null; # Cilium ships its complete Go vendor tree.
  subPackages = [ "daemon" ];
  env.CGO_ENABLED = 0;
  ldflags = [
    "-s"
    "-w"
    ''-X "github.com/cilium/cilium/pkg/version.ciliumVersion=${sourceVersion}"''
  ];

  # Exercise the built executable rather than Cilium's kernel-dependent test suite.
  doCheck = false;
  postInstall = ''
    mv "$out/bin/daemon" "$out/bin/cilium-agent"
    "$out/bin/cilium-agent" --version | grep -F -- '${sourceVersion} go version'
  '';

  meta = {
    description = "Cilium Agent with the Sysbox lab warning patch";
    license = lib.licenses.asl20;
    mainProgram = "cilium-agent";
    platforms = [ "aarch64-linux" "x86_64-linux" ];
  };
}
