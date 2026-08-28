{
  lib,
  ...
}:

{
  options.host.monitors = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          output = lib.mkOption {
            type = lib.types.str;
          };
          mode = lib.mkOption {
            type = lib.types.str;
            default = "";
          };
          position = lib.mkOption {
            type = lib.types.str;
            default = "";
          };
          scale = lib.mkOption {
            type = lib.types.float;
            default = 1.0;
          };
        };
      }
    );
    default = [ ];
  };
}
