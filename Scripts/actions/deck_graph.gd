extends RefCounted
class_name DeckGraph

enum DECKS {UPPER, MAIN, MID, LOWER}

# The decks that take on water.
const FLOODED_DECKS := [DECKS.MID, DECKS.LOWER]

# Universal per-deck fade/shrink schema: anything drawn on a lower deck
# is fainter and smaller. Used by crewmates and hole points alike.
const DECK_ALPHA := {
	DECKS.UPPER: 1.0,
	DECKS.MAIN: 0.85,
	DECKS.MID: 0.7,
	DECKS.LOWER: 0.55,
}
const DECK_SIZE_SCALE := {
	DECKS.UPPER: 1.0,
	DECKS.MAIN: 0.9,
	DECKS.MID: 0.8,
	DECKS.LOWER: 0.7,
}


static func is_valid_deck(deck: int) -> bool:

	return DECKS.values().has(deck)


static func get_deck_name(deck: int) -> String:

	return "%s Deck" % String(DECKS.find_key(deck)).capitalize()
