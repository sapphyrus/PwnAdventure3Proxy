# Pwn Adventure 3 Proxy

![PWN Adventure 3](https://camo.githubusercontent.com/71b900b6bd6f3feb4c0d9961e94120e8d188d5fb/687474703a2f2f7777772e70776e616476656e747572652e636f6d2f696d672f6c6f676f2e706e67)

> Pwn Adventure 3: Pwnie Island is a limited-release, first-person, true open-world MMORPG set on a beautiful island where anything could happen. That's because this game is intentionally vulnerable to all kinds of silly hacks! Flying, endless cash, and more are all one client change or network proxy away. Are you ready for the mayhem?!

- Original website: https://www.pwnadventure.com/
- Server setup guide: https://github.com/LiveOverflow/PwnAdventure3/#install-server

--- 

This is a MITM Proxy for Pwn Adventure 3 written in Ruby. It's still very much a work in progress, but the following features have been implemented:

- parsing of game packets (not all are currently supported)
- support for injecting forged packets into the game->server or server->game stream
- entity list
- very basic aimbot
- auto pickup drops

Credits (<3):

- https://github.com/Foxmole/PwnAdventure3/
- https://github.com/LiveOverflow/PwnAdventure3/tree/master/tools/proxy
