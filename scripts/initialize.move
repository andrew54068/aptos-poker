script {
    use aptos_poker::shuffle_manager;

    fun initialize(admin: signer) {
        shuffle_manager::initialize(&admin);
    }
}