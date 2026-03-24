{ pkgs, ... }:

let
  # Obfuscated to reduce bot scraping
  emailUser = "hello";
  emailDomain = "chrismiller.xyz";
  email = "${emailUser}@${emailDomain}";

  # Fastmail server endpoints
  imapHost = "imap.fastmail.com";
  smtpHost = "smtp.fastmail.com";
  caldavBase = "https://caldav.fastmail.com/dav/calendars/user/${email}/";
  carddavBase = "https://carddav.fastmail.com/dav/addressbooks/user/${email}/Default/";

  # Catppuccin Macchiato userChrome CSS for Thunderbird
  # Based on https://github.com/catppuccin/thunderbird
  catppuccinUserChrome = ''
    /* Catppuccin Macchiato for Thunderbird */
    :root {
      /* Base palette */
      --ctp-rosewater: #f4dbd6;
      --ctp-flamingo: #f0c6c6;
      --ctp-pink: #f5bde6;
      --ctp-mauve: #c6a0f6;
      --ctp-red: #ed8796;
      --ctp-maroon: #ee99a0;
      --ctp-peach: #f5a97f;
      --ctp-yellow: #eed49f;
      --ctp-green: #a6da95;
      --ctp-teal: #8bd5ca;
      --ctp-sky: #91d7e3;
      --ctp-sapphire: #7dc4e4;
      --ctp-blue: #8aadf4;
      --ctp-lavender: #b7bdf8;
      --ctp-text: #cad3f5;
      --ctp-subtext1: #b8c0e0;
      --ctp-subtext0: #a5adcb;
      --ctp-overlay2: #939ab7;
      --ctp-overlay1: #8087a2;
      --ctp-overlay0: #6e738d;
      --ctp-surface2: #5b6078;
      --ctp-surface1: #494d64;
      --ctp-surface0: #363a4f;
      --ctp-base: #24273a;
      --ctp-mantle: #1e2030;
      --ctp-crust: #181926;

      /* Map to Thunderbird variables */
      --toolbar-bgcolor: var(--ctp-mantle) !important;
      --toolbar-color: var(--ctp-text) !important;
      --toolbar-field-background-color: var(--ctp-surface0) !important;
      --toolbar-field-color: var(--ctp-text) !important;
      --toolbar-field-border-color: var(--ctp-surface1) !important;
      --toolbar-field-focus-background-color: var(--ctp-surface1) !important;
      --toolbar-field-focus-color: var(--ctp-text) !important;
      --lwt-sidebar-background-color: var(--ctp-base) !important;
      --lwt-sidebar-text-color: var(--ctp-text) !important;
      --sidebar-background-color: var(--ctp-base) !important;
      --sidebar-text-color: var(--ctp-text) !important;
      --sidebar-border-color: var(--ctp-surface0) !important;
      --tab-selected-bgcolor: var(--ctp-surface0) !important;
      --tab-selected-textcolor: var(--ctp-text) !important;
      --tab-loading-fill: var(--ctp-blue) !important;
      --lwt-tab-text: var(--ctp-subtext1) !important;
      --arrowpanel-background: var(--ctp-base) !important;
      --arrowpanel-color: var(--ctp-text) !important;
      --arrowpanel-border-color: var(--ctp-surface1) !important;
      --button-primary-bgcolor: var(--ctp-blue) !important;
      --button-primary-hover-bgcolor: var(--ctp-sapphire) !important;
      --button-primary-active-bgcolor: var(--ctp-lavender) !important;
      --button-primary-color: var(--ctp-crust) !important;
      --color-accent-primary: var(--ctp-blue) !important;
      --color-accent-primary-hover: var(--ctp-sapphire) !important;
      --color-accent-primary-active: var(--ctp-lavender) !important;
    }

    /* Menu and popup backgrounds */
    menupopup, panel {
      --panel-background: var(--ctp-base) !important;
      background-color: var(--ctp-base) !important;
      color: var(--ctp-text) !important;
    }

    /* Folder pane */
    #folderTree {
      background-color: var(--ctp-mantle) !important;
      color: var(--ctp-text) !important;
    }

    /* Message list */
    #threadTree {
      background-color: var(--ctp-base) !important;
      color: var(--ctp-text) !important;
    }

    /* Message header area */
    .message-header-container {
      background-color: var(--ctp-base) !important;
      color: var(--ctp-text) !important;
    }

    /* Selected items */
    treechildren::-moz-tree-row(selected) {
      background-color: var(--ctp-surface1) !important;
    }
    treechildren::-moz-tree-cell-text(selected) {
      color: var(--ctp-text) !important;
    }

    /* Hover */
    treechildren::-moz-tree-row(hover) {
      background-color: var(--ctp-surface0) !important;
    }

    /* Unread messages */
    treechildren::-moz-tree-cell-text(unread) {
      font-weight: bold !important;
      color: var(--ctp-blue) !important;
    }

    /* Status bar */
    #status-bar {
      background-color: var(--ctp-crust) !important;
      color: var(--ctp-subtext0) !important;
    }
  '';

  catppuccinUserContent = ''
    /* Catppuccin Macchiato for Thunderbird message content */
    :root {
      --ctp-base: #24273a;
      --ctp-text: #cad3f5;
      --ctp-blue: #8aadf4;
      --ctp-surface0: #363a4f;
    }
  '';

  # Extension policies for force-installing addons
  thunderbirdPolicies = {
    DisableTelemetry = true;
    DisableFirefoxStudies = true;
    ExtensionSettings = {
      # ImportExportTools NG — backup/export messages
      "{3ed8cc52-6571-499d-8f12-4cec2e0e5f4b}" = {
        installation_mode = "normal_installed";
        install_url = "https://addons.thunderbird.net/thunderbird/downloads/latest/importexporttools-ng/latest.xpi";
      };
    };
  };
