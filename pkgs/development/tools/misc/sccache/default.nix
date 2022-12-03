{ stdenv, lib, fetchFromGitHub, rustPlatform, pkg-config, openssl, Security
, runtimeShell
, makeWrapper
, sccache
}:

rustPlatform.buildRustPackage rec {
    version = "0.3.1";
    pname = "sccache";

    src = fetchFromGitHub {
      owner = "mozilla";
      repo = "sccache";
      rev = "v${version}";
    sha256 = "sha256-SjGtFkFyHJRnFg3QwXksrV+T08oku80vcivLzFWt94g=";
  };

  cargoSha256 = "sha256-cd/4otvrneOqntBzNZP1/RY0jg/NYeugiblr1tatITI=";


    nativeBuildInputs = [ pkg-config ];
    buildInputs = [ openssl ] ++ lib.optional stdenv.isDarwin Security;

    # sccache-dist is only supported on x86_64 Linux machines.
    buildFeatures = lib.optionals (stdenv.system == "x86_64-linux") [ "dist-client" "dist-server" ];

    # Tests fail because of client server setup which is not possible inside the pure environment,
    # see https://github.com/mozilla/sccache/issues/460
    doCheck = false;

    passthru = {
      # A derivation that provides gcc and g++ commands, but that
      # will end up calling sccache for the given cacheDir
      links = {unwrappedCC, extraConfig}: stdenv.mkDerivation {
        name = "sccache-links";
        passthru = {
          isClang = unwrappedCC.isClang or false;
          isGNU = unwrappedCC.isGNU or false;
        };
        inherit (unwrappedCC) lib;
        nativeBuildInputs = [ makeWrapper ];
        buildCommand = ''
          mkdir -p $out/bin

          wrap() {
            local cname="$1"
            if [ -x "${unwrappedCC}/bin/$cname" ]; then
              makeWrapper ${sccache}/bin/sccache $out/bin/$cname \
                --run ${lib.escapeShellArg extraConfig} \
                --add-flags ${unwrappedCC}/bin/$cname
            fi
          }

          wrap cc
          wrap c++
          wrap gcc
          wrap g++
          wrap clang
          wrap clang++

          for executable in $(ls ${unwrappedCC}/bin); do
            if [ ! -x "$out/bin/$executable" ]; then
              ln -s ${unwrappedCC}/bin/$executable $out/bin/$executable
            fi
          done
          for file in $(ls ${unwrappedCC} | grep -vw bin); do
            ln -s ${unwrappedCC}/$file $out/$file
          done
        '';
      };
    };

    meta = with lib; {
      description = "Ccache with Cloud Storage";
      homepage = "https://github.com/mozilla/sccache";
      maintainers = with maintainers; [ doronbehar ];
      license = licenses.asl20;
    };
}
