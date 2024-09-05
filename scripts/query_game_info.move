script {
    use aptos_poker::shuffle_manager;
    use std::debug;

    fun query_game_info(game_id: u64) {
        let state = shuffle_manager::game_state(game_id);
        let num_cards = shuffle_manager::get_num_cards(game_id);
        let (x0, x1, selector0, selector1) = shuffle_manager::query_deck(game_id);
        
        debug::print(&state);
        debug::print(&num_cards);
        debug::print(&x0);
        debug::print(&x1);
        debug::print(&selector0);
        debug::print(&selector1);
    }
}