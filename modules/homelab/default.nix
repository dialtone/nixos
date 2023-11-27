{inputs, outputs, config, lib, pkgs, ...}:

let
  cfg = config.homelab;
in 
{

  imports = [
    ./aspm-tuning.nix
  ];
  environment = {
    systemPackages = with pkgs; [
	inputs.agenix.packages.x86_64-linux.default
    	#agenix.packages.x86_64-linux.default
    ];
  };

}
