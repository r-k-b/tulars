_doc status: pre-pre-alpha_

# Why?

Friend was developing a game (think FTL × The Sims?), having trouble getting the NPCs to behave sensibly.

They'd taken a kind of Finite State Machine / Pushdown Automata approach.

Trouble with FSM though, is the scaling problem ― for each extra state, if you want the NPCs to be able
to react in a lifelike way in varied circumstances, then you need many, many transitions between those
states.

And you need to consider of each of those many transitions.

Here's a contrived example:
There's a fire raging! I want to put it out, but I don't have an extinguisher! I will push "put out
the fire" onto the stack, then push "get an extinguisher" onto the stack.
On my way to get the extinguisher, I pass by a pile of snacks. I am starving to death, it'll be a long while
before I can get more food and I'll need to eat something as soon as I'm done fighting the fire, but there's
no transition between the state "Go get an extinguisher" and the state "Grab the food that's in reach right 
now". So, I pass by the food, grab the extinguisher, then go the fire & put it out. Now with that dealt with,
I'm free to go all the way back to the snacks, if I don't die of hunger before then, or something slightly
more important pops up.


Is there a better way?

Utility Theory to the rescue!

UT doesn't have a stack, or even an historical state; it's evaluated moment-by-moment.
So as the poor soul from the prior example passes by the snacks, even though snack-grabbing is in general
less important than putting out fires, because it's so "cheap" to grab the snacks, they will pocket it
on the way.

(Quick glossary of terms here: actions, considerations, outcomes, normalisation, weighting)

Something else that UT helps with is doing more than one thing at a time - in the simplest case, we just pick
the action with the highest weight, and do that. 
But, we still have the list of normalised actions, right? And we can walk and talk at the same time, yeah?
So we still have the top action, but we can filter the list down to, say, actions whose outcomes we can do
at the same time as the top action, take the top action from that list, then do that thing as well. 

---
