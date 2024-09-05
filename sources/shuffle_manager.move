use aptos_poker::bit_map::{Self, BitMap256};

struct Deck has store {
    config: u8,
    cards: vector<Card>,
    decrypt_record: vector<BitMap256>,
    cards_to_deal: BitMap256,
    player_to_deal: u64,
}

public fun create_shuffle_game(creator: &signer, num_players: u8): u64 acquires ShuffleManagerData {
    // ... existing code ...
    let new_game = Game {
        // ... other fields ...
        deck: Deck {
            config: 0, // Default config
            cards: vector::empty(),
            decrypt_record: vector::empty(),
            cards_to_deal: bit_map::empty(),
            player_to_deal: 0,
        },
        // ... other fields ...
    };
    // ... existing code ...
}

public fun get_decrypt_record(game_id: u64, card_idx: u64): BitMap256 acquires ShuffleManagerData {
    let shuffle_data = borrow_global<ShuffleManagerData>(@aptos_poker);
    assert!(game_id <= shuffle_data.largest_game_id, EINVALID_GAME_ID);
    let game = table::borrow(&shuffle_data.games, game_id);
    assert!(card_idx < vector::length(&game.deck.cards), EINVALID_CARD_INDEX);
    *vector::borrow(&game.deck.decrypt_record, card_idx)
}

// ... remaining code ...