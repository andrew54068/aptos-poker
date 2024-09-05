script {
    use aptos_poker::shuffle_manager;

    fun register_game(game_id: u64) {
        shuffle_manager::register(game_id);
    }
}