script {
    use aptos_poker::shuffle_manager;

    fun start_shuffle(game_id: u64) {
        shuffle_manager::shuffle(game_id);
    }
}