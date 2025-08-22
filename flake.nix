{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      # This discussion inspired me
      # https://discourse.nixos.org/t/best-practices-for-expo-react-native-development-with-devenv/58776/5
      #
      # What we want to do here is just provision the listed packages below,
      # without the clang compiler nor Apple SDK.
      # So we need to undo some side effects of mkShellNoCC.
      {
        # Use mkShellNoCC instead of mkShell so that it wont pull in clang.
        # We need to use the clang from Xcode.
        devShells.default = pkgs.mkShellNoCC {
          packages = [
            # 20.18.1
            pkgs.nodejs_20
            # 3.3.6
            pkgs.ruby_3_3
            # The flutter setup is broken as of 2025-06-16
            #
            # See https://github.com/NixOS/nixpkgs/issues/405066
            # See https://github.com/flutter/flutter/issues/167823
            #
            # The known workaround is to use a manual flutter installation.
            # You can download a specific version of flutter at
            # https://docs.flutter.dev/install/archive
            #
            # In the below shellHook, you need to put the manual flutter installation in your PATH
            # See https://docs.flutter.dev/install/manual#add-to-path
            # For example,
            #
            #  export PATH="/path/to/your/installation/bin:$PATH"

            # 3.32.8
            # pkgs.flutter332
          ];
          # Even we use mkShellNoCC, DEVELOPER_DIR, SDKROOT, MACOSX_DEPLOYMENT_TARGET is still set.
          # We undo that.
          #
          # Also, xcrun from Nix is put in PATH, we want to undo that as well.
          shellHook = ''
            export PATH=$(echo $PATH | sed "s,${pkgs.xcbuild.xcrun}/bin,,")
            unset DEVELOPER_DIR
            unset SDKROOT
            unset MACOSX_DEPLOYMENT_TARGET
          '';
        };
      }
    );
}
