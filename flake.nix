{
  description = "tesht development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true; # Allow unfree packages like vscode
        };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            asciinema
            asciinema-agg
            bash
            coreutils
            git
            scc
          ] ++ (if pkgs.stdenv.isLinux then [ kcov vscode ] else [ code-cursor ]);
          shellHook = ''
            export IN_NIX_DEVELOP=1
            echo "Welcome to the development shell!"
          '';
        };
      }
    );
}

