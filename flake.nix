{
  description = "Barebones NixOS on ZFS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    home-manager.url = "github:nix-community/home-manager/release-23.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    helix.url = "github:helix-editor/helix";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.home-manager.follows = "home-manager";
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
    , home-manager
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

      nixosModules = import ./modules; #/nixos;
      # homeManagerModules = import ./modules/home-manager;

      nixosConfigurations =
        let
          defaultModules = (builtins.attrValues nixosModules) ++ [
	    ./configuration.nix
            agenix.nixosModules.default
            home-manager.nixosModules.default
          ];
          specialArgs = { inherit inputs outputs; };
        in
        {
          dabass = nixpkgs.lib.nixosSystem {
            inherit specialArgs;
            modules = defaultModules ++ [
              ./hosts/dabass
            ];
          };
        };
    };
}




  # outputs = { self, nixpkgs, nixpkgs-unstable, home-manager }@inputs:
  #   let
  #     mkHost = hostName: system:
  #       nixpkgs.lib.nixosSystem {
  #         pkgs = import nixpkgs {
  #           inherit system;
  #           # settings to nixpkgs goes to here
  #           # nixpkgs.pkgs.zathura.useMupdf = true;
  #           # nixpkgs.config.allowUnfree = false;
  #         };
  #
  #         specialArgs = {
  #           # By default, the system will only use packages from the
  #           # stable channel.  You can selectively install packages
  #           # from the unstable channel.  You can also add more
  #           # channels to pin package version.
  #           pkgs-unstable = import nixpkgs-unstable {
  #             inherit system;
  #             # settings to nixpkgs-unstable goes to here
  #           };
  #
  #           # make all inputs availabe in other nix files
  #           inherit inputs;
  #         };
  #
  #         modules = [
  #           # Root on ZFS related configuration
  #           ./modules
  #
  #           # Configuration shared by all hosts
  #           ./configuration.nix
  #
  #           # Configuration per host
  #           ./hosts/dabass
  #
	 #    # per user
	 #    ./users/dialtone
  #
	 #    # services
	 #    ./services/deluge
  #
  #           # home-manager
  #           home-manager.nixosModules.home-manager
  #           {
  #             home-manager.useGlobalPkgs = true;
  #             home-manager.useUserPackages = true;
  #           }
  #         ];
  #       };
  #   in {
  #     nixosConfigurations = {
  #       dabass = mkHost "dabass" "x86_64-linux";
  #     };
  #   };

