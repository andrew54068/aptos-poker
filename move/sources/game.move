module aptos_poker::game {
    use std::vector;
    use aptos_std::table::{Self, Table};
    use aptos_framework::signer;
    use aptos_poker::deck::{Self, Card, Deck};
    use aptos_poker::encryption::{Self, EncryptedValue};

    struct Game has key {
        players: vector<address>,
        deck: Deck,
        pot: EncryptedValue,
        current_turn: u8,
        community_cards: vector<Card>,
        player_hands: Table<address, vector<EncryptedValue>>,
        player_bets: Table<address, EncryptedValue>,
        state: u8,
    }

    const CREATED: u8 = 0;
    const REGISTRATION: u8 = 1;
    const SHUFFLE: u8 = 2;
    const DEAL: u8 = 3;
    const OPEN: u8 = 4;
    const COMPLETE: u8 = 5;
    const ERROR: u8 = 6;

    public fun create_game(creator: &signer) {
        let game = Game {
            players: vector::empty(),
            deck: deck::new(),
            pot: encryption::encrypt(0, 0),
            current_turn: 0,
            community_cards: vector::empty(),
            player_hands: table::new(),
            player_bets: table::new(),
            state: CREATED,
        };
        move_to(creator, game);
    }

    public fun register(game: &mut Game, player: &signer) {
        let player_address = signer::address_of(player);
        vector::push_back(&mut game.players, player_address);
        table::add(&mut game.player_hands, player_address, vector::empty());
        table::add(&mut game.player_bets, player_address, encryption::encrypt(0, 0));
        game.state = REGISTRATION;
    }

    public fun shuffle(game: &mut Game) {
        // TODO: Implement proper shuffle logic using curve_baby_jubjub
        game.state = SHUFFLE;
    }

    public fun deal_cards(game: &mut Game) {
        // TODO: Implement proper deal cards logic using curve_baby_jubjub
        game.state = DEAL;
    }

    public fun bet(game: &mut Game, player: &signer, amount: u64) {
        let player_address = signer::address_of(player);
        let current_bet = table::borrow(&game.player_bets, player_address);
        let new_bet = encryption::add(*current_bet, encryption::encrypt(amount, 0));
        *table::borrow_mut(&mut game.player_bets, player_address) = new_bet;
        game.pot = encryption::add(game.pot, encryption::encrypt(amount, 0));
    }

    public fun open_cards(game: &mut Game, player: &signer, card_indices: vector<u8>) {
        let _player_address = signer::address_of(player);
        let _num_cards_to_open = vector::length(&card_indices);
        // Implement open cards logic here
        // For now, we'll just change the game state
        game.state = OPEN;
    }

    public fun end_game(game: &mut Game) {
        game.state = COMPLETE;
    }

    public fun error(game: &mut Game) {
        game.state = ERROR;
    }
}