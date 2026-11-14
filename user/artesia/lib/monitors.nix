# Formatting for host.monitors entries, shared by the compositor configs.
{ lib }:

{
  # 143.973 -> "143.973", 60.0 -> "60.000"
  fmtRefresh =
    r:
    let
      whole = builtins.floor r;
      milli = builtins.floor ((r - whole) * 1000 + 0.5);
    in
    if milli == 1000 then
      "${toString (whole + 1)}.000"
    else
      "${toString whole}.${lib.fixedWidthNumber 3 milli}";

  resolution = m: "${toString m.width}x${toString m.height}";
}
