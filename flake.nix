{
  description = "Arytmometr FP - dev shell z GHDL i GTKWave do symulacji VHDL z CLI";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        ghdl       # symulator VHDL
        gtkwave    # przegladarka waveformow (.vcd)
        go-task    # task runner (Taskfile.yml)
      ];

      shellHook = ''
        echo "GHDL: $(ghdl --version | head -1)"
        echo "Cele: task --list"
      '';
    };
  };
}
