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
    pythonPackages = pkgs."${python}Packages";
    deps = [ pkgs."${python}" ] ++ (with pythonPackages; [
      lxml
      svg-path
    ]);
  in {
    devShells."${system}".default = pkgs.mkShell {
      packages = deps ++ (with pythonPackages; [
        types-lxml # lxml type hints
        black # formatting
      ]);
    };
  };
}
