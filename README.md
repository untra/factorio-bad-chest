Adds a Blueprint Deployer chest which can be connected to the circuit network to build a self-expanding factory.

Example commands:

![Construction robot = 1](http://davemcw.com/factorio/images/construction-robot_1.jpg)

Deploy blueprint. Construction robot signal can be any value ≥ 1.

---

![Construction robot = 2](http://davemcw.com/factorio/images/construction-robot_2.jpg)

Deploy blueprint from book. Construction robot signal selects which blueprint to use.  If it is greater than the size of the book, the active blueprint is used instead.

---

![Deconstruction planner = -1](http://davemcw.com/factorio/images/deconstruction-planner_-1.jpg)

Deconstruct area. W = width, H = height.  The deployer chest will never deconstruct itself with this command.

---

![Deconstruction planner = 1](http://davemcw.com/factorio/images/deconstruction-planner_1.jpg)

Cancel deconstruction in area.

---

![Deconstruction planner = -2](http://davemcw.com/factorio/images/deconstruction-planner_-2.jpg)

Deconstruct the deployer chest.

---

X and Y signals shift the position of the construction/deconstruction order.

R signal rotates the blueprint. R = 1 = 90° clockwise, R = 2 = 180°, R = 3 = 90° counterclockwise.

branch 3

Blueprints are centered on: 1) The first wooden chest in the blueprint, 2) The first deployer chest in the blueprint, 3) The center of the blueprint.
