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
        { stdenv
        , lib
        , python3
        , python3Packages
        , kanjiList ? null
        }:
        stdenv.mkDerivation {
          name = "kanimaji";
          buildInputs = [ python3 ] ++ (with python3Packages; [
            lxml
            svg-path
            python-dotenv
          ]);
          src = ./.;
          KANJI_LIST_FILE = if kanjiList == null
              then null
              else pkgs.writeText "kanji-list.txt" (lib.concatStringsSep "\n" kanjiList);
          installPhase = ''
            mkdir -p $out
            export LC_ALL=C.UTF-8

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
              python $src/kanimaji.py $svg
              rm $svg
            done
            rm .env
            popd
          '';

          GENERATE_GIF = false;
          GENERATE_JS_SVG = false;
        };
    in {
      default = self.packages."${system}".all;
      all = pkgs.callPackage kanimaji { };
      custom = pkgs.callPackage kanimaji {
        "kanjiList" = [ "日" "本" "位" "位-Kaisho" ];
      };
    };
    devShells."${system}".default = pkgs.mkShell {
      inputsFrom = [ self.packages."${system}".default ];
      packages = with pkgs.python314Packages; [
        types-lxml # lxml type hints
        black # formatting
      ];
    };
  };
}
