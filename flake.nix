{
  description = "Beautiful animated SVG or GIF kanji from KanjiVG data set.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    kanjivg = {
      url = "github:KanjiVG/kanjivg";
      flake = false;
    };
  };

  outputs = { nixpkgs, kanjivg, self }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
    };
  in {
    packages."${system}" = let
      kanimaji =
        { lib
        , python3Packages
        , cairosvg
        , imagemagick
        , gifsicle
        , gifSupport ? true
        }:
        python3Packages.buildPythonApplication rec {
          name = "kanimaji";
          src = ./.;
          dependencies = (with python3Packages; [
            lxml
            svg-path
            python-dotenv
          ]) ++ lib.optionals gifSupport [
            cairosvg
            imagemagick
            gifsicle
          ];
          format = "other";
          installPhase = ''
            mkdir -p $out/bin
            pushd $out/bin
            cp $src/*.py .
            cp $src/.env .
            ln -s ${name}.py ${name}
            popd
          '';
        };
      generate =
        { stdenv
        , lib
        , makeFontsConf
        , kanjiList ? null
        }:
        stdenv.mkDerivation {
          name = "kanimaji-out";
          src = ./.;
          KANJI_LIST_FILE = if kanjiList == null
              then null
              else pkgs.writeText "kanji-list.txt" (lib.concatStringsSep "\n" kanjiList);
          buildInputs = [ self.packages."${system}".kanimaji ];
          FONTCONFIG_FILE = makeFontsConf { fontDirectories = [ ]; };
          installPhase = ''
            mkdir -p $out
            export LC_ALL=C.UTF-8
            export XDG_CACHE_HOME="$(mktemp -d)"

            if [ -z "$KANJI_LIST_FILE" ]; then
              echo "Processing all kanji..."
              FULL_PATHS=(${kanjivg}/kanji/*.svg)
              TARGET_FILES=("''${FULL_PATHS[@]##*/}")
            else
              echo "Processing specified kanji..."
              TARGET_FILES=()
              while IFS= read -r line || [ -n "$line" ]; do
                # split e.g. "字-Kaisho" into "字" and "-Kaisho"
                char=''${line:0:1}
                suffix=''${line:1}

                # %05x ensures 5-digit padding
                hex=$(printf "%05x" "'$char")

                filename="''${hex}''${suffix}.svg"

                if [ -f "${kanjivg}/kanji/$filename" ]; then
                    TARGET_FILES+=("$filename")
                else
                    echo "Warning: $full_path not found, skipping."
                fi
              done < "$KANJI_LIST_FILE"
            fi

            pushd $out
            ln -s $src/.env .
            for svg in "''${TARGET_FILES[@]}"; do
              ln -s ${kanjivg}/kanji/$svg .
              kanimaji $svg
              rm $svg
            done
            rm .env
            popd
          '';
        };
    in {
      kanimaji = pkgs.callPackage kanimaji { };
      default = self.packages."${system}".kanimaji;
      all = pkgs.callPackage generate { };
      custom = pkgs.callPackage generate {
        "kanjiList" = [ "日" "本" "位" "位-Kaisho" ];
      };
    };
    devShells."${system}".default = pkgs.mkShell {
      inputsFrom = [ self.packages."${system}".kanimaji ];
      packages = with pkgs.python3Packages; [
        types-lxml # lxml type hints
        black # formatting
      ];
    };
  };
}
