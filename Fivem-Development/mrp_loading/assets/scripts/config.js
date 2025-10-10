Config = {}; // Don't touch

Config.ServerIP = "medusarp.pt:30110";

// Social media buttons on the left side
Config.Socials = [
    {name: "discord", label: "Discord", description: "Junta-te ao discord para ter acesso as nossas regras, novas atualizações e novidades", icon: "assets/media/icons/discord.png", link: "https://discord.gg/VsYNTkwBSy"},
    {name: "instagram", label: "Instagram", description: "Junta-te a nós no instagram e vê conteúdo criado pelos nossos jogadores", icon: "assets/media/icons/tiktok.png", link: "#"},
    {name: "tebex", label: "Donations", description: "Para efetuar uma doação dirige-te a aba #doações no nosso Discord", icon: "assets/media/icons/tebex.png", link: "https://discord.com/channels/888367113604067349/888367115097235497"},
];

Config.HideoverlayKeybind = 112 // JS key code https://keycode.info
Config.CustomBindText = "F1"; // leave as "" if you don't want the bind text in html to be statically set

// Staff list
Config.Staff = [
    {name: "Nezy", description: "Dono", color: "#52E04B", image: "assets/media/test.png"},
    {name: "Syn", description: "Dono & Main Dev", color: "#52E04B", image: "assets/media/test.png"},
    {name: "Jonnz", description: "Developer", color: "#52E04B", image: "assets/media/test.png"},
];

// Categories
Config.Categories = [
    {label: "Social Media", default: true},
    {label: "Staff", default: false}
];

// Music
Config.Song = "song.mp3";
