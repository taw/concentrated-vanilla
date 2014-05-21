----------------------------------------------
Mediaval 2 Total War: "Sinuhet's Battle Mechanics" modification by Sinuhet/Pavel Vesely

Copyright (C) 2007  Pavel Vesely 
This original project is not an open source, it is a freeware - you can use freely all files included as you want 
for your personal use only. To release in public the officially published version of this mod or any part of it, 
that is originally developed by me (and it doesn't matter if un-modified or modified) is possible only after my 
written permission.
  
Version 5.0 - Creation Date: December 2, 2007, Release Date: December 2, 2007

This software was originally developed for the Total War Center's community in an effort to enhance its MTW2 
gameplay experience. 

Description and Using Medieval Total War 2: "Sinuhet's Battle Mechanics"
-------------------------------------------------------------------------
This mod is a modification of 4 original files from MTW2: "descr_formations_ai.txt", "config_ai_batle.xml", 
"descr_formations.txt" and "descr_battle_map_movement_modifiers.txt", and also reformated "battle_config.xml" file 
is included. These files define the way in which the AI creates group formations of units in the battles, some 
features of the battle AI, Human Player formations and speed of units in respective types of terrain. They were 
expanded and tweaked for more challenging AI and more variety of the AI behaviour during the battles. Don't be afraid 
of any irreversible damages of your game's installation by implementing of this mod - you can simply remove it at 
any moment by copy/paste of your original archived files. 

This version has been developed and thoroughly tested on the MTW2 1.2 platform (official patch 1.2), but it should 
be fully functional with leaked MTW2 1.2 pre-patch too eventually. 

This mod should be fully saved-game friendly, but nothing is ever 100%, so use only the archived games to be sure you 
don't lost any information.   

As for a more detailed information on the changes compared to the original vanilla see the below sections and mainly 
the subforum in the www.twcenter.net web site. 


The key features:
-----------------
This is next step of battle mechanics, that have introduced in version 4.0 the various attack formations for MTW2 platform 
in such manner like it was in RTW. Many modders has claimed that they had created a set of different attack formations 
for MTW2, but thsi formations have not been used in game, because the engine have use them only in the deployment phase 
of the battle, and from the start of the battle, only one of them was used in every case. 
However, this new feature is revolutionary for the MTW2 game engine to such extent that the apparent new bug in the game's 
hard-code is de-masqued, as compared with the RTW engine. I have been trying to find out any solution for avoiding the bug 
caused by introducing the set of new attack formations for MTW2 engine, which is causing passive defensive AI formations. 
However, I have not been sucessful in this my effort, so the better attack is on cost of more passive AI defense also in 
version 5.0 of my AI formations for MTW2.

With this technological break-through, I have been able to introduce the fully functioning attack formations of mine 
from RTW platform, including the so called "small ones". The impact on the gameplay in battles is huge, in my opinion, 
compared to vanilla, and also as compared with all other formation's battle mechanics released to-date. There is one 
exception - CA has decided to remove "pursuing" formations from MTW2, so my small pursuing formations from RTW cannot 
be used, and the cavalry is a bit less flanking than in RTW with my formations from this reason. Nevertheless, you will 
have a lot of work to cope with e.g. Mongolian cavalry also in MTW2 with this new AI formations. 

The key features of this version of my AI formations for MTW2 are as follows:
- modified the original "Triple line" AI formation template by CA to be able to define various attack formations as 
explained above ... There are two new faction specific historical formations in version 5.0: 
 Byzantine formation for byzantium, and Crescent formation for turks, egypt and moors 
- included and partially modified almost all my "RTW formations" for open battles, siege and bridge battles and small 
formations where applicable (i.e without "pursue" ones) from version 7.0 of my RTW AI formations project. By this way 
I am introducing also on the MTW2 platform the AI formations of the 3rd generation (i.e. the ones which dont change 
only placements of units for respective factions, but they are changing the functionality of the units and the whole 
battle dynamics (as for the theory to this look at the respective threads to the RTW project in TW center forum).
- redefined also several "formation independent" settings in "config_ai_batle.xml", which create overly more aggresive 
AI behaviour during battles. It was very difficult to find out only the several ones from the huge number of all 
possible combinations of parameters, the results are relativelly optimal, but I dont state that still better settings
of these or some others parameters in this file doesnt exist. Altogether, they are a bit more enhanced compared to 
the vanilla or previous versions of this mod ... 
Quite concretely, the sending the archers forward to attack in each situation is diminished in version 5.0, but not 
entirely removed, because sometimes it is desired feature.
- included also new HP formations based on the ones, which I have developed already for MTW2 Demo - in fact it was 
the first modification for MTW2 platform ever released and it was released still before the full game official relase. 
In this newer version I ahve implemented two complex formations on the position 5 and 6 (two universal ones, the 1st is 
based on the CAs original tripple line form the AI fomrations, the 2nd one is in fact my own Universal Attack formations
from Open battle section of the AI formations version 3.0 ...)
- redefined the movement modifiers, another thing, that was developed for MTW2 Demo already - it is not something 
hugely original, but it is creating more variety compared to MTW2 vanilla, similarly to various MTW2 mods


Visit Total War Center's official thread of this mod, for information about updates or any questions.
If you are not still sure that you fully understand principles on which MTW2: "Sinuhet's Battle Mechanics" operates 
and if you are not sure you really need this changes, I recommend you not to use it at this stage.

----------------------------------------------
Licence Agreement:
----------------------------------------------
Terms of Use
This software is FREEWARE for owners of valid license of The Medieval 2 Total War software. 
This software is provided "as is", without any guarantee made as to its suitability or fitness for any particular use. 
It may contain bugs, so use of this tool is at your own risk. I take no responsibility for any damage that may 
unintentionally be caused through its use. 
I have verified it on a local system and partially also on a number of other users computers, but there is no way 
for me to be able to guarantee that it will work on each and every system configuration out there.

Copyright Notice
Pavel Vesely holds valid copyright on the Software, i.e. only the portions of the files "descr_formations_ai.txt", 
"config_ai_batle.xml", "descr_formations.txt" and "descr_battle_map_movement_modifiers.txt" originally designed 
and modified by Sinuhet/Pavel Vesely and the way how to use them via hexediting the names in "data" packs. 
The original portions of the file are part of The Mediaval II Total War software - property of:
Total War Software © 2002 - 2006 The Creative Assembly Limited. Total War, Mediaval II:Total War and the Total War 
logo are trademarks or registered trademarks of The Creative Assembly Limited in the United Kingdom and/or other countries. 
Published by SEGA. All rights reserved. 
Nothing in this agreement constitutes a waiver of any rights under U.S. Copyright law or any other federal or state law.

----------------------------------------------
Installation Instructions:
----------------------------------------------
1. Copy all 5 files from SBM 5.0/data folder to <root folder of your MTW2>/data, or alternativelly to the "your mod"/Data/ 
subfolder.
2. If you dont use them included in "your mod", you need to install these 5 files via "file_first" option in cfg file or 
via -mod mymod switch or ShellShocks MedManager - it is all possible and should be fully functional, but I personally 
prefer the "hexediting" of the data pack (you can do it also for conveniance via MedBattleSelector program by ShellShock) 
because of the theoretical best performance  .... Feel free to install it in your preferred way ...
3. You can freely combine this mod with parts of the Battle mechanics by other authors - if you use only the files, which 
are not included in this my mod, you can obtain very interesting combo without any lost of the functionality of my 
project .... You can combine it with the parts of the same files too for your personal usage, but be careful in this, 
because you must know exactly what you are doing. The game is very sensitive on these files, and you could create hidden
CTDs by this way. Again, you can do this, but you must know exactly what is the respective part of the code for ...

------------------------------------------------------------
The Most Important Changes\ Update Log of previous versions:
------------------------------------------------------------
12/16/2006, version 1.0 - original version
7/6/2007, version 2.0, for MTW2 with patch 1.2 only
7/8/2007, version 3.0, merged the main principle of the version 1.0 (mutually independent formations for attack and 
defence) and functionality in defence of the version 2.0 (via a lot of my own formations migrated from RTW platform)
9/15/2007, released version 4.0, which introduced various attack AI formations used indeed by the MTW2 engine

----------------------------------------------
Known limitations:
----------------------------------------------
Naturally, this mod is incompatible with other mods of the "descr_formations_ai.txt", "config_ai_batle.xml", 
"battle_config.xml", "descr_formations.txt" and "descr_battle_map_movement_modifiers.txt" files or mods, which have 
these mods incorporated. Otherwise no incompatibility issues are known in this stage of the development. However, it 
has not been systematically tested with all available mods for MTW2 1.2. 

----------------------------------------------
If you encounter problems, please visit http://www.twcenter.net and download the latest version to see if the issue has
 been resolved. 
If not, please send a bug report to: seshat@seznam.cz

If you feel you have any suggestions that could make this software better please feel free to contact me with your
 suggestion.

----------------------------------------------
The Mediavel II Total War software is property of:
Total War Software © 2002 - 2006 The Creative Assembly Limited. Total War, Mediaval II:Total War and the Total War logo 
are trademarks or registered trademarks of The Creative Assembly Limited in the United Kingdom and/or other countries. 
Published by SEGA. All rights reserved. 
----------------------------------------------
All trademarked names mentioned in this document and SOFTWARE are used for editorial purposes only, with no intention 
of infringing upon the trademarks.

