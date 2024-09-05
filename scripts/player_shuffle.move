script {
    use aptos_poker::shuffle_manager;

    fun player_shuffle(player: signer, game_id: u64) {
        shuffle_manager::player_shuffle(&player, game_id);
    }
}