const { Client, GatewayIntentBits, Partials, Collection } = require('discord.js');
const config = require('./config.json');
const fs = require('fs');
const path = require('path');
const sendLiberarMessage = require('./components/liberar');

// 👉 importa o autoBackup
const { startAutoBackup } = require('./autoBackup');

const client = new Client({
    intents: [
        GatewayIntentBits.Guilds,
        GatewayIntentBits.GuildMembers,
        GatewayIntentBits.GuildMessages,
        GatewayIntentBits.MessageContent
    ],
    partials: [Partials.Message, Partials.Channel, Partials.Reaction]
});

// Mapeia comandos (!comando)
client.commands = new Collection();
const commandFiles = fs.readdirSync(path.join(__dirname, 'commands')).filter(file => file.endsWith('.js'));

for (const file of commandFiles) {
    const command = require(`./commands/${file}`);
    client.commands.set(command.name, command);
}

client.once('ready', async () => {
    console.log(`✅ Bot online como ${client.user.tag}`);
    await sendLiberarMessage(client);

    // 👉 ativa o backup automático
    startAutoBackup(client);
});

// Escuta mensagens de texto no Discord
client.on('messageCreate', async message => {
    if (message.author.bot || !message.guild) return;

    const prefix = '!';
    if (!message.content.startsWith(prefix)) return;

    const args = message.content.slice(prefix.length).trim().split(/ +/);
    const commandName = args.shift().toLowerCase();

    const command = client.commands.get(commandName);
    if (!command) return;

    try {
        await command.execute(client, message, args);
    } catch (error) {
        console.error(error);
        message.reply('❌ Erro ao executar o comando.');
    }
});

client.login(config.token);
