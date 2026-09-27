{
  description = "Recall — dev tools for the native iOS app (CI driving, core tests, sideloading)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (
        pkgs:
        let
          inherit (pkgs) lib;
          inherit (pkgs.stdenv) hostPlatform;
          common = with pkgs; [
            gh # create the repo, drive GitHub Actions, download the IPA
            actionlint # lint .github/workflows
            just # task runner (see justfile)
            jq
            yq-go
            swiftformat # formatting for ios/
            imagemagick # renders the app icon from its SVG source
            python3 # `just serve` for the web prototype
          ];
          # There is no Xcode on Linux: the app itself is compiled by GitHub Actions.
          # Locally we build and test RecallCore (pure Swift), edit with sourcekit-lsp,
          # sideload with iloader and read device logs/crash reports with libimobiledevice.
          swiftLibs = with pkgs.swiftPackages; [
            Dispatch
            Foundation
            XCTest
          ];
          linux =
            with pkgs;
            [
              swift
              swiftpm
              sourcekit-lsp
              iloader
              libimobiledevice
            ]
            ++ swiftLibs;
          darwin = with pkgs; [
            xcodegen
            xcbeautify
          ];
        in
        {
          default = pkgs.mkShell {
            packages = common ++ lib.optionals hostPlatform.isLinux linux ++ lib.optionals hostPlatform.isDarwin darwin;
            # SwiftPM runs its compiled manifest (and our test runner) without an rpath to
            # the Swift runtime libraries, so point the loader at them.
            shellHook = lib.optionalString hostPlatform.isLinux ''
              export LD_LIBRARY_PATH=${lib.makeLibraryPath swiftLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
            '';
          };
        }
      );

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
