script {
    use aptos_poker::shuffle_manager;

    fun register_player(player: signer, game_id: u64, signing_addr: address, pk_x: u256, pk_y: u256) {
        shuffle_manager::player_register(&player, game_id, signing_addr, pk_x, pk_y);
    }
}