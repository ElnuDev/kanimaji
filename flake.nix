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
        , libwebp
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
            libwebp
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
            JOBS="''${NIX_BUILD_CORES:-0}"
            if ! [ "$JOBS" -gt 0 ] 2>/dev/null; then JOBS="$(nproc)"; fi
            echo "Processing ''${#TARGET_FILES[@]} kanji with $JOBS parallel workers..."
            # Each kanji is an independent process. Frame files are uniquely named
            # per input and deleted once its webp/gif is compiled
            # (DELETE_TEMPORARY_FILES), so the on-disk/in-flight working set stays
            # bounded to the active workers regardless of dataset size.
            printf '%s\n' "''${TARGET_FILES[@]}" | xargs -P "$JOBS" -I{} bash -c '
              svg="$1"
              echo "  $svg"
              ln -sf ${kanjivg}/kanji/"$svg" "$svg"
              kanimaji "$svg" > /dev/null
              rm -f "$svg"
            ' _ {}
            rm .env
            popd
          '';
        };
      discord = let
        stroke = "#5865f2"; # blurple
      in {
        GENERATE_SVG = false;
        GENERATE_JS_SVG = false;
        GENERATE_GIF = false;
        GENERATE_WEBP = true;
        WEBP_SIZE = 1024;
        WEBP_BACKGROUND_COLOR = "transparent"; # no background, adapts to Discord theme
        WEBP_POSTER_FINAL_FRAME = true; # lead with the completed glyph (static fallback)
        STROKE_UNFILLED_COLOR = "#000";
        STROKE_FILLING_COLOR = stroke;
        STROKE_FILLED_COLOR = "#eee";
        BRUSH_COLOR = stroke;
      };
    in {
      kanimaji = pkgs.callPackage kanimaji { };
      default = self.packages."${system}".kanimaji;
      all = pkgs.callPackage generate { };
      custom = pkgs.callPackage generate {
        "kanjiList" = [ "日" "本" "位" "位-Kaisho" ];
      };
      allDiscord = (pkgs.callPackage generate { }).overrideAttrs (final: prev: discord);
      customDiscord = (pkgs.callPackage generate {
        "kanjiList" = [ "語" ];
      }).overrideAttrs (final: prev: discord);
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
