# Fast Logic
With great optimization, comes great speed. Fast logic provides significant acceleration compared to vanilla logic gates and makes the use of logic for practical purposes much more viable.

* **Fast Logic Gate**
Behaves just like a vanilla logic gate, until you hover over it and press U. This will significantly increase the speed at which your logic runs. On top of this, fast logic gates allow you to change the color of their connection dot with the help of the multitool.
* **Single Tick Step Button**
This button can be used to stop the simulation of Fast Logic. When pressing it the first time the simulation speed will be set to 0. Every time you press it after that it will step the simulation one tick. This is useful when debugging a creation because you can see exactly what happens on every tick.
* **End Tick Button**
This block is used to end the current simulation tick. By powering it by with a logic input it makes the creation only run one more simulation tick till the next game tick. This can be used to automatically synchronize displays to the tickspeed of the game.
* **Logic Memory**
This block allows for highly compact memory. Used with Interface blocks. Input: Make a line of Address gates then one Data Write gate and a line of Data In Gates. Connect these all in series going out from the Memory. Output: Make a line of Address gates then a line of Data Out Gates. Connect these in series like the input. You can disable the output with a Data Write gate inbetween the Address and Data.

# Silicon
Logic gates cause lag due to their existence, the calculation of physics, and the updating of logic states. The solution to this is to consolidate cuboids of logic into "silicon" blocks, which internally store all the data that the logic gates inside would have had and behave exactly the same. These silicon blocks are much better for game performance. A side effect of consolidating blocks together is that we can perform data compression on the logic blocks stored inside the silicon blocks, leading to significantly smaller file sizes. This means you can save much larger logic creations on your lift without needing to worry about spawning them.

# Multitool
The multitool is a new tool that allows players to easily manipulate logic efficiently. It has functions that work with the rest of the mod such as converting to fast logic or silicon and colorizing the fast logic connection dots. It also has functions that let you quickly and effortlessly manufacture logic by creating large amounts of connections quickly. Many tools allow you to shorten the time it takes to create logic from hours to minutes. On top of that, many helper tools are present that allow you to debug your logic quickly.

### Here are just a few of the tools this mod adds

## Connection Shower
Allows you to see the inputs and outputs of any gate (Even inside of a silicon block). This is great when you have a mess of wires.

![](https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExdWFsODRtMDIxMmNwcnB5aTdsYWVtcGZjdjBtMGV5cHBvcDJ3YndwNiZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/Txbf3zPT7py96SI8os/giphy.gif)

## Parallel Connect
Connects rows of gates in parallel very quickly. Great for wiring up complex circuits.

![](https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExMzZ4NnZsNnF0emZnaDA3d3dsbXA4ZXUwc3J6dDRkNmEycnIwb3Q3MCZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/Nm4MDReXKguzcfhPc7/giphy.gif)

## Tensor Connect
Parallel connect's big brother. Makes orders of magnitude more connections than parallel connect efficiently.

![](https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExenY0emY4d3d1MG95Z3B1eDQwb2NoeXZxMGw1djd6YXI3ZGFmbnRoOSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/A0CuwesGXJfCwTvoEt/giphy.gif)

## Volume Placer
Have you ever needed **a lot** of logic gates in a cube? This is the tool for you!

![](https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExNGJlMXE4bXl0NXNyemp4ZGM4ZGFoc2lzazZqMTNnc3IwaXVweXA3YSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/3NEm5yO91VaoXUi0qA/giphy.gif)

## One Tick Hammer
You can hit a fast logic gate with a hammer to pulse it for one tick.

![](https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExbDR1NmY1MnVja3Zsbm94MnJ3OGVndjZvYjVibTUwbG1vZzVqbDAzcCZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/JuiP8UJhrinbzLtztC/giphy.gif)

## Colored Connection Dots
You can change the connection dot color of fast logic gates to allow for better clarity within your circuits.

![](https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExNzhqemVjb3hqdGxiZXB2dXVseXZtMWxib2t4cDI1ZHdwMTZibHFzbSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/2QWxev1dP3207uun4p/giphy.gif)

# Useful Links:
* [Discord](https://discord.gg/9NwK65xe2G)
* [Steam](https://steamcommunity.com/sharedfiles/filedetails/?id=3100500975)
