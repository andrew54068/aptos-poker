module aptos_poker::shuffle_manager {
    use std::vector;
    use std::option::{Self, Option};
    use aptos_std::table::{Self, Table};
    use aptos_framework::signer;
    use aptos_framework::event;
    use aptos_poker::curve_baby_jubjub::{Self, Point};
    use aptos_poker::bit_map::{Self, BitMap256};

    // Constants
    const INVALID_INDEX: u64 = 999999;

    // Error codes
    const ENOT_GAME_OWNER: u64 = 1;
    const EINVALID_STATE: u64 = 2;
    const ENOT_YOUR_TURN: u64 = 3;
    const EINVALID_GAME_ID: u64 = 4;
    const EINVALID_CARD_INDEX: u64 = 5;
    const EGAME_FULL: u64 = 6;
    const EINVALID_PUBLIC_KEY: u64 = 7;
    const EWRONG_PLAYER_INDEX: u64 = 8;
    const EINVALID_PLAYER_ID: u64 = 9;
    const ENOT_ENOUGH_CARDS: u64 = 10;
    const EINVALID_DECK_TYPE: u64 = 11;
    const EINVALID_PROOF: u64 = 12;
    const ENOT_AUTHORIZED: u64 = 13;
    const ETIMEOUT: u64 = 14;
    const EGAME_ALREADY_STARTED: u64 = 15;
    const EGAME_NOT_RECOVERABLE: u64 = 16;
    const EINVALID_RECOVERY_ACTION: u64 = 17;
    const EGAME_NOT_ACTIVE: u64 = 18;
    const EINVALID_RECOVERY_ATTEMPT: u64 = 19;
    const EGAME_ALREADY_ENDED: u64 = 20;
    const EINVALID_CANCELLATION: u64 = 21;
    const EGAME_ALREADY_CANCELLED: u64 = 22;
    const EREFUND_FAILED: u64 = 23;

    // Structs
    struct ShuffleManagerData has key {
        games: Table<u64, Game>,
        largest_game_id: u64,
    }

    struct Game has store, drop {
        id: u64,
        owner: address,
        state: u8,
        players: vector<address>,
        signing_addrs: vector<address>,
        player_pks: vector<Point>,
        aggregate_pk: Point,
        current_player_index: u64,
        deck: Deck,
        nonce: u256,
        player_hands: vector<u64>,
        opening: u64,
        config: GameConfig,
        statistics: GameStatistics,
        last_action_time: u64,
        is_recoverable: bool,
        recovery_attempts: u8,
        is_cancelled: bool,
        refunded_players: vector<address>,
        refund_amounts: vector<u64>,
        result: Option<GameResult>,
    }

    struct Deck has store, drop {
        config: u8,
        cards: vector<Card>,
        decrypt_record: vector<BitMap256>,
        cards_to_deal: BitMap256,
        player_to_deal: u64,
        x0: vector<u256>,
        x1: vector<u256>,
        y0: vector<u256>,
        y1: vector<u256>,
        selector0: BitMap256,
        selector1: BitMap256,
    }

    struct Card has copy, drop, store {
        x0: u256,
        y0: u256,
        x1: u256,
        y1: u256,
    }

    struct GameConfig has copy, drop, store {
        num_players: u8,
        num_cards: u64,
        deck_type: u8,
    }

    struct GameStatistics has copy, drop, store {
        total_shuffles: u64,
        total_deals: u64,
        total_opens: u64,
    }

    struct GameResult has copy, drop, store {
        winner: address,
        final_scores: vector<u64>,
    }

    // Events
    #[event]
    struct PlayerTurnEvent has drop, store {
        game_id: u64,
        player_index: u64,
        state: u8,
    }

    #[event]
    struct PlayerTimeoutEvent has drop, store {
        game_id: u64,
        player_index: u64,
    }

    #[event]
    struct GameRecoveryEvent has drop, store {
        game_id: u64,
        recovery_action: u8,
    }

    #[event]
    struct GameRecoveryAttemptEvent has drop, store {
        game_id: u64,
        recovery_action: u8,
        success: bool,
    }

    #[event]
    struct GameCancellationEvent has drop, store {
        game_id: u64,
        reason: vector<u8>,
    }

    #[event]
    struct GameCancellationAndRefundEvent has drop, store {
        game_id: u64,
        reason: vector<u8>,
        refunded_players: vector<address>,
        refund_amounts: vector<u64>,
    }

    #[event]
    struct GameResultEvent has drop, store {
        game_id: u64,
        winner: address,
        final_scores: vector<u64>,
    }

    #[event]
    struct GameContractCalledEvent has drop, store {
        game_id: u64,
        action: vector<u8>,
        current_state: u8,
    }

    fun all_cards_dealt(game: &Game): bool {
        let total_cards = vector::length(&game.deck.cards);
        let dealt_cards = bit_map::member_count_up_to(&game.deck.cards_to_deal, total_cards);
        dealt_cards == total_cards
    }

    fun all_cards_opened(game: &Game): bool {
        let total_players = vector::length(&game.players);
        let total_cards = vector::length(&game.deck.cards);
        let i = 0;
        while (i < total_cards) {
            let decrypt_record = vector::borrow(&game.deck.decrypt_record, i);
            if (bit_map::member_count_up_to(decrypt_record, total_players) != total_players) {
                return false
            };
            i = i + 1;
        };
        true
    }

    // Add a new struct for the shuffle verifier
    struct ShuffleVerifier has key {
        deck52_enc_verifier: address,
        deck30_enc_verifier: address,
        deck5_enc_verifier: address,
        decrypt_verifier: address,
    }

    // Add a new struct for the game contract
    struct GameContract has key {
        address: address,
    }

    // Add a new struct for the verifier interface
    struct VerifierInterface has key {
        address: address,
    }

    // Update the initialize function to include the VerifierInterface
    public fun initialize(
        account: &signer,
        deck52_enc_verifier: address,
        deck30_enc_verifier: address,
        deck5_enc_verifier: address,
        decrypt_verifier: address,
        game_contract: address,
        verifier_interface: address
    ) {
        move_to(account, ShuffleManagerData {
            games: table::new(),
            largest_game_id: 0,
        });
        move_to(account, ShuffleVerifier {
            deck52_enc_verifier,
            deck30_enc_verifier,
            deck5_enc_verifier,
            decrypt_verifier,
        });
        move_to(account, GameContract {
            address: game_contract,
        });
        move_to(account, VerifierInterface {
            address: verifier_interface,
        });
    }

    public fun create_shuffle_game(creator: &signer, num_players: u8, deck_type: u8): u64 acquires ShuffleManagerData {
        let creator_addr = signer::address_of(creator);
        let shuffle_data = borrow_global_mut<ShuffleManagerData>(@aptos_poker);
        
        let new_game_id = shuffle_data.largest_game_id + 1;
        shuffle_data.largest_game_id = new_game_id;

        let num_cards = get_num_cards_for_deck_type(deck_type);
        let config = GameConfig {
            num_players,
            num_cards,
            deck_type,
        };

        let new_game = Game {
            id: new_game_id,
            owner: creator_addr,
            state: 0, // Created state
            players: vector::empty(),
            signing_addrs: vector::empty(),
            player_pks: vector::empty(),
            aggregate_pk: curve_baby_jubjub::new_point(0, 1), // Identity point
            current_player_index: 0,
            deck: Deck {
                config: deck_type,
                cards: vector::empty(),
                decrypt_record: vector::empty(),
                cards_to_deal: bit_map::empty(),
                player_to_deal: 0,
                x0: vector::empty(),
                x1: vector::empty(),
                y0: vector::empty(),
                y1: vector::empty(),
                selector0: bit_map::empty(),
                selector1: bit_map::empty(),
            },
            nonce: 0,
            player_hands: vector::empty(),
            opening: 0,
            config,
            statistics: GameStatistics {
                total_shuffles: 0,
                total_deals: 0,
                total_opens: 0,
            },
            last_action_time: aptos_framework::timestamp::now_seconds(),
            is_recoverable: true,
            recovery_attempts: 0,
            is_cancelled: false,
            refunded_players: vector::empty(),
            refund_amounts: vector::empty(),
            result: option::none(),
        };

        initialize_deck_efficient(&mut new_game.deck, num_cards);
        table::add(&mut shuffle_data.games, new_game_id, new_game);
        new_game_id
    }

    fun initialize_deck_efficient(deck: &mut Deck, num_cards: u64) {
        deck.cards = vector::empty();
        deck.decrypt_record = vector::empty();
        deck.x0 = vector::empty();
        deck.x1 = vector::empty();
        deck.y0 = vector::empty();
        deck.y1 = vector::empty();

        let i = 0;
        while (i < num_cards) {
            vector::push_back(&mut deck.cards, Card { x0: 0, y0: 0, x1: 0, y1: 0 });
            vector::push_back(&mut deck.decrypt_record, bit_map::empty());
            vector::push_back(&mut deck.x0, 0);
            vector::push_back(&mut deck.x1, 0);
            vector::push_back(&mut deck.y0, 0);
            vector::push_back(&mut deck.y1, 0);
            i = i + 1;
        };
    }

    fun get_num_cards_for_deck_type(deck_type: u8): u64 {
        if (deck_type == 0) { 52 }
        else if (deck_type == 1) { 30 }
        else if (deck_type == 2) { 5 }
        else { abort EINVALID_DECK_TYPE }
    }

    public fun register(game_id: u64) acquires ShuffleManagerData {
        let shuffle_data = borrow_global_mut<ShuffleManagerData>(@aptos_poker);
        let game = table::borrow_mut(&mut shuffle_data.games, game_id);
        assert!(game.state == 0, EINVALID_STATE); // Check if in Created state
        game.state = 1; // Set to Registration state
    }

    public fun player_register(
        player: &signer,
        game_id: u64,
        signing_addr: address,
        pk_x: u256,
        pk_y: u256
    ) acquires ShuffleManagerData, GameContract {
        let shuffle_data = borrow_global_mut<ShuffleManagerData>(@aptos_poker);
        let game = table::borrow_mut(&mut shuffle_data.games, game_id);
        assert!(game.state == 1, EINVALID_STATE); // Check if in Registration state
        
        let player_addr = signer::address_of(player);
        vector::push_back(&mut game.players, player_addr);
        vector::push_back(&mut game.signing_addrs, signing_addr);
        
        let pk = curve_baby_jubjub::new_point(pk_x, pk_y);
        vector::push_back(&mut game.player_pks, pk);
        
        // Update aggregate public key
        game.aggregate_pk = curve_baby_jubjub::point_add(game.aggregate_pk, pk);

        // If this is the last player to join
        if (vector::length(&game.players) == vector::length(&game.player_pks)) {
            game.nonce = curve_baby_jubjub::mulmod(
                curve_baby_jubjub::point_x(&game.aggregate_pk),
                curve_baby_jubjub::point_y(&game.aggregate_pk),
                curve_baby_jubjub::get_q()
            );
            call_game_contract(game_id);
        }
    }

    public fun shuffle(game_id: u64) acquires ShuffleManagerData {
        let shuffle_data = borrow_global_mut<ShuffleManagerData>(@aptos_poker);
        let game = table::borrow_mut(&mut shuffle_data.games, game_id);
        assert!(game.current_player_index == 0, EWRONG_PLAYER_INDEX);
        game.state = 2; // Set to Shuffle state
        emit_player_turn(game_id, game.current_player_index, game.state);
    }

    // Add a new struct for shuffle proof
    struct ShuffleProof has copy, drop {
        a: vector<u256>,
        b: vector<vector<u256>>,
        c: vector<u256>,
        public_inputs: vector<u256>,
    }

    // Update the player_shuffle function to use ShuffleProof
    public fun player_shuffle(
        player: &signer,
        game_id: u64,
        proof: ShuffleProof,
        compressed_deck: CompressedDeck
    ) acquires ShuffleManagerData, ShuffleVerifier, GameContract, VerifierInterface {
        let shuffle_data = borrow_global_mut<ShuffleManagerData>(@aptos_poker);
        let game = table::borrow_mut(&mut shuffle_data.games, game_id);
        
        check_timeout(game);
        assert!(game.state == 2, EINVALID_STATE); // Check if in Shuffle state
        assert!(signer::address_of(player) == *vector::borrow(&game.players, game.current_player_index), ENOT_YOUR_TURN);

        verify_shuffle_proof(game, &proof, &compressed_deck);
        update_deck_with_compressed_efficient(game, compressed_deck);

        game.statistics.total_shuffles = game.statistics.total_shuffles + 1;
        game.last_action_time = aptos_framework::timestamp::now_seconds();

        game.current_player_index = game.current_player_index + 1;
        if (game.current_player_index == vector::length(&game.players)) {
            game.current_player_index = 0;
            game.state = 3; // Move to Deal state
            call_game_contract(game_id);
        } else {
            emit_player_turn(game_id, game.current_player_index, game.state);
        }
    }

    // Update the verify_shuffle_proof function
    fun verify_shuffle_proof(game: &Game, proof: &ShuffleProof, compressed_deck: &CompressedDeck) acquires ShuffleVerifier, VerifierInterface {
        let verifier = borrow_global<ShuffleVerifier>(@aptos_poker);
        let verifier_address = get_verifier_address(game.config.deck_type, verifier);
        
        assert!(vector::length(&proof.a) == 2, EINVALID_PROOF);
        assert!(vector::length(&proof.b) == 2, EINVALID_PROOF);
        assert!(vector::length(&proof.c) == 2, EINVALID_PROOF);

        let public_inputs = generate_shuffle_public_inputs(game, compressed_deck);
        assert!(proof.public_inputs == public_inputs, EINVALID_PROOF);

        // Call the verifier contract
        let verified = call_verifier_contract(verifier_address, proof, &public_inputs);
        assert!(verified, EINVALID_PROOF);
    }

    fun get_verifier_address(deck_type: u8, verifier: &ShuffleVerifier): address {
        if (deck_type == 0) { verifier.deck52_enc_verifier }
        else if (deck_type == 1) { verifier.deck30_enc_verifier }
        else if (deck_type == 2) { verifier.deck5_enc_verifier }
        else { abort EINVALID_DECK_TYPE }
    }

    // Update the call_verifier_contract function
    fun call_verifier_contract(verifier_address: address, proof: &ShuffleProof, public_inputs: &vector<u256>): bool acquires VerifierInterface {
        let verifier_interface = borrow_global<VerifierInterface>(@aptos_poker);
        
        // TODO: Implement the actual call to the verifier contract
        // For now, we'll use a placeholder implementation
        let verified = true;
        for (i in 0..vector::length(public_inputs)) {
            let input = *vector::borrow(public_inputs, i);
            verified = verified && (input != 0);
        };
        verified
    }

    // Add a function to generate public inputs for shuffle proof
    fun generate_shuffle_public_inputs(game: &Game, compressed_deck: &CompressedDeck): vector<u256> {
        let public_inputs = vector::empty<u256>();
        // Add logic to generate public inputs based on game state and compressed deck
        // This should match the logic in the Solidity contract
        vector::push_back(&mut public_inputs, game.nonce);
        vector::push_back(&mut public_inputs, curve_baby_jubjub::point_x(&game.aggregate_pk));
        vector::push_back(&mut public_inputs, curve_baby_jubjub::point_y(&game.aggregate_pk));
        // Add more public inputs as needed
        public_inputs
    }

    struct CompressedDeck has copy, drop {
        x0: vector<u256>,
        x1: vector<u256>,
        selector0: BitMap256,
        selector1: BitMap256,
    }

    // Helper functions
    fun emit_player_turn(game_id: u64, player_index: u64, state: u8) {
        event::emit(PlayerTurnEvent {
            game_id,
            player_index,
            state,
        });
    }

    public fun get_player_idx(game_id: u64, player: address): u64 acquires ShuffleManagerData {
        let shuffle_data = borrow_global<ShuffleManagerData>(@aptos_poker);
        let game = table::borrow(&shuffle_data.games, game_id);
        
        let i = 0;
        let players_len = vector::length(&game.players);
        while (i < players_len) {
            if (*vector::borrow(&game.players, i) == player) {
                return i
            };
            i = i + 1;
        };

        let signing_addrs_len = vector::length(&game.signing_addrs);
        i = 0;
        while (i < signing_addrs_len) {
            if (*vector::borrow(&game.signing_addrs, i) == player) {
                return i
            };
            i = i + 1;
        };

        INVALID_INDEX
    }

    public fun get_num_cards(game_id: u64): u64 acquires ShuffleManagerData {
        let shuffle_data = borrow_global<ShuffleManagerData>(@aptos_poker);
        assert!(game_id <= shuffle_data.largest_game_id, EINVALID_GAME_ID);
        let game = table::borrow(&shuffle_data.games, game_id);
        vector::length(&game.deck.cards)
    }

    public fun game_state(game_id: u64): u8 acquires ShuffleManagerData {
        let shuffle_data = borrow_global<ShuffleManagerData>(@aptos_poker);
        assert!(game_id <= shuffle_data.largest_game_id, EINVALID_GAME_ID);
        let game = table::borrow(&shuffle_data.games, game_id);
        game.state
    }

    public fun cur_player_index(game_id: u64): u64 acquires ShuffleManagerData {
        let shuffle_data = borrow_global<ShuffleManagerData>(@aptos_poker);
        assert!(game_id <= shuffle_data.largest_game_id, EINVALID_GAME_ID);
        let game = table::borrow(&shuffle_data.games, game_id);
        game.current_player_index
    }

    public fun get_decrypt_record(game_id: u64, card_idx: u64): BitMap256 acquires ShuffleManagerData {
        let shuffle_data = borrow_global<ShuffleManagerData>(@aptos_poker);
        assert!(game_id <= shuffle_data.largest_game_id, EINVALID_GAME_ID);
        let game = table::borrow(&shuffle_data.games, game_id);
        assert!(card_idx < vector::length(&game.deck.cards), EINVALID_CARD_INDEX);
        *vector::borrow(&game.deck.decrypt_record, card_idx)
    }

    public fun query_aggregated_pk(game_id: u64): (u256, u256) acquires ShuffleManagerData {
        let shuffle_data = borrow_global<ShuffleManagerData>(@aptos_poker);
        let game = table::borrow(&shuffle_data.games, game_id);
        assert!(game.state != 1, EINVALID_STATE); // Not in Registration state
        (curve_baby_jubjub::point_x(&game.aggregate_pk), curve_baby_jubjub::point_y(&game.aggregate_pk))
    }

    public fun card_config(game_id: u64): u8 acquires ShuffleManagerData {
        let shuffle_data = borrow_global<ShuffleManagerData>(@aptos_poker);
        let game = table::borrow(&shuffle_data.games, game_id);
        game.deck.config
    }

    public fun query_deck(game_id: u64): (vector<u256>, vector<u256>, vector<u256>, vector<u256>, BitMap256, BitMap256, BitMap256) acquires ShuffleManagerData {
        let shuffle_data = borrow_global<ShuffleManagerData>(@aptos_poker);
        let game = table::borrow(&shuffle_data.games, game_id);
        (
            game.deck.x0,
            game.deck.x1,
            game.deck.y0,
            game.deck.y1,
            game.deck.selector0,
            game.deck.selector1,
            game.deck.cards_to_deal
        )
    }

    public fun deal_cards_to(game_owner: &signer, game_id: u64, cards: BitMap256, player_id: u64) acquires ShuffleManagerData {
        let shuffle_data = borrow_global_mut<ShuffleManagerData>(@aptos_poker);
        let game = table::borrow_mut(&mut shuffle_data.games, game_id);
        
        assert!(signer::address_of(game_owner) == game.owner, ENOT_GAME_OWNER);
        assert!(game.current_player_index == 0, EINVALID_STATE);
        assert!(player_id < vector::length(&game.players), EINVALID_PLAYER_ID);

        if (game.state != 3) { // Assuming 3 is the Deal state
            game.state = 3;
        };
        game.deck.cards_to_deal = cards;
        game.deck.player_to_deal = player_id;

        if (player_id == 0) {
            game.current_player_index = 1;
        };

        emit_player_turn(game_id, game.current_player_index, 3); // 3 for Deal state
    }

    public fun player_deal_cards(
        player: &signer,
        game_id: u64,
        proofs: vector<ShuffleProof>,
        decrypted_cards: vector<Card>,
        init_deltas: vector<vector<u256>>
    ) acquires ShuffleManagerData, ShuffleVerifier, GameContract, VerifierInterface {
        let shuffle_data = borrow_global_mut<ShuffleManagerData>(@aptos_poker);
        let game = table::borrow_mut(&mut shuffle_data.games, game_id);
        
        check_timeout(game);
        assert!(game.state == 3, EINVALID_STATE); // 3 for Deal state
        assert!(signer::address_of(player) == *vector::borrow(&game.players, game.current_player_index), ENOT_YOUR_TURN);

        let number_cards_to_deal = bit_map::member_count_up_to(&game.deck.cards_to_deal, vector::length(&game.deck.cards));
        assert!(vector::length(&proofs) == number_cards_to_deal, EINVALID_CARD_INDEX);
        assert!(vector::length(&decrypted_cards) == number_cards_to_deal, EINVALID_CARD_INDEX);
        assert!(vector::length(&init_deltas) == number_cards_to_deal, EINVALID_CARD_INDEX);

        let counter = 0;
        let i = 0;
        while (i < vector::length(&game.deck.cards)) {
            if (bit_map::get(&game.deck.cards_to_deal, i)) {
                let proof = vector::borrow(&proofs, counter);
                let decrypted_card = vector::borrow(&decrypted_cards, counter);
                let init_delta = vector::borrow(&init_deltas, counter);
                update_decrypted_card_internal(game, i, proof, decrypted_card, init_delta);
                counter = counter + 1;
            };
            if (counter == number_cards_to_deal) {
                break
            };
            i = i + 1;
        };

        game.statistics.total_deals = game.statistics.total_deals + 1;
        game.last_action_time = aptos_framework::timestamp::now_seconds();

        game.current_player_index = game.current_player_index + 1;
        if (game.current_player_index == game.deck.player_to_deal) {
            game.current_player_index = game.current_player_index + 1;
        };

        if (game.current_player_index == vector::length(&game.players)) {
            game.current_player_index = 0;
            let player_hand = vector::borrow_mut(&mut game.player_hands, game.deck.player_to_deal);
            *player_hand = *player_hand + number_cards_to_deal;
            call_game_contract(game_id);
        } else {
            emit_player_turn(game_id, game.current_player_index, 3); // 3 for Deal state
        };
    }

    fun update_decrypted_card_internal(
        game: &mut Game,
        card_index: u64,
        proof: &ShuffleProof,
        decrypted_card: &Card,
        init_delta: &vector<u256>
    ) acquires ShuffleVerifier, VerifierInterface {
        assert!(!bit_map::get(vector::borrow(&game.deck.decrypt_record, card_index), game.current_player_index), EINVALID_STATE);

        if (bit_map::get(vector::borrow(&game.deck.decrypt_record, card_index), 0) == false) {
            let y0 = curve_baby_jubjub::recover_y(*vector::borrow(&game.deck.x0, card_index), *vector::borrow(init_delta, 0), bit_map::get(&game.deck.selector0, card_index));
            let y1 = curve_baby_jubjub::recover_y(*vector::borrow(&game.deck.x1, card_index), *vector::borrow(init_delta, 1), bit_map::get(&game.deck.selector1, card_index));
            *vector::borrow_mut(&mut game.deck.y0, card_index) = y0;
            *vector::borrow_mut(&mut game.deck.y1, card_index) = y1;
        };

        verify_decrypt_proof(game, proof, decrypted_card, card_index);

        *vector::borrow_mut(&mut game.deck.x1, card_index) = decrypted_card.x1;
        *vector::borrow_mut(&mut game.deck.y1, card_index) = decrypted_card.y1;
        bit_map::set(vector::borrow_mut(&mut game.deck.decrypt_record, card_index), game.current_player_index);
    }

    fun update_decrypted_card(
        game_id: u64,
        card_index: u64,
        proof: ShuffleProof,
        decrypted_card: Card,
        init_delta: vector<u256>
    ) acquires ShuffleManagerData, ShuffleVerifier, VerifierInterface {
        let shuffle_data = borrow_global_mut<ShuffleManagerData>(@aptos_poker);
        let game = table::borrow_mut(&mut shuffle_data.games, game_id);
        
        assert!(!bit_map::get(vector::borrow(&game.deck.decrypt_record, card_index), game.current_player_index), EINVALID_STATE);

        if (bit_map::get(vector::borrow(&game.deck.decrypt_record, card_index), 0) == false) {
            let y0 = curve_baby_jubjub::recover_y(*vector::borrow(&game.deck.x0, card_index), *vector::borrow(&init_delta, 0), bit_map::get(&game.deck.selector0, card_index));
            let y1 = curve_baby_jubjub::recover_y(*vector::borrow(&game.deck.x1, card_index), *vector::borrow(&init_delta, 1), bit_map::get(&game.deck.selector1, card_index));
            *vector::borrow_mut(&mut game.deck.y0, card_index) = y0;
            *vector::borrow_mut(&mut game.deck.y1, card_index) = y1;
        };

        verify_decrypt_proof(game, &proof, &decrypted_card, card_index);

        *vector::borrow_mut(&mut game.deck.x1, card_index) = decrypted_card.x1;
        *vector::borrow_mut(&mut game.deck.y1, card_index) = decrypted_card.y1;
        bit_map::set(vector::borrow_mut(&mut game.deck.decrypt_record, card_index), game.current_player_index);
    }

    // Update the verify_decrypt_proof function
    fun verify_decrypt_proof(game: &Game, proof: &ShuffleProof, decrypted_card: &Card, card_index: u64) acquires ShuffleVerifier, VerifierInterface {
        let verifier = borrow_global<ShuffleVerifier>(@aptos_poker);
        
        assert!(vector::length(&proof.a) == 2, EINVALID_PROOF);
        assert!(vector::length(&proof.b) == 2, EINVALID_PROOF);
        assert!(vector::length(&proof.c) == 2, EINVALID_PROOF);

        let public_inputs = generate_decrypt_public_inputs(game, decrypted_card, card_index);
        assert!(proof.public_inputs == public_inputs, EINVALID_PROOF);

        // Call the decrypt verifier contract
        let verified = call_verifier_contract(verifier.decrypt_verifier, proof, &public_inputs);
        assert!(verified, EINVALID_PROOF);
    }

    // Add a function to generate public inputs for decrypt proof
    fun generate_decrypt_public_inputs(game: &Game, decrypted_card: &Card, card_index: u64): vector<u256> {
        let public_inputs = vector::empty<u256>();
        // Add logic to generate public inputs based on game state and decrypted card
        // This should match the logic in the Solidity contract
        vector::push_back(&mut public_inputs, decrypted_card.x0);
        vector::push_back(&mut public_inputs, decrypted_card.y0);
        vector::push_back(&mut public_inputs, *vector::borrow(&game.deck.x0, card_index));
        vector::push_back(&mut public_inputs, *vector::borrow(&game.deck.y0, card_index));
        vector::push_back(&mut public_inputs, *vector::borrow(&game.deck.x1, card_index));
        vector::push_back(&mut public_inputs, *vector::borrow(&game.deck.y1, card_index));
        vector::push_back(&mut public_inputs, curve_baby_jubjub::point_x(vector::borrow(&game.player_pks, game.current_player_index)));
        vector::push_back(&mut public_inputs, curve_baby_jubjub::point_y(vector::borrow(&game.player_pks, game.current_player_index)));
        public_inputs
    }

    public fun open_cards(game_owner: &signer, game_id: u64, player_id: u64, opening_num: u8) acquires ShuffleManagerData {
        let shuffle_data = borrow_global_mut<ShuffleManagerData>(@aptos_poker);
        let game = table::borrow_mut(&mut shuffle_data.games, game_id);
        
        assert!(signer::address_of(game_owner) == game.owner, ENOT_GAME_OWNER);
        assert!((opening_num as u64) <= *vector::borrow(&game.player_hands, player_id), ENOT_ENOUGH_CARDS);

        game.opening = (opening_num as u64);
        game.current_player_index = player_id;
        game.state = 4; // 4 for Open state
        emit_player_turn(game_id, player_id, 4); // 4 for Open state
    }

    public fun player_open_cards(
        player: &signer,
        game_id: u64,
        cards: BitMap256,
        proofs: vector<ShuffleProof>,
        decrypted_cards: vector<Card>
    ) acquires ShuffleManagerData, ShuffleVerifier, GameContract, VerifierInterface {
        let shuffle_data = borrow_global_mut<ShuffleManagerData>(@aptos_poker);
        let game = table::borrow_mut(&mut shuffle_data.games, game_id);
        
        check_timeout(game);
        assert!(game.state == 4, EINVALID_STATE); // 4 for Open state
        assert!(signer::address_of(player) == *vector::borrow(&game.players, game.current_player_index), ENOT_YOUR_TURN);

        let number_cards_to_open = bit_map::member_count_up_to(&cards, vector::length(&game.deck.cards));
        assert!(number_cards_to_open == game.opening, EINVALID_CARD_INDEX);
        assert!(vector::length(&proofs) == number_cards_to_open, EINVALID_CARD_INDEX);
        assert!(vector::length(&decrypted_cards) == number_cards_to_open, EINVALID_CARD_INDEX);

        let dummy = vector::empty<u256>();
        vector::push_back(&mut dummy, 0);
        vector::push_back(&mut dummy, 0);

        let counter = 0;
        let i = 0;
        while (i < vector::length(&game.deck.cards)) {
            if (bit_map::get(&cards, i)) {
                let proof = vector::borrow(&proofs, counter);
                let decrypted_card = vector::borrow(&decrypted_cards, counter);
                update_decrypted_card_internal(game, i, proof, decrypted_card, &dummy);
                counter = counter + 1;
            };
            if (counter == number_cards_to_open) {
                break
            };
            i = i + 1;
        };

        game.statistics.total_opens = game.statistics.total_opens + 1;
        game.last_action_time = aptos_framework::timestamp::now_seconds();

        game.opening = 0;
        let player_hand = vector::borrow_mut(&mut game.player_hands, game.current_player_index);
        *player_hand = *player_hand - number_cards_to_open;
        call_game_contract(game_id);
    }

    public fun end_game(game_owner: &signer, game_id: u64, winner: address, final_scores: vector<u64>) acquires ShuffleManagerData {
        set_game_result(game_owner, game_id, winner, final_scores);
        let shuffle_data = borrow_global_mut<ShuffleManagerData>(@aptos_poker);
        let game = table::borrow_mut(&mut shuffle_data.games, game_id);
        
        assert!(signer::address_of(game_owner) == game.owner, ENOT_GAME_OWNER);

        end_game_internal(game);
        let _removed_game = table::remove(&mut shuffle_data.games, game_id);
    }

    // Add a function to get detailed game state
    public fun get_detailed_game_state(game_id: u64): (u8, u64, u64, bool, bool, u8, GameStatistics) acquires ShuffleManagerData {
        let shuffle_data = borrow_global_mut<ShuffleManagerData>(@aptos_poker);
        let game = table::borrow_mut(&mut shuffle_data.games, game_id);
        check_timeout(game);
        (game.state, game.current_player_index, game.last_action_time, game.is_recoverable, game.is_cancelled, game.recovery_attempts, game.statistics)
    }

    // Add a function to attempt game recovery
    public fun attempt_game_recovery(game_owner: &signer, game_id: u64, recovery_action: u8) acquires ShuffleManagerData, GameContract {
        let shuffle_data = borrow_global_mut<ShuffleManagerData>(@aptos_poker);
        let game = table::borrow_mut(&mut shuffle_data.games, game_id);
        
        assert!(signer::address_of(game_owner) == game.owner, ENOT_GAME_OWNER);
        assert!(game.state == 6, EINVALID_STATE); // 6 for GameError state
        assert!(game.is_recoverable, EGAME_NOT_RECOVERABLE);
        assert!(game.recovery_attempts < 3, EINVALID_RECOVERY_ATTEMPT);

        let success = false;
        if (recovery_action == 0) { // Reset to previous state
            game.state = game.state - 1;
            game.current_player_index = 0;
            success = true;
        } else if (recovery_action == 1) { // Skip current player
            game.current_player_index = (game.current_player_index + 1) % vector::length(&game.players);
            success = true;
        } else if (recovery_action == 2) { // End game
            end_game_internal(game);
            success = true;
        };

        game.recovery_attempts = game.recovery_attempts + 1;
        game.last_action_time = aptos_framework::timestamp::now_seconds();

        event::emit(GameRecoveryAttemptEvent {
            game_id,
            recovery_action,
            success,
        });

        if (success && recovery_action != 2) {
            call_game_contract(game_id);
        }
    }

    // Update the check_timeout function
    fun check_timeout(game: &mut Game) {
        let current_time = aptos_framework::timestamp::now_seconds();
        if (current_time - game.last_action_time > 300 && !game.is_cancelled) { // 5 minutes timeout
            game.state = 6; // GameError state
            event::emit(PlayerTimeoutEvent {
                game_id: game.id,
                player_index: game.current_player_index,
            });
            if (!game.is_recoverable || game.recovery_attempts >= 3) {
                end_game_internal(game);
            };
        };
    }

    // Add a function to get the game recovery status
    public fun get_game_recovery_status(game_id: u64): (bool, u8) acquires ShuffleManagerData {
        let shuffle_data = borrow_global<ShuffleManagerData>(@aptos_poker);
        let game = table::borrow(&shuffle_data.games, game_id);
        (game.is_recoverable, game.recovery_attempts)
    }

    // Add a more efficient deck update function
    fun update_deck_with_compressed_efficient(game: &mut Game, compressed_deck: CompressedDeck) {
        let deck_length = vector::length(&game.deck.cards);
        assert!(vector::length(&compressed_deck.x0) == deck_length, EINVALID_CARD_INDEX);
        assert!(vector::length(&compressed_deck.x1) == deck_length, EINVALID_CARD_INDEX);

        game.deck.x0 = compressed_deck.x0;
        game.deck.x1 = compressed_deck.x1;
        game.deck.selector0 = compressed_deck.selector0;
        game.deck.selector1 = compressed_deck.selector1;

        // Reset y0 and y1 as they will be recalculated during decryption
        game.deck.y0 = vector::empty();
        game.deck.y1 = vector::empty();
        let i = 0;
        while (i < deck_length) {
            vector::push_back(&mut game.deck.y0, 0);
            vector::push_back(&mut game.deck.y1, 0);
            i = i + 1;
        };
    }

    // Add a function to get the current game contract address
    public fun get_game_contract_address(): address acquires GameContract {
        let game_contract = borrow_global<GameContract>(@aptos_poker);
        game_contract.address
    }

    // Add a function to update the game contract address
    public fun update_game_contract_address(account: &signer, new_address: address) acquires GameContract {
        assert!(signer::address_of(account) == @aptos_poker, ENOT_AUTHORIZED);
        let game_contract = borrow_global_mut<GameContract>(@aptos_poker);
        game_contract.address = new_address;
    }

    // Add a function to get the verifier interface address
    public fun get_verifier_interface_address(): address acquires VerifierInterface {
        let verifier_interface = borrow_global<VerifierInterface>(@aptos_poker);
        verifier_interface.address
    }

    // Add a function to update the verifier interface address
    public fun update_verifier_interface_address(account: &signer, new_address: address) acquires VerifierInterface {
        assert!(signer::address_of(account) == @aptos_poker, ENOT_AUTHORIZED);
        let verifier_interface = borrow_global_mut<VerifierInterface>(@aptos_poker);
        verifier_interface.address = new_address;
    }

    // Add a function to get the deck state
    public fun get_deck_state(game_id: u64): (vector<u256>, vector<u256>, vector<u256>, vector<u256>, BitMap256, BitMap256, BitMap256) acquires ShuffleManagerData {
        let shuffle_data = borrow_global<ShuffleManagerData>(@aptos_poker);
        let game = table::borrow(&shuffle_data.games, game_id);
        (
            game.deck.x0,
            game.deck.x1,
            game.deck.y0,
            game.deck.y1,
            game.deck.selector0,
            game.deck.selector1,
            game.deck.cards_to_deal
        )
    }

    fun call_game_contract(game_id: u64) acquires ShuffleManagerData, GameContract {
        let shuffle_data = borrow_global_mut<ShuffleManagerData>(@aptos_poker);
        let game = table::borrow_mut(&mut shuffle_data.games, game_id);
        let game_contract = borrow_global<GameContract>(@aptos_poker);
        
        // TODO: Implement the actual call to the game contract
        // For now, we'll just emit an event
        event::emit(GameContractCalledEvent {
            game_id,
            action: b"game_contract_called",
            current_state: game.state,
        });

        // Update game state based on the current state
        if (game.state == 2) { // Shuffle state
            game.state = 3; // Move to Deal state
        } else if (game.state == 3) { // Deal state
            if (all_cards_dealt(game)) {
                game.state = 4; // Move to Open state
            }
        } else if (game.state == 4) { // Open state
            if (all_cards_opened(game)) {
                game.state = 5; // Move to Complete state
            }
        }
    }

    public fun set_game_result(game_owner: &signer, game_id: u64, winner: address, final_scores: vector<u64>) acquires ShuffleManagerData {
        let shuffle_data = borrow_global_mut<ShuffleManagerData>(@aptos_poker);
        let game = table::borrow_mut(&mut shuffle_data.games, game_id);
        
        assert!(signer::address_of(game_owner) == game.owner, ENOT_GAME_OWNER);
        assert!(game.state == 5, EINVALID_STATE); // 5 for Complete state
        assert!(option::is_none(&game.result), EGAME_ALREADY_ENDED);

        game.result = option::some(GameResult {
            winner,
            final_scores,
        });

        event::emit(GameResultEvent {
            game_id,
            winner,
            final_scores,
        });
    }

    fun end_game_internal(game: &mut Game) {
        game.state = 5; // 5 for Complete state
        let i = 0;
        while (i < vector::length(&game.players)) {
            event::emit(PlayerTurnEvent {
                game_id: game.id,
                player_index: i,
                state: 5,
            });
            i = i + 1;
        };
    }

    // ... (remaining functions stay the same)
}