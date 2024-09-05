#[test_only]
module aptos_poker::shuffle_manager_tests {
    use std::signer;
    use std::vector;
    use aptos_framework::account;
    use aptos_poker::shuffle_manager;
    use aptos_poker::bit_map;

    fun setup_test_env(): signer {
        let admin = account::create_account_for_test(@aptos_poker);
        shuffle_manager::initialize(&admin);
        admin
    }

    #[test]
    fun test_shuffle() {
        let admin = setup_test_env();
        let player = account::create_account_for_test(@0x123);

        let game_id = shuffle_manager::create_shuffle_game(&player, 2);
        shuffle_manager::register(game_id);
        shuffle_manager::player_register(&player, game_id, @0x123, 1, 2);

        shuffle_manager::shuffle(game_id);
        assert!(shuffle_manager::game_state(game_id) == 2, 0); // Shuffle state
        assert!(shuffle_manager::cur_player_index(game_id) == 0, 1);
    }

    #[test]
    fun test_get_num_cards() {
        let admin = setup_test_env();
        let player = account::create_account_for_test(@0x123);

        let game_id = shuffle_manager::create_shuffle_game(&player, 2);
        shuffle_manager::register(game_id);
        shuffle_manager::card_config(game_id, 1); // Set config to 1 (assuming this adds cards)

        let num_cards = shuffle_manager::get_num_cards(game_id);
        assert!(num_cards > 0, 0); // The exact number depends on the implementation of card_config
    }

    #[test]
    fun test_get_decrypt_record() {
        let admin = setup_test_env();
        let player = account::create_account_for_test(@0x123);

        let game_id = shuffle_manager::create_shuffle_game(&player, 2);
        shuffle_manager::register(game_id);
        shuffle_manager::card_config(game_id, 1); // Set config to 1 (assuming this adds cards)

        let decrypt_record = shuffle_manager::get_decrypt_record(game_id, 0);
        // Initially, the decrypt record should be empty
        assert!(bit_map::count_up_to(&decrypt_record, 64) == 0, 0);
    }

    #[test]
    fun test_query_aggregated_pk() {
        let admin = setup_test_env();
        let player1 = account::create_account_for_test(@0x123);
        let player2 = account::create_account_for_test(@0x456);

        let game_id = shuffle_manager::create_shuffle_game(&player1, 2);
        shuffle_manager::register(game_id);
        shuffle_manager::player_register(&player1, game_id, @0x123, 1, 2);
        shuffle_manager::player_register(&player2, game_id, @0x456, 3, 4);

        let (pk_x, pk_y) = shuffle_manager::query_aggregated_pk(game_id);
        // The exact values depend on the implementation, but they should not be zero
        assert!(pk_x != 0 && pk_y != 0, 0);
    }

    #[test]
    #[expected_failure(abort_code = shuffle_manager::EINVALID_STATE)]
    fun test_query_aggregated_pk_invalid_state() {
        let admin = setup_test_env();
        let player = account::create_account_for_test(@0x123);

        let game_id = shuffle_manager::create_shuffle_game(&player, 2);
        shuffle_manager::query_aggregated_pk(game_id); // Should fail as the game is still in Created state
    }

    #[test]
    #[expected_failure(abort_code = shuffle_manager::EINVALID_GAME_ID)]
    fun test_invalid_game_id() {
        let admin = setup_test_env();
        shuffle_manager::game_state(999); // Should fail with invalid game ID
    }
}