in
{
  # Email account configuration
  emailAccount = {
    address = email;
    userName = email;
    realName = "Chris Miller";
    primary = true;

    imap = {
      host = imapHost;
      port = 993;
      tls.enable = true;
    };

    smtp = {
      host = smtpHost;
      port = 465;
      tls.enable = true;
      tls.useStartTls = false;
    };

    thunderbird = {
      enable = true;
      settings = id: {
        "mail.server.server_${id}.authMethod" = 3; # Normal password
      };
    };
  };

  # Calendar account (CalDAV)
  calendarAccount = {
    primary = true;
    remote = {
      type = "caldav";
      url = caldavBase;
      userName = email;
    };
  };

  # Contact account (CardDAV)
  contactAccount = {
    remote = {
      type = "carddav";
      url = carddavBase;
      userName = email;
    };
  };

  # Thunderbird program configuration
  thunderbird = {
    enable = true;
    profiles.default = {
      isDefault = true;
      settings = {
        # Privacy & telemetry
        "datareporting.policy.dataSubmissionEnabled" = false;
        "toolkit.telemetry.enabled" = false;
        "app.shield.optoutstudies.enabled" = false;

        # Enable userChrome/userContent CSS
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

        # Auto-enable extensions
        "extensions.autoDisableScopes" = 0;

        # Calendar settings
        "calendar.caldav.sched.enabled" = true;

        # CalDAV calendars (Fastmail)
        # Primary calendar
        "calendar.registry.fastmail-primary.type" = "caldav";
        "calendar.registry.fastmail-primary.uri" = "${caldavBase}B5B41062-61E2-11EC-BF9A-FEF9F86E4CD5";
        "calendar.registry.fastmail-primary.name" = "Calendar";
        "calendar.registry.fastmail-primary.username" = email;
        "calendar.registry.fastmail-primary.cache.enabled" = true;
        "calendar.registry.fastmail-primary.calendar-main-in-composite" = true;



        # CardDAV address book (Fastmail contacts)
        "ldap_2.servers.fastmail.carddav.url" = carddavBase;
        "ldap_2.servers.fastmail.carddav.username" = email;
        "ldap_2.servers.fastmail.description" = "Fastmail Contacts";
        "ldap_2.servers.fastmail.dirType" = 102;
        "ldap_2.servers.fastmail.filename" = "abook-fastmail.sqlite";
        "ldap_2.servers.fastmail.auth.method" = 3; # Normal password (same as IMAP)

        # Check for new mail every 3 minutes
        "mail.server.default.check_new_mail" = true;
        "mail.server.default.check_time" = 3;

        # Compose in HTML by default
        "mail.html_compose" = true;
        "mail.identity.default.compose_html" = true;

        # Show all headers in message view
        "mail.show_headers" = 1;
      };

      userChrome = catppuccinUserChrome;
      userContent = catppuccinUserContent;
    };
  };

  # Thunderbird policies (extension management)
  thunderbirdPoliciesFile = {
    ".thunderbird/policies/policies.json".text = builtins.toJSON {
      policies = thunderbirdPolicies;
    };
  };

  # WebDAV file access via Dolphin
  webdavDesktopEntry = {
    name = "Fastmail Files";
    genericName = "Cloud Files";
    comment = "Access Fastmail file storage via WebDAV";
    exec = "dolphin webdavs://myfiles.fastmail.com/";
    icon = "folder-cloud";
    terminal = false;
    type = "Application";
    categories = [
      "FileManager"
      "Network"
    ];
  };
}
