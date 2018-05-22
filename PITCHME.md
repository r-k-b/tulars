_doc status: pre-pre-alpha_

# Why?

Note:
Friend was developing a game (think FTL × The Sims?), having trouble getting the NPCs to behave sensibly.

They'd taken a kind of Finite State Machine / Pushdown Automata approach.

---

## The trouble with Finite State Machines

Note:
Trouble with FSM though, is the scaling problem ― for each extra state, if you want the NPCs to be able
to react in a lifelike way in varied circumstances, then you need many, many transitions between those
states.

And you need to consider of each of those many transitions.

---

## Here's a contrived example

```
🔥       🚒                       😦
                               🍖
```

Note:
There's a fire raging! I want to put it out, but I don't have an extinguisher! I will push "put out
the fire" onto the stack, then push "get an extinguisher" onto the stack.

+++

## Soo Hungery... but fire bad!

```
🔥       🚒                    😦
                               🍖
```

Note:
On my way to get the extinguisher, I pass by a pile of snacks. I am _starving to death_, it'll be a long while
before I can get more food and I'll need to eat something as soon as I'm done fighting the fire, but there's
no transition between the state "Go get an extinguisher" and the state "Grab the food that's in reach right 
now". 

+++

## Dealing with the fire

```
🔥🚒😦
                               🍖
```

Note:
So, I pass by the food, grab the extinguisher, then go the fire & put it out. Now with that dealt with,
I'm free to go all the way back to the snacks, if I don't _die of hunger_ before then, or something slightly
more important pops up.

+++

## Oh no... starved to death...

```
☁🚒      😱
                               🍖
```

Note:
Is there a better way?

---

## Utility Theory to the rescue!

_"Maximising Expected Utility"_

Note:
UT doesn't have a stack, or even an historical state; it's evaluated moment-by-moment.
So as the poor soul from the prior example passes by the snacks, even though snack-grabbing is in general
less important than putting out fires, because it's so "cheap" to grab the snacks, they will pocket it
on the way.

---

## Wait, what?


(Quick glossary of terms here: actions, considerations, outcomes, normalisation, weighting)

---

_tba_

Note:
Something else that UT helps with is doing more than one thing at a time - in the simplest case, we just pick
the action with the highest weight, and do that. 
But, we still have the list of normalised actions, right? And we can walk and talk at the same time, yeah?
So we still have the top action, but we can filter the list down to, say, actions whose outcomes we can do
at the same time as the top action, take the top action from that list, then do that thing as well. 

---

A good place to start in the code might be [`getConsiderationRawValue`](https://github.com/r-k-b/tulars/blob/master/app/UtilityFunctions.elm#L151) - of all the steps, we won't get far unless we can
convert every consideration into a number. `getConsiderationRawValue` allows us to take the "`input`"
union type property of a Consideration, examine the relevant state in the model, and return a number.

---

Visual representation of some utility functions: [desmos.com/calculator/ubiswoml1r](https://www.desmos.com/calculator/ubiswoml1r)

---
(later: [`isMovementAction`](https://github.com/r-k-b/tulars/blob/master/app/UtilityFunctions.elm#L280))

---

[Good talk on UT in games](https://www.gdcvault.com/play/1012410/Improving-AI-Decision-Modeling-Through) 

@22m29s: 

> Don't simply process 1 action at a time
> - Should I attack?
> - Should I reload?
> - Should I heal?
> - Should I have a beer?
> 
> Compare all potential actions to **each other**
> - Of all the things I could do, which is the most important at this moment?
