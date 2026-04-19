## BoatSimulator

**A Java-based game meant to improve both my Java and naval skills alike in the game Sea of Thieves.**

This project takes much inspiration from the game *Sea of Thieves* (Rare LTD, 2018), incorporating many time constants from it and 2 images (the boat, from the game itself, and the wheel from the .svg loading icon from [the website](https://seaofthieves.com/)). Its goal is to be as accurate as possible to give an offline experience of player vs. player naval combat for purposes of on-the-go practice.

[kilt-graphics](https://github.com/mac-comp127/kilt-graphics/blob/main/README.md) lies at the heart of the project, making it streamlined and nice to work with.

Sloop outline credits: <https://www.seaofthieves.com/community/forums/topic/30448/5-ship-types-for-sea-of-thieves-speculation-graphic/92>

## Gameplay Tweaks / Quality of Life Features

Since this is a simulation of a game, there are some tweaks that are made to make the experience a little more fluid. Below they are listed out:

1.  The cannoneer knows exactly how far their cannon reaches and will preemptively adjust the closest cannon to the target when they don't have an angle

2.  Repairing cannot be interrupted by cannons (this may change later)

3.  Supplies can be gotten instantaneously

4.  No storms (this may change later)

5.  Exact level of water is shown in the ship

6.  All action areas are placed in 3 main zones: 3 main 'zones': upper deck, mid-deck, and lower deck / bilge

7.  An action done in the same area as a previous one has minimal transition time)

### Actions

\*~~Strike-through~~ means not implemented

| Action | Location | Rate | Source | Can Other Actions be Done During it? | Is Progress Retained When Cancelled Halfway of action starting to being 100% finished (i.e. water barrel being all the way empty to full, sails being all the way up to down)? |
|------------|------------|------------|------------|------------|------------|
| Turn wheel | Upper deck | {From center to extreme} 3.041 seconds; 118.38º/sec | Testing in-game | No | Left at exact state |
| ~~Repair wheel~~ | ~~Upper deck~~ |  |  | ~~No~~ | ~~Not saved~~ |
| Lower sails | Upper deck | {From 0 to 100%} |  | No | Left at exact state |
| Raise sails | Upper deck | {From 100% to 0%} |  | No | Left at exact state |
| Adjust sails | Upper deck | {From center to extreme} |  | No | Left at exact state |
| Raise mast (when fallen) | Upper deck |  |  | No | Partially {depletes at} \_\_\_ /second |
| Drop anchor | Upper deck | {Anchor prompt} 0.5 seconds; {Anchor dropping} 4 seconds; -180º/s | Testing in-game | Yes | No |
| Raise anchor | Upper deck |  |  | No | Partially {depletes at} \_\_\_ /second |
| ~~Repair anchor~~ | ~~Upper deck~~ |  |  | ~~No~~ | ~~Not saved~~ |
| Cannon (= reload and fire cannon) | Mid-deck | {Reload} 1.6s; {Fire} 0.4s | Sea of Thieves Youtube Video analysis | No | Partially, have to have it loaded to save progress |
| Patch mast (= patch all the mast holes) | Mid-deck |  |  | No | Partially, have to patch at least 1-2 holes to save progress |
| ~~Harpoon player~~ | ~~Main deck~~ |  |  |  | ~~Complete in 1-shot~~ |
| ~~Reel ship in w/ harpoon~~ | ~~Main deck~~ |  |  |  | ~~Left at exact state~~ |
| ~~Harpoon turn (= fire harpoon + reel)~~ | ~~Main deck~~ |  |  |  | ~~Left at exact state~~ |
| ~~Access cannonball barrel~~ | ~~Main deck~~ |  |  |  | ~~Complete in 1-shot (see feature #7 above)~~ |
| Bucket water (=get water and bail it) | Lower / mid-deck |  |  | No | Partially |
| ~~Get ammo~~ | ~~Mid-deck~~ |  |  | ~~No~~ | ~~Complete in 1-shot~~ |
| ~~Close window~~ | ~~Mid-deck~~ |  |  | ~~No~~ | ~~Not saved~~ |
| ~~Detach rowboat~~ | ~~Mid-deck~~ |  |  | ~~No~~ | ~~Not saved~~ |
| Patch tier n hull | Lower / mid-deck |  |  | No | Not saved |
| ~~Take water from water barrel~~ | ~~Lower deck~~ |  |  | ~~No~~ | Not saved |
| ~~Refill water barrel (=pour water in repeatedly)~~ | ~~Lower deck~~ |  |  | ~~No~~ | Partially |
| ~~Access wood barrel~~ | ~~Lower deck~~ |  |  | ~~No~~ | ~~Complete in 1-shot (see feature #7 above)~~ |
| ~~Access food barrel~~ | ~~Lower deck~~ |  |  | ~~No~~ | ~~Complete in 1-shot (see feature #7 above)~~ |
| ~~Sleep~~ | ~~Lower deck~~ |  |  |  | ~~Partially~~ |
| ~~Cook food (=put on stove and wait until done)~~ | ~~Lower deck~~ |  |  | ~~Yes~~ | ~~Partially, fish has \~10 seconds of being done to have progress saved~~ |
| ~~Put out fire (= grab water from floor/barrel and throw water repeatedly)~~ | ~~Upper/main/mid/lower decks~~ |  |  | ~~No~~ | ~~Partially~~ |
| ~~Kill skeletons (= fire weapon repeatedly)~~ | ~~Upper/main/mid decks~~ |  |  | ~~No~~ | ~~Partially~~ |
| ~~Snipe at other crew (=fire and reload gun and get more ammo every 5)~~ | ~~Upper/main/mid decks~~ |  |  |  | ~~No~~ |
| ~~Throw throwable at other crew~~ | ~~Upper/main/mid decks~~ |  |  |  | ~~Complete in 1-shot~~ |
| ~~Ladder guard boarder~~ | ~~Upper (maybe mid?) deck~~ |  |  | ~~No~~ | ~~No~~ |
| ~~Kill boarder~~ | ~~Upper/mid/lower decks~~ |  |  | ~~No~~ | ~~Partially, can damage boarder~~ |
| ~~Revive crewmate~~ | ~~Upper/mid/lower decks~~ |  |  | ~~No~~ | ~~No~~ |

: These are the actions that are assumed can be done by the player, along with their location and tested rate (completion by seconds). Included is the source of where the rate comes from.

### Other Constants

<https://www.youtube.com/shorts/7lccAB1Pavw>

Guy might have some stuff

|  |  |  |
|------------------------|------------------------|------------------------|
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
| When can bucket from mid-deck |  (how many buckets / what percentage of ship health) |  |

### Cannoning

There is no doubt that firing cannons is a core aspect of this simulation and so it is important that it is at least addressed individually.

#### Range

It is hard to say for certain how far cannons fire. However, from testing in-game, it seems like a quarter of a square is the maximum range (to be tested further). This was done by firing at a sea fort and back the boat up until the cannons just barely would hit the side of island.

#### Probability of Hitting

This simulation doesn't let the user aim the cannons themselves, instead opting for prediction-based aiming with randomness involved as explained later. It is difficult to say what the actual probability of hitting an enemy ship by distance the whole player population has and difficult to test so the following base probabilities are made to make the simulation itself to be complete-able (not too low so that neither boat can put multiple holes in the other) but challenging (not too high so any naval position comes down to who is luckier instead of who is able to outmaneuver the other).

These probabilities are then changed by the following factors:

1.  ~~'Dialed in' factor~~

> When someone is dialed in on the cannons, it means that they know what angle to aim the cannon at to hit the opposing ship. Because of this, the simulator includes this as a bonus to hit: if the cannons just landed, the next cannon has an increased chance to land by 10 percentage points; if it hits twice consecutively, it is 20 percentage points; if it 3 or more times, it is 30%

2.  ~~Wave bounce~~ (as of now, not implemented, but will be in the future)

> Waves bounce the ship up and down a lot, especially when you are going against them. When it is particularly rocky, it is hard to aim the cannons and fire them at the angle you want. Therefore, since waves go from NW to SE, the following formula is used: $\text{OverallProbability} \times 0.4\left|\text{ShipHeading} \cdot \text{SE-NW} \right|$

3.  ~~Crew experience~~

> More experienced cannoneers can get dialed in more easily and know how to deal with waves better, albeit not perfectly. Crew experience multiplies / divides them respectively by a constant determined on the "experience level".

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

-   ~~Others: Firework / Signal flare / Pet~~

-   ~~Player~~

### Other Items

-   ~~Rowboat types (Harpoon, cannon, keg)~~
-   ~~Keg types (regular, stronghold, Athena, smuggler's)~~
-   ~~Horn of Fair Winds~~
-   ~~Cannon of Rage~~
-   ~~Skeletons on boat (Bonecaller, Reaper's chest seal)~~
-   ~~The Burning Blade~~

World

-   ~~Megaladon variants~~

-   ~~Storm~~

-   ~~Skeleton ship variants~~

-   ~~Ghost ship haunting~~
