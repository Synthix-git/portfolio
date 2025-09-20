# Syn Network — Welcome Script

Lightweight **welcome & announcement system** for Syn/Creative (vRP-based) servers.  
Displays a configurable welcome message when players join, with persistent ON/OFF toggle and runtime admin commands.

---

## ✨ Features

- **Configurable Welcome Message**  
  Edit title, color, duration and body text directly in `server/welcome.lua`.

- **Join Modes**  
  - `first` → Only once per session.  
  - `always` → Every time a player spawns.

- **Persistence**  
  Toggle and mode settings survive server restarts (stored in `vRP.SetSrvData`).

- **Admin Commands**  
  Restricted to staff group (`Admin` by default).

---

 Adjust the config at the top of `server/welcome.lua`:
```lua
local WelcomeCfg = {
  enabled_default   = true,
  send_mode_default = "always",
  staff_group       = "Admin",

  discord_link = "https://discord.gg/xxxxxxx",

  notify = {
    title = "Corridas",
    color = "rosa",
    time  = 13000,
    body  = "Edit this body text with your own welcome message..."
  }
}

🔑 Commands
Player

/discord → Opens keyboard with your Discord invite link.

If keyboard fails, shows the link in a notification.

Staff/Admin

/welcometoggle [on|off]
Toggle the welcome script (persistent).

/welcomestatus
Show current state, mode and Discord link.

/welcomemode first|always
Change whether the message is shown once per session or on every spawn.

/welcomeclear
Clear the memory of players already greeted (useful in first mode).

📂 File Structure
welcome/
│
├── client/welcome.lua   # Sends spawn event once per session
├── server/welcome.lua   # Handles config, persistence, notifications & commands


🧑‍💻 Author

Developed and maintained by Gabriel "Synthix" Silva
Part of the Syn Network custom framework.