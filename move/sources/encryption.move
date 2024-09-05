module aptos_poker::encryption {
    struct EncryptedValue has copy, drop, store { 
        value: u64,
    }

    public fun encrypt(value: u64, key: u64): EncryptedValue {
        EncryptedValue { value: value ^ key }
    }

    public fun add(a: EncryptedValue, b: EncryptedValue): EncryptedValue {
        EncryptedValue { value: a.value + b.value }
    }

    public fun decrypt(encrypted: EncryptedValue, key: u64): u64 {
        encrypted.value ^ key
    }
}