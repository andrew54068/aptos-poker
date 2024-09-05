script {
    use aptos_poker::shuffle_manager;
    use std::debug;

    fun query_card_value(game_id: u64, card_idx: u64) {
        let (x0, y0, x1, y1) = shuffle_manager::query_card_value(game_id, card_idx);
        debug::print(&x0);
        debug::print(&y0);
        debug::print(&x1);
        debug::print(&y1);
    }
}