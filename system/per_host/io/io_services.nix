{ diy, ... }:

{
  services = {
    xserver = {
      enable = true;
      desktopManager.xfce.enable = true;
    };

    tailscale.enable = true;
    printing = {
      enable = true;
      drivers = [ diy.cups-citizen-ctzcls ];
    };
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
    sunshine = {
      enable = true;
      openFirewall = true;
      settings = {
        bind_address = "10.2.50.4";
        csrf_allowed_origins = "https://10.2.50.4:47990,https://io.cl2.artesia.cloud:47990";
      };
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
