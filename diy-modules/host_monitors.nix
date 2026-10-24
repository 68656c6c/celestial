{
  config,
  lib,
  ...
}:

{
  options.host.monitors = lib.mkOption {
    description = "Attached displays, first one is the primary. Read by the compositor and shell configs.";
    default = [ ];
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          output = lib.mkOption {
            type = lib.types.str;
            example = "DP-1";
          };
          width = lib.mkOption {
            type = lib.types.ints.positive;
            example = 2560;
          };
          height = lib.mkOption {
            type = lib.types.ints.positive;
            example = 1440;
          };
          refresh = lib.mkOption {
            type = lib.types.nullOr lib.types.float;
            default = null;
            example = 143.973;
            description = "Refresh rate in Hz, null lets the compositor pick.";
          };
          x = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "Logical x position, null lets the compositor place it. Set x and y together.";
          };
          y = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
          };
          scale = lib.mkOption {
            type = lib.types.float;
            default = 1.0;
          };
        };
      }
    );
  };

  config.assertions = [
    {
      assertion = lib.all (m: (m.x == null) == (m.y == null)) config.host.monitors;
      message = "host.monitors: set x and y together or not at all";
    }
  ];
}
