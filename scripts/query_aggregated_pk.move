script {
    use aptos_poker::shuffle_manager;
    use std::debug;

    fun query_aggregated_pk(game_id: u64) {
        let (pk_x, pk_y) = shuffle_manager::query_aggregated_pk(game_id);
        debug::print(&pk_x);
        debug::print(&pk_y);
    }
}