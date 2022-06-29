linkage-tests
=============

This is an effort to take some node-linking features built upon a very crude editor
([ancient video](https://www.youtube.com/watch?v=lt3vg573PKQ)) and make some major
improvements to them.

The previous implementation was quite monolithic, so this is first and foremost an
attempt to break up the node-linking logic into more manageable and logical modules,
along with some of the helpers that go with it. This includes a far saner way of
specifying pairing interfaces, especially defaults (although the more general cases
still need some work); an iteration on node patterns; and much more.

Some things are not yet fully implemented or need another pass: undo-redo; saving and
loading of linkage, including for "generated" (terrible nomenclature, but the alternatives
all seem to be ambiguous...) links, i.e. those belonging to nodes allowing multiple
in- and / or out-links (with corresponding UI demands). One of the tests is a half-done
shader graph: until just recently, it lacked `graphics.undefineEffect()`.

On that note, the `tests` folders contain a number of things. These include quite a
battery to hammer out a fancy `drag` module; stuff for the node-linking "runner" and
its helper modules (**link\_connection** is has more or less obsolete; much of what
it did has been incorporated into the node runner itself). There is also an editor
WIP, in part trying to recreate some features in the video above, but mostly meant
to stress-test all of these things put together. It also includes an "edit-this-object"
scene, although somewhat basic.

A newer video discussing some of this may be found [here](https://www.youtube.com/watch?v=qolJXXjtWK8).

---

I don't remember why there are three iterations of the project, so I'm just including
them all, and will perhaps sort them out later. In any case, I've only really looked
at **LINKAGE_TESTING3** lately.

Also, right now this project simply inlines several of my submodules, and is probably
horribly out of sync with them in some ways, in particular **solar2d_ui**. I should
obviously rectify this at some point.
