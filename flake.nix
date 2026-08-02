{
  description = "Personal Emacs Lisp extensions";

  inputs = {
    flake-parts = {
      inputs = {
        nixpkgs-lib = {
          follows = "nixpkgs";
        };
      };

      url = "git+https://github.com/hercules-ci/flake-parts.git?ref=main";
    };

    nixpkgs = {
      url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixos-unstable";
    };
  };

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      self,
      ...
    }:
    let
      inherit (flake-parts.lib)
        mkFlake
        ;

      projectRoot = ./.;
    in
    mkFlake
      {
        inherit
          inputs
          ;

        specialArgs = {
          inherit
            projectRoot
            ;
        };
      }
      {
        imports = [
          flake-parts.flakeModules.partitions
        ];

        flake = {
          overlays = {
            default =
              final: prev:
              let
                inherit (prev)
                  emacsPackagesFor
                  ;

                emacs-bs =
                  {
                    edit-indirect,
                    elfeed,
                    khalel,
                    lib,
                    melpaBuild,
                    mu4e,
                    projectRoot,
                    tabspaces,
                    ...
                  }:
                  let
                    inherit (lib)
                      licenses
                      maintainers
                      ;
                  in
                  melpaBuild {
                    files = ''("bs.el" "bs-*.el")'';

                    packageRequires = [
                      edit-indirect
                      elfeed
                      khalel
                      mu4e
                      tabspaces
                    ];

                    meta = {
                      description = "Personal Emacs Lisp extensions";
                      homepage = "https://github.com/brsvh/emacs-bs";
                      license = licenses.gpl3Plus;
                      maintainers = with maintainers; [ brsvh ];
                    };

                    pname = "bs";
                    src = projectRoot + /lisp;
                    version = "0.1.0";
                  };

                scope = finalAttrs: _: {
                  bs = finalAttrs.callPackage emacs-bs {
                    inherit
                      projectRoot
                      ;
                  };
                };
              in
              {
                emacsPackagesFor =
                  emacs:
                  (emacsPackagesFor emacs).overrideScope scope;
              };
          };
        };

        partitionedAttrs = {
          devShells = "tool";
          formatter = "tool";
        };

        partitions = {
          tool = {
            extraInputsFlake = projectRoot + /tool;

            module =
              {
                ...
              }:
              {
                imports = [
                  (projectRoot + /tool/flake-module.nix)
                ];
              };
          };
        };

        perSystem =
          {
            system,
            ...
          }:
          {
            _module = {
              args = {
                pkgs = import nixpkgs {
                  inherit
                    system
                    ;

                  overlays = [
                    self.overlays.default
                  ];
                };
              };
            };
          };

        systems = [
          "x86_64-linux"
        ];
      };
}
