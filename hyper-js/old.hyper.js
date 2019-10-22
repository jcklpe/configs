// Future versions of Hyper may add additional config options,
// which will not automatically be merged into this file.
// See https://hyper.is#cfg for all currently supported options.

module.exports = {
  config: {
    // choose either `'stable'` for receiving highly polished,
    // or `'canary'` for less polished but more frequent updates
    updateChannel: "stable",

    hyperBorder: {
      //   borderColors: ['random','random'],
      //   borderColors: ['rgb(10, 40, 45)', 'rgb(15, 25, 50)'],
      borderColors: ["rgb(212, 244, 66)", "rgb(2, 247, 88)"],
      borderRadiusOuter: "1px",
      borderRadiusInner: "1px",
      borderWidth: "2px"
    },

    // default font size in pixels for all tabs
    fontSize: 19,

    // font family with optional fallbacks
    fontFamily: "FuraCode Nerd Font Mono",

    // default font weight: 'normal' or 'bold'
    fontWeight: "normal",

    scrollback: 60000,

    // font weight for bold characters: 'normal' or 'bold'
    fontWeightBold: "bold",

    // terminal cursor background color and opacity (hex, rgb, hsl, hsv, hwb or cmyk)
    cursorColor: "rgba(248,28,229,0.8)",

    // terminal text color under BLOCK cursor
    cursorAccentColor: "#000",

    // `'BEAM'` for |, `'UNDERLINE'` for _, `'BLOCK'` for █
    cursorShape: "BEAM",

    // set to `true` (without backticks and without quotes) for blinking cursor
    cursorBlink: true,

    // color of the text
    foregroundColor: "#fffbf4",

    // terminal background color
    // opacity is only supported on macOS
    backgroundColor: "transparent",

    // terminal selection color
    selectionColor: "rgba(248,28,229,0.3)",

    // border color (window, tabs)
    borderColor: "#333",

    // custom CSS to embed in the main window
    css: "",

    // custom CSS to embed in the terminal window
    termCSS: "",

    // if you're using a Linux setup which show native menus, set to false
    // default: `true` on Linux, `true` on Windows, ignored on macOS
    showHamburgerMenu: "",

    // set to `false` (without backticks and without quotes) if you want to hide the minimize, maximize and close buttons
    // additionally, set to `'left'` if you want them on the left, like in Ubuntu
    // default: `true` (without backticks and without quotes) on Windows and Linux, ignored on macOS
    showWindowControls: "",

    // custom padding (CSS format, i.e.: `top right bottom left`)
    padding: "24px 30px",

    // the full list. if you're going to provide the full color palette,
    // including the 6 x 6 color cubes and the grayscale map, just provide
    // an array here instead of a color map object
    colors: {
      black: "black",
      red: "#F70258",
      green: "#02F758",
      yellow: "#ffbc05",
      blue: "#0e35d1",
      magenta: "#7b39c8",
      cyan: "#00c6a5",
      white: "#adaaa4",
      lightBlack: "#3d342b",
      lightRed: "#ff5470",
      lightGreen: "#D4F442",
      lightYellow: "#fffa00",
      lightBlue: "#19aeff",
      lightMagenta: "#c932fc",
      lightCyan: "#65f2ca",
      lightWhite: "#fffbf4"
    },

    // the shell to run when spawning a new session (i.e. /usr/local/bin/fish)
    // if left empty, your system's login shell will be used by default
    //
    // Windows
    // - Make sure to use a full path if the binary name doesn't work
    // - Remove `--login` in shellArgs
    //
    // Bash on Windows
    // - Example: `C:\\Windows\\System32\\bash.exe`
    //
    // PowerShell on Windows
    // - Example: `C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe`
    shell: `C:\\Windows\\System32\\bash.exe`,

    // for setting shell arguments (i.e. for using interactive shellArgs: `['-i']`)
    // by default `['--login']` will be used
    shellArgs: ["--login"],
    // shellArgs: [""],

    // for environment variables
    env: {},

    // set to `false` for no bell
    bell: "SOUND",

    // summon: {
    //   hideDock: true,
    //   hideOnBlur: true,
    //   hotkey: 'Ctrl+.'
    // },

    // if `true` (without backticks and without quotes), selected text will automatically be copied to the clipboard
    copyOnSelect: false,

    // if `true` (without backticks and without quotes), hyper will be set as the default protocol client for SSH
    defaultSSHApp: true,

    // if `true` (without backticks and without quotes), on right click selected text will be copied or pasted if no
    // selection is present (`true` by default on Windows and disables the context menu feature)
    // quickEdit: true,

    // URL to custom bell
    // bellSoundURL: 'http://example.com/bell.mp3',

    // for advanced config flags please refer to https://hyper.is/#cfg

    // opacity: {
    //   focus: 0.9,
    //   blur: 0.5
    // }

    overlay: {
      alwaysOnTop: true,
      animate: true,
      hasShadow: true,
      hideDock: false,
      hideOnBlur: false,
      hotkeys: {
        open: ["Control+Space"], // On MacOS hotkey is default to Option + Space!
        close: ["Control+Shift+Space"] // On MacOS hotkey is default to Option + Escape!
      },
      position: "top",
      primaryDisplay: false,
      resizable: true,
      size: {
        width: 0.4,
        height: 0.6
      },
      startAlone: true,
      startup: true,
      tray: true,
      unique: false
    }
  },

  plugins: [
    //'hyperterm-tabs',
    //'hypertheme',
    //'hyperterm-blink',
    //'hyper-transparent-bg', does not work on Windows
    //'hyper-opacity',
    //'hyper2-border',
    //'hyperterm-paste',
    // 'hyper-alt-click',
    //'hyper-match',
    //'hyperterm-crosshair',
    //'hyper-autohide-tabs',
    //'hyper-tab-icons',
    //'hyper-hover-header',
    //'hyper-background',
    //'hyperterm-summon',
    //'hyper-stylesheet',

    // adds animation to git push and pull
    "gitrocket",
    "space-pull",

    //add support for pane multiplexing
    "hyper-pane",

    //enhances tab styling
    "hyper-tabs-enhanced",
    "hyperterm-bold-tab",
    "hyperterm-dibdabs",

    // open new tabs in the same location as current tab
    "hypercwd",

    // adds overlay hotkey abilities
    "hyper-overlay",

    // give normal scrolling in nano
    "hyperterm-alternatescroll",

    // Cool looking border
    "hyperborder",

    // 𝑻𝑯𝑬𝑴𝑬𝑺
    "hyper-bloody"
    //'an-old-hype',
    //'hyper-clean',
    //'hyper-oldschool',
    //'hyperatompunk',
    //'hyperterm-retro',
    //'hyperpunk2.0'
    //'hyperblue-vibrancy',
    //'hyper-mahoushoujo',
    //'hypermaterial-vibrancy'
  ],

  // in development, you can create a directory under
  // `~/.hyper_plugins/local/` and include it here
  // to load it and avoid it being `npm install`ed
  localPlugins: [],

  keymaps: {
    // Example
    // 'window:devtools': 'cmd+alt+o',
  }
};

// this is the version that is in my drobpox folder
