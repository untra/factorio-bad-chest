
Digitizer Combinator can connect to various other devices to give more advanced circuit behaviors.

* Blueprint deployer
* Train Stop


### Blueprint Deployer

Commands are sent on `signal-blue` and work directly on a lone blueprint.
Write variant where supported with `signal-white`=1 by sending output signal as input

Resered Commands:
* Ignore
  * `blueprint`
  * `blueprint-book`
* Abort
  * `construction-robot`
  * `deconstruction-planner`

|Command|Input|Output
|-
|BoM|2|2 item signals needed to build
|Stats|3|3:Print Stats E:#entities T:#tiles I:#icons L:#label
|Icons|4 I=icon index|4 I=icon index, icon signal=1
|Tiles|5 T=tile index|5 T=tile index, X,Y, tile signal=1
|Entities|6 E=entity number|6 E=enity number, X,Y,D, entity signal=1, R=recipe index, C=#connections, F=#filters?
|Blueprint Name|7|7 A-Z0-9=Binary Encoded Print name. LSB is leftmost character
|Entity Connections|?|? E=entity number,C=local port,R=remote entity,P=remote connection port,red or green wire=connection number
|Entity Filters|?|? E=entity number, signals=filters
