Adds a Blueprint Deployer chest which can be connected to the circuit network to build a self-expanding factory.

The Blueprint Deployer recognizes the following signals:

* X,Y: Command Position, relative to itself
* deconstruction-planner=-1, W=width, H=height: Deconstruct area. Deployer will order deconstruction of the designated area centered around the command position. Deployer will not deconstruct itself with this command, even if it is in the covered area.
* deconstruction-planner=-2: Deconstruct self. Deployer will order it's own deconstruction.
* construction-robot=n: Deploy print. If the chest is holding a single blueprint, it will be deployed at the command position. If the chest is holding a blueprint book, the nth print from it will be deployed. To select the "active" print in a book, use a value greater than the main inventory size. The blueprint will be aligned such that the anchor position (search order: first wooden chest, first deployer, {0,0}) is on the command position.