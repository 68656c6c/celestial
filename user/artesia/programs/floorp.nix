{ ... }:

{
  programs.floorp = {
    enable = true;
    languagePacks = [
      "en-US"
      "en-GB"
      "ja"
      "nl"
      "de"
      "ar"
    ];

    policies = {
      ExtensionSettings =
        with builtins;
        let
          extension = shortId: uuid: {
            name = uuid;
            value = {
              install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
              installation_mode = "normal_installed";
              default_area = "navbar";
            };
          };
        in
        listToAttrs [
          (extension "ublock-origin" "uBlock0@raymondhill.net")
          (extension "bitwarden-password-manager" "{446900e4-71c2-419f-a6a7-df9c091e268b}")
          (extension "sponsorblock" "sponsorBlocker@ajay.app")
          (extension "decentraleyes" "jid1-BoFifL9Vbdl2zQ@jetpack")
          (extension "return-youtube-dislikes" "{762f9885-5a13-4abd-9c77-433dcd38b8fd}")
          (extension "privacy-badger17" "jid1-MnnxcxisBPnSXQ@jetpack")
          (extension "clearurls" "{74145f27-f039-47ce-a470-a662b129930a}")
          (extension "pywalfox" "pywalfox@frewacom.org")
          (extension "linkwarden" "jordanlinkwarden@gmail.com")
          (extension "floccus" "floccus@handmadeideas.org")
        ];

      SkipTermsOfUse = true;
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisableAccounts = true;
      DisableProfileRefresh = true;
      DisableFirefoxScreenshots = true;
      DisableProfileImport = true;
      DisableFormHistory = true;
      DisableEncryptedClientHello = false;
      OfferToSaveLogins = false;
      PasswordManagerEnabled = false;
      SearchSuggestEnabled = false;
      AutofillAddressEnabled = false;
      AutofillCreditCardEnabled = false;
      IPProtectionAvailable = false;

      "SearchEngines" = {
        Default = "ecosia";
        Remove = [
          "Google"
          "DuckDuckGo"
          "Bing"
          "Startpage"
          "You.com"
        ];
        Add = [
          {
            Name = "ecosia";
            Alias = "e";
            IconURL = "https://www.ecosia.org/favicon.ico"; # make it look pretty at least lmao
            URLTemplate = "https://www.ecosia.org/search?q={searchTerms}";
          }
          {
            Name = "duckduckgo";
            Alias = "d";
            IconURL = "https://duckduckgo.com/favicon.ico"; # make it look pretty at least lmao
            URLTemplate = "https://duckduckgo.com/?q={searchTerms}";
          }
          {
            Name = "kagi";
            Alias = "k";
            IconURL = "https://kagi.com/favicon.ico";
            URLTemplate = "https://kagi.com/search?q={searchTerms}";
          }
          {
            Name = "google";
            Alias = "g";
            IconURL = "https://www.google.com/favicon.ico";
            URLTemplate = "https://google.com/search?q={searchTerms}";
          }
        ];
      };

      "DNSOverHTTPS" = {
        Enabled = true;
        Locked = true;
        ExcludedDomains = [
          "lab.local"
          "lab2.local"
          "artesia.cloud"
          "artesia.club"
          "artesia.moe"
          "artesia.me"
          "artesia.space"
          "artesia.agency"
          "artesia.dev"
          "artesia.app"
        ];
      };

      "Sync" = {
        Enabled = false;
      };

      "AIControls" = {
        Default = {
          Value = "blocked";
          Locked = true;
        };
      };

      "GenerativeAI" = {
        Enabled = false;
        Chatbot = false;
        LinkPreviews = false;
        TabGroups = false;
        Locked = true;
      };

      # Extension policies
      "3rdparty" = {
        Extensions = {
          "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
            environment = {
              base = "https://vault.artesia.cloud";
            };
          };
        };
      };
    };

    profiles.og = {
      id = 0;
      name = "og";
      containersForce = true;

      containers = {
        personal = {
          color = "red";
          icon = "fingerprint";
          id = 1;
        };
        epicawesome = {
          color = "purple";
          icon = "briefcase";
          id = 2;
        };
        mom = {
          color = "blue";
          icon = "chill";
          id = 3;
        };
        dad = {
          color = "green";
          icon = "tree";
          id = 4;
        };
      };
      extensions.force = true;
    };
  };
}
