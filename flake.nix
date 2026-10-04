{
  description = "page";

  inputs      = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs     = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs   = import nixpkgs { inherit system; };
    in
      with builtins;
      with pkgs.lib;
      with pkgs;
    rec {
      mk = { static ? []
           , inputs ? []
           , pages  ? {}
           , page
           , name
           , src
           }:
             let
               toCp = drv: { copy = drv; name = drv.name; };
               copy = to: ls:
                 let
                   f = map ({ copy, name }: "cp -r ${copy} ${to}/${name}") ls;
                   g = concatStringsSep "\n" f;
                 in g;
               make = { static ? []
                      , inputs ? []
                      , pages  ? {}
                      , name
                      , page
                      , meta
                      }:
                        let
                          pages'    =
                            let
                              m = n: {
                                path = "${meta.path}${n}/";
                                last = meta;
                                name = n;
                              };

                              f = x: make (pages.${x} // { name = x; meta = m x; });
                              g = attrNames pages;
                            in map f g;

                          c = writeText "${name}-context.json" (builtins.toJSON meta);
                        in stdenv.mkDerivation {
                          inherit name;
                          inherit src;

                          nativeBuildInputs = [
                            gomplate
                          ];

                          buildInputs  = inputs ++ pages';
                          buildPhase   = ''
                              runHook preBuild

                              gomplate -c .=${c} -f ${page} -o index.html

                              runHook postBuild
                          '';

                          installPhase = ''
                              runHook preInstall
                              mkdir -p $out/static
                              ${copy "$out/static" static}
                              ${copy "$out" (map toCp inputs)}
                              ${copy "$out" (map toCp pages')}
                              cp index.html $out
                              runHook postInstall
                          '';
                        };

               meta = {
                 inherit name;
                 last = null;
                 path = "/";
               };
             in make {
               inherit static inputs pages page name meta;
             };
    };
}
