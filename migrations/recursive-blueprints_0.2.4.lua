for i, force in pairs(game.forces) do 
 force.reset_recipes()
 force.reset_technologies()
 force.recipes["blueprint-digitizer"].enabled = force.technologies["recursive-blueprints"].researched
end