
Digitizer Combinator can connect to various other devices to give more advanced circuit behaviors.

* Blueprint deployer
* Train Stop


### Blueprint Deployer

Commands are sent on `signal-blue` and work directly on a lone blueprint.
Write variant where supported with `signal-white`=1 by sending output signal as input

Reserved Commands:
* Ignore
  * `blueprint`
  * `blueprint-book`
* Abort
  * `construction-robot`
  * `deconstruction-planner`

|Command| ID |Input|Output|
|-------|----|-----|------|
|BoM|2||item signals needed to build
|Stats|3||E:#entities T:#tiles I:#icons L:#label
|Icons|4|I=icon index|I=icon index, icon signal=1
|Tiles|5|T=tile index|T=tile index, X,Y, tile signal=1
|Entities|6|E=entity number|E=enity number, X,Y,D, entity signal=1, R=recipe index, C=#connections, F=#filters?
|Blueprint Name|7||A-Z0-9=Print name bitstring. LSB is leftmost character
|Entity Connections|?||E=entity index,C=local port,R=remote entity,P=remote port,red or green wire=connection number
|Entity Filters|?|E=entity index|E=entity index, signals=filters
