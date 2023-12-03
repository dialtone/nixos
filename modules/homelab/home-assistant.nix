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
