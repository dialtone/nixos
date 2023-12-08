{ lib, config, ... }:
{

  services.home-assistant = {
    enable = true;
    extraComponents = [
      "shelly"
      "ecobee"
      "sense"
      "mikrotik"
      "systemmonitor"
    ];
    openFirewall = true;
    config = {
      http = {
        use_x_forwarded_for = true;
        trusted_proxies = [ "127.0.0.1" "::1" ];
      };
      default_config = { };
      homeassistant = {
        unit_system = "metric";
	temperature_unit = "C";
      };
      sensor = [
      	{
	  platform = "systemmonitor";
	  resources = [
	    {type = "memory_use_percent";}
	    {type = "processor_use";}
	    {type = "last_boot";}
	  ];
	}
      ]; 
    };
  };

}
