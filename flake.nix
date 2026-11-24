{
  description = "Nix packaging for the standard Sysbox compatibility runtime";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/04906337b6d53e8bb0eaf0470ae9f070a4d4eb55";
    transfer = {
      url = "github:michibiki-io/sysbox-compat/905e09e1e417364ae08ae3713ce7dfb9eab681a1";
      flake = false;
    };
    cilium = {
      url = "github:cilium/cilium/beb276d2f38d4aadfda14710acf8d14a0f1ba723";
      flake = false;
    };
    root = {
      url = "github:nestybox/sysbox/82881aaaf2ce22ad0ff81487f458162908cb933f";
      flake = false;
    };
    fs = {
      url = "github:nestybox/sysbox-fs/c3d2ebc65102e32e74e383675f03b45556326888";
      flake = false;
    };
    runc = {
      url = "github:nestybox/sysbox-runc/081856cc5d17e7095f066b08d0eca6bb0b515c47";
      flake = false;
    };
    ipc = {
      url = "github:nestybox/sysbox-ipc/f05151f4b4c1df63d7fd241577ca032905c1bd0e";
      flake = false;
    };
    libs = {
      url = "github:nestybox/sysbox-libs/cacac19395528afa42b467a980b05d8d1c6d646c";
      flake = false;
    };
    fuse = {
      url = "github:nestybox/fuse/5ce319439091b08f33b149cb2482039f1b0a24fe";
      flake = false;
    };
    legacyProtobuf = {
      url = "github:golang/protobuf/84668698ea25b64748563aa20726db66a6b8d299"; # v1.3.5
      flake = false;
    };
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    {
      packages = nixpkgs.lib.genAttrs [ "aarch64-linux" "x86_64-linux" ] (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          package = pkgs.callPackage ./package.nix { inherit inputs; };
        in
        {
          sysbox-compat = package;
          sysbox-proc-transfer = package;
          sysbox-cilium-lab = package;
          cilium-warning-agent = pkgs.callPackage ./cilium-warning-agent.nix { inherit inputs; };
          default = package;
        }
      );
    };
}
