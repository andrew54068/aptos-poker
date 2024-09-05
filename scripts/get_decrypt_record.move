script {
    use aptos_poker::shuffle_manager;
    use std::debug;

    fun get_decrypt_record(game_id: u64, card_idx: u64) {
        let decrypt_record = shuffle_manager::get_decrypt_record(game_id, card_idx);
        debug::print(&decrypt_record);
    }
}