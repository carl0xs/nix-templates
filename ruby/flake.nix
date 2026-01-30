{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixpkgs-ruby, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        proj_dir = builtins.getEnv "PROJ_DIR";

        ruby =
          let
            envRubyVersion = builtins.getEnv "RUBY_VERSION";
            rubyVersionFile = "${proj_dir}/.ruby-version";

            rubyVersion =
              if envRubyVersion != ""
              then envRubyVersion
              else if builtins.pathExists rubyVersionFile
              then builtins.readFile rubyVersionFile
              else "3.3.4";  # fallback
          in
          nixpkgs-ruby.packages.${system}."ruby-${rubyVersion}";

        pkgs-2305 = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-22.05.tar.gz") {
          config = { allowUnfree = true; };
        };

        gems = pkgs.bundlerEnv {
          name = "gemset";
          inherit ruby;
          gemfile = "${proj_dir}/Gemfile";
          lockfile = "${proj_dir}/Gemfile.lock";
          gemset = ./gemset.nix;
          groups = [ "default" "production" "development" "test" ];
        };
      in
      {
        devShell = pkgs.mkShell {
            buildInputs = [
              ruby
              pkgs.bundix
              pkgs.postgresql
              pkgs.libyaml
              pkgs.msgpack
              pkgs.ruby-lsp
              pkgs.openssl
              pkgs.shared-mime-info
              pkgs.file
              pkgs-2305.yarn
              pkgs-2305.nodejs-16_x
              pkgs.curl
              
              pkgs.libxml2
              pkgs.libxml2.dev
              pkgs.libxslt
              pkgs.libxslt.dev
              pkgs.pkg-config
              pkgs.zlib
              pkgs.zlib.dev
            ];

            shellHook = ''
              export FREEDESKTOP_MIME_TYPES_PATH="${pkgs.shared-mime-info}/share/mime/packages/freedesktop.org.xml"
              export LD_LIBRARY_PATH="${pkgs.curl.out}/lib:$LD_LIBRARY_PATH"
              export PKG_CONFIG_PATH="${pkgs.libxml2.dev}/lib/pkgconfig"
              export CFLAGS="-I${pkgs.libxml2.dev}/include/libxml2 -I${pkgs.zlib.dev}/include $CFLAGS"
              export LDFLAGS="-L${pkgs.libxml2.out}/lib -L${pkgs.zlib.out}/lib $LDFLAGS"


              echo RubyVersion: $(ruby -v)
            '';
          };
      });
}
