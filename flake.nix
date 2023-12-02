{
  description = "Barebones NixOS on ZFS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    helix.url = "github:helix-editor/helix";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    neovim-plugins.url = "github:LongerHV/neovim-plugins-overlay";
    neovim-plugins.inputs.nixpkgs.follows = "nixpkgs-unstable";
    nixgl.url = "github:guibou/nixGL";
    nixgl.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { self
    , nixpkgs
    , nixpkgs-unstable
    , nixos-hardware
    , helix
    , agenix
    , neovim-plugins
    , nixgl
    , ...
    }@inputs:
    let
      inherit (self) outputs;
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" ];
    in
    rec {
      overlays = {
        default = import ./overlay/default.nix;
        unstable = final: prev: {
          unstable = nixpkgs-unstable.legacyPackages.${prev.system};
          inherit (nixpkgs-unstable.legacyPackages.${prev.system}) neovim-unwrapped;
          inherit (helix.packages.${prev.system}) helix;
        };
        neovimPlugins = neovim-plugins.overlays.default;
        agenix = agenix.overlays.default;
        nixgl = nixgl.overlays.default;
      };

      legacyPackages = forAllSystems (system:
        import inputs.nixpkgs {
          inherit system;
          overlays = builtins.attrValues overlays;
          config.allowUnfree = true;
        }
      );

      secretsModule = [./secrets];
      nixosModules = import ./modules; #/nixos;

      nixosConfigurations =
        let
          defaultModules = (builtins.attrValues nixosModules) ++ [
	    ./configuration.nix
            agenix.nixosModules.default
          ];
          specialArgs = { inherit inputs outputs; vars = import ./hosts/dabass/vars.nix;};
        in
        {
          dabass = nixpkgs.lib.nixosSystem {
            inherit specialArgs;
            modules = secretsModule ++ defaultModules ++ [
              ./hosts/dabass
            ];
          };
        };
    };
}
