module aptos_poker::bit_map {
    use std::error;

    struct BitMap256 has copy, drop, store {
        data: u256,
    }

    const EINDEX_OUT_OF_RANGE: u64 = 1;

    public fun empty(): BitMap256 {
        BitMap256 { data: 0 }
    }

    public fun get(bitmap: &BitMap256, index: u64): bool {
        assert!(index < 256, error::invalid_argument(EINDEX_OUT_OF_RANGE));
        let mask = 1u256 << ((index & 0xff) as u8);
        (bitmap.data & mask) != 0
    }

    public fun set_to(bitmap: &mut BitMap256, index: u64, value: bool) {
        if (value) {
            set(bitmap, index);
        } else {
            unset(bitmap, index);
        }
    }

    public fun set(bitmap: &mut BitMap256, index: u64) {
        assert!(index < 256, error::invalid_argument(EINDEX_OUT_OF_RANGE));
        let mask = 1u256 << ((index & 0xff) as u8);
        bitmap.data = bitmap.data | mask;
    }

    public fun unset(bitmap: &mut BitMap256, index: u64) {
        assert!(index < 256, error::invalid_argument(EINDEX_OUT_OF_RANGE));
        let mask = 1u256 << ((index & 0xff) as u8);
        bitmap.data = bitmap.data & (0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ^ mask);
    }

    public fun member_count_up_to(bitmap: &BitMap256, up_to: u64): u64 {
        let count = 0;
        let i = 0;
        while (i < up_to) {
            if (get(bitmap, i)) {
                count = count + 1;
            };
            i = i + 1;
        };
        count
    }
}