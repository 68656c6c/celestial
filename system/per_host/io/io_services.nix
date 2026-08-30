{ diy, ... }:

{
  services = {
    printing = {
      enable = true;
      drivers = [ diy.cups-citizen-ctzcls ];
    };
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
  };

  hardware.printers = {
    ensureDefaultPrinter = "Citizen_CL-S521";
    ensurePrinters = [
      {
        name = "Citizen_CL-S521";
        deviceUri = "usb://CITIZEN/CL-S521?serial=0.00";
        model = "ctzcls.ppd";
        description = "Citizen CL-S521 Label Printer";
        location = "Home";
      }
    ];
  };
}
