{
  description = "Beautiful animated SVG or GIF kanji from KanjiVG data set.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    kanijvg = {
      url = "github:KanjiVG/kanjivg";
      flake = false;
    };
  };

  outputs = { nixpkgs, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
    };
    python = "python314";
  in {
    devShells.x86_64-linux.default = pkgs.mkShell {
      packages = [ pkgs."${python}" ] ++ (with pkgs."${python}Packages"; [
        lxml
        types-lxml
        svg-path
      ]);
    };
  };
}
