{
  lib,
  ...
}:

{
  options.host.cursor = {
    size = lib.mkOption {
      type = lib.types.ints.positive;
      default = 38;
    };
  };
}
