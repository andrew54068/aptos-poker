script {
    use aptos_poker::shuffle_manager;

    fun create_game(creator: signer, num_players: u8) {
        let game_id = shuffle_manager::create_shuffle_game(&creator, num_players);
        // You might want to emit an event or return the game_id somehow
    }
}