# The Hive — Not In v1

This is a **deferral** list, not a rejection list. Everything here was
considered and wanted. It is out of v1 so that v1 exists.

Check this before adding anything. If a request would build something on this
list, say so instead of building it.

---

## World and structure

1. **No continuous zoom between nest and surface.** Discrete transition by
   walking into an entrance.
2. **No day/night cycle, weather, or seasons.**
3. **No rival ant colonies.**
4. **No permanent surface map change** — worn paths, cleared obstacles.
5. **No roots, clay layers, or buried food** in the dirt. Soil, rock and air
   pockets only.
6. **No hard bedrock layer.** Depth-scaled dig time instead.

## Colony

7. **No satellite colonies or alates.** The v2 headline feature.
8. **No egg or pupa stages.** Larva to adult only.
9. **No larval caste choice.** Caste is assigned at birth from the ratio.
10. **No death by old age.**
11. **No nurse ants physically feeding larvae.** Larvae draw from the pool.
12. **No resource other than food.** No building material, no water.
13. **No hard population cap.** The ceiling emerges from food and map size.

## Player and control

14. **No soldier possession.** Workers only.
15. **No voluntary ant switching.** Auto-swap on death only.
16. **No follower squad.**
17. **No designation-based digging.** The other v2 headline feature.
18. **No fast-forward in the shipped build.** Pause only; 0.25x and 4x stay in
    the debug build.

## Enemies

19. **No second enemy type.** One worm.
20. **No enemy tunnelling.** Worms use existing tunnels and entrances.
21. **No environmental or spontaneous tunnel collapse.** Player-triggered only.

## Presentation

22. **No audio of any kind.**
23. **No walk-cycle animation.** Rigid sprites rotated to surface normals.
24. **No commissioned or final art.** Coloured shapes.
25. **No text anywhere.** Numbers only.
26. **No minimap.**
27. **No messenger ants.** Entrance glow is the only off-screen signal.

## Systems

28. **No pheromone type beyond FORAGE and ALARM.**
29. **No spoil as a player-facing economy.** Workers haul it in the background.
30. **No A\* pathfinding.** Gradient following plus the nest-distance field.
31. **No per-ant inspector UI, visible names, or stats screen.** The data
    exists; the interface does not.
32. **No corpses as food.**

## Meta

33. **No meta-progression, achievements, or run history.**
34. **No difficulty settings.** One curve, adjustable in `data/tuning.json`.
35. **No tutorial, and no menus beyond start and quit.**
36. **No Play Store release.** Sideloaded APK only.

---

## Held for v2

In rough priority order, if v0.5 turns out to be worth continuing:

1. Satellite colonies via alates
2. Designation-based digging
3. Messenger ants replacing entrance glow
4. Soldier possession
5. Audio
6. Enemy tunnelling and a second enemy type
7. Day/night and seasons
