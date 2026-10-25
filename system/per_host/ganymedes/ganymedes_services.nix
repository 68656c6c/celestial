{ ... }:

{
  services = {
    # The ALC255 has two DACs, so the three speaker pins come out as a 4.0
    # device: front = left pair, rear = right pair, subs on a shared DAC.
    # Start on the 4.0 + microphone profile instead of WirePlumber's stereo
    # duplex pick, which would leave the right side silent.
    pipewire.wireplumber.extraConfig."51-ganymedes-audio-profile"."monitor.alsa.rules" = [
      {
        matches = [ { "device.name" = "alsa_card.pci-0000_00_1f.3"; } ];
        actions."update-props"."device.profile" = "output:analog-surround-40+input:analog-stereo";
      }
    ];
  };
}
