## BoatSimulator

**A Java-based game meant to improve both my Java and naval skills alike in the game Sea of Thieves.**

This project takes much inspiration from the game *Sea of Thieves* (Rare LTD, 2018), incorporating many time constants from it and 2 images (the boat, from the game itself, and the wheel from the .svg loading icon from [the website](https://seaofthieves.com/)). Its goal is to be as accurate as possible to give an offline experience of player vs. player naval combat for purposes of on-the-go practice.

[kilt-graphics](https://github.com/mac-comp127/kilt-graphics/blob/main/README.md) lies at the heart of the project, making it streamlined and nice to work with.

Sloop outline credits: <https://www.seaofthieves.com/community/forums/topic/30448/5-ship-types-for-sea-of-thieves-speculation-graphic/92>

## Assumptions

Since this is a simulation of a game, there are many assumptions are made; not just in the logic, but also in the constants that govern the game (i.e. the time it takes for actions to be done, the rate at which tasks are completed, and all speed aspects of the game). Below are of the assumptions listed out:

### Gameplay Assumptions

1.  There are 2 people per boat (may change in a custom mode)

    -   The 2 people start at their respective positions (at the upper deck and at the mid-deck)

2.  The helmsman (the one steering the boat) is the one who does all of the actions

3.  When one action is being done, another action cannot be carried out

4.  It takes time to run to and from the activity areas because they are in different spots

    -   There are 3 main 'zones': upper deck, mid-deck, and lower deck / bilge.

    -   Include image with arrows pointing on the sloop

        -   Screenshot from almost in front of quested table looking towards the stairs with arrow pointed diagonally up and to the right with "upper deck", arrow pointed to the left more level with "main-deck", arrow pointing down to the left with "lower deck", arrow pointing behind with "mid-deck"

5.  Any action done within the same area as the one previous one can be done with negligible transition time between.

6.  The crew have storage crates filled to the brim with their needed resource and are very quick at retrieving from them (aka there is no need to get more wood or cannonballs; *may change with future additions*)

7.  The crew are experts at dodging cannonballs / are very lucky (aka the crew cannot die, be interrupted during an action, nor need to eat to heal; *may change with future additions*)

8.  The crew only keeps to the ship and do not try to board (*may change with future additions*)

9.  The closer the cannoneer is, the more they are able to hit the other ship accurately

10. The moment a ship enters their effective range the cannoneer knows and attempts to fire a cannon

11. There are 5 parts of the ship that can be damaged: the mast, the port side, the starboard side, the bow, and the stern (*wheel and anchor may be added in the future*).

    -   Each part of the ship has its own capacity of holes that can be opened up and after that capacity is reached no more holes can be opened up until 1 is repaired

12. When the anchor is down, the ship cannot be moved

13. Dropping the anchor when you have a good amount of momentum and the wheel is turned at least a quarter, the ship will rotate quickly

    -   The rate of rotation and total rotational is proportional to how much the wheel is turned and how fast the ship was moving. An empirical formula will be made and included

14. The ship reaches its maximum velocity when the ship is going parallel (with $\pm$ 15º of leeway) with the wind and the sail is fully lowered

    1.  At every value the sail can have, depending on how the ship is travelling with the wind, the ship has a velocity that it accelerates / decelerates to (there is a cap)

15. The ship has an acceleration constant that is static (*may change with future additions*)

16. The ship has a deceleration / friction constant that is static (*may change with future additions*)

17. The sail automatically adjusts itself to get the most amount of billow (*may change with future additions*)

18. The mast will fall if a cannon hits it and it already has 2 or 3 holes in it OR if the player tries to lower the sails when it has 3 holes in it

    -   The mast can be caught by raising the sails

19. The ship sinks instantly when it is filled with enough water

20. If a tier n hole in the hull is repaired, when it's broken again, a tier n+1 hole will appear (capping at 4)

21. Neither boats have cannon rowboats attached (*could be a cool add-on*)

22. The boats do not fight in storms

23. It's open-water, not hourglass

### Actions

\*~~Strike-through~~ means not implemented

| Action | Location | Rate | Source | Can Other Actions be Done During it? |
|---------------|---------------|---------------|---------------|---------------|
| Turn wheel | Upper deck | {From center to extreme} 3.041 seconds; 118.38º/sec | Testing in-game | No |
| ~~Repair wheel~~ | ~~Upper deck~~ |  |  | ~~No~~ |
| Lower sails | Upper deck | {From 0 to 100%} |  | No |
| Raise sails | Upper deck | {From 100% to 0%} |  | No |
| ~~Adjust sails~~ | ~~Upper deck~~ | {From center to extreme} |  | ~~No~~ |
| Raise mast (when fallen) | Upper deck |  |  | No |
| Drop anchor | Upper deck | {Anchor prompt} 0.5 seconds; {Anchor dropping} 4 seconds; -180º/s | Testing in-game | Yes |
| Raise anchor | Upper deck |  |  | No |
| ~~Repair anchor~~ | ~~Upper deck~~ |  |  | ~~No~~ |
| Reload + Fire cannon | Mid-deck | {Reload} 1.6s; {Fire} 0.4s | Sea of Thieves Youtube Video analysis | No |
| Patch mast | Mid-deck |  |  | No |
| ~~Harpoon loot / player / reel ship in / rapidly adjust angle~~ | ~~Main deck~~ |  |  |  |
| ~~Access cannonball barrel~~ | ~~Main deck~~ |  |  |  |
| Bucket water | Lower / mid-deck |  |  | No |
| Throw water | Mid-deck |  |  | No |
| ~~Get ammo~~ | ~~Mid-deck~~ |  |  | ~~No~~ |
| ~~Close window~~ | ~~Mid-deck~~ |  |  | ~~No~~ |
| ~~Detach rowboat~~ | ~~Mid-deck~~ |  |  | ~~No~~ |
| Patch tier n hull | Lower / mid-deck |  |  | No |
| ~~Take water from water barrel~~ | ~~Lower deck~~ |  |  | ~~No~~ |
| ~~Refill water barrel~~ | ~~Lower deck~~ |  |  | ~~No~~ |
| ~~Access wood barrel~~ | ~~Lower deck~~ |  |  | ~~No~~ |
| ~~Access food barrel~~ | ~~Lower deck~~ |  |  | ~~No~~ |
| ~~Sleep~~ | ~~Lower deck~~ |  |  |  |
| ~~Cook food~~ | ~~Lower deck~~ |  |  | ~~Yes~~ |
| ~~Put out fire~~ | ~~Upper/main/mid/lower decks~~ |  |  | ~~No~~ |
| ~~Kill skeletons~~ | ~~Upper/main/mid decks~~ |  |  | ~~No~~ |
| ~~Snipe at other crew~~ | ~~Upper/main/mid decks~~ |  |  |  |
| ~~Throw throwables at other crew~~ | ~~Upper/main/mid decks~~ |  |  |  |
| ~~Ladder guard boarder~~ | ~~Upper (maybe mid?) deck~~ |  |  | ~~No~~ |
| ~~Kill boarder~~ | ~~Upper/mid/lower decks~~ |  |  | ~~No~~ |
| ~~Revive crewmate~~ | ~~Upper/mid/lower decks~~ |  |  | ~~No~~ |

: These are the actions that are assumed can be done by the player, along with their location and tested rate (completion by seconds). Included is the source of where the rate comes from.

### Other Constants

<https://www.youtube.com/shorts/7lccAB1Pavw>

Guy might have some stuff

|  |  |  |
|----------------------------------|-------------------|-------------------|
| **Constant** | **Value** | **Source** |
| Ship acceleration |  |  |
| Ship deceleration (from raising sails) |  |  |
| Ship deceleration (from fully lowering anchor) |  |  |
| Ship max velocity w/ wind w/ waves |  |  |
| Ship max velocity w/ wind against waves |  |  |
| Ship max velocity w/ side-wind w/ waves |  |  |
| Ship max velocity w/ side-wind against waves |  |  |
| Ship max velocity against wind w/ waves | 0.01615grids/sec (1 min 1.9143secs per grid) | Testing in-game |
| Ship max velocity against wind against waves | 0.92735grids/sec (1 min 4.7002secs per grid) | Testing in-game |
| Ship rotational speed | \_\_\_ \* \|degrees wheel rotated\| |  |
| Wheel rotational speed with n damage | \_\_\_ \* \|degrees wheel rotated\| |  |
| Ship health | 67 buckets of seawater (57 for death groan) | Testing in-game |
| Tier 1 hull hole |  |  |
| Tier 2 hull hole |  |  |
| Tier 3 hull hole |  |  |
| Tier 4 hull hole |  |  |
| Tier 5 hull hole |  |  |
| Cannonball loading |  |  |
| Max cannonball range |  |  |
| Max cannon horizontal rotation | {Center to extreme} 22.5º | Testing in-game |
| Respawning from Ferry of the Damned | 10 seconds + 5 \* [Crew Size] | <https://www.seaofthieves.com/community/forums/topic/149197/new-respawn-times/3> |
| Grid size |  |  |

### Cannoning

There is no doubt that firing cannons is a core aspect of this simulation and so it is important that it is at least addressed individually.

#### Range

It is hard to say for certain how far cannons fire. However, from testing in-game, it seems like a quarter of a square is the maximum range (to be tested further). This was done by firing at a sea fort and back the boat up until the cannons just barely would hit the side of island.

#### Probability of Hitting

This simulation doesn't let the user aim the cannons themselves, instead opting for a model based on pure chance. It is difficult to say what the actual probability of hitting an enemy ship by distance the whole player population has and difficult to test so the following base probabilities are made to make the simulation itself to be complete-able (not too low so that neither boat can put multiple holes in the other) but challenging (not too high so any naval position comes down to who is luckier instead of who is able to outmaneuver the other).

These probabilities are then changed by the following factors:

1.  Ship spin

> Ship spin can be hard to deal with because the cannonballs curve with the ship, making them harder to hit a target. The more the ship spins, the more the cannons balls curve,

2.  'Dialed in' factor

> When someone is dialed in on the cannons, it means that they know what angle to aim the cannon at to hit the opposing ship. Because of this, the simulator includes this as a bonus to hit: if the cannons just landed, the next cannon has an increased chance to land by 10 percentage points; if it hits twice consecutively, it is 20 percentage points; if it 3 or more times, it is 30%

3.  ~~Wave bounce~~ (as of now, not implemented, but will be in the future)

> Waves bounce the ship up and down a lot, especially when you are going against them. When it is particularly rocky, it is hard to aim the cannons and fire them at the angle you want. Therefore, since waves go from NW to SE, the following formula is used: $\text{OverallProbability} \times 0.4\left|\text{ShipHeading} \cdot \text{SE-NW} \right|$

#### Ammo Types

If you have played *Sea of Thieves* before, you will know that there are a total of 8 ammo types. Below are the ones present in the game:

\*~~Strike-through~~ means not implemented

-   Cannonball

-   ~~Chainshot~~ (not implemented as of now, but later will be)

-   ~~Cursed cannonballs~~ (*may change with future additions*)

    -   Phantom cannonball (Implemented because functionally the same as regular ones)

    -   ~~Flame phantom cannonball~~

-   ~~Wraith ball~~ (*may change with future additions*)

-   ~~Scattershot~~ (*may change with future additions*)

-   ~~Hunting spear~~ (*may change with future additions*)

-   ~~Blunderbomb~~

-   ~~Firebomb~~ (*may change with future additions*)

-   ~~Bone caller~~ (*may change with future additions*)

-   ~~Firework / Signal flare~~

### Other Items

-   Rowboat types
-   Keg types
-   Horn of Fair Winds
-   Cannon of Rage
-   Skeletons on boat (Bonecaller, Reaper's chest seal)
-   The Burning Blade

World

-   Megaladon variants

-   Storm

-   Skeleton ship variants

-   Ghost ship haunting